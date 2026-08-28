# ai-factory-codex-plugins

Codex marketplace plugins for [ai-factory](https://github.com/Verdure-oss/ai-factory)
delegated workflows.

This repository is a **Codex plugin marketplace**. It is consumed by the
ai-factory coding agent (`ai-factory-agent codex`) inside sandbox pods: at the
start of each task, the agent registers this marketplace and installs the
`issue-fix` plugin, so editing a skill here and pushing takes effect on the next
task — no image or pod rebuild.

## Layout

```
.agents/plugins/marketplace.json    # marketplace catalog (harness-neutral; Codex reads this)
plugins/issue-fix/
  .codex-plugin/plugin.json          # plugin manifest
  skills/issue-fix/
    SKILL.md                         # the delegated workflow playbook
    references/github.md             # gh (GitHub) command recipes
    references/gitlab.md             # glab (GitLab) command recipes
```

## How it is used

```sh
codex plugin marketplace add Verdure-oss/ai-factory-codex-plugins
codex plugin marketplace upgrade          # fetch latest after a push
codex plugin add issue-fix@ai-factory     # (re)install into CODEX_HOME/plugins/cache
```

`codex exec` then loads the plugin's skills automatically; the model selects a
skill by its front-matter `description`.

## Updating

Edit a skill, commit, and push. The next ai-factory task runs
`marketplace upgrade` + `plugin add` and picks up the change. Bumping the
`version` in `marketplace.json` / `plugin.json` is optional — `plugin add`
re-copies the source even at the same version.

## Roadmap

Currently a single `issue-fix` skill (migrated from the ai-factory repo). It will
be split into role-based skills (e.g. speccer / planner / builder / reviewer /
cleanup) as the workflow grows.
