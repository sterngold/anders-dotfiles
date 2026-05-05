#!/usr/bin/env python3
"""claude-usage-launcher.py — wrap phuryn/claude-usage to cover Vlad's 3 CC profiles.

Vlad runs cc-full (~/.claude-full), cc-build (~/.claude-build), and the default
profile (~/.claude). Each writes transcripts to its own CLAUDE_CONFIG_DIR/projects
directory.

Upstream's `scanner.DEFAULT_PROJECTS_DIRS` only lists the default ~/.claude/projects
plus Xcode's. The dashboard's `/api/rescan` POST endpoint and `cli.cmd_dashboard`'s
own scan-on-open both call `scanner.scan(projects_dirs=DEFAULT_PROJECTS_DIRS)`, AND
the rescan endpoint deletes the DB file before re-scanning — so a rescan-button
press wipes all cc-build and cc-full data every time.

Fix: monkey-patch `scanner.DEFAULT_PROJECTS_DIRS` at launch time so all of Vlad's
profiles are part of the default scan list. Then dispatch to upstream cli.py.

Source of truth: ~/anders-dotfiles/.local/lib/claude-usage-launcher.py
Wrapper: ~/anders-dotfiles/.local/bin/claude-usage (bash; calls this launcher)
Upstream: ~/.local/lib/claude-usage/  (git clone of phuryn/claude-usage, untouched)
"""

import sys
from pathlib import Path

LIB_DIR = Path.home() / ".local" / "lib" / "claude-usage"
sys.path.insert(0, str(LIB_DIR))

import scanner  # noqa: E402

# Augment DEFAULT_PROJECTS_DIRS with the cc-build + cc-full project trees that
# exist on this machine. Filter to existing directories so the patch is a no-op
# on machines that don't run all profiles (e.g. BabyStar, Alex's M5).
EXTRA_PROJECT_DIRS = [
    Path.home() / ".claude-build" / "projects",
    Path.home() / ".claude-full" / "projects",
]
for extra in EXTRA_PROJECT_DIRS:
    if extra.is_dir() and extra not in scanner.DEFAULT_PROJECTS_DIRS:
        scanner.DEFAULT_PROJECTS_DIRS.append(extra)

# Dispatch to upstream cli's main entry, mirroring its __main__ block exactly.
import cli  # noqa: E402

if len(sys.argv) < 2 or sys.argv[1] not in cli.COMMANDS:
    print(cli.USAGE)
    sys.exit(0)

command = sys.argv[1]
rest = sys.argv[2:]
projects_dir = cli.parse_named_arg(rest, "--projects-dir")

if command == "dashboard":
    cli.cmd_dashboard(
        projects_dir=projects_dir,
        host=cli.parse_named_arg(rest, "--host"),
        port=cli.parse_named_arg(rest, "--port"),
    )
elif command == "scan" and projects_dir:
    cli.cmd_scan(projects_dir=projects_dir)
else:
    cli.COMMANDS[command]()
