---
name: issue-fix
description: Use when running as the delegated coding agent inside an ai-factory sandbox — the AI_FACTORY_* environment variables are set, and the task is a repository issue that must reach an opened pull request or merge request with no controller step afterwards. This skill is the orchestrator: it plans, then dispatches the builder and reviewer role skills, then commits, pushes, and opens the change request.
---

# ai-factory issue-fix (delegated workflow)

You are Codex running inside an ai-factory sandbox. The repository is already
cloned and checked out at `AI_FACTORY_WORKDIR` (default `/workspace/repo`), git
auth is already in the environment, and you are authenticated. **You own the
whole workflow** and act as its **orchestrator**: the controller runs no
commit/push/PR/CI steps after you — if you do not push and open the change
request, nothing will.

You drive two role skills in sequence:

| Role | Skill | What it does |
| --- | --- | --- |
| **Builder** | `skills/builder/SKILL.md` (`../builder/SKILL.md`) | Implements the fix and validates it locally — no commit/push |
| **Reviewer** | `skills/reviewer/SKILL.md` (`../reviewer/SKILL.md`) | Audits the diff with an independent perspective and gives a verdict |

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
| `AI_FACTORY_CI_COMMANDS` | optional, semicolon-separated validation commands injected for this task — may be unset, then skip |
| `AI_FACTORY_GIT_PROXY` | git proxy host used to rewrite `origin` (see provider references) |
| `GITHUB_TOKEN` / `GITLAB_TOKEN` | git + `gh`/`glab` auth (already exported) |

The task instructions (the issue) are the prompt you were given.

## Workflow

1. **Understand + plan.** Read the issue and locate the relevant code (`rg`,
   `find`, read files). Reproduce the problem when practical. Write a plan to
   `.ai-factory/plan.md` (REQUIRED): the problem, the proposed fix, and each
   requirement classified IN scope / OUT of scope / UNCERTAIN. Follow the
   repository's own conventions and `AGENTS.md`/contributor rules.

2. **Build phase.** Load and follow the **builder** skill
   (`skills/builder/SKILL.md`): it creates the change branch off the base,
   implements the smallest correct fix, and validates it locally. The builder
   does **not** commit or push — edits stay in the working tree.

3. **Review phase.** Load and follow the **reviewer** skill
   (`skills/reviewer/SKILL.md`): it audits the working-tree diff against the
   plan and issue, and returns a verdict — **APPROVE** or **REQUEST_CHANGES**
   with concrete reasons.

4. **Iterate until approved.** On **REQUEST_CHANGES**, return to the build phase
   with the reviewer's reasons, re-implement, and re-review. Stop at the
   no-progress cap: the same failure twice, or no new commit, means report the
   blocker instead of looping.

5. **Commit, push, open the PR/MR.** Once approved, commit with a semantic
   message, push the branch, and open the change request — see below.

6. **Report the result** (required — see "Result contract").

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

**PR/MR body.** Keep `AI_FACTORY_PR_BODY` when set as the **opening line** — it
records that the change was generated by ai-factory (e.g. "Generated by
ai-factory for <url>"). Then compose the REQUIRED template below. Every field
is REQUIRED; write `None` when a field has no content:

```text
<AI_FACTORY_PR_BODY opening line>

Changes:
- <what changed, one point per line>
- <reason when not obvious from the code>

Validation:   <checks run and their result, or
              "N/A: environment lacks X — relying on remote CI">
Out of scope: <requests you declined, or None>

Resolves <AI_FACTORY_ISSUE_URL>
```

The opening line and the `Resolves` line both reference the issue — that is not
a conflict. `Resolves` is the only closing instruction (it auto-closes the
issue on merge; GitHub and GitLab both accept it), while the opening line only
records who generated the PR and never closes anything. Always keep `Resolves`.
`Out of scope` is where the scope rules below require you to record declined
requests.

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
- The builder never commits, pushes, or opens a change request; the reviewer
  never modifies files. Only you, the orchestrator, do after review passes.
