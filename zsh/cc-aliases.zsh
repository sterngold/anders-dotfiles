# Claude Code mode aliases (AND-640) + visual session signals
# Source from ~/.zprofile: [[ -f ~/anders-dotfiles/zsh/cc-aliases.zsh ]] && source ~/anders-dotfiles/zsh/cc-aliases.zsh
#
# Two profiles after 2026-05-09 merge:
#   cc          — unified everyday profile (was cc-full + cc-build); AW-F7 local; sovereign tools allowed
#   cc-partner  — clean room (read-only, minimal toolset)
#
# Functions (not aliases): cd into $PROJECTS_ROOT in a subshell so cwd is preserved
# after claude exits. This ensures Claude Code discovers the workspace's .claude/skills
# chain + CLAUDE.md context regardless of where you invoke cc from.
# PROJECTS_ROOT is defined per-machine in ~/.zprofile.
#
# Visual signals (iTerm2): each wrapper sets tab color, tab title, and two iTerm2
# user variables (cc_mode, cc_project) via OSC escape codes. The AndersStar dynamic
# profile interpolates these into its Badge Text. On exit, the trap restores defaults.
#
# Optional first arg = project name. Resolution (in order):
#   0. Explicit path — absolute (cc /abs/proj, cc ~/anywhere/proj) or any existing
#      directory from cwd (cc ./x, cc ../sibling). Zero-config; works anywhere.
#   1. Direct child of $PROJECTS_ROOT (back-compat for pre-Work-3.0 layout)
#   2. Two-level search under ACTIVE category dirs (00_SYSTEM, 10_AI_OS, 20_PRODUCTS,
#      30_DOMAINS, 40_EXPERIMENTS, 50_CLIENTS) — exact case-insensitive match.
#      90_ARCHIVE is deliberately NOT scanned: an archived copy must never shadow the
#      active project of the same name (e.g. alf-podcast). Reach an archived project
#      explicitly via its relative path, e.g. `cc 90_ARCHIVE/alf-podcast` (Rule 3).
#   3. Explicit relative path (e.g. 20_PRODUCTS/Nudge) — works as a normal dir
#   4. Exact case-insensitive name match under any configured search root. Default
#      root = parent of $PROJECTS_ROOT (~/Code, covering the sibling repos). Extend
#      with CC_PROJECT_ROOTS (colon-separated) in ~/.zprofile to add project homes
#      anywhere, e.g.  export CC_PROJECT_ROOTS="$HOME/Code:$HOME/work:$HOME/clients".
#      Skips $PROJECTS_ROOT itself and any *-worktrees container.
# Multiple matches across categories+roots abort with disambiguation hint.
# Tab-completion lists all direct children + grandchildren under category dirs + every root.
#
# Auto-worktree: every `cc <project>` opens an isolated worktree at
# <repo>/.claude/worktrees/<project>/ on branch wt/<project>. The repo is
# auto-chosen:
#   - project inside $PROJECTS_ROOT → worktree off $PROJECTS_ROOT (so submodule
#     projects worktree off the parent and the submodule is auto-init'd inside)
#   - sibling repo under ~/Code/<name> → worktree off that repo itself
# Reuses an existing worktree if one is already there; otherwise creates it off the
# repo's TRUE default branch (origin/HEAD, learned from the remote when unset) — not
# blindly local `main`, which may be a stale/orphan branch. See _cc_worktree_base.
# Bare `cc` (no project arg) skips worktree entirely. One convention everywhere.
# Opt-out per call: pass --no-worktree. Opt-out globally: export CC_NO_WORKTREE=1.
# Opt-out per project: place a .no-worktree file at the project root (content/writing projects).
#
#   Examples:  cc                          # workspace root, no worktree
#              cc Nudge                    # → my-projects/.claude/worktrees/Nudge/
#              cc Anderson                 # → my-projects/.claude/worktrees/Anderson/
#              cc 107                      # → my-projects/.claude/worktrees/107/
#              cc the-symbiotic-mind       # → the-symbiotic-mind/.claude/worktrees/the-symbiotic-mind/
#              cc seo-ops                  # → seo-ops/.claude/worktrees/seo-ops/
#              cc FoodLog --resume
#              cc 20_PRODUCTS/Nudge        # explicit relative path also works
#              cc Nudge --no-worktree      # skip worktree for this call
#              cc-partner                  # clean-room, badge "PARTNER · workspace"

# ── Internal helpers ──────────────────────────────────────────────────────────
# Emit OSC 1337 SetUserVar=<key>=<base64(value)> — sets an iTerm2 user variable
# that the badge / status bar / window title can interpolate as \(user.<key>).
_cc_set_user_var() {
  local key="$1" val="$2" b64
  b64=$(printf '%s' "$val" | base64 | tr -d '\n')
  printf '\e]1337;SetUserVar=%s=%s\a' "$key" "$b64"
}

# Set tab color via OSC 6 (iTerm2 proprietary). Components 0-255.
_cc_set_tab_color() {
  local r="$1" g="$2" b="$3"
  printf '\e]6;1;bg;red;brightness;%d\a'   "$r"
  printf '\e]6;1;bg;green;brightness;%d\a' "$g"
  printf '\e]6;1;bg;blue;brightness;%d\a'  "$b"
}

# Reset tab color to profile default.
_cc_reset_tab_color() {
  printf '\e]6;1;bg;*;default\a'
}

# Set tab/window title via OSC 0 (standard).
_cc_set_title() {
  printf '\e]0;%s\a' "$1"
}

# Apply the full visual signal set: tab color + title + user vars.
# Args: mode (FULL|BUILD|PARTNER), project, R, G, B
_cc_apply_visuals() {
  local mode="$1" proj="$2" r="$3" g="$4" b="$5"
  _cc_set_tab_color "$r" "$g" "$b"
  _cc_set_title "${proj} · ${mode}"
  _cc_set_user_var cc_mode    "$mode"
  _cc_set_user_var cc_project "$proj"
}

# Reset all visuals to default.
_cc_reset_visuals() {
  _cc_reset_tab_color
  _cc_set_user_var cc_mode    ""
  _cc_set_user_var cc_project ""
  # Do not reset title — shell-prompt / next command will reclaim it.
}

# Core launcher: shared between all three wrappers.
# Args: mode, config-dir, R, G, B, model_class, then user args ("$@" from the wrapper).
# model_class drives AW-F7 sovereignty guard (anders-config/specs/2026-04-24-aw-f7…):
#   local         — sovereign tools (anders_health_query / anders_fin_query /
#                   anders_coach_ask) may run; the agent class is on-host inference.
#   remote_egress — sovereign tools refuse via T6 / S2; the agent class talks to a
#                   cloud model (Anthropic / OpenAI / etc.) and must not see vault data.
# Workspace categories that may hold projects as grandchildren of $PROJECTS_ROOT.
# Order is irrelevant for resolution; case-insensitive exact match decides.
# 90_ARCHIVE is intentionally excluded so a retired project never shadows the active
# one of the same name. Archived projects are still reachable via explicit relative
# path (Rule 3), e.g. `cc 90_ARCHIVE/alf-podcast`.
_CC_CATEGORIES=(00_SYSTEM 10_AI_OS 20_PRODUCTS 30_DOMAINS 40_EXPERIMENTS 50_CLIENTS)

# Resolve a project name → absolute directory.
# Echoes the resolved path on stdout, or prints an error to stderr and returns 1.
# Resolution rules (first match wins):
#   0. explicit path — absolute or any existing dir from cwd
#   1. $root/$name (direct child)
#   2. $root/<category>/$name (two-level, case-insensitive, exact)
#   3. $name as a relative path under $root
#   4. exact name match under each CC_PROJECT_ROOTS entry (default: ${root:h} = ~/Code)
_cc_resolve_project() {
  local root="$1" name="$2"
  # Rule 0: an explicit path (absolute, or any existing dir from cwd) → use as-is.
  # Tilde is already shell-expanded before we see $name, so this covers `cc ~/x/proj`.
  if [[ "$name" == /* && -d "$name" ]]; then
    printf '%s\n' "${name:A}"; return 0
  fi
  if [[ "$name" == */* && -d "$name" ]]; then     # cwd-relative path like ./x or ../y
    printf '%s\n' "${name:A}"; return 0           # :A → absolute, normalized
  fi
  # Rule 3: explicit relative path like "20_PRODUCTS/Nudge"
  if [[ "$name" == */* && -d "$root/$name" ]]; then
    printf '%s\n' "$root/$name"; return 0
  fi
  # Rule 1: direct child
  if [[ -d "$root/$name" ]]; then
    printf '%s\n' "$root/$name"; return 0
  fi
  # Rule 2: two-level case-insensitive exact match under $root.
  local cat dir matches=()
  local lname="${name:l}"
  for cat in "${_CC_CATEGORIES[@]}"; do
    [[ -d "$root/$cat" ]] || continue
    for dir in "$root/$cat"/*(N/); do
      local base="${dir:t}"
      [[ "${base:l}" == "$lname" ]] && matches+=("$dir")
    done
  done
  # Rule 4: scan configured project roots for a case-insensitive exact name match.
  # Default = parent of $PROJECTS_ROOT (~/Code). Extend in ~/.zprofile, e.g.:
  #   export CC_PROJECT_ROOTS="$HOME/Code:$HOME/work:$HOME/clients"
  # Excludes $root itself and any *-worktrees container dir.
  local -a roots
  if [[ -n "$CC_PROJECT_ROOTS" ]]; then
    roots=("${(@s/:/)CC_PROJECT_ROOTS}")
  else
    roots=("${root:h}")
  fi
  typeset -U matches            # dedupe identical paths across overlapping roots
  local sroot
  for sroot in "${roots[@]}"; do
    [[ -d "$sroot" && "$sroot" != "$root" ]] || continue
    for dir in "$sroot"/*(N/); do
      local base="${dir:t}"
      [[ "$dir" == "$root" || "$base" == *-worktrees ]] && continue
      [[ "${base:l}" == "$lname" ]] && matches+=("$dir")
    done
  done
  case ${#matches[@]} in
    0) printf 'cc: no project named %s under %s or %s\n' "$name" "$root" "${roots[*]}" >&2
       # Did-you-mean: rank every known project name by edit distance to the typo and
       # suggest the closest few. Only runs on a miss, so the cost is irrelevant.
       local -a _allnames=()
       for cat in "${_CC_CATEGORIES[@]}"; do
         [[ -d "$root/$cat" ]] || continue
         for dir in "$root/$cat"/*(N/); do _allnames+=("${dir:t}"); done
       done
       for dir in "$root"/*(N/); do
         [[ "${dir:t}" == [0-9][0-9]_* ]] && continue   # skip every NN_ category prefix (incl. 90_ARCHIVE); future-proof vs a hardcoded list
         _allnames+=("${dir:t}")
       done
       for sroot in "${roots[@]}"; do
         [[ -d "$sroot" && "$sroot" != "$root" ]] || continue
         for dir in "$sroot"/*(N/); do
           [[ "$dir" == "$root" || "${dir:t}" == *-worktrees ]] && continue
           _allnames+=("${dir:t}")
         done
       done
       typeset -U _allnames
       # Tolerance scales with the typed length (min 2): a 1-char slip in a long name
       # like "knowldgebase" → "KnowledgeBase" is still caught, short names stay strict.
       local -i _thresh=$(( ${#lname} / 3 )); (( _thresh < 2 )) && _thresh=2
       local -a _within=()
       local _cand
       for _cand in "${_allnames[@]}"; do
         _cc_levenshtein "$lname" "$_cand"          # result in $REPLY
         (( REPLY <= _thresh )) && _within+=("${(l:2::0:)REPLY}:$_cand")
       done
       if (( ${#_within} )); then
         local -a _sorted=( "${(@o)_within}" )      # zero-padded keys → lexical = nearest-first
         local -a _sugg=() _it
         for _it in "${_sorted[@]:0:3}"; do _sugg+=("${_it#*:}"); done
         printf 'cc: did you mean: %s?\n' "${(j:, :)_sugg}" >&2
       fi
       return 1 ;;
    1) printf '%s\n' "${matches[1]}"; return 0 ;;
    *) printf 'cc: ambiguous project name %s — matches:\n' "$name" >&2
       local m
       for m in "${matches[@]}"; do
         if [[ "$m" == "$root/"* ]]; then
           printf '  %s\n' "${m#$root/}" >&2
         else
           printf '  %s\n' "$m" >&2
         fi
       done
       return 1 ;;
  esac
}

# Levenshtein edit distance between $1 and $2 (case-insensitive). Result in $REPLY.
# Pure zsh, no fork — used only on the cc-miss "did you mean?" path. 1-based arrays;
# prev[c]/cur[c] hold the DP value for column c-1 (0..lb). Classic two-row DP.
_cc_levenshtein() {
  local a="${1:l}" b="${2:l}"
  local -i la=${#a} lb=${#b} i c j cost del ins sub mn
  if (( la == 0 )); then REPLY=$lb; return; fi
  if (( lb == 0 )); then REPLY=$la; return; fi
  local -a prev cur
  for (( c = 1; c <= lb + 1; c++ )); do prev[c]=$(( c - 1 )); done
  for (( i = 1; i <= la; i++ )); do
    cur[1]=$i
    for (( c = 2; c <= lb + 1; c++ )); do
      j=$(( c - 1 ))
      [[ "${a[i]}" == "${b[j]}" ]] && cost=0 || cost=1
      del=$(( prev[c] + 1 ))
      ins=$(( cur[c-1] + 1 ))
      sub=$(( prev[c-1] + cost ))
      mn=$del
      (( ins < mn )) && mn=$ins
      (( sub < mn )) && mn=$sub
      cur[c]=$mn
    done
    prev=( "${cur[@]}" )
  done
  REPLY=${prev[lb+1]}
}

# Resolve the base ref for a NEW worktree: the repo's true default branch.
# Prefers the remote's recorded default (origin/HEAD) over local `main`, which may be
# stale/orphan (e.g. a repo whose real trunk is a feature branch). Order:
#   origin/HEAD → (learn it once via the remote if unset) → origin/main → origin/master
#   → local main → local master → HEAD.
# The common path (origin/HEAD already set at clone) is network-free.
_cc_worktree_base() {
  local repo_root="$1" ref
  ref=$(git -C "$repo_root" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
  if [[ -z "$ref" ]] && git -C "$repo_root" remote get-url origin >/dev/null 2>&1; then
    git -C "$repo_root" remote set-head origin --auto >/dev/null 2>&1   # one network call, non-fatal
    ref=$(git -C "$repo_root" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
  fi
  if [[ -z "$ref" ]]; then
    if   git -C "$repo_root" show-ref --verify --quiet refs/remotes/origin/main;   then ref=origin/main
    elif git -C "$repo_root" show-ref --verify --quiet refs/remotes/origin/master; then ref=origin/master
    fi
  fi
  if [[ -z "$ref" ]]; then
    if   git -C "$repo_root" show-ref --verify --quiet refs/heads/main;   then ref=main
    elif git -C "$repo_root" show-ref --verify --quiet refs/heads/master; then ref=master
    else ref=HEAD
    fi
  fi
  printf '%s\n' "$ref"
}

# For a project that lives inside a git submodule of $repo_root, echo the submodule's
# path (from .gitmodules) so cc can worktree the SUBMODULE ITSELF (proper git, full
# checkout, real freshness) instead of populating it inside a linked superproject
# worktree — the latter inherits the primary checkout's relative core.worktree, so
# every git call in the inner submodule fails → silent stale-freeze + missing files
# (the 2026-06-28 cc-Nudge trap). Returns 1 if the subpath isn't inside any submodule.
_cc_submodule_for_subpath() {
  local repo_root="$1" subpath="$2" sub
  [[ -n "$subpath" && -f "$repo_root/.gitmodules" ]] || return 1
  while IFS= read -r sub; do
    [[ "$subpath" == "$sub" || "$subpath" == "$sub/"* ]] && { print -r -- "$sub"; return 0; }
  done < <(git -C "$repo_root" config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')
  return 1
}

# ── Submodule linked-worktree config repair ─────────────────────────────────────
# git stores a submodule's core.worktree in its SHARED config (.git/modules/<n>/config)
# pointing at the PRIMARY checkout. Every LINKED worktree of that submodule then
# inherits it and dies with "cannot chdir to ../../../<path>" — so `cc <submodule>`
# worktrees (and any `git worktree add` of a submodule) silently break. The git-blessed
# fix: enable extensions.worktreeConfig and move core.worktree into the MAIN worktree's
# per-worktree config (config.worktree), out of shared. git RE-ADDS it to shared on every
# `submodule update --init`, so this runs after each init and is safe to repeat (no-op
# when shared is already clean). 2026-06-29 — the cc-Nudge orphan/broken-worktree class.
_cc_normalize_submodule_worktree_config() {
  local primary="$1" gitdir
  [[ -n "$primary" && -e "$primary/.git" ]] || return 0
  gitdir=$(git -C "$primary" rev-parse --absolute-git-dir 2>/dev/null) || return 0
  grep -qE '^[[:space:]]*worktree[[:space:]]*=' "$gitdir/config" 2>/dev/null || return 0  # already clean
  git -C "$primary" config extensions.worktreeConfig true 2>/dev/null
  git -C "$primary" config --worktree core.worktree "$primary" 2>/dev/null
  git -C "$primary" config --unset core.worktree 2>/dev/null
  git -C "$primary" rev-parse --show-toplevel >/dev/null 2>&1 \
    || printf 'cc: ⚠ core.worktree normalize may have broken git in %s.\n' "$primary" >&2
}

# `cc --repair` — repair the submodule linked-worktree trap across the whole workspace:
# normalize every initialized submodule's core.worktree, then prune stale worktree
# registrations. Idempotent + safe; run when cc warns about a BROKEN git dir.
_cc_repair_worktree_configs() {
  local root="${PROJECTS_ROOT:-$HOME/Code/my-projects}" path
  [[ -f "$root/.gitmodules" ]] || { printf 'cc --repair: no .gitmodules at %s\n' "$root" >&2; return 0; }
  # Enumerate submodule paths straight from .gitmodules using ONLY zsh builtins — no
  # external command (git config --get-regexp / grep / sed all proved flaky inside a
  # function in some shells), so the repair tool works even in a degraded environment.
  local -a _lines; local _line
  _lines=( "${(@f)$(<"$root/.gitmodules")}" )
  for _line in "${_lines[@]}"; do
    [[ "$_line" == *path*=* ]] || continue        # the `path = <value>` lines only
    path="${_line#*=}"; path="${path// /}"; path="${path//$'\t'/}"   # value, whitespace-stripped
    [[ -n "$path" && -e "$root/$path/.git" ]] || continue
    _cc_normalize_submodule_worktree_config "$root/$path"
    printf 'cc --repair: normalized %s\n' "$path" >&2
  done
  git -C "$root" worktree prune 2>/dev/null
  printf 'cc --repair: done — submodule worktree configs normalized, stale worktrees pruned.\n' >&2
}

# Fetch one git dir and fast-forward it to its remote default branch when SAFE.
# Safe = clean tree AND no local commits ahead → ff-only can never lose work. If the
# dir is behind but dirty/ahead, warn (with the base ref) instead of mutating. Pure
# safety net against the stale-HEAD trap (a worktree silently sitting behind origin).
_cc_ff_or_warn() {
  local dir="$1" label="$2" base behind ahead dirty
  # A BROKEN git dir (e.g. a submodule wrongly populated inside a linked superproject
  # worktree → inherited core.worktree) fails every git call. Surface it LOUDLY rather
  # than silently swallowing it (the stale-freeze trap) — never refresh blind.
  if ! git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    printf 'cc: ⚠ %s has a BROKEN git dir — content may be STALE, NOT refreshed (run: cc --repair).\n' "$label" >&2
    return 0
  fi
  git -C "$dir" fetch -q origin 2>/dev/null \
    || { printf 'cc: ⚠ could not fetch %s (offline?) — using local state, may be stale.\n' "$label" >&2; return 0; }
  base=$(_cc_worktree_base "$dir")
  behind=$(git -C "$dir" rev-list --count "HEAD..$base" 2>/dev/null) || return 0
  [[ "${behind:-0}" -gt 0 ]] || return 0
  ahead=$(git -C "$dir" rev-list --count "$base..HEAD" 2>/dev/null || echo 0)
  dirty=$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$ahead" -eq 0 && "$dirty" -eq 0 ]]; then
    git -C "$dir" merge --ff-only "$base" >/dev/null 2>&1 \
      && printf 'cc: refreshed %s → %s (was %s behind)\n' "$label" "$base" "$behind" >&2
  else
    printf 'cc: ⚠ %s is %s behind %s (ahead %s, dirty %s files) — NOT refreshed. Branch task work off %s.\n' \
      "$label" "$behind" "$base" "$ahead" "$dirty" "$base" >&2
  fi
}

# On worktree REUSE, refresh the worktree (and the project's submodule, where the
# AND-1346 stale-HEAD trap actually bit) so a session never starts on a stale tree.
_cc_refresh_worktree() {
  local wt_root="$1" repo_root="$2" project_subpath="$3" wt_branch="$4"
  _cc_ff_or_warn "$wt_root" "$wt_branch"
  if [[ -n "$project_subpath" && -f "$repo_root/.gitmodules" ]]; then
    local sub
    while IFS= read -r sub; do
      if [[ "$project_subpath" == "$sub" || "$project_subpath" == "$sub/"* ]]; then
        [[ -e "$wt_root/$sub/.git" ]] && _cc_ff_or_warn "$wt_root/$sub" "submodule $sub"
        break
      fi
    done < <(git -C "$repo_root" config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')
  fi
}

# Ensure a worktree exists for $project_name off $repo_root.
# Echoes the final target path (worktree root, or worktree+subpath) on stdout.
# Args: repo_root, project_subpath (relative to repo_root, may be ""), project_name
# Reuses the worktree at $repo_root/.claude/worktrees/$project_name on branch
# wt/$project_name. Creates it off the repo's true default branch (origin/HEAD,
# via _cc_worktree_base — NOT blindly local `main`) on first use.
# Auto-inits the relevant submodule inside the worktree when the project lives
# inside one (e.g. cc Nudge → 20_PRODUCTS/Nudge submodule).
_cc_ensure_worktree() {
  local repo_root="$1" project_subpath="$2" project_name="$3"
  local wt_branch="wt/${project_name}"
  local wt_root="$repo_root/.claude/worktrees/$project_name"

  if [[ ! -d "$wt_root" ]]; then
    mkdir -p "$repo_root/.claude/worktrees"
    if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$wt_branch"; then
      git -C "$repo_root" worktree add "$wt_root" "$wt_branch" >&2 || return 1
    else
      local base
      base=$(_cc_worktree_base "$repo_root")
      git -C "$repo_root" worktree add -b "$wt_branch" "$wt_root" "$base" >&2 || return 1
    fi
  else
    # Reuse: don't hand back a stale worktree (the AND-1346 trap). Non-fatal.
    _cc_refresh_worktree "$wt_root" "$repo_root" "$project_subpath" "$wt_branch" || true
  fi

  # If project lives inside a submodule that isn't populated in the worktree,
  # init just that submodule. Non-fatal: surface output to stderr, keep going.
  if [[ -n "$project_subpath" && -f "$repo_root/.gitmodules" ]]; then
    local sub
    while IFS= read -r sub; do
      if [[ "$project_subpath" == "$sub" || "$project_subpath" == "$sub/"* ]]; then
        [[ ! -e "$wt_root/$sub/.git" ]] && \
          git -C "$wt_root" submodule update --init -- "$sub" >&2 || true
        break
      fi
    done < <(git -C "$repo_root" config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')
  fi

  if [[ -n "$project_subpath" ]]; then
    printf '%s/%s\n' "$wt_root" "$project_subpath"
  else
    printf '%s\n' "$wt_root"
  fi
}

_cc_launch() {
  local mode="$1" config_dir="$2" r="$3" g="$4" b="$5" model_class="$6"
  shift 6
  local root="${PROJECTS_ROOT:?PROJECTS_ROOT not set}"
  local target badge no_worktree=0 force_new=0

  # Strip cc-only flags from args; everything else passes through to claude.
  #   --no-worktree  skip worktree creation (run in the project dir itself)
  #   --new          force a FRESH, uniquely-named worktree off the remote default —
  #                  for a session running parallel to another on the same project
  #                  (plain cc reuses the one worktree → collision).
  local -a _args
  local a
  for a in "$@"; do
    case "$a" in
      --no-worktree) no_worktree=1 ;;
      --new)         force_new=1 ;;
      --repair)      _cc_repair_worktree_configs; return 0 ;;
      *)             _args+=("$a") ;;
    esac
  done
  set -- "${_args[@]}"

  if [[ -n "$1" ]]; then
    target=$(_cc_resolve_project "$root" "$1") || return 1
    badge="${target:t}"
    shift
    # Auto-worktree: every cc <project> opens in <repo>/.claude/worktrees/<name>/.
    # Repo root depends on where the target lives:
    #   - inside $root → use $root (submodule projects worktree off the parent)
    #   - else        → use the target's own git toplevel (sibling repos like
    #                    ~/Code/the-symbiotic-mind)
    # Per-project opt-out: a .no-worktree file at the project root skips worktree creation.
    [[ -f "$target/.no-worktree" ]] && no_worktree=1
    # Skip entirely if --no-worktree, $CC_NO_WORKTREE, .no-worktree file, or target isn't in any git repo.
    if (( ! no_worktree )) && [[ -z "$CC_NO_WORKTREE" ]]; then
      local repo_root subpath
      if [[ "$target" == "$root" || "$target" == "$root/"* ]] \
           && git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
        repo_root="$root"
        subpath="${target#$root/}"
        [[ "$subpath" == "$target" ]] && subpath=""
        # Submodule-root projects (Nudge, Momentum, …): worktree the SUBMODULE itself,
        # not a superproject worktree with the submodule init'd inside (that inherits
        # the primary checkout's core.worktree → broken git + silent stale-freeze +
        # missing files). A worktree OF the submodule has normal git, full checkout, and
        # real freshness off the submodule's own origin/main. Opt out (keep superproject
        # tooling in-tree, e.g. git-land/closeout) with CC_SUPERPROJECT_WORKTREE=1.
        local _sub
        if [[ -z "$CC_SUPERPROJECT_WORKTREE" ]] && _sub=$(_cc_submodule_for_subpath "$root" "$subpath"); then
          [[ -e "$root/$_sub/.git" ]] || git -C "$root" submodule update --init -- "$_sub" >&2 || true
          _cc_normalize_submodule_worktree_config "$root/$_sub"   # prevent the linked-worktree core.worktree trap
          if git -C "$root/$_sub" rev-parse --git-dir >/dev/null 2>&1; then
            [[ -d "$root/.claude/worktrees/$badge" ]] && \
              printf 'cc: %s now worktrees the submodule (%s); old superproject tree at %s is unused — remove with: git -C %s worktree remove .claude/worktrees/%s\n' \
                "$badge" "$_sub" "$root/.claude/worktrees/$badge" "$root" "$badge" >&2
            repo_root="$root/$_sub"
            subpath="${subpath#$_sub}"; subpath="${subpath#/}"
          else
            printf 'cc: ⚠ submodule %s git not usable — falling back to superproject worktree (may be partial).\n' "$_sub" >&2
          fi
        fi
      else
        repo_root=$(git -C "$target" rev-parse --show-toplevel 2>/dev/null)
        if [[ -n "$repo_root" ]]; then
          subpath="${target#$repo_root/}"
          [[ "$subpath" == "$target" ]] && subpath=""
        fi
      fi
      if [[ -n "$repo_root" ]]; then
        local wt_name="$badge"
        if (( force_new )); then
          # Pick the next free <project>-N (no dir AND no wt/ branch) so a parallel
          # session gets its own isolated worktree off the current remote default.
          local n=2
          while [[ -d "$repo_root/.claude/worktrees/${badge}-${n}" ]] \
                || git -C "$repo_root" show-ref --verify --quiet "refs/heads/wt/${badge}-${n}"; do
            (( n++ ))
          done
          wt_name="${badge}-${n}"
          printf 'cc: --new → fresh worktree %s off the remote default\n' "$wt_name" >&2
        fi
        target=$(_cc_ensure_worktree "$repo_root" "$subpath" "$wt_name") || return 1
        badge="$wt_name"
      fi
    fi
  else
    target="$root"; badge="workspace"
    # Non-breaking hint: bare `cc` always opens the workspace root, even when run from
    # inside another repo/project. Don't change where it lands — just stop being silent.
    local _cwd_top
    _cwd_top=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null)
    if [[ -n "$_cwd_top" && "$_cwd_top" != "$root" && "$_cwd_top" != *"/.claude/worktrees/"* ]]; then
      printf 'cc: bare `cc` opens the workspace root (%s) — you are in %s.\n' "${root:t}" "${_cwd_top:t}" >&2
      printf '    To open this project instead:  cc %s\n' "${_cwd_top:t}" >&2
    fi
  fi
  (
    cd "$target" || return
    _cc_apply_visuals "$mode" "$badge" "$r" "$g" "$b"
    trap '_cc_reset_visuals' EXIT INT TERM
    AW_F7_MODEL_CLASS="$model_class" CLAUDE_CONFIG_DIR="$config_dir" claude --add-dir "$HOME/Vaults" "$@"
  )
}

# ── Wrappers ──────────────────────────────────────────────────────────────────
# Color choices are deliberately distinct hues for at-a-glance discrimination:
#   CC       = green   (R=  0 G=200 B= 80)  — unified everyday profile (post 2026-05-09 merge)
#   PARTNER  = purple  (R=160 G= 70 B=210)  — clean-room
#
# AW-F7 model class: cc uses `local` (sovereign tools allowed), cc-partner uses
# `remote_egress` (sovereign tools refused — clean room must not see vault data).

cc() {
  _cc_launch CC      "$HOME/.claude-full"      0 200  80 local "$@"
}

cc-partner() {
  _cc_launch PARTNER "$HOME/.claude-partner" 160  70 210 remote_egress "$@"
}

# Vault shortcut — VladFinance lives outside PROJECTS_ROOT at ~/Vaults/self/Finance/.
# Uses same green as cc + local model class (sovereign tools allowed).
cc-finance() {
  (
    cd ~/Vaults/self/Finance || return
    _cc_apply_visuals CC Finance 0 200 80
    trap '_cc_reset_visuals' EXIT INT TERM
    AW_F7_MODEL_CLASS=local CLAUDE_CONFIG_DIR="$HOME/.claude-full" claude --add-dir "$HOME/Vaults" "$@"
  )
}

# Vault shortcut — Health lives outside PROJECTS_ROOT at ~/Vaults/self/Health/.
# Uses same green as cc + local model class (sovereign tools allowed).
cc-health() {
  (
    cd ~/Vaults/self/Health || return
    _cc_apply_visuals CC Health 0 200 80
    trap '_cc_reset_visuals' EXIT INT TERM
    AW_F7_MODEL_CLASS=local CLAUDE_CONFIG_DIR="$HOME/.claude-full" claude --add-dir "$HOME/Vaults" "$@"
  )
}

# ── Cross-agent build worktree (The Link / Codex handoff) ───────────────────────
# `codexwt <project> <branch> [worktree-name]` — make an isolated, build-ready worktree
# for handing a coding task to Codex (or any agent) WITHOUT typing the uv-sync dance:
#   1. detached checkout off origin/<branch> — detached frees the branch name, so this
#      session's own worktree (which may hold <branch>) doesn't collide; the build pushes
#      back with `git push origin HEAD:<branch>`.
#   2. uv-sync the venv ONLY if the project is a uv project (pyproject.toml present).
#      uv reflinks from the warm ~/.cache/uv on APFS → seconds, not a re-download. Extras
#      default to --all-extras (covers e.g. AndersMem's required mcp+dev); override with
#      CODEXWT_UV_ARGS (e.g. CODEXWT_UV_ARGS='--extra mcp --extra dev'). Python is taken
#      from the project's .python-version automatically.
#   3. cd you in, ready for `codex exec --full-auto "..."`.
# Isolation-safe by construction (separate worktree, never the primary checkout). For a
# submodule project the worktree is of the submodule repo, which is fine for a self-
# contained build (no superproject tools needed). Clean up after: `git -C <proj> worktree
# remove <wt>` (printed on success).
codexwt() {
  local name="$1" branch="${2#origin/}" wtname="$3"
  if [[ -z "$name" || -z "$branch" ]]; then
    print -u2 "usage: codexwt <project> <branch> [worktree-name]"
    return 2
  fi
  local root="${PROJECTS_ROOT:-$HOME/Code/my-projects}"
  local proj
  proj=$(_cc_resolve_project "$root" "$name") || return 1
  local base="$HOME/codex-worktrees"
  mkdir -p "$base"
  [[ -n "$wtname" ]] || wtname="${proj:t}-${branch:t}"
  local wt="$base/$wtname"
  if [[ -e "$wt" ]]; then
    print -u2 "codexwt: $wt already exists — remove it first: git -C ${proj} worktree remove $wt"
    return 1
  fi
  print -u2 "codexwt: fetching origin in ${proj} ..."
  git -C "$proj" fetch origin || return 1
  if ! git -C "$proj" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    print -u2 "codexwt: origin/$branch not found in ${proj} (push the branch first?)"
    return 1
  fi
  print -u2 "codexwt: detached worktree at $wt off origin/$branch"
  git -C "$proj" worktree add --detach "$wt" "origin/$branch" || return 1
  cd "$wt" || return 1
  if [[ -f pyproject.toml ]]; then
    local uvargs="${CODEXWT_UV_ARGS:---all-extras}"
    print -u2 "codexwt: uv sync ${uvargs} (warm cache → APFS reflink, seconds) ..."
    uv sync ${=uvargs} || print -u2 "codexwt: uv sync failed — fix deps before building"
  fi
  print -u2 "codexwt: ready in $wt (detached at origin/$branch)"
  print -u2 "codexwt: when green → git push origin HEAD:$branch ; cleanup → git -C ${proj} worktree remove $wt"
}

# ── Health check ──────────────────────────────────────────────────────────────
# `ccdoctor` runs the cc-resolver invariant check (sibling cc-doctor.zsh): asserts
# every active project resolves uniquely via `cc <name>`. Run it after archiving,
# renaming, or moving a project, or after editing this file. Exit 0 = green, 1 =
# a project doesn't resolve, 3 = the check couldn't run. The path is computed
# script-relative (%x = this file at source time) so it survives a repo move.
alias ccdoctor="zsh ${${(%):-%x}:A:h}/cc-doctor.zsh"

# ── Tab completion ────────────────────────────────────────────────────────────
# Lists every project as the first arg: direct children of $PROJECTS_ROOT plus
# every grandchild under category dirs. After the project arg, falls back to
# normal file completion so `--resume`, paths, etc. still work.
_cc_projects() {
  local root="${PROJECTS_ROOT}"
  [[ -z "$root" || ! -d "$root" ]] && return 1
  local -a projects
  local cat dir base
  # Direct children of $root (non-category dirs only — keep the list clean).
  for dir in "$root"/*(N/); do
    base="${dir:t}"
    [[ "$base" == [0-9][0-9]_* ]] && continue   # skip every NN_ category prefix (incl. 90_ARCHIVE); future-proof vs a hardcoded list
    projects+=("$base")
  done
  # Grandchildren under each category.
  for cat in "${_CC_CATEGORIES[@]}"; do
    [[ -d "$root/$cat" ]] || continue
    for dir in "$root/$cat"/*(N/); do
      projects+=("${dir:t}")
    done
  done
  # Projects under each configured search root (default: parent of $root = ~/Code),
  # excluding $root itself and any *-worktrees container. Mirrors _cc_resolve_project Rule 4.
  local -a roots
  if [[ -n "$CC_PROJECT_ROOTS" ]]; then
    roots=("${(@s/:/)CC_PROJECT_ROOTS}")
  else
    roots=("${root:h}")
  fi
  typeset -U projects           # dedupe names across overlapping roots
  local sroot
  for sroot in "${roots[@]}"; do
    [[ -d "$sroot" && "$sroot" != "$root" ]] || continue
    for dir in "$sroot"/*(N/); do
      base="${dir:t}"
      [[ "$dir" == "$root" || "$base" == *-worktrees ]] && continue
      projects+=("$base")
    done
  done
  if (( CURRENT == 2 )); then
    _describe -t projects 'project' projects
  else
    _files
  fi
}
# Only register completion if compinit has run (skips non-interactive contexts).
(( $+functions[compdef] )) && compdef _cc_projects cc cc-partner

# git-clean — check all repos and submodules are pristine
alias git-clean='cd ~/Code/my-projects && git status --short && git log origin/main..HEAD --oneline && git branch -a | grep -v "main\|HEAD" && for sub in 10_AI_OS/Anderson 10_AI_OS/AndersMem 20_PRODUCTS/FoodLog 20_PRODUCTS/Momentum 20_PRODUCTS/Nudge 00_SYSTEM/anders-config; do echo "=== $sub ===" && git -C $sub status --short && git -C $sub log origin/main..HEAD --oneline 2>/dev/null && git -C $sub branch -a | grep -v "main\|HEAD"; done'

# atlas — regenerate + open the Process Atlas (workspace process map: PM + engineer views)
# Passes through extra args, e.g. `atlas --json`. PROJECTS_ROOT must point at the primary checkout.
atlas() {
  local root="${PROJECTS_ROOT:-$HOME/Code/my-projects}"
  PROJECTS_ROOT="$root" python3 "$root/00_SYSTEM/anders-config/tools/process-atlas.py" --open "$@"
}

# Per-machine identity banner (login shells → once per terminal tab). See host-banner.zsh.
# Replaces the fragile iTerm2 "Send text at start" approach. Host-portable via ${0:A:h}.
[[ -f "${0:A:h}/host-banner.zsh" ]] && source "${0:A:h}/host-banner.zsh"
