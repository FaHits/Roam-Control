# 手绘闭环路线实施状态

本文件是跨 AI 窗口的当前进度来源。任务方法以 `Documentation/Plans/ManualRunningRoutesImplementation.md` 为准，设计和架构以 `Documentation/Plans/ManualRunningRoutesDesign.md` 为准。

## 当前交接

- 功能：手绘闭环路线与拟人跑步模拟
- 当前分支：`feat/manual-running-routes`
- 源码基线：`b68dac0`
- 目标版本：`0.10.0`
- 目标构建号：`62`
- 当前任务：Task 2 - 路线坐标与闭环几何
- 任务状态：`completed`
- 当前执行窗口：Codex Task 2
- 最近完成：Task 2 - 路线坐标与闭环几何
- 已完成工程修改：
  - `RoamControl/Features/Routes/Models/GeoCoordinate.swift`
  - `RoamControl/Features/Routes/Models/RouteDefinition.swift`
  - `RoamControl/Features/Routes/Models/RouteGeometry.swift`
  - `RoamControlTests/RouteGeometryTests.swift`
  - `RoamControl.xcodeproj/project.pbxproj`
  - `RoamControl.xcodeproj/xcshareddata/xcschemes/RoamControl.xcscheme`
  - `RoamControlTests/BaselineTests.swift`
  - `.github/workflows/xcode-27.yml`
- 已完成的仓库准备：个人 fork、`fork` 远程、开发分支、版本规范、设计计划、跨窗口交接规则均已建立并纳入 Git
- 自动同步规则：任务验证完成后自动更新本文件、提交任务文件并推送到个人 fork，不需要用户再次提醒
- Task 2 测试结果：GitHub Actions `Xcode 27 verification` run `41048147464` 通过；Xcode 27.1 下 `RouteGeometryTests` 的 10 个用例全部通过，结果为 `TEST SUCCEEDED`
- Task 2 构建结果：同一 run 的 Debug 模拟器构建通过，结果为 `BUILD SUCCEEDED`
- 当前环境限制：本地工作区为 Windows，不能直接运行 `xcodebuild`；验证在 `xcode-27` runner 上完成
- 下一步：执行 Task 3 - 确定性拟人速度、步频和 GPS 抖动

## 自动完成规则

- 只有实际测试和构建通过的任务才能进入 `completed`。
- `completed` 后自动更新本文件、提交当前任务文件和状态文件、推送到 `fork`。
- 禁止使用 `git add .`，不得夹带其他窗口或用户的改动。
- 推送后必须核对远端哈希，再报告提交和 CI 状态。
- `implemented_unverified`、`blocked` 或 `in_progress` 不得由窗口自行升级为完成。

## 任务进度

| 任务 | 状态 | 结果或下一步 |
|---|---|---|
| Task 1：增加 XCTest 目标和最小基线测试 | `completed` | Xcode 27.1 测试与 Debug 构建均通过 |
| Task 2：路线坐标与闭环几何 | `completed` | Xcode 27.1 下 10 个几何测试与 Debug 构建均通过 |
| Task 3：确定性拟人速度、步频和 GPS 抖动 | `pending` | Task 2 已完成，可开始 |
| Task 4：纯 Swift 路线运行器 | `pending` | 等待 Task 3 |
| Task 5：路线库原子持久化 | `pending` | 等待 Task 4 |
| Task 6：路线库状态模型 | `pending` | 等待 Task 5 |
| Task 7：路线编辑器状态模型 | `pending` | 等待 Task 6 |
| Task 8：手动路线编辑界面 | `pending` | 等待 Task 7 |
| Task 9：路线库和运行设置界面 | `pending` | 等待 Task 8 |
| Task 10：恢复模型与设备会话基础 | `pending` | 等待 Task 9 |
| Task 11：运行中进度持久化 | `pending` | 等待 Task 10 |
| Task 12：运行卡片与主页整合 | `pending` | 等待 Task 11 |
| Task 13：中断路线恢复 | `pending` | 等待 Task 12 |
| Task 14：完整验证 | `pending` | 等待 Task 13 |

## 交接记录

### 2026-10-30

- 建立 `AGENTS.md`、持续开发规范和仓库内设计/计划副本。
- 尚未开始源码任务。
- 下一窗口只执行 Task 1，不进入路线几何或 UI。

### 2026-10-30 Task 1 完成记录

- 任务：Task 1 - 增加 XCTest 目标和最小基线测试
- 状态：`completed`
- 分支与基线：`feat/manual-running-routes`，源码基线 `b68dac0`
- 修改文件：
  - `RoamControl.xcodeproj/project.pbxproj`
  - `RoamControl.xcodeproj/xcshareddata/xcschemes/RoamControl.xcscheme`
  - `RoamControlTests/BaselineTests.swift`
  - `.github/workflows/xcode-27.yml`
  - `Documentation/ImplementationStatus.md`
- 工程配置：新增 `RoamControlTests` unit-test target、`RoamControlTests.xctest` 产品、同步测试源码组、App target dependency、共享 `RoamControl` scheme；Debug 工程配置开启 `ENABLE_TESTABILITY`
- 版本：App `MARKETING_VERSION = 0.9.2`、`CURRENT_PROJECT_VERSION = 61` 未变；未添加第三方依赖
- 测试命令：`xcodebuild test -project RoamControl.xcodeproj -scheme RoamControl -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -only-testing:RoamControlTests CODE_SIGNING_ALLOWED=NO`
- 测试结果：GitHub Actions run `41039599444`、Xcode 27.1（build 27A9275）、iOS 27.1 SDK；`BaselineTests.testLocationTargetPreservesCoordinate()` 通过（0.008 秒），结果为 `TEST SUCCEEDED`
- 构建命令：`xcodebuild build -project RoamControl.xcodeproj -scheme RoamControl -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`
- 构建结果：`BUILD SUCCEEDED`；job `124008844147` 总耗时 4 分 44 秒
- 未验证内容：本地 Windows 无法运行 `xcodebuild`；Task 1 基线测试不涉及真机、设备会话或真实定位
- 已知风险：Xcode 27 runner 当前提供 `iPhone 17` 而非计划示例中的 `iPhone 17 Pro`；工作流出现 `actions/checkout@v4` 的 Node.js 20 弃用提示，不影响本次测试和构建
- 下一步第一条命令或动作：下一窗口先检查 Git 状态和本文件；开始 Task 2 前将其标记为 `in_progress`
- 验证提交：`3cf606e6dae9fd52a45410dfd9c6fce0d5192479`
- 工作流：https://github.com/FaHits/Roam-Control/actions/runs/41039599444
- 更新时间：2026-10-30

### 2026-10-30 仓库治理完成

- 任务：把跨窗口开发规则、设计、计划和版本规范纳入 Git。
- 状态：`completed`。
- 修改文件：`AGENTS.md`、`Documentation/AIDevelopment.md`、`Documentation/ImplementationStatus.md`、`Documentation/Plans/`、`VERSIONING.md`。
- 自动化规则：已通过验证的任务完成后，窗口自动更新状态、创建任务提交、推送到 `fork` 并核对远端。
- 验证要求：文档格式检查通过；代码测试与构建的最新证据仍为 Task 1 的 CI run `41039599444`。
- 下一步：Task 2 可认领。下一步第一条动作是读取 Task 2 并将状态改为 `in_progress`。
- 更新时间：2026-10-30

### 2026-10-30 Task 2 完成记录

- 任务：Task 2 - 路线坐标与闭环几何
- 状态：`completed`
- 分支与基线：`feat/manual-running-routes`，源码基线 `24cb5ad`
- 修改文件：
  - `RoamControl/Features/Routes/Models/GeoCoordinate.swift`
  - `RoamControl/Features/Routes/Models/RouteDefinition.swift`
  - `RoamControl/Features/Routes/Models/RouteGeometry.swift`
  - `RoamControlTests/RouteGeometryTests.swift`
  - `Documentation/ImplementationStatus.md`
- 模型：新增 `GeoCoordinate`、`RouteSource`、`RouteDefinition`、`RouteGeometryError` 和 `RouteGeometry`
- 几何规则：校验有限经纬度；连续距离小于 0.5 米的点折叠；闭环至少 3 个有效点、开放路线至少 2 个；闭环接缝只由 `RouteGeometry` 添加一次；总长度包含闭合段；负距离返回起点，达到或超过总长度返回终点；段内使用线性经纬度插值
- 红灯命令：`xcodebuild test -project RoamControl.xcodeproj -scheme RoamControl -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -only-testing:RoamControlTests CODE_SIGNING_ALLOWED=NO`
- 红灯结果：run `41043952436` 在 `RouteGeometryTests.swift:5` 以 `cannot find 'GeoCoordinate' in scope` 失败，确认测试先于生产类型存在
- 绿灯测试命令：`xcodebuild test -project RoamControl.xcodeproj -scheme RoamControl -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -only-testing:RoamControlTests CODE_SIGNING_ALLOWED=NO`
- 测试结果：run `41048147464`、job `124037253823`、Xcode 27.1；`RouteGeometryTests` 10 个用例全部通过，结果为 `TEST SUCCEEDED`
- 构建命令：`xcodebuild build -project RoamControl.xcodeproj -scheme RoamControl -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`
- 构建结果：`BUILD SUCCEEDED`
- 静态检查：`git diff --check` 通过；路线模型与测试未导入 `MapKit` 或 `SwiftUI`
- 已知风险：本地 Windows 无法运行 `xcodebuild`；runner 出现一次瞬时的 iOS 模拟器 service hub 告警和 `invalidDigitCount` 日志，但测试与构建均成功；`coordinate(atDistance:)` 按任务约定将超过总长的距离夹到终点，后续圈数推进逻辑必须自行记录圈数并将圈内距离传入该 API
- 验证提交：`cfff42a`
- 工作流：https://github.com/FaHits/Roam-Control/actions/runs/41048147464
- 下一步：执行 Task 3 - 确定性拟人速度、步频和 GPS 抖动
- 更新时间：2026-10-30
