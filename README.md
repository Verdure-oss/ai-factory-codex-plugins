# ai-factory-codex-plugins

为 [ai-factory](https://github.com/Verdure-oss/ai-factory) 的 **Codex 委托模式**提供工作流 skill 的 Codex 插件市场。

沙箱里的 Codex Agent 安装这里的 skill 后，能把 Issue 一路完成到 PR / MR：**理解需求 → 修改代码 → 本地跑检查 → 提交 → 推送 → 创建变更请求**。

## 包含的 skill

| Skill | 角色 | 作用 |
| --- | --- | --- |
| **issue-fix** | 编排者 | 把 Issue 做成 PR/MR 的总流程：理解需求 → 派发 builder 实现、reviewer 审查 → 提交、推送、开变更请求 |
| **builder** | 执行者 | 被 issue-fix 派发：实现最小正确改动并本地校验 |
| **reviewer** | 审查者 | 被 issue-fix 派发：审查改动 diff，给出 APPROVE / REQUEST_CHANGES |

`builder` / `reviewer` 是**角色 skill**（非独立触发），由编排者 `issue-fix` 按需加载。GitHub 与 GitLab 均支持。

## 使用方法

**在 ai-factory 中启用** —— 在部署配置里指向本仓库即可，Agent 会在每个任务开始时自动注册并安装最新插件：

```bash
# ai-factory.env（或 helm 值 codex.plugin.source）
AI_FACTORY_CODEX_PLUGIN_SOURCE=Verdure-oss/ai-factory-codex-plugins
```

**手动体验（可选）** —— 装有 Codex CLI 的机器上：

```sh
codex plugin marketplace add Verdure-oss/ai-factory-codex-plugins
codex plugin add issue-fix@ai-factory
```

**更新 skill** —— 编辑本仓库任一文件 → `git push` → **下一个 ai-factory 任务自动生效**，无需重建镜像或预热 pod。

## 仓库结构

```
.agents/plugins/marketplace.json          # 市场清单：声明提供哪些插件
plugins/issue-fix/                        # issue-fix 插件
├── .codex-plugin/plugin.json             # 插件清单
└── skills/
    ├── issue-fix/                        # 编排 skill（总控流程）
    │   ├── SKILL.md                      # 主流程 + 安全约束
    │   ├── references/                   # gh / glab 命令参考
    │   │   ├── github.md
    │   │   └── gitlab.md
    │   └── scripts/local-ci.sh           # 提交前的本地检查辅助
    ├── builder/SKILL.md                  # builder 角色 skill
    └── reviewer/SKILL.md                 # reviewer 角色 skill
```

## 开发与贡献

1. 编辑 `plugins/issue-fix/skills/` 下对应 skill 的文件
2. 提交并推送
3. 下一个 ai-factory 任务即生效

## 相关

- 主仓 [ai-factory](https://github.com/Verdure-oss/ai-factory) —— 完整部署文档：`docs/self-hosted/guide.md` §2.9（Codex 委托模式）
- 设计文档：`docs/`
