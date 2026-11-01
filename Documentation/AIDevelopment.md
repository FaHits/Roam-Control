# AI 持续开发与交接规范

本文件定义多个 AI 窗口连续实现 Roam Control 路线系统时的统一流程。它解决三个问题：新窗口从哪里继续、什么算完成、失败或中断后如何交接。

## 1. 事实来源

所有实现以仓库内容为准：

- 路线设计：`Documentation/Plans/ManualRunningRoutesDesign.md`（只保留在本地，不入库）
- 逐任务计划：`Documentation/Plans/ManualRunningRoutesImplementation.md`（同上）
- 当前进度：`Documentation/ImplementationStatus.md`
- 版本规范：`VERSIONING.md`
- Git 分支和实际差异：当前仓库状态

历史聊天只用于解释背景，不作为接口、状态或完成情况的证明。

## 2. 新窗口启动顺序

每个新窗口按以下顺序执行：

1. 运行 `git status --short --branch`。
2. 运行 `git log -1 --oneline`。
3. 阅读 `AGENTS.md`、本文件、`VERSIONING.md`。
4. 阅读 `Documentation/ImplementationStatus.md`。
5. 只阅读当前任务的计划章节，不一次加载整个计划的无关部分。
6. 检查任务依赖文件是否已存在，避免重复实现。
7. 在状态文件中把当前任务标记为 `in_progress`，写明窗口标识后再修改代码。

如果状态文件显示另一个任务在同一分支处于 `in_progress`，当前窗口不得同时写入。先完成、暂停或明确放弃该任务。

## 3. 单任务工作循环

每个任务严格执行：

1. 说明本任务的范围、将修改的文件和验收标准。
2. 确认 Git 工作树中的既有改动，不覆盖不属于当前任务的改动。
3. 写一个会失败的测试，并记录失败原因。
4. 实现满足测试的最小代码。
5. 运行针对性测试。
6. 运行 Debug 构建。
7. 检查是否影响固定位置和 Apple 步行路线。
8. 更新状态文件。
9. 运行格式检查并只暂存当前任务文件。
10. 自动提交并推送到个人 fork。
11. 核对远端提交并报告真实结果。

不得把多个计划任务合并为一次无法审查的大改动。

## 4. 状态定义

`Documentation/ImplementationStatus.md` 只使用以下状态：

- `pending`：尚未开始。
- `in_progress`：已有窗口认领并正在修改。
- `implemented_unverified`：代码已写，但当前环境无法完成测试或构建。
- `blocked`：缺少必要环境、权限、设备或上游决定。
- `completed`：测试和构建均通过，交接信息已补齐。
- `superseded`：被用户确认的新方案替代。

没有实际命令结果时，不得标记 `completed`。

## 5. 验证要求

核心路线逻辑必须使用 XCTest 覆盖。根据任务范围至少运行：

```bash
xcodebuild test \
  -project RoamControl.xcodeproj \
  -scheme RoamControl \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -only-testing:RoamControlTests \
  CODE_SIGNING_ALLOWED=NO
```

构建检查：

```bash
xcodebuild build \
  -project RoamControl.xcodeproj \
  -scheme RoamControl \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

涉及设备会话、后台运行、配对或真机定位时，模拟器结果不能代替真机验收。

当前 Windows 工作区不能运行 `xcodebuild`。在 Windows 中只能完成源码和工程文件修改；必须明确记录为 `implemented_unverified`，等待 macOS/Xcode 27 环境验证。

## 6. 架构边界

- 路线几何、运行器和拟人模型不依赖 SwiftUI、MapKit 或 `AppModel`。
- UI 只读取状态并发送命令，不计算下一坐标。
- GPS 抖动只修改上报坐标，不参与路线进度。
- 设备输出统一经过 `LocalDeviceSessionCoordinator.updateLocation(_:)`。
- 恢复快照包含完整路线，不依赖路线库当前条目。
- 固定位置不表示成零长度路线。
- GPX 和 Apple 路线是后续适配器，不复制第二套运行器。

需要改变以上边界时，先更新设计文档，再修改实现计划，不能只改代码。

## 7. 版本与分支

- 当前功能目标版本是 `0.10.0`，首个分发构建号是 `62`。
- 当前功能分支是 `feat/manual-running-routes`。
- 上游远程名是 `origin`，个人 fork 远程名是 `fork`。
- 不强制推送，不改写已推送历史。
  - 已推送的提交禁止 `git commit --amend`，包括只改提交信息或只改文档数字。
  - 已推送的提交禁止 `git rebase`，包括 `git rebase -i` 压缩或改写提交顺序。
  - 禁止 `git push --force` 和 `git push --force-with-lease`；`--force-with-lease` 不是安全例外。
  - 发现已推送提交有误时，追加一个新的修复提交，不重写远端历史。
  - 推送前检查 `git log --oneline fork/<当前分支>..HEAD`，确认将要推送的都是新提交；若需要修改的正是已推送提交，停止并报告，不要自行强推。
- 提交信息使用 `feat(routes):`、`fix(recovery):`、`test(routes):`、`docs(repo):` 等前缀。
- 已通过验证的任务默认自动提交并推送到 `fork`；用户明确要求暂停同步时除外。

## 8. 自动完成与同步

每个任务完成后，执行窗口自动执行：

```bash
git diff --check
git status --short
git add -- <当前任务文件> Documentation/ImplementationStatus.md
git commit -m "<规范前缀>: <结果>"
git push fork HEAD:feat/manual-running-routes
git ls-remote fork refs/heads/feat/manual-running-routes
```

规则：

- 不使用 `git add .`，不暂存其他窗口或用户留下的改动。
- App 版本、构建号和 `schemaVersion` 只在对应发布或兼容性任务中修改。
- 推送前确认当前分支不是 `main`。
- 推送后确认远端哈希等于本地 `HEAD`。
- 只有测试和构建通过的任务才标记 `completed` 并自动同步。
- `implemented_unverified`、`blocked` 和窗口中断不自动伪造成完成；交接文件必须保留真实验证状态和下一步。
- 推送或远端核对失败时，报告具体错误，不声称交接已经完成。

当前分支的 CI 由 `.github/workflows/xcode-27.yml` 在推送后自动运行。完成窗口应报告运行编号或链接；若 CI 尚未结束，应明确写“已触发、尚未完成”，不能提前写成通过。

## 9. 交接模板

每次结束一个窗口，在 `Documentation/ImplementationStatus.md` 中填写：

```text
任务：Task N - 名称
状态：pending | in_progress | implemented_unverified | blocked | completed
分支与基线：
修改文件：
测试命令与结果：
构建命令与结果：
未验证内容：
已知风险：
下一步第一条命令或动作：
更新时间：
```

接手窗口先验证状态文件与实际 Git 差异一致，再继续工作。
