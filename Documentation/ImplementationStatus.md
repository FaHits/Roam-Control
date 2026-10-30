# 手绘闭环路线实施状态

本文件是跨 AI 窗口的当前进度来源。任务方法以 `Documentation/Plans/ManualRunningRoutesImplementation.md` 为准，设计和架构以 `Documentation/Plans/ManualRunningRoutesDesign.md` 为准。

## 当前交接

- 功能：手绘闭环路线与拟人跑步模拟
- 当前分支：`feat/manual-running-routes`
- 源码基线：`b68dac0`
- 目标版本：`0.10.0`
- 目标构建号：`62`
- 当前任务：Task 3 - 确定性拟人速度、步频和 GPS 抖动
- 任务状态：`completed`
- 当前执行窗口：DSH Task 3（2026-10-30 19:52 起，Asia/Shanghai）
- 最近完成：Task 3 - 确定性拟人速度、步频和 GPS 抖动
- 已完成工程修改：
  - `RoamControl/Features/Routes/Models/RunProfile.swift`
  - `RoamControl/Features/Routes/Core/HumanizedMotionModel.swift`
  - `RoamControlTests/HumanizedMotionModelTests.swift`
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
- Task 3 测试结果：GitHub Actions `Xcode 27 verification` run `41055798306` 通过；Xcode 27.1 下 `HumanizedMotionModelTests` 的 8 个用例全部通过，`RoamControlTests` 全量 19 个用例 0 失败，结果为 `TEST SUCCEEDED`
- Task 3 构建结果：同一 run 的 `Build Debug` 步骤通过，结果为 `BUILD SUCCEEDED`
- 当前环境限制：本地工作区为 Windows，不能直接运行 `xcodebuild`；验证在 `xcode-27` runner 上完成
- 下一步：执行 Task 4 - 纯 Swift 路线运行器

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
| Task 3：确定性拟人速度、步频和 GPS 抖动 | `completed` | Xcode 27.1 下 8 个运动模型测试与全量 19 个测试通过 |
| Task 4：纯 Swift 路线运行器 | `pending` | Task 3 已完成，可开始 |
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

### 2026-10-30 Task 3 完成记录

- 任务：Task 3 - 确定性拟人速度、步频和 GPS 抖动
- 状态：`completed`
- 分支与基线：`feat/manual-running-routes`，源码基线 `15e229ad0928bcc056d0dc90575be20e71136e12`
- 修改文件：
  - `RoamControl/Features/Routes/Models/RunProfile.swift`
  - `RoamControl/Features/Routes/Core/HumanizedMotionModel.swift`
  - `RoamControlTests/HumanizedMotionModelTests.swift`
  - `Documentation/ImplementationStatus.md`
- 接口：`RunProfileValidationError`（`invalidSpeed`、`invalidCadence`、`invalidVariation`、`invalidJitter`）、`RunProfile`（六个字段、`static let running`、`validate()`）、`HumanizedMotionModel(seed:)` 及其 `speedMetersPerSecond(at:profile:)`、`cadenceStepsPerMinute(at:profile:)`、`reportedCoordinate(for:at:profile:)`
- 取值范围：速度 `0.5...10.0` m/s、步频 `60...240` spm、变化比例 `0...0.35`、抖动半径 `0...10` m；`ClosedRange.contains` 同时拒绝 NaN 和 ±∞，边界值本身合法
- 算法：由 `noiseSeed` 经 SplitMix64 生成 12 个固定相位；速度、步频、抖动南北轴、抖动东西轴各用三个低频正弦（权重 0.5/0.3/0.2）加权求和，按权重和归一化并夹到 `-1...1`，输出因此被解析地限制在 `target × (1 ± variation)`；抖动两轴各限制在 `radius / √2`，合矢量必然不超过半径，不需要事后截断；米制偏移用保守的每度米数（纬度 111700、经度 111320·cos(latitude)）换算，真实大圆距离恒不大于配置半径；半径为 0 时函数第一步直接返回地面坐标，逐位相同
- 测试覆盖：8 个用例，含边界合法性（0.5/10.0、60/240、0/0.35、0/10）、NaN 与 ±∞ 拒绝、0/0.25/1/7.25/61/600/3600/86400 秒采样、抖动半径 0.5/1.5/10 米全时段扫描、1 秒步进 12 秒平滑性（阈值取独立随机点平均间距 `128R/(45π) ≈ 0.905R` 的 30%）
- 红灯命令：`xcodebuild test -project RoamControl.xcodeproj -scheme RoamControl -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -only-testing:RoamControlTests/HumanizedMotionModelTests CODE_SIGNING_ALLOWED=NO`
- 红灯结果：run `41055509171`（提交 `fb91b3f`）在 `HumanizedMotionModelTests.swift:6` 以 `cannot find 'RunProfile' in scope` 失败，失败原因正是类型尚不存在
- 绿灯命令：`xcodebuild test -project RoamControl.xcodeproj -scheme RoamControl -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -only-testing:RoamControlTests CODE_SIGNING_ALLOWED=NO`
- 绿灯结果：run `41055798306`、Xcode 27.1（build `27A9275`）；`HumanizedMotionModelTests` 8 个用例逐个通过（0.001–0.015 秒），全量 `RoamControlTests` 19 个用例 0 失败，`** TEST SUCCEEDED **`
- 构建命令：`xcodebuild build -project RoamControl.xcodeproj -scheme RoamControl -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`
- 构建结果：同一 run 的 `Build Debug` 步骤 `** BUILD SUCCEEDED **`
- 定向测试取证方式：本地为 Windows 且没有 `xcodebuild`，CI 工作流固定执行 `-only-testing:RoamControlTests`，因此只跑子集的命令没有实际执行；`HumanizedMotionModelTests` 的结果从 run 日志逐条用例提取，工作流文件未改动
- 静态检查：`git diff --check` 通过；`HumanizedMotionModel` 只导入 Foundation，不依赖 SwiftUI、MapKit、`AppModel` 或 CoreLocation
- 未验证内容：不涉及真机与真实定位；未验证后续运行器接入后的实际轨迹外观（本任务只产出纯函数）
- 已知风险：平滑阈值与 1e-6 米半径容差依赖当前正弦周期、权重和保守的每度米数换算；若后续调整这些常数，需要重新核对阈值余量。实测最大抖动幅度为 `0.845R`，相邻一秒位移约 `0.06R`，余量充足
- Task 4 前置状态：`RouteRunner` 可直接用 `HumanizedMotionModel(seed: profile.noiseSeed)` 取速度与步频，用 `reportedCoordinate(for:at:profile:)` 生成上报坐标；模型不推进行程、不改地面坐标，保存设置前可调用 `RunProfile.validate()`
- 验证提交：`35a879f`；同任务另含 `fb91b3f`（红灯测试）与 `fed5ca9`（测试辅助方法重命名）
- 工作流：https://github.com/FaHits/Roam-Control/actions/runs/41055798306
- 下一步第一条命令或动作：下一窗口先核对 Git 状态与本文件，再读取 Task 4 章节并把 Task 4 标记为 `in_progress`
- 更新时间：2026-10-30
