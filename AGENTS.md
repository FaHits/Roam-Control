# AI 开发协作规则

本文件适用于整个 `roam-src` 仓库。任何 AI 在本仓库开始工作前，必须先读取本文件和 `Documentation/AIDevelopment.md`。

## 强制启动流程

1. 确认当前目录、Git 分支和工作树状态。
2. 阅读 `Documentation/ImplementationStatus.md`，确认当前允许执行的任务。
3. 阅读 `Documentation/Plans/ManualRunningRoutesDesign.md` 和当前任务对应的实施计划章节。
4. 检查 `VERSIONING.md`，不要擅自改变版本号、构建号或路线数据格式版本。
5. 当前用户指令与仓库文档冲突时，先执行当前用户指令，并同步更新交接文档。

聊天记录不是长期事实来源。后续窗口只以仓库内文档、Git 状态和实际测试结果为准。

## 事实优先级

发生冲突时按以下顺序处理：

1. 当前用户明确指令。
2. 本文件。
3. `Documentation/ImplementationStatus.md` 中的当前任务和阻塞状态。
4. `Documentation/Plans/ManualRunningRoutesImplementation.md`。
5. `Documentation/Plans/ManualRunningRoutesDesign.md`。
6. 历史聊天或压缩摘要。

## 单任务规则

- 一次只执行一个计划任务，不顺手实现后续任务。
- 修改前先向用户简述本任务会改哪些区域、验收标准是什么。
- 先补能失败的测试，再实现最小可用代码。
- 不添加第三方依赖，不重构与当前任务无关的代码。
- 不覆盖、不回滚其他窗口或用户留下的未提交改动。
- 同一分支同一时间只允许一个窗口写入。状态文件显示其他任务正在执行时，不并发修改同一分支。
- 任务完成后按“自动完成与同步”执行，不等待用户再次提醒提交或推送；用户明确要求暂停同步时除外。

## 完成标准

一个任务只有同时满足以下条件才算完成：

- 计划中要求的文件和接口已经实现。
- 针对性测试通过。
- Debug 构建通过；涉及发布配置时补做 Release 构建。
- 现有固定位置和 Apple 步行路线没有被破坏。
- `Documentation/ImplementationStatus.md` 已记录文件、命令、结果、风险和下一任务。

如果当前机器没有 macOS、Xcode 27 或 iOS 27 SDK，只能标记为 `implemented_unverified`，不得声称构建或测试通过。

## 自动完成与同步

任务从 `in_progress` 进入 `completed` 时，执行者必须自动完成以下收尾，不等待用户提醒：

1. 更新 `Documentation/ImplementationStatus.md`，写入真实测试、构建、风险和下一任务。
2. 运行 `git diff --check` 和 `git status --short`。
3. 只暂存当前任务文件和状态文件，禁止使用 `git add .` 或顺带暂存其他窗口的改动。
4. 使用规范前缀创建提交，例如 `feat(routes): ...`、`fix(recovery): ...`、`docs(repo): ...`。
5. 将当前分支推送到个人 fork：`git push fork HEAD:<当前分支>`。
6. 用 `git ls-remote fork refs/heads/<当前分支>` 确认远端提交与本地 `HEAD` 一致。
7. 在最终回复中报告提交哈希、推送结果和 CI 的当前状态。
8. 推送后才发现提交内容有误时，只能追加新的修复提交；不得对已推送历史使用 `git commit --amend`、`git rebase`、`git push --force` 或 `git push --force-with-lease`。
9. 普通 `git push` 被远端拒绝时，停止并报告，不要改用 force 推送。

只有测试和构建都通过的任务才自动进入 `completed` 并提交推送。`implemented_unverified`、`blocked` 或 `in_progress` 状态不得伪装成完成；窗口中断时至少把状态和下一步写入交接文件，但不能声称任务完成。

`main` 分支禁止自动提交或推送。若暂存区出现无关改动、当前分支与状态文件不一致或另一个窗口正在写入同一分支，立即停止自动收尾并报告冲突。

## 交接规则

每个窗口结束前必须更新 `Documentation/ImplementationStatus.md`，至少包含：

- 当前任务编号和状态。
- 修改过的文件。
- 已运行的测试或构建命令及真实结果。
- 未验证内容和已知风险。
- 下一个窗口可以直接执行的第一步。

下一窗口从状态文件继续，不要求用户重新解释整个项目。
