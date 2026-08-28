# 设计文档

本目录存放与 issue-fix 插件（本仓库）相关的设计文档副本。原件在主仓
[Verdure-oss/ai-factory](https://github.com/Verdure-oss/ai-factory) 的
`docs/superpowers/specs/` 下；这里放一份，让插件仓自解释。

| 文档 | 内容 |
| --- | --- |
| `2026-08-26-codex-skill-delegated-agent-design.md` | 委托模式的起点设计：为什么让 Codex 自己走完 issue→PR，SKILL.md 契约与结果回传 |
| `2026-08-28-codex-plugin-marketplace-design.md` | 本仓库的由来：把单个 SKILL.md 改造成 marketplace 插件（多 skill、push 即生效、不重建 go-dev），含 pod 内实测结论 |

主仓变更（Go / helm / 脚本）走分支 + PR；本仓库的 skill 内容可直接 push `main`，
下一个 ai-factory 任务会自动 `marketplace upgrade` + `plugin add` 取到。
