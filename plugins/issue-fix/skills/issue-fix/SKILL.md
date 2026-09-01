---
name: issue-fix
description: Use when running as the delegated coding agent inside an ai-factory sandbox — the AI_FACTORY_* environment variables are set, and the task is a repository issue that must reach an opened pull request or merge request with no controller step afterwards.
---

# ai-factory issue-fix (delegated workflow)

You are Codex running inside an ai-factory sandbox. The repository is already
cloned and checked out at `AI_FACTORY_WORKDIR` (default `/workspace/repo`), git
auth is already in the environment, and you are authenticated. **You own the
whole workflow**: fix the issue, validate locally, commit, push, and open the
PR/MR. The controller runs no commit/push/PR/CI steps after you — if you do not
push and open the change request, nothing will.

## Inputs (already in the environment)

| Variable | Meaning |
| --- | --- |
| `AI_FACTORY_REPO` | `owner/repo` slug |
| `AI_FACTORY_PROVIDER` | `github` or `gitlab` |
| `AI_FACTORY_BASE_REF` | base branch to target (e.g. `main`) |
| `AI_FACTORY_BRANCH` | the deterministic change branch to create/update |
| `AI_FACTORY_TARGET_BRANCH` | branch the PR/MR merges into |
| `AI_FACTORY_REMOTE` | git remote name (usually `origin`) |
| `AI_FACTORY_ISSUE_URL` | the triggering issue URL |
| `AI_FACTORY_PR_TITLE` | suggested PR/MR title (may be empty) |
| `AI_FACTORY_PR_BODY` | suggested PR/MR body (may be empty) |
| `AI_FACTORY_WORKDIR` | repository checkout directory (default `/workspace/repo`) |
| `AI_FACTORY_CI_COMMANDS` | semicolon-separated validation commands injected for this task (may be empty) |
| `AI_FACTORY_GIT_PROXY` | git proxy host used to rewrite `origin` (see provider references) |
| `GITHUB_TOKEN` / `GITLAB_TOKEN` | git + `gh`/`glab` auth (already exported) |

The task instructions (the issue) are the prompt you were given.

## Workflow

1. **Understand.** Read the issue and locate the relevant code (`rg`, `find`,
   read files). Reproduce the problem when practical.
2. **Plan.** State a short plan. Classify each requirement as IN scope, OUT of
   scope, or UNCERTAIN. Do the smallest complete change that resolves the issue.
   Follow the repository's own conventions and `AGENTS.md`/contributor rules.
3. **Edit.** Make focused edits. Do not refactor unrelated code.
4. **Validate locally (CI left-shift).** Run the repository's own checks in the
   sandbox before pushing — see "Local CI" below. Fix failures and re-run until
   green, or stop at the no-progress cap. If the environment cannot run the
   checks, note that in the result and proceed — remote CI covers it.
5. **Commit.** Create/switch to `AI_FACTORY_BRANCH` off the base, then commit
   real changes only, with a semantic message (`fix:`, `feat:`, `docs:`…).
6. **Push.** Push the branch to `AI_FACTORY_REMOTE` (see safety rails on force).
7. **Open the PR/MR.** Read this task's provider reference first — see "Open the
   change request" below.
8. **Report the result** (required — see "Result contract").

## Local CI (validate before you push)

Local validation is **environment-dependent and best-effort**. The sandbox is a
generic dev image that may not match the repo's toolchain or dependencies.
Probe before you run, and never fight a missing environment:

1. Any validation commands ai-factory injected for this task via
   `AI_FACTORY_CI_COMMANDS` (if set) — these are the most authoritative; the
   controller knows the environment, so run them as given.
2. Otherwise infer from the repo — but **only when the toolchain is installed**:
   probe with `command -v go` before `go build ./...`, `command -v npm` before
   `npm test`, and so on. If a tool is missing, state it plainly ("environment
   lacks X; local validation skipped, relying on remote CI") and move on — do
   not hard-run a check that must fail for lack of environment.
3. Best-effort: skim `.github/workflows/*.yml` or `.gitlab-ci.yml` for the
   `run:` steps and mirror the cheap, non-network ones the environment supports.

[`scripts/local-ci.sh`](scripts/local-ci.sh) automates steps 1-2 with this
probe-then-skip behavior (run it from the repo root, or anywhere with
`AI_FACTORY_WORKDIR` set).

The sandbox is largely offline for Go (`GOTOOLCHAIN=local`, no proxy); even with
the toolchain present, a check needing unfetched dependencies may fail — note it
and move on rather than fighting it.

Local validation is an approximation — remote CI can still differ. The goal is
to catch the common failures (build, unit tests, format, lint) **when the
environment allows**, not to guarantee remote green. If the environment cannot
validate the repo at all, that is acceptable: open the PR and let remote CI do
its job.

## Commit and push

This task may be a **re-run of the same issue** (e.g. a retry after a failure):
the change branch `AI_FACTORY_BRANCH` and its PR may already exist on the
remote. Treat a re-run as a **clean redo**, never as incremental work on the
previous attempt's commits — start from the base branch and rebuild:

```sh
cd "${AI_FACTORY_WORKDIR:-/workspace/repo}"
git fetch origin
git checkout -B "$AI_FACTORY_BRANCH" "origin/$AI_FACTORY_BASE_REF"   # clean start from base
git add -A            # NEVER stage .ai-factory/ (it is git-excluded already)
git -c user.name=ai-factory -c user.email=ai-factory@example.invalid \
    commit -m "fix: <concise summary>"
git push --force-with-lease -u "$AI_FACTORY_REMOTE" "$AI_FACTORY_BRANCH"
```

- `--force-with-lease` only rewrites this deterministic per-issue branch (see
  safety rails). On a re-run, the existing PR follows the branch automatically —
  reuse its URL (see the provider reference) instead of creating a new one.
- If a re-run finds the issue already resolved and there is nothing to change,
  say so in the result instead of redoing work.

## Open the change request

Read the reference for this task's provider before running any provider command:

| `AI_FACTORY_PROVIDER` | Read |
| --- | --- |
| `github` | [`references/github.md`](references/github.md) — `gh pr create` |
| `gitlab` | [`references/gitlab.md`](references/gitlab.md) — `glab mr create` |

Each reference carries the exact command, the flags that are mandatory in this
sandbox (a git proxy rewrites the origin remote, so provider CLIs need the repo
named explicitly), how to reuse an existing change request on a re-run, and how
to recover the URL when the create call prints nothing. Both set `PR_URL`, which
the result contract below requires — you cannot finish the task without it.

Target `AI_FACTORY_TARGET_BRANCH`, and use `AI_FACTORY_PR_TITLE` when set.

**PR/MR body.** Use `AI_FACTORY_PR_BODY` verbatim when it is set. Otherwise
compose the body yourself — every field below is REQUIRED; write `None` when a
field has no content:

```text
Changes:      <what changed and why>
Validation:   <checks run and their result, or
              "N/A: environment lacks X — relying on remote CI">
Out of scope: <requests you declined, or None>

Resolves <AI_FACTORY_ISSUE_URL>
```

The `Resolves` line auto-closes the issue on merge (GitHub and GitLab both
accept it) — it is never optional. `Out of scope` is where the scope rules below
require you to record declined requests.

## Result contract (required)

When finished, record the change-request URL both ways so the controller can
report it:

```sh
mkdir -p .ai-factory
printf '%s\n' "$PR_URL" > .ai-factory/result-url.txt
printf '__AI_FACTORY_RESULT__=%s\n' \
  "{\"pr_url\":\"$PR_URL\",\"branch\":\"$AI_FACTORY_BRANCH\",\"summary\":\"<one sentence>\"}"
```

Print the `__AI_FACTORY_RESULT__=...` line exactly once, as the final line, with
nothing after it.

## Scope rules

- Priority: repository rules > issue intent > your own preferences.
- Make the smallest change that fully resolves the issue; classify each item
  IN/OUT/UNCERTAIN and act only on IN. Declining out-of-scope work is success,
  not failure — note it in the PR body.

## Safety rails

- **Never print or commit secrets.** Tokens are in the environment; keep them there.
- **Never stage `.ai-factory/`** (scaffolding + result files). It is already in
  `.git/info/exclude`; do not `git add` it.
- **Force-push only the deterministic per-issue branch** `AI_FACTORY_BRANCH`, and
  only when updating this same task's existing branch. Never force-push the base
  or target branch; never rewrite others' commits.
- **Never merge** the PR/MR yourself, and never bypass required checks.
- **No-progress cap:** if repeated attempts make no forward progress (same
  failure twice, or no new commit), stop and report the blocker in the result
  summary rather than looping.
- Commit only real diffs; if there is nothing to change, say so in the result.
