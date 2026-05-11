#!/usr/bin/env bash
# anders-dotfiles sync-settings.sh
#
# Apply portable-key updates from the dotfiles template into each machine's
# live ~/.claude*/settings.json. Machine-specific UI preferences are preserved.
#
# Default = dry-run (show what would change). Use --apply to write.
#
# WHY: install.sh treats settings.json as bootstrap-then-leave-alone (CC writes
# UI prefs to it on every change; can't be a symlink). When the template gets
# new permissions/hooks/plugins, this propagates only those to each machine.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME}"
APPLY=0

usage() {
  cat <<EOF
sync-settings.sh — propagate portable settings.json keys from dotfiles to live

Usage: $0 [--apply]

Default mode is dry-run: prints what would change, writes nothing.
With --apply: backs up each live file (.pre-sync.<timestamp>) and writes the
              merged result.

Portable keys (template -> live):  permissions, hooks, statusLine, enabledPlugins,
                                   effortLevel, skipAutoPermissionPrompt
Machine keys  (live preserved):    theme, model, voiceEnabled, autoDreamEnabled,
                                   tui, cleanupPeriodDays, skillListingBudgetFraction
Unknown keys: flagged but not synced — add to PORTABLE_KEYS in this script if
              they belong with the portable set.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

python3 - "$REPO" "$HOME_DIR" "$APPLY" <<'PY'
import json, os, sys, shutil, datetime

REPO  = sys.argv[1]
HOME  = sys.argv[2]
APPLY = sys.argv[3] == "1"

PORTABLE_KEYS = ["permissions", "hooks", "statusLine", "enabledPlugins",
                 "effortLevel", "skipAutoPermissionPrompt"]
MACHINE_KEYS  = ["theme", "model", "voiceEnabled", "autoDreamEnabled", "tui",
                 "cleanupPeriodDays", "skillListingBudgetFraction"]

PROFILES = [
    ("claude-full",    ".claude-full"),
    ("claude-partner", ".claude-partner"),
]

def load(path):
    with open(path) as f:
        return json.load(f)

def section_summary(t_val, l_val):
    if isinstance(t_val, dict) and isinstance(l_val, dict):
        added   = sorted(set(t_val) - set(l_val))
        removed = sorted(set(l_val) - set(t_val))
        changed = sorted(k for k in (set(t_val) & set(l_val)) if t_val[k] != l_val[k])
        bits = []
        if added:   bits.append(f"+{len(added)} ({', '.join(added[:3])}{'...' if len(added)>3 else ''})")
        if removed: bits.append(f"-{len(removed)} ({', '.join(removed[:3])}{'...' if len(removed)>3 else ''})")
        if changed: bits.append(f"~{len(changed)}")
        return ", ".join(bits) if bits else "differs (deep)"
    if isinstance(t_val, list) and isinstance(l_val, list):
        added   = [x for x in t_val if x not in l_val]
        removed = [x for x in l_val if x not in t_val]
        bits = []
        if added:   bits.append(f"+{len(added)}")
        if removed: bits.append(f"-{len(removed)}")
        return ", ".join(bits) if bits else "differs (deep)"
    return f"replaced (was {type(l_val).__name__}, now {type(t_val).__name__})"

total_sections = 0
total_files_to_change = 0

for tdir, ldir in PROFILES:
    tpath = os.path.join(REPO, tdir, "settings.json")
    lpath = os.path.join(HOME, ldir, "settings.json")
    print(f"\n=== {ldir}/settings.json ===")
    if not os.path.isfile(tpath):
        print(f"  (no template at {tpath} — skipping)")
        continue
    if not os.path.isfile(lpath):
        print(f"  (no live file — run install.sh to bootstrap; skipping sync)")
        continue

    try:
        template = load(tpath)
        live     = load(lpath)
    except json.JSONDecodeError as e:
        print(f"  ERROR: invalid JSON ({e}) — skipping")
        continue

    plan = []  # (key, summary)
    for key in PORTABLE_KEYS:
        if key not in template:
            continue
        if live.get(key) != template[key]:
            if key not in live:
                plan.append((key, "(new section, would be added)"))
            else:
                plan.append((key, section_summary(template[key], live[key])))

    unknown_in_template = [k for k in template
                           if k not in PORTABLE_KEYS and k not in MACHINE_KEYS]

    if not plan and not unknown_in_template:
        print("  in sync — no portable changes")
        continue

    if plan:
        for key, summary in plan:
            print(f"  PORTABLE  {key}: {summary}")
        total_sections += len(plan)
        total_files_to_change += 1

    if unknown_in_template:
        print(f"  UNKNOWN   keys in template not classified: {unknown_in_template}")
        print( "            (add to PORTABLE_KEYS or MACHINE_KEYS in this script)")

    if APPLY and plan:
        ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        backup = f"{lpath}.pre-sync.{ts}"
        shutil.copy2(lpath, backup)
        print(f"  BACK      {backup}")
        for key, _ in plan:
            live[key] = template[key]
        tmp = lpath + ".tmp"
        with open(tmp, "w") as f:
            json.dump(live, f, indent=2)
            f.write("\n")
        os.replace(tmp, lpath)
        print(f"  APPL      {lpath} updated")

print()
if APPLY:
    print(f"Done. {total_sections} portable section(s) across {total_files_to_change} file(s) written.")
elif total_sections:
    print(f"Dry run: {total_sections} portable section(s) across {total_files_to_change} file(s) would be written.")
    print("Re-run with --apply to write (each live file is backed up first).")
else:
    print("Dry run: all live files in sync with template.")
PY
