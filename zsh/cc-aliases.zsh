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
#   1. Direct child of $PROJECTS_ROOT (back-compat for pre-Work-3.0 layout)
#   2. Two-level search under category dirs (00_SYSTEM, 10_AI_OS, 20_PRODUCTS,
#      30_DOMAINS, 40_EXPERIMENTS, 50_CLIENTS, 90_ARCHIVE) — exact case-insensitive match
#   3. Explicit relative path (e.g. 20_PRODUCTS/Nudge) — works as a normal dir
#   4. Sibling repo under the parent of $PROJECTS_ROOT (e.g. ~/Code/the-symbiotic-mind,
#      ~/Code/seo-ops, ~/Code/ai-context) — case-insensitive exact match.
#      Skips $PROJECTS_ROOT itself and any *-worktrees container.
# Multiple matches across categories+siblings abort with disambiguation hint.
# Tab-completion lists all direct children + grandchildren under category dirs + siblings.
#
# Auto-worktree: every `cc <project>` opens an isolated worktree at
# <repo>/.claude/worktrees/<project>/ on branch wt/<project>. The repo is
# auto-chosen:
#   - project inside $PROJECTS_ROOT → worktree off $PROJECTS_ROOT (so submodule
#     projects worktree off the parent and the submodule is auto-init'd inside)
#   - sibling repo under ~/Code/<name> → worktree off that repo itself
# Reuses an existing worktree if one is already there; otherwise creates from `main`.
# Bare `cc` (no project arg) skips worktree entirely. One convention everywhere.
# Opt-out per call: pass --no-worktree. Opt-out globally: export CC_NO_WORKTREE=1.
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
_CC_CATEGORIES=(00_SYSTEM 10_AI_OS 20_PRODUCTS 30_DOMAINS 40_EXPERIMENTS 50_CLIENTS 90_ARCHIVE)

# Resolve a project name → absolute directory.
# Echoes the resolved path on stdout, or prints an error to stderr and returns 1.
# Resolution rules (first match wins):
#   1. $root/$name (direct child)
#   2. $root/<category>/$name (two-level, case-insensitive, exact)
#   3. $name itself if it is already a directory under $root
_cc_resolve_project() {
  local root="$1" name="$2"
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
  # Rule 4: sibling repo under parent of $root (e.g. ~/Code/<name>).
  # Excludes $root itself and any *-worktrees container dir.
  local siblings_root="${root:h}"
  local root_name="${root:t}"
  if [[ -d "$siblings_root" && "$siblings_root" != "$root" ]]; then
    for dir in "$siblings_root"/*(N/); do
      local base="${dir:t}"
      [[ "$base" == "$root_name" || "$base" == *-worktrees ]] && continue
      [[ "${base:l}" == "$lname" ]] && matches+=("$dir")
    done
  fi
  case ${#matches[@]} in
    0) printf 'cc: no project named %s under %s or %s\n' "$name" "$root" "$siblings_root" >&2; return 1 ;;
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

# Ensure a worktree exists for $project_name off $repo_root.
# Echoes the final target path (worktree root, or worktree+subpath) on stdout.
# Args: repo_root, project_subpath (relative to repo_root, may be ""), project_name
# Reuses the worktree at $repo_root/.claude/worktrees/$project_name on branch
# wt/$project_name. Creates it from main (then master, then HEAD) on first use.
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
      if git -C "$repo_root" show-ref --verify --quiet refs/heads/main; then
        base=main
      elif git -C "$repo_root" show-ref --verify --quiet refs/heads/master; then
        base=master
      else
        base=HEAD
      fi
      git -C "$repo_root" worktree add -b "$wt_branch" "$wt_root" "$base" >&2 || return 1
    fi
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
  local target badge no_worktree=0

  # Strip --no-worktree from args; everything else passes through to claude.
  local -a _args
  local a
  for a in "$@"; do
    if [[ "$a" == "--no-worktree" ]]; then
      no_worktree=1
    else
      _args+=("$a")
    fi
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
    # Skip entirely if --no-worktree, $CC_NO_WORKTREE, or target isn't in any git repo.
    if (( ! no_worktree )) && [[ -z "$CC_NO_WORKTREE" ]]; then
      local repo_root subpath
      if [[ "$target" == "$root" || "$target" == "$root/"* ]] \
           && git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
        repo_root="$root"
        subpath="${target#$root/}"
        [[ "$subpath" == "$target" ]] && subpath=""
      else
        repo_root=$(git -C "$target" rev-parse --show-toplevel 2>/dev/null)
        if [[ -n "$repo_root" ]]; then
          subpath="${target#$repo_root/}"
          [[ "$subpath" == "$target" ]] && subpath=""
        fi
      fi
      if [[ -n "$repo_root" ]]; then
        target=$(_cc_ensure_worktree "$repo_root" "$subpath" "$badge") || return 1
      fi
    fi
  else
    target="$root"; badge="workspace"
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
    case "$base" in
      00_SYSTEM|10_AI_OS|20_PRODUCTS|30_DOMAINS|40_EXPERIMENTS|50_CLIENTS|90_ARCHIVE) ;;
      *) projects+=("$base") ;;
    esac
  done
  # Grandchildren under each category.
  for cat in "${_CC_CATEGORIES[@]}"; do
    [[ -d "$root/$cat" ]] || continue
    for dir in "$root/$cat"/*(N/); do
      projects+=("${dir:t}")
    done
  done
  # Siblings under the parent of $root (e.g. ~/Code/the-symbiotic-mind),
  # excluding $root itself and any *-worktrees container.
  local siblings_root="${root:h}"
  local root_name="${root:t}"
  if [[ -d "$siblings_root" && "$siblings_root" != "$root" ]]; then
    for dir in "$siblings_root"/*(N/); do
      base="${dir:t}"
      [[ "$base" == "$root_name" || "$base" == *-worktrees ]] && continue
      projects+=("$base")
    done
  fi
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
