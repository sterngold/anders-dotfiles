#!/usr/bin/env zsh
# codex-dispatch.zsh — worktree-isolated, headless Codex dispatch primitive.
#
# Source from ~/.zprofile AFTER cc-aliases.zsh:
#   [[ -f ~/anders-dotfiles/zsh/codex-dispatch.zsh ]] && source ~/anders-dotfiles/zsh/codex-dispatch.zsh
#
# WHY this exists (AND-1672, 2026-06-29):
#   Dispatching Codex used to be a manual GUI dance (Codex Desktop → New worktree →
#   paste a giant brief). The CLI alternative `cd <repo> && codex exec --full-auto`
#   landed Codex in the PRIMARY shared checkout — the exact cross-agent collision the
#   workspace AGENTS.md invariant prohibits (observed data loss 2026-05-29: a Codex
#   git add -A swept up a live Claude session's uncommitted edits). There was no safe,
#   repeatable primitive. This is it.
#
# WHAT it does:
#   Resolves <project>, creates/reuses an ISOLATED worktree at
#   <repo>/.codex/worktrees/<name>/ on a WORK-named branch (ad-hoc default:
#   wt/<name>-build; Link builds pass --branch pipeline/<issue>-build), auto-inits
#   any --submodule it needs, then runs
#   `codex exec -C <worktree> --full-auto` with the brief piped on stdin. Codex never
#   touches the primary checkout or the .claude/worktrees/ a live Claude session owns.
#
# DESIGN NOTES:
#   - Separate container (.codex/worktrees/, not .claude/worktrees/) + separate branch
#     so Claude and Codex worktrees of the same project never collide on one branch.
#   - Branch is WORK-named, never codex/* — agent identity belongs in the commit
#     trailer, not the branch (AGENTS.md cross-agent invariant).
#   - Reuses cc's proven, read-only helpers (_cc_resolve_project, _cc_worktree_base)
#     but does NOT touch cc-aliases.zsh — cc runs on every session and stays untouched.
#   - Does NOT commit. Leaves changes in the worktree for human/orchestrator review +
#     commit (the Codex one-shot-brief contract: human reviews before the build lands).
#   - Brief is piped on stdin (codex reads instructions from stdin when no PROMPT arg),
#     avoiding arg-length and shell-quoting hazards with large briefs.
#   - Provisions the ONE obviously-missing dep (npm ci when a lockfile is present and
#     node_modules is missing) before assembling the codex command, so a fresh worktree
#     doesn't burn a Codex round-trip hard-stopping on missing deps (AND-1773 C).
#     --skip-deps opts out. Python gets a warn-only venv check — never auto-created.
#   - A stale --reuse container (left on a prior ticket's branch) auto-heals onto the
#     requested branch when clean (fetch + switch -C); a dirty container still refuses,
#     naming the exact remedy (AND-1773 D).

codex-dispatch() {
  emulate -L zsh
  setopt local_options no_nomatch

  local usage='codex-dispatch [opts] <project> <brief-file|->

Dispatch Codex headlessly in an isolated .codex/worktrees/<project> worktree.

  <project>        project name or path (resolved like `cc`)
  <brief-file|->   path to the brief, or - to read the brief from stdin

Options:
  --branch <ref>     worktree branch (ad-hoc default: wt/<name>-build;
                     Link builds use pipeline/<ISSUE>-build)
  --submodule <p>    submodule path to init inside the worktree (repeatable),
                     e.g. --submodule 10_AI_OS/Anderson
  --add-dir <d>      extra writable dir for codex outside the worktree (repeatable),
                     e.g. --add-dir ~/.local/bin  (build-tool caches like ~/.cache/uv too)
  --cwd <subpath>    codex working root, relative to the worktree (or absolute).
                     Default: the worktree root (correct for superproject-relative
                     briefs). Pass e.g. --cwd 20_PRODUCTS/Nudge for a self-contained
                     single-project build whose brief paths are project-relative.
  --model <m>        codex model
  --sandbox <mode>   read-only | workspace-write | danger-full-access
  --output <file>    write codex final message here (default: a file in the excluded
                     .codex/worktrees/ parent, OUTSIDE the worktree — so it never dirties it)
  --reuse            reuse an existing worktree instead of erroring
  --allow-dirty-source
                     allow dispatch from a source checkout with uncommitted changes
  --json             stream codex events as JSONL
  --dry-run          set up the worktree + print the exact codex command, do NOT run codex
  --skip-deps        skip dependency provisioning (npm ci / python venv check)
  -h, --help         this help'

  local branch="" model="" sandbox="" lastmsg="" cwd=""
  local dry=0 reuse=0 jsonl=0 allow_dirty_source=0 skip_deps=0
  local -a submodules add_dirs

  while [[ "$1" == -* ]]; do
    case "$1" in
      --branch)    branch="$2"; shift 2 ;;
      --submodule) submodules+=("$2"); shift 2 ;;
      --add-dir)   add_dirs+=("${2/#\~/$HOME}"); shift 2 ;;
      --cwd)       cwd="$2"; shift 2 ;;
      --model)     model="$2"; shift 2 ;;
      --sandbox)   sandbox="$2"; shift 2 ;;
      --output)    lastmsg="${2/#\~/$HOME}"; shift 2 ;;
      --reuse)     reuse=1; shift ;;
      --allow-dirty-source) allow_dirty_source=1; shift ;;
      --json)      jsonl=1; shift ;;
      --dry-run)   dry=1; shift ;;
      --skip-deps) skip_deps=1; shift ;;
      -h|--help)   print -r -- "$usage"; return 0 ;;
      *)           print -ru2 -- "codex-dispatch: unknown flag: $1"; print -ru2 -- "$usage"; return 2 ;;
    esac
  done

  local project="$1" brief="$2"
  if [[ -z "$project" || -z "$brief" ]]; then print -ru2 -- "$usage"; return 2; fi

  command -v codex >/dev/null 2>&1 || { print -ru2 -- "codex-dispatch: codex CLI not found on PATH"; return 1; }

  # Brief: a file path, or '-' for stdin.
  local brief_text
  if [[ "$brief" == "-" ]]; then
    brief_text="$(cat)"
  else
    brief="${brief/#\~/$HOME}"
    [[ -f "$brief" ]] || { print -ru2 -- "codex-dispatch: brief file not found: $brief"; return 2; }
    brief_text="$(cat -- "$brief")"
  fi
  [[ -n "${brief_text//[[:space:]]/}" ]] || { print -ru2 -- "codex-dispatch: brief is empty"; return 2; }

  local root="${PROJECTS_ROOT:?codex-dispatch: PROJECTS_ROOT not set}"

  # Resolve the project to an absolute path using cc's resolver (single source of truth).
  if ! typeset -f _cc_resolve_project >/dev/null; then
    print -ru2 -- "codex-dispatch: _cc_resolve_project not loaded (source cc-aliases.zsh first)"; return 1
  fi
  local target_proj
  target_proj="$(_cc_resolve_project "$root" "$project")" \
    || { print -ru2 -- "codex-dispatch: cannot resolve project '$project'"; return 1; }

  # Worktree off the SUPERPROJECT when the target lives inside $root (so submodule
  # projects + sibling submodules like Anderson resolve); else off the target's own
  # git toplevel. Mirrors cc's repo-root selection.
  local repo_root project_subpath
  if [[ "$target_proj" == "$root" || "$target_proj" == "$root"/* ]]; then
    repo_root="$root"
    project_subpath="${target_proj#$root/}"
    [[ "$project_subpath" == "$target_proj" ]] && project_subpath=""
  else
    repo_root="$(git -C "$target_proj" rev-parse --show-toplevel 2>/dev/null)" \
      || { print -ru2 -- "codex-dispatch: '$target_proj' is not in a git repo"; return 1; }
    project_subpath="${target_proj#$repo_root/}"
    [[ "$project_subpath" == "$target_proj" ]] && project_subpath=""
  fi

  local name="${target_proj:t}"
  [[ -z "$branch" ]] && branch="wt/${name}-build"
  local wt_root="$repo_root/.codex/worktrees/$name"

  # Keep the .codex worktree container out of the PARENT repo's status — mirror how
  # .claude/worktrees/ is excluded. Without this, `git status` in the primary checkout
  # shows .codex/worktrees/ untracked and a stray `git add -A` could stage the nested
  # worktree as an embedded gitlink, defeating isolation. Idempotent; resolves the real
  # git dir so it works for submodules too (git-common-dir may be relative/external).
  local _gitdir
  _gitdir="$(git -C "$repo_root" rev-parse --git-common-dir 2>/dev/null)" || _gitdir=""
  if [[ -n "$_gitdir" ]]; then
    [[ "$_gitdir" != /* ]] && _gitdir="$repo_root/$_gitdir"
    mkdir -p "$_gitdir/info"
    grep -qxF '**/.codex/worktrees/' "$_gitdir/info/exclude" 2>/dev/null \
      || print -r -- '**/.codex/worktrees/' >> "$_gitdir/info/exclude"
  fi

  # codex-dispatch creates the isolated worktree from committed state. If the source
  # checkout is dirty, a brief authored from what the human/Claude can see may name bytes
  # that the Codex worktree cannot contain. Refuse by default; allow an explicit escape
  # only when the orchestrator has verified the dirty state is irrelevant.
  local -a dirty_cmd=(git -C "$repo_root" status --porcelain --untracked-files=all --)
  [[ -n "$project_subpath" ]] && dirty_cmd+=("$project_subpath")
  local dirty_source
  dirty_source="$("${dirty_cmd[@]}")" || return 1
  if [[ -n "$dirty_source" ]]; then
    if (( ! allow_dirty_source )); then
      print -ru2 -- "codex-dispatch: source checkout has uncommitted changes that the isolated worktree will not contain."
      print -ru2 -- "  commit/stash them first, or pass --allow-dirty-source after verifying the brief only references committed state."
      print -ru2 -- "$dirty_source"
      return 1
    fi
    print -ru2 -- "codex-dispatch: warning: source checkout is dirty; proceeding because --allow-dirty-source was set."
  fi

  # Create or reuse the isolated Codex worktree (mirrors _cc_ensure_worktree's add).
  if [[ -d "$wt_root" ]]; then
    if (( ! reuse )); then
      print -ru2 -- "codex-dispatch: worktree already exists: $wt_root"
      print -ru2 -- "  --reuse to use it, or remove: git -C \"$repo_root\" worktree remove \"$wt_root\""
      return 1
    fi
    # On reuse the existing worktree MUST be on the requested branch — otherwise we would
    # print one branch but run Codex on a different checkout (work lands on the wrong
    # branch). A stale container (left on a PRIOR ticket's branch, AND-1773 D) is common
    # enough that refusing outright is needless friction when the container is CLEAN:
    # auto-heal it onto the requested branch, same as the create path (fetch + branch off
    # _cc_worktree_base). A DIRTY container is never auto-healed — that would risk
    # discarding uncommitted work, so it still refuses, naming the exact remedy.
    local _cur
    _cur="$(git -C "$wt_root" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    if [[ "$_cur" != "$branch" ]]; then
      local _dirty_container
      _dirty_container="$(git -C "$wt_root" status --porcelain)"
      if [[ -n "$_dirty_container" ]]; then
        print -ru2 -- "codex-dispatch: reuse refused — worktree is on '$_cur', not requested '$branch', and has uncommitted changes."
        print -ru2 -- "  inspect it first: git -C \"$wt_root\" status && git -C \"$wt_root\" diff"
        print -ru2 -- "  then either commit/stash the changes and switch: git -C \"$wt_root\" checkout \"$branch\""
        print -ru2 -- "  or remove the container entirely: git -C \"$repo_root\" worktree remove \"$wt_root\""
        return 1
      fi
      local base
      base="$(_cc_worktree_base "$repo_root")"
      # An EXISTING requested branch is preserved (plain switch — it may carry prior
      # build commits; resetting it to base would drop the tip). Only a branch that
      # doesn't exist yet is created off base — mirroring the create path below.
      local _heal_verb="switch to existing"
      git -C "$wt_root" show-ref --verify --quiet "refs/heads/$branch" || _heal_verb="create off $base"
      if (( dry )); then
        print -ru2 -- "codex-dispatch: DRY RUN — would auto-heal stale container: currently on '$_cur' (clean), would fetch origin + $_heal_verb '$branch'"
      else
        print -ru2 -- "codex-dispatch: worktree is on stale branch '$_cur' (clean) — auto-healing to '$branch' ($_heal_verb)"
        local _fetch_err
        if ! _fetch_err="$(git -C "$wt_root" fetch origin --quiet 2>&1)"; then
          print -ru2 -- "codex-dispatch: warning: git fetch origin failed in $wt_root (continuing with local refs): $_fetch_err"
        fi
        if git -C "$wt_root" show-ref --verify --quiet "refs/heads/$branch"; then
          git -C "$wt_root" switch "$branch" >&2 \
            || { print -ru2 -- "codex-dispatch: auto-heal failed — could not switch \"$wt_root\" to existing '$branch'"; return 1; }
        else
          git -C "$wt_root" switch -c "$branch" "$base" >&2 \
            || { print -ru2 -- "codex-dispatch: auto-heal failed — could not create '$branch' @ $base in \"$wt_root\""; return 1; }
        fi
        print -ru2 -- "codex-dispatch: auto-healed stale container: was on '$_cur', now '$branch'"
      fi
    else
      print -ru2 -- "codex-dispatch: reusing worktree $wt_root (on $branch)"
    fi
  else
    mkdir -p "$repo_root/.codex/worktrees"
    if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch"; then
      git -C "$repo_root" worktree add "$wt_root" "$branch" >&2 || return 1
    else
      local base
      base="$(_cc_worktree_base "$repo_root")"
      git -C "$repo_root" worktree add -b "$branch" "$wt_root" "$base" >&2 || return 1
    fi
  fi

  # Init requested submodules inside the worktree (Anderson for NightOwl, etc.).
  local sub
  for sub in "${submodules[@]}"; do
    if [[ ! -e "$wt_root/$sub/.git" ]]; then
      print -ru2 -- "codex-dispatch: init submodule $sub"
      git -C "$wt_root" submodule update --init -- "$sub" >&2 \
        || { print -ru2 -- "codex-dispatch: submodule init failed: $sub"; return 1; }
    fi
  done

  # Working root for codex (-C). Default: the worktree root — correct for superproject-
  # relative briefs (e.g. one that touches a sibling submodule + tools/). For a
  # self-contained single-project build, pass --cwd <subpath> so the project's own dir is
  # the root and repo-local instructions/build commands resolve there (Codex review #2).
  local codex_root="$wt_root"
  if [[ -n "$cwd" ]]; then
    [[ "$cwd" == /* ]] && codex_root="$cwd" || codex_root="$wt_root/$cwd"
  fi
  [[ -d "$codex_root" ]] || { print -ru2 -- "codex-dispatch: --cwd path does not exist: $codex_root"; return 1; }

  # Dependency provisioning (AND-1773 C): a fresh isolated worktree has no node_modules
  # even when the source checkout does — npm's install artifacts live in the working
  # tree, not in git. The AND-1770 dispatch burned a full Codex round-trip on a
  # hard-stopped verify.sh (missing root node_modules). Provision the ONE obviously-
  # missing dep so the brief's own build steps can assume it's there; this is not a
  # general build system, and it never creates Python venvs.
  if (( ! skip_deps )); then
    local prov_root=""
    if [[ -f "$codex_root/package-lock.json" ]]; then
      prov_root="$codex_root"
    elif [[ -f "$wt_root/package-lock.json" ]]; then
      prov_root="$wt_root"
    fi
    if [[ -n "$prov_root" && ! -d "$prov_root/node_modules" ]]; then
      if (( dry )); then
        print -ru2 -- "[codex-dispatch] would run: npm ci (--no-audit --no-fund) in $prov_root"
      else
        print -ru2 -- "codex-dispatch: node_modules missing at $prov_root — provisioning: npm ci --no-audit --no-fund"
        if ! ( cd "$prov_root" && npm ci --no-audit --no-fund >&2 ); then
          print -ru2 -- "codex-dispatch: WARNING: npm ci failed in $prov_root — continuing; the build's own verify step will surface the missing deps."
        fi
      fi
    fi

    # Python: same codex_root-then-wt_root resolution order, but resolved independently
    # of the node lockfile check above — a python-only project (no package-lock.json
    # anywhere) must still get the venv warning.
    local py_root=""
    if [[ -f "$codex_root/pyproject.toml" || -f "$codex_root/requirements.txt" ]]; then
      py_root="$codex_root"
    elif [[ -f "$wt_root/pyproject.toml" || -f "$wt_root/requirements.txt" ]]; then
      py_root="$wt_root"
    fi
    if [[ -n "$py_root" && ! -d "$py_root/.venv" && ! -d "$py_root/venv" ]]; then
      print -ru2 -- "codex-dispatch: warning: no venv in fresh worktree at $py_root — ensure the brief's Kitchen Check provisions it"
    fi
  fi

  # Assemble the codex exec command. -C <codex_root> is the isolated working root.
  # Default the -o file OUTSIDE the worktree: a sibling under the git-excluded
  # .codex/worktrees/ parent. Writing it INSIDE the worktree dirties it with an
  # untracked file, which trips brief cleanliness guards (`git status` stop rules)
  # and risks being swept into a build commit. Outside = invisible to both the
  # worktree's status and the parent repo's status.
  [[ -z "$lastmsg" ]] && lastmsg="$repo_root/.codex/worktrees/${name}.last-message.txt"
  local -a cmd=(codex exec -C "$codex_root" --full-auto --skip-git-repo-check -o "$lastmsg")
  [[ -n "$model" ]]   && cmd+=(--model "$model")
  [[ -n "$sandbox" ]] && cmd+=(--sandbox "$sandbox")
  (( jsonl ))         && cmd+=(--json)
  local d
  for d in "${add_dirs[@]}"; do cmd+=(--add-dir "$d"); done

  print -ru2 -- ""
  print -ru2 -- "codex-dispatch: project    $name  ($target_proj)"
  print -ru2 -- "codex-dispatch: worktree   $wt_root"
  print -ru2 -- "codex-dispatch: work-root  $codex_root"
  print -ru2 -- "codex-dispatch: branch     $branch"
  print -ru2 -- "codex-dispatch: last-msg   $lastmsg"
  (( ${#submodules} )) && print -ru2 -- "codex-dispatch: submodules ${submodules[*]}"
  (( ${#add_dirs} ))   && print -ru2 -- "codex-dispatch: add-dirs   ${add_dirs[*]}"
  # Hint: project lives in a subdir but work-root is the worktree root. Fine for
  # superproject-relative briefs; pass --cwd "$project_subpath" for a project-local build.
  if [[ -z "$cwd" && -n "$project_subpath" ]]; then
    print -ru2 -- "codex-dispatch: note       brief paths are relative to the worktree root; for a project-local root pass --cwd $project_subpath"
  fi
  print -ru2 -- "codex-dispatch: review     git -C \"$wt_root\" status && git -C \"$wt_root\" diff"
  print -ru2 -- ""

  if (( dry )); then
    print -ru2 -- "codex-dispatch: DRY RUN — worktree ready; would execute:"
    print -r -- "${(q)cmd[@]}"
    return 0
  fi

  print -ru2 -- "codex-dispatch: launching codex exec --full-auto (brief on stdin) …"
  print -r -- "$brief_text" | "${cmd[@]}"
}
