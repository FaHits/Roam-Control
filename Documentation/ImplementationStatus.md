# 手绘闭环路线实施状态

本文件是跨 AI 窗口的当前进度来源。任务方法以 `Documentation/Plans/ManualRunningRoutesImplementation.md` 为准，设计和架构以 `Documentation/Plans/ManualRunningRoutesDesign.md` 为准。

## 当前交接

> 2026-11-01 Task 14 A 段交付：10 条自动化门禁全过，README / CHANGELOG / Issue 模板按 fork 现状改写，任务状态统一为 `implemented`；19 项真机行为登记在 [`Documentation/Handoffs/2026-10-31-rework-handoff.md`](Handoffs/2026-10-31-rework-handoff.md) 第 7 节，由用户执行 B 段后逐行回填。2026-10-31 的返工方案仍以该交接文档为准。

- 功能：手绘闭环路线与拟人跑步模拟
- 当前分支：`feat/manual-running-routes`
- 源码基线：`a7b68b2`
- 目标版本：`0.10.0`
- 目标构建号：`62`
- 当前任务：Task 14 - 最终全量回归 —— `implemented`（A 段门禁与产物已交付，最终 HEAD `28472c6`，CI run `41271600000` 三 job 全绿、153 用例 0 失败；同代码状态的过程记录 run `41271064818`（head `c027584`）只留作过程记录，不是装机源；2026-11-01 用户在 build `88ba4ff`（run `41272520335`，Release artifact `13069868630` / 3,109,102 字节）实机跑完交接文档第 7 节 28 项，全部 pass；真机另暴露两条设计问题（见第 7 节后「真机暴露的设计问题」：语言弹窗按 enum 判定、缺少显式「保持在当前点」），第一条由 14G 收到 14H：14H 把判定改成「`Bundle.preferredLocalizations` 反映的显示语言」对比「选择将要生效的语言」，并让 `apply()` 无条件执行（14G 只比较存储偏好的解析值，未重启场景仍误判，那条路径已删除）；第二条归入 0.10.0 之后的任务，故仍不写 `completed`）
- 任务状态：Task 14 `implemented`（自动化门禁、CI 与最终 IPA 已交付；第 7 节 28 项真机行为首轮全部 pass，未标 `completed`）；Task 9R / 19 / 16R / 20 / 17 / 18 全部 `implemented`，真机项与交接文档第 7 节逐行对齐（9R #1–#7、19 #8–#9、16R #10–#11、20 #12–#15、17 #16、18 #17 与 #19、历史回归 #18）；`DeviceCoordinateAdapter.live` 保持 `.gcj02ToWGS84`
- Task 17 收尾口径：代码/测试 run `41236893110`（head `76d41f1`）与最终 HEAD run `41237968926`（head `b414c21`，含文档提交）三 job 均 success；最终 HEAD 产物 Release `RoamControl-unsigned-ipa` id `13056249465` / 3,107,749 字节、Debug `RoamControl-unsigned-debug-ipa` id `13056740573` / 4,635,484 字节
- 当前执行窗口：Task 14 收尾；下一步为用户用 14H 产物（Run `41289235750` / Release artifact `13077195268` / 3,109,539 字节）重测 L1 / L3 / L6 三项，三项绿则把 Task 14 标 `completed`，并打 `v0.10.0` 与 `v0.10.0-fa.1`
- 并行任务：无。Task 16 的返工已在 Task 16R 内完成，语言弹窗与英文残留项以 Task 16R 记录为准
- 最近完成：Task 14H（语言重启提示改为比较显示语言，`AppLanguage.requiresRestart` 删除，新增 `displayed` / `shouldPromptRestart` / `recordSystemLanguageIfUnoverridden`；14G 的解析值比较在未重启场景仍误判、且弹窗分支让 `apply()` 不落地，一并修掉），HEAD `1b1ff42` CI run `41289235750` 三 job 全绿、158 用例 0 失败
- 已完成工程修改：
  - `RoamControl/Features/Routes/Views/RouteRunCard.swift`
  - `RoamControl/Features/Map/MapViewModel.swift`
  - `RoamControl/Features/Home/HomeView.swift`
  - `RoamControl/Features/Routes/State/RouteSessionModel.swift`
  - `RoamControl/Models/SessionRecoveryRecord.swift`
  - `RoamControl/App/AppModel.swift`
  - `RoamControlTests/RouteRecoveryTests.swift`
  - `RoamControlTests/RouteSessionModelTests.swift`
  - `RoamControl/Features/Routes/Views/RouteEditorView.swift`
  - `RoamControl/Features/Routes/Views/RouteLibraryView.swift`
  - `RoamControl/Features/Routes/Views/RouteRunSetupView.swift`
  - `RoamControl/Features/Routes/State/RouteEditorModel.swift`
  - `RoamControlTests/RouteEditorModelTests.swift`
  - `RoamControlTests/RouteProfileStoreTests.swift`
  - `RoamControl/Features/Routes/State/RouteNameValidator.swift`
  - `RoamControl/Features/Routes/State/RouteLibraryModel.swift`
  - `RoamControlTests/RouteLibraryModelTests.swift`
  - `RoamControl/Features/Routes/Storage/RouteStore.swift`
  - `RoamControlTests/RouteStoreTests.swift`
  - `RoamControl/Features/Routes/Models/RouteRunMode.swift`
  - `RoamControl/Features/Routes/Core/RouteRunner.swift`
  - `RoamControlTests/RouteRunnerTests.swift`
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
- Task 4 测试结果：GitHub Actions `Xcode 27 verification` run `41061243835` 通过；Xcode 27.1 下 `RouteRunnerTests` 的 18 个用例全部通过，`RoamControlTests` 全量 37 个用例 0 失败，结果为 `TEST SUCCEEDED`
- Task 4 构建结果：同一 run 的 `Build Debug` 步骤通过，结果为 `BUILD SUCCEEDED`
- Task 5 测试结果：GitHub Actions `Xcode 27 verification` run `41066742147` 通过；Xcode 27.1 下 `RouteStoreTests` 的 8 个用例全部通过，`RoamControlTests` 全量 45 个用例 0 失败，结果为 `TEST SUCCEEDED`
- Task 5 构建结果：同一 run 的 `Build Debug` 步骤通过，结果为 `BUILD SUCCEEDED`
- Task 6 测试结果：GitHub Actions `Xcode 27 verification` run `41070257714` 通过；Xcode 27.1 下 `RouteLibraryModelTests` 的 12 个用例全部通过，`RoamControlTests` 全量 57 个用例 0 失败，结果为 `TEST SUCCEEDED`
- Task 6 构建结果：同一 run 的 `Build Debug` 步骤通过，结果为 `BUILD SUCCEEDED`
- Task 7 测试结果：GitHub Actions `Xcode 27 verification` run `41075730246` 通过；Xcode 27.1 下 `RouteEditorModelTests` 的 21 个用例全部通过，`RoamControlTests` 全量 78 个用例 0 失败，结果为 `TEST SUCCEEDED`
- Task 7 构建结果：同一 run 的 `Build Debug` 步骤通过，结果为 `BUILD SUCCEEDED`
- Task 8 测试结果：GitHub Actions `Xcode 27 verification` run `41079471220` 通过；Xcode 27.1 下 `RoamControlTests` 全量 78 个用例 0 失败，结果为 `TEST SUCCEEDED`（本任务只新增视图，未新增测试）
- Task 8 构建结果：同一 run 的 `Build Debug` 步骤通过，结果为 `BUILD SUCCEEDED`
- Task 8 验收修正测试结果：GitHub Actions run `41088976344` 通过；`RoamControlTests` 全量 80 个用例 0 失败（新增 2 个 `canSave` 名称测试），结果为 `TEST SUCCEEDED`
- Task 8 验收修正构建结果：同一 run 的 `Build Debug` 步骤通过，结果为 `BUILD SUCCEEDED`
- Task 9 测试结果：GitHub Actions `Xcode 27 verification` run `41095688833` 通过；Xcode 27.1 下 `RouteProfileStoreTests` 的 3 个用例全部通过，`RoamControlTests` 全量 83 个用例 0 失败，结果为 `TEST SUCCEEDED`
- Task 9 构建结果：同一 run 的 `Build Debug` 步骤通过，结果为 `BUILD SUCCEEDED`
- Task 9R 红灯：run `41214550560`（head `2be0f25`）`Run RoamControlTests` 失败，`RouteLibraryModelTests.swift:158` 报 `cannot find 'RouteNameValidator' in scope`，确认 4 条新测试先于实现存在
- Task 9R 测试结果：run `41214754177`（head `b50fe68`）`conclusion=success`；`RouteLibraryModelTests` 16 个用例（新增 4 个名称规范化用例）全部通过，`RoamControlTests` 全量 123 个用例 0 失败，结果为 `** TEST SUCCEEDED **`
- Task 9R 构建结果：同一 run 的 `Build Debug` 与 `Build Release` 均通过，结果为 `** BUILD SUCCEEDED **`
- Task 9R 产物：最终 HEAD `a873844` 的 run `41215787777` 产出 Release IPA artifact `RoamControl-unsigned-ipa` id `13048681679` / 3,146,361 字节；Debug IPA artifact `RoamControl-unsigned-debug-ipa` id `13048498113` / 4,731,549 字节。中间 run `41214754177` 的 `13048490403` / `13048205807` 仅作过程记录
- Task 9R 真机项：执行方无法接触 iOS 真机，7 项行为改由用户批量验证，登记在 [`Documentation/Handoffs/2026-10-31-rework-handoff.md`](Handoffs/2026-10-31-rework-handoff.md) 第 7 节，Task 14 前一次装最终 IPA 全测
- Task 10 测试结果：GitHub Actions `Xcode 27 verification` run `41102340345` 通过；Xcode 27.1 下新增 `RouteRecoveryTests` 6 个用例、`RouteSessionModelTests` 3 个用例全部通过，`RoamControlTests` 全量 92 个用例 0 失败，结果为 `TEST SUCCEEDED`
- Task 10 构建结果：同一 run 的 `Build Debug` 步骤通过，结果为 `BUILD SUCCEEDED`
- Task 11 测试结果：GitHub Actions `Xcode 27 verification` run `41156408775` 通过；Xcode 27.1 下新增 `RouteRecoveryTests` 4 个用例全部通过，`RoamControlTests` 全量 96 个用例 0 失败，结果为 `TEST SUCCEEDED`
- Task 11 构建结果：同一 run 的 `Build Debug` 步骤通过，结果为 `BUILD SUCCEEDED`
- Task 12 测试结果：GitHub Actions `Xcode 27 verification` run `41160737660` 通过；Xcode 27.1 下 `RoamControlTests` 全量 96 个用例 0 失败，结果为 `TEST SUCCEEDED`（本任务只新增视图与接线，未新增测试）
- Task 12 构建结果：同一 run 的 `Build Debug` 步骤通过，结果为 `BUILD SUCCEEDED`
- Task 13 测试结果：GitHub Actions `Xcode 27 verification` run `41162486040` 通过；Xcode 27.1 下 `RoamControlTests` 全量 98 个用例 0 失败，结果为 `TEST SUCCEEDED`（新增 2 个用例，invalid-progress 复用 `RouteSessionModelTests.testPrepareRejectsNegativeProgress`）
- Task 13 构建结果：同一 run 的 `Build Debug` 步骤通过，结果为 `BUILD SUCCEEDED`
- 当前环境限制：本地工作区为 Windows，不能直接运行 `xcodebuild`；验证在 `xcode-27` runner 上完成
- （2026-10-31 记录，已被 2026-11-01 A 段记录取代，仅作历史证据）以下 6 条为当时基线上的证据，不代表当前状态
- Task 14 架构边界：两条 `rg`（`import (SwiftUI|MapKit)|AppModel` 与 `MKRoute|MKMapPoint|MKPolyline`，范围 `Routes/Core` + `Routes/Models`）均无输出，`exit=1`，无架构违规
- Task 14 测试结果：GitHub Actions `Xcode 27 verification` run `41166020073`（触发提交 `9b4984a` `ci: verify release build`）`conclusion=success`；Xcode 27.1 下 `RoamControlTests` 全量 98 个用例 0 失败，98 行 `Test case … passed`、0 行 `failed`，结果为 `** TEST SUCCEEDED **`（未新增测试）
- Task 14 Debug 构建结果：同一 run 的 `Build Debug` 步骤 `** BUILD SUCCEEDED **`
- Task 14 Release 构建结果：同一 run 新增的 `Build Release` 步骤 `** BUILD SUCCEEDED **`；该步骤为本次补入的 CI 缺口（此前工作流只有 test + Debug）
- Task 14 手工验收：模拟器与真机清单全部未验证（本机为 Windows，无 macOS、无 iOS 模拟器、无配对设备），不记为通过
- 当时遗留的手工验收（模拟器清单与真机后台长跑、强制退出恢复）后来统一由用户按交接文档第 7 节 19 行执行；此条为历史陈述，不再作为行动指令
- Task 15 改动文件：新增 `RoamControl/Services/Location/ChinaCoordinateTransform.swift`、`RoamControl/Services/Location/DeviceCoordinateAdapter.swift`、`RoamControl/Services/Location/DeviceLocationProbe.swift`（`#if DEBUG`，真机读回）、`RoamControl/Features/Settings/CoordinateDiagnosticsView.swift`、`RoamControlTests/ChinaCoordinateTransformTests.swift`、`RoamControlTests/DeviceInjectionBoundaryTests.swift`；修改 `RoamControl/Services/Tunnel/LocalDeviceSessionCoordinator.swift`（`injectedCoordinate(for:)` 为唯一转换点；`updateLocation` 的 `rc_location_session_update`（`:240`）与 `runNativeLocationSession` 的 `rc_location_session_run`（`:583-586` 计算、`:615` 调用）只用适配器输出；`#if DEBUG` 的 `injectProbeCoordinate` 供 A/B 单候选注入）、`RoamControl/Features/Settings/SettingsView.swift`（Device 段）、`RoamControl/Models/LocationTarget.swift`（仅注释）、`.github/workflows/xcode-27.yml`（新增 `unsigned-ipa-debug` job，Release 的 `unsigned-ipa` 未动）
- Task 15 边界：只改注入边界，`LocationTarget` / `GeoCoordinate` / `RouteGeometry` / `RouteRunner` / `RouteStore` / Rust-FFI 均未动，无数据迁移；`DeviceCoordinateAdapter.live` 取 `.gcj02ToWGS84`，没有运行时开关；Probe 注入绕开适配器、不改 `selectedTarget` / history / 路线
- Task 15 实测结论（2026-10-31，天安门-城楼，用户真机）：raw `39.908717, 116.397488`，高德蓝点在城楼东侧约 500 m；`wgs84ToGCJ02` 得 `39.910120, 116.403732`，蓝点更东；`gcj02ToWGS84` 得 `39.907316, 116.391247`，蓝点落在城楼上。三次 Probe 的 Readback 与注入值完全一致，`Simulated=yes`、`Accuracy=5.0 m`。判定：MapKit raw = GCJ-02，DVT 期望 WGS-84，`.live` 取 `.gcj02ToWGS84`
- Task 15 剩余待办：真机回归 ① 装 Release 包搜「天安门-城楼」Start Location，高德蓝点与 Apple Maps pin 应在城楼；② 「岭南师范学院田径场」同样；③ 经过田径场的路线起点与轨迹不偏；④ Update Location 换目标蓝点跟随；⑤ Stop & Restore 恢复真实位置
- Task 15 真机回归操作单：Release 包即可（Probe 只在 Debug 包）；同一地标截图用同一缩放级别，两地图不一致时两个都报
- Task 15 CI 结果（当前 HEAD）：GitHub Actions run `41186642773`（`https://github.com/FaHits/Roam-Control/actions/runs/41186642773`）`conclusion=success`；`test` job 9m23s，113 个用例通过、0 失败，`** TEST SUCCEEDED **`；`Build Debug` 与 `Build Release` 均 `** BUILD SUCCEEDED **`
- Task 15 Debug IPA：run `41186642773` 的 `unsigned-ipa-debug` job（41s）产出 `RoamControl-unsigned-debug.ipa`，artifact `RoamControl-unsigned-debug-ipa`，id `13037142318`，4,652,079 字节；archive 配置为 `CONFIGURATION = Debug` / `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG` / `SWIFT_OPTIMIZATION_LEVEL = -Onone`，`ENABLE_DEBUG_DYLIB=NO`
- Task 15 Debug IPA 自检：job 内 `strings -a …/RoamControl.app/RoamControl | grep -cF 'Probe (Debug)'` 输出 `hits: 2`，命中行 `Probe (Debug) inject single candidate`（Probe 区 accessibilityIdentifier）与 `Probe (Debug)`（Probe section 标题），命中为 0 则 job 失败；Release 包不含 Probe
- Task 15 artifact：run `41186642773` 的 `unsigned-ipa` job（1m6s）产物 `RoamControl-unsigned-ipa`，id `13037307005`，3,092,232 字节
- Task 15 历史 CI：run `41184102255`（111 用例 + Debug IPA）、`41181841011`（111 用例）、`41176205058`（107 用例）、`41176782498`（仅文档）
- Task 15 新增测试：`DeviceInjectionBoundaryTests` 4 例（适配器输出即注入值、`.none` 透传、注入不改 target、源码断言两个 FFI 调用点只用 `injected`），`ChinaCoordinateTransformTests` 往返用例补 1e-6 度断言
- Task 15 转换算法核对：独立 Python 实现复算固定算例，天安门 `39.908722,116.397499 → 39.91012550007891,116.4037425752605`（554.93 m）、岭南师范 `21.27122,110.34213 → 21.268808687690072,110.34659102093997`（534.39 m）、湛江田径场 `21.2585,110.3025 → 21.25601589175258,110.30687415389694`（530.82 m），与计划给定值逐位一致
- Task 10 返工（2026-10-31）：路线启动不再写 Saved Places 历史。`RoamControl/App/AppModel.swift` 的私有 `startLocationSession` 参数由 `historyTarget: LocationTarget` 改为 `LocationTarget?`，`addToHistory` 只在非 `nil` 时执行；`startRouteLocationSession` 传 `historyTarget: nil` 并加注释「A route run is owned by My Routes; it must not enter Saved Places history.」。固定位置与 Apple walking 的 `historyTarget` 取值不变
- Task 10 返工红灯：run `41195523226`（head `b163951`）`conclusion=failure`，`** TEST FAILED **`，唯一失败用例 `RouteHistoryTests.testStartingRouteRunDoesNotWriteLocationHistory()`（115 passed / 1 failed）
- Task 10 返工绿灯：run `41195528908`（head `80af1a7`）`conclusion=success`；`test` job 419s、`unsigned-ipa` 68s、`unsigned-ipa-debug` 40s；116 个用例 0 失败，`** TEST SUCCEEDED **`，`Build Debug` 与 `Build Release` 均 `** BUILD SUCCEEDED **`；Debug IPA 自检 `self-check 'Probe (Debug)' hits: 2`
- Task 10 返工产物：Release IPA artifact `RoamControl-unsigned-ipa` id `13040706415` / 3,093,454 字节；Debug IPA artifact `RoamControl-unsigned-debug-ipa` id `13040422834` / 4,654,993 字节
- Task 10 返工副作用核对：`startLocationSession(at:)` 与 `startWalkingLocationSession` 仍传非 `nil` 历史目标，新增 `RouteHistoryTests.testStartingFixedLocationSessionStillWritesLocationHistory` 断言固定位置仍写入历史，`locationHistory` 其他读写点（`removeFromHistory`、`clearHistory`、恢复流程）未改动
- Task 17 代码提交 `20ef07f`（`feat(routes): run open routes out and back by trip count`）、测试提交 `76d41f1`（`test(routes): cover out-and-back trips`），CI run `41236893110`（head `76d41f1`）`test` / `unsigned-ipa` / `unsigned-ipa-debug` 三 job 全绿，`RoamControlTests` 全量 147 用例 0 失败
- Task 17 产物（run `41236893110`）：Release IPA artifact `RoamControl-unsigned-ipa` id `13055889161` / 3,107,748 字节；Debug IPA artifact `RoamControl-unsigned-debug-ipa` id `13055378342` / 4,635,484 字节
- Task 17 本地化与坐标边界：`check_localizations.py` 输出 `Localizable.xcstrings: 613/613`、`InfoPlist.xcstrings: 2/2`、`All 615 keys have non-empty zh-Hans values.`（exit 0）；`rg -n "gcj02ToWGS84|offsetDegrees|coordinateOffset" RoamControl | wc -l` 为 8，与起点 `03f9a92` 的 8 一致，`DeviceCoordinateAdapter.swift:37` 仍 `.gcj02ToWGS84`
- Task 17 真机项：执行方无法接触 iOS 真机，折返去程/回程与趟数指标由用户批量验证，登记在 [`Documentation/Handoffs/2026-10-31-rework-handoff.md`](Handoffs/2026-10-31-rework-handoff.md) 第 7 节第 16 行

## 自动完成规则

- 只有实际测试和构建通过的任务才能进入 `completed`。
- `completed` 后自动更新本文件、提交当前任务文件和状态文件、推送到 `fork`。
- 禁止使用 `git add .`，不得夹带其他窗口或用户的改动。
- 推送后必须核对远端哈希，再报告提交和 CI 状态。
- `implemented_unverified`、`blocked` 或 `in_progress` 不得由窗口自行升级为完成。
- 2026 大返工轮的口径：执行方在 CI 上、本机无 macOS，且碰不到 iOS 真机，因此单个 Task 的验收证据为「测试通过 + CI 三 job 全绿 + 可签名 IPA 产物」，达标即 `implemented` 并推进下一项；`completed` 只在用户真机实测通过后由用户授予。只有真机能判定的项登记在交接文档第 7 节，不阻塞单项推进，也不得提前写成 `completed`。

## 任务进度

| 任务 | 状态 | 结果或下一步 |
|---|---|---|
| Task 1：增加 XCTest 目标和最小基线测试 | `completed` | Xcode 27.1 测试与 Debug 构建均通过 |
| Task 2：路线坐标与闭环几何 | `completed` | Xcode 27.1 下 10 个几何测试与 Debug 构建均通过 |
| Task 3：确定性拟人速度、步频和 GPS 抖动 | `completed` | Xcode 27.1 下 8 个运动模型测试与全量 19 个测试通过 |
| Task 4：纯 Swift 路线运行器 | `completed` | Xcode 27.1 下 18 个运行器测试与全量 37 个测试通过 |
| Task 5：路线库原子持久化 | `completed` | Xcode 27.1 下 8 个存储测试与全量 45 个测试通过 |
| Task 6：路线库状态模型 | `completed` | Xcode 27.1 下 12 个状态模型测试与全量 57 个测试通过 |
| Task 7：路线编辑器状态模型 | `completed` | Xcode 27.1 下 21 个编辑器测试与全量 78 个测试通过 |
| Task 8：手动路线编辑界面 | `completed` | Xcode 27.1 全量 78 个测试与 Debug 构建均通过 |
| Task 9：路线库和运行设置界面 | `completed` | Xcode 27.1 全量 83 个测试（新增 3 个 `RunProfileStore` 测试）与 Debug 构建均通过；2026-10-31 因删除动画与微信输入法重命名返工，见 Task 9R |
| Task 9R：路线库删除动画与微信输入法重命名 | `implemented` | 删除 swipe 改为普通红色按钮，确认前不动列表数据；重命名改用 UIKit `UITextField` 读取 marked text，点击时校验并写入；新增 `RouteNameValidator` 4 个测试，全量 123 个 0 失败；最终 HEAD CI run `41215787777` 三 job 全绿，Release artifact `13048681679`（3,146,361 字节）、Debug artifact `13048498113`（4,731,549 字节）；第 7 节 7 条（#1–#7）登记在交接文档，随 Task 14 B 段验证 |
| Task 10：恢复模型与设备会话基础 | `implemented_unverified` | 返工修复路线启动污染 Saved Places 地点历史：`startLocationSession` 的 `historyTarget` 改为 `LocationTarget?`，只有非 `nil` 才 `addToHistory`，路线传 `nil`（`AppModel.swift:366`、`:380`、`:393-395`）；新增 `RouteHistoryTests` 2 例；CI run `41195528908` 116 用例 0 失败、Debug/Release 构建与两个 unsigned IPA 均成功（Release artifact `13040706415`、Debug artifact `13040422834`）；真机 6 步验收与截图 `Task10-saved-places-history.png`、`Task10-home-routes-icon.png` 未做 |
| Task 11：运行中进度持久化 | `completed` | Xcode 27.1 下 4 个新测试与全量 96 个测试通过 |
| Task 12：运行卡片与主页整合 | `implemented_unverified` | 返工修复 Routes 按钮空图标（`RouteSymbol.library`，无效符号名全仓 0 命中）；CI run `41193407036` 114 用例 0 失败、Debug/Release 构建通过，Release IPA artifact `13039403715`；真机截图 `Task12-routes-icon.png` 未做 |
| Task 13：中断路线恢复 | `completed` | Xcode 27.1 下新增 2 个测试、全量 98 个测试与 Debug 构建均通过；手工强制退出恢复未验证 |
| Task 14：完整验证 | `implemented` | A 段 10 条自动化门禁全过：`check_localizations.py` 613/613 + 2/2（`All 615 keys`，exit 0）、analytics 关键词 0 命中、两条架构边界 rg 无输出、`DeviceCoordinateAdapter.swift:37` 取 `.gcj02ToWGS84`、pbxproj 无 `0.9.2` / `61` 残留、`seanhowarthdev` 全仓 0 命中、`has_issues=true` 且 `private-vulnerability-reporting.enabled=true`；版本 `0.10.0` / `62` 未变；最终 HEAD `28472c6`，CI run `41271600000` 三 job 全绿、153 用例 0 失败、Debug 与 Release 构建均 `** BUILD SUCCEEDED **`，Release IPA artifact `13069906753`（3,109,112 字节）、Debug IPA `13069387607`（4,643,768 字节）；同代码状态的过程记录 run `41271064818`（head `c027584`，artifact `13068894830` / `13069935430`）非装机源，仅留作过程记录；19 项真机行为待用户 B 段验证，未写 `completed` |
| Task 15：统一中国大陆坐标域 | `implemented_unverified` | 方向已由真机 A/B 实测确定：MapKit raw 为 GCJ-02、DVT 期望 WGS-84，`DeviceCoordinateAdapter.swift:36` 取 `.gcj02ToWGS84`，只转换一次且仅在注入边界；CI run `41186642773` 113 用例 0 失败、Debug/Release 构建通过，产 Release IPA `13037307005` 与 Debug IPA `13037142318`；真机回归（天安门城楼、田径场、路线、Update、Stop & Restore）未做 |
| Task 19：移除匿名统计/共享数据全链路 | `implemented` | Task 19F 收尾补正完成：删三处死回调（`LocalDeviceSessionCoordinator.onFailure` / `onRecoveryNeeded`、`OnDevicePairingCoordinator.onFailure`）与两个私有 `failureSnapshot(...)` 工厂，`FailureDiagnosticSnapshot` 随之删除，`FailureDiagnostics.swift` 收敛为 `FailureStage` / `FailureDisposition` / `SchedulerFailureReason` 三个类型（131 行）；删孤儿本地化 key `Privacy`，`check_localizations.py` 604/604 + 2/2、`All 606 keys` exit 0；`rg -n "UsageAnalytics|sharesAnonymousUsageStatistics|AnonymousUsage|What Is Shared|Share Anonymous"` exit 1，`Telemetry` 只剩 4 处 `BackgroundSessionTelemetry`；`rg -n "failureSnapshot\(|FailureDiagnosticSnapshot"` 无输出；123 用例 0 失败（未删未增）；最终代码状态 CI run `41223835438`（head `3ffd834`）三 job 全绿，Release IPA artifact `13050992072`（3,101,262 字节）、Debug IPA `13051995426`（4,623,883 字节）；第 7 节 2 条（#8–#9） |
| Task 16R：语言弹窗与剩余英文残留返工 | `implemented` | 语言切换只在生效语言真正改变时写入并弹窗：`AppLanguage.effective(...)` 由 `AppleLanguages` 覆盖值推导（无覆盖回落到系统偏好），`requiresRestart(comparedTo:)` 供 `SettingsView` 判定；Onboarding 三页 `title/message`、`PairingSetupView` 的 `requirementRow` / `instructionRow` / `pairingDetail(title:)`、`ConnectionHealthView.healthRow(title:)` 改 `LocalizedStringKey`；`ConnectionHealthView.restorationText(for:)` 把四个内部英文状态映射成本地化文案（内部值不变），`"None"` 两处显示改 `String(localized:)`；`Localizable.xcstrings` 604 → 609 key（+4 恢复状态、+1 a11y 逗号），合计 611；新增 6 例 AppLanguage/映射测试，全量 129 用例 0 失败；head `b7797d1`，CI run `41227597504` 三 job 全绿，Release artifact `13052626294`（3,104,532 字节）、Debug artifact `13053106037`（4,626,145 字节）；第 7 节 2 条（#10–#11）登记在交接文档，随 Task 14 B 段验证 |
| Task 20：更新/反馈仓库地址 | `implemented` | 新增 `RoamControl/Services/AppRepository.swift` 单一来源（`owner`/`repo`/`webURL`/`issuesURL(template:)`/`latestReleaseAPIURL`）；`SettingsView.swift:4-5` 两个反馈 URL 改由常量派生，`ReleaseUpdateChecker.swift:34-40` 用 `AppRepository.latestReleaseAPIURL`；新增纯函数 `ReleaseUpdateChecker.result(statusCode:body:)`（`:49`）：200 解码、404 → `.noPublishedRelease`、其他 → `.unavailable`，`latestRelease()` 只发请求；`SettingsView.swift:337-339` 的 `.noPublishedRelease` 文案改为 `This repository has no published release yet.` /「该仓库尚未发布版本。」，不回落上游 release、不伪装成「已是最新」；`rg -n "seanhowarthdev/Roam-Control" RoamControl` exit 1，`FaHits` 在 swift 里只剩 `AppRepository.swift:7` 一处；`check_localizations.py` 609/609 + 2/2、`All 611 keys` exit 0；新增 6 例 `ReleaseUpdateCheckerTests`，129 + 6 = 135 用例 0 失败；head `c75f2b0`，CI run `41231501665` 三 job 全绿，Release artifact `13053863895`（3,105,244 字节）、Debug artifact `13054018030`（4,628,549 字节）；第 7 节 4 条（#12–#15）登记在交接文档，随 Task 14 B 段验证 |
| Task 17：开放路线折返（单程趟数） | `implemented` | `.outAndBack(trips:)` 由 `completedLaps` 奇偶决定方向（偶数趟回起点、奇数趟停终点），恢复时按奇偶还原并把 `completedLaps` 夹到 `trips`；全量 135 → 147（+12）0 失败，head `76d41f1`，CI run `41236893110` 三 job 全绿，Release artifact `13055889161`（3,107,748 字节）、Debug artifact `13055378342`（4,635,484 字节）；第 7 节 1 条（#16），随 Task 14 B 段验证 |
| Task 18：路线编辑器卫星/混合底图 | `implemented` | `MapDisplayStyle.mapStyle` 成为唯一映射点（`AppPreferences.swift:47`），Home 与编辑器共用；编辑器面板内可就地切换，无障碍字号下降级为 `.menu`；147 → 153（+6）0 失败，head `94cc7a9`，CI run `41263004257` 三 job 全绿，Release artifact `13066740244`（3,109,098 字节）、Debug artifact `13065689661`（4,637,760 字节）；第 7 节 2 条（#17、#19），随 Task 14 B 段验证 |

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

### 2026-10-30 Task 4 完成记录

- 任务：Task 4 - 纯 Swift 路线运行器
- 状态：`completed`
- 分支与基线：`feat/manual-running-routes`，源码基线 `604cbd27a37e7fbccf39b6ce4d6a38d9450fbe7c`
- 修改文件：
  - `RoamControl/Features/Routes/Models/RouteRunMode.swift`
  - `RoamControl/Features/Routes/Core/RouteRunner.swift`
  - `RoamControlTests/RouteRunnerTests.swift`
  - `Documentation/ImplementationStatus.md`
- 接口：`RouteRunMode`（`once`、`laps(Int)`、`continuous`，`Codable`、`Equatable`、`Sendable`，`validated()`）、`RouteRunModeError`（`invalidLapCount`、`requiresClosedRoute`）、`RouteRunnerPhase`（`idle`、`running`、`paused`、`finished`）、`RouteRunProgress`（`distanceInLap`、`completedLaps`、`elapsedTime`）、`RouteRunSnapshot`（九个字段）、`RouteRunner`（`geometry`、`profile`、`mode`、`phase`、`snapshot`、`start()`、`pause()`、`resume()`、`advance(by:)`）
- 模式校验：`validated()` 只管圈数，`laps(0)`、`laps(-1)` 抛 `invalidLapCount`；闭环要求由 `RouteRunner.init` 判定，开放路线用 `laps(_:)` 或 `continuous` 抛 `requiresClosedRoute`；初始化器是 `throws`，没有 `precondition`、没有强制解包，非法模式不会崩溃
- 初始状态：`phase` 为 `idle`，`groundCoordinate` 由 `RouteGeometry.coordinate(atDistance:)` 按 `progress.distanceInLap` 采样，`reportedCoordinate` 由 `HumanizedMotionModel.reportedCoordinate(for:at:profile:)` 在 `progress.elapsedTime` 生成，速度、步频同时间点取值；`distanceInLap` 先夹到 `0...totalDistance`，越界的恢复进度不会让几何采样越界
- 推进算法：`advance(by:)` 只用传入的 delta，不读 `Date`、`Timer`、SwiftUI、MapKit、`AppModel` 或 `UserDefaults`；非正、NaN、±∞ 的 delta 和非 `running` 相位都原样返回当前快照；新 `elapsedTime = 旧 + delta`，本 tick 用新 `elapsedTime` 的速度推进 `速度 × delta`，GPS 抖动只改上报坐标；`finished` 由 `completedLaps >= 目标圈数` 判定，是终态
- 圈数算法：闭环一次算完，`covered = Double(completedLaps) × L + distanceInLap + step`，超出目标圈数时先按 `目标圈数 × L` 封顶，然后 `商 = floor(covered / L)`、`余数 = covered − 商 × L`；跨接缝时 `completedLaps` 只加一次，地面坐标始终由圈内距离采样，所以接缝前后连续
- 浮点容差：`max(1e-9, 0.000000001 × L)`（1 km 圈约 1 微米）；`L − 余数 ≤ 容差` 时补一圈并把圈内距离清零（防 0.999999 圈漏记），`余数 ≤ 容差` 时清零（防 1.000001 圈重记）
- 完成语义：`laps(n)` 第 n 圈立即 `finished`，同时 `completedLaps == n`、`distanceInLap == 0`、坐标回到起点；闭环 `once` 等价一圈；`continuous` 永不 `finished`；开放路线 `once` 到终点时 `completedLaps == 1`、`distanceInLap == totalDistance`、坐标等于路线最后一点；超出目标的 delta 只把行程推到目标终点，`elapsedTime` 仍按真实 delta 增加
- `snapshot.totalDistance` 定义：累计已跑地面里程，闭环为 `completedLaps × L + distanceInLap`，开放路线为已跑距离
- 测试覆盖：18 个用例，含计划里的 10 个（起点、暂停不推进、继续从暂停点走、有限圈数完成、开放路线终点、闭环接缝无跳变、接缝只记一圈、大 delta 跨 4.5 圈、1000 圈无漂移、`progress` 恢复圈内位置）以及开放路线 `once` 终点坐标精确、闭环 `once` 完成语义、`finished` 终态、非正/NaN/±∞ delta 不推进、`laps(0)`/`laps(-1)`/开放路线 `continuous`/开放路线 `laps` 四类模式校验；断言除相位外都覆盖坐标、圈数、圈内距离与 `elapsedTime`，接缝用例额外交付速度与步频有限性
- 测试数据：边长约 0.1 km 的方形闭环（周长 L ≈ 0.41 km），用零速度变化、零步频变化、零抖动半径的 `steadyProfile`，使速度、步频与上报坐标都是精确值；1000 圈用例以 4 m/s、每 tick 1 秒推进约 10.3 万次，耗时 0.335 秒
- 红灯命令：`xcodebuild test -project RoamControl.xcodeproj -scheme RoamControl -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -only-testing:RoamControlTests CODE_SIGNING_ALLOWED=NO`
- 红灯结果：run `41061030062`（提交 `93a31c4`）编译期失败，`RouteRunnerTests.swift:46` 报 `cannot find 'RouteRunner' in scope`，全部 102 条报错都是 `RouteRunner`、`RouteRunProgress`、`RouteRunModeError`、`RouteRunMode` 成员缺失，失败原因正是实现类型尚不存在
- 绿灯结果：run `41061243835`、Xcode 27.1（build `27A9275`）；`RouteRunnerTests` 18 个用例逐个通过（最慢 `testThousandLapsDoNotAccumulateLapError` 0.335 秒），全量 `RoamControlTests` 37 个用例 0 失败，`** TEST SUCCEEDED **`
- 构建命令：`xcodebuild build -project RoamControl.xcodeproj -scheme RoamControl -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`
- 构建结果：同一 run 的 `Build Debug` 步骤 `** BUILD SUCCEEDED **`
- 定向测试取证方式：本地为 Windows 且没有 `xcodebuild`，CI 工作流固定执行 `-only-testing:RoamControlTests`，因此只跑 `-only-testing:RoamControlTests/RouteRunnerTests` 的命令没有实际执行；18 个用例的通过记录是从 run 日志逐条提取的，工作流文件未改动
- 静态检查：`git diff --check` 通过；实现只导入 Foundation，不访问 `Date`、`Timer`、SwiftUI、MapKit、`AppModel`、`UserDefaults`；最后一次提交同时清掉了测试里两处 `advance(by:)` 返回值未使用的警告
- 未验证内容：不涉及真实设备会话、真实定位与后台恢复（Task 10、Task 11）；没有 UI；tick 频率由未来的会话层决定，本任务只保证任意 delta 下的结果可复现
- 已知风险：容差按圈长比例 1e-9 取，若 `RouteGeometry` 的距离计算方式改变需要复核；`continuous` 的 `totalDistance` 会随里程无限增长，1000 圈（约 413 km）实测无漂移，长期上限取决于 `Double` 精度；闭环的目标圈数封顶只在 `advance(by:)` 内生效，绕过它直接改 `snapshot` 不在设计范围内
- Task 5 前置状态：`RouteRunProgress` 与 `RouteRunMode` 都是 `Codable`、`Equatable`、`Sendable`，可直接被路线库或进度文件序列化；恢复运行时只需把持久化的 `elapsedTime`、`completedLaps`、`distanceInLap` 传回 `RouteRunner.init`，地面坐标会自动重算，不需要额外存储坐标
- 验证提交：`72334e5`（红绿灯实现）；同任务另含 `93a31c4`（红灯测试）
- 工作流：https://github.com/FaHits/Roam-Control/actions/runs/41061243835
- 下一步第一条命令或动作：下一窗口先核对 Git 状态与本文件，再读取 Task 5 章节并把 Task 5 标记为 `in_progress`
- 更新时间：2026-10-30

### 2026-10-30 Task 5 完成记录

- 任务：Task 5 - 路线库原子持久化
- 状态：`completed`
- 分支与基线：`feat/manual-running-routes`，源码基线 `2a1dca05f892713ab6aecfe87622993efe8c7404`
- 修改文件：
  - `RoamControl/Features/Routes/Storage/RouteStore.swift`
  - `RoamControlTests/RouteStoreTests.swift`
  - `Documentation/ImplementationStatus.md`
- 接口：`RouteStoreError`（`unsupportedSchema(Int)`、`corruptedFile`、`writeFailed`，`Error`、`Equatable`）、`RouteStore`（`Sendable`，`currentSchemaVersion = 1`、`liveFileURL`、`fileURL`、`init(fileURL:)`、`load()`、`save(_:)`）；文件级私有 `RouteLibraryDocument`（`schemaVersion`、`routes`，`Codable`）
- 路径解析：`liveFileURL` 取 `FileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first`，取不到时退回 `NSHomeDirectory()/Library/Application Support`，再追加 `RoamControl/routes.json`；`liveFileURL` 是 `static var`，不缓存，测试与宿主进程各取各的沙盒
- 读取行为：文件不存在直接返回空数组，不建目录、不建文件；存在时用 `.iso8601` 解码策略解码，解码失败（语法错误、字段缺失、类型错误、日期格式错误）统一抛 `corruptedFile`；`schemaVersion > currentSchemaVersion` 抛 `unsupportedSchema(该版本号)`；`schemaVersion < 1` 当前接受（迁移留给后续任务）；文件读取本身的 IO 错误（如权限不足）原样抛出，不伪装成数据损坏；整个 `load()` 不写任何字节，损坏文件保持原样
- 写入行为：先编码，后建目录，再以 `Data.WriteOptions.atomic` 写盘；编码失败、目录创建失败、写盘失败都映射为 `writeFailed`，错误不被吞掉；编码器用 `.iso8601` 日期策略加 `[.sortedKeys]` 输出，键顺序稳定；每次 `save` 写整份文档，`routes` 为空数组时也写成 `{"routes":[],"schemaVersion":1}`
- 精度约定：`JSONEncoder.DateEncodingStrategy.iso8601` 不写小数秒，`Date` 往返后截断到整秒；测试夹具全部使用整秒时间戳，Task 6 之后的比较也要按秒
- 测试隔离：每个用例在 `FileManager.default.temporaryDirectory` 下建 `RouteStoreTests-<UUID>` 目录，`tearDownWithError` 删除；所有用例只通过注入的 `fileURL` 访问磁盘，不触碰真实 `liveFileURL`
- 测试覆盖：8 个用例
  - `testMissingFileLoadsAsEmptyLibrary`：空库返回 `[]`，且 load 后目录仍不存在
  - `testSaveAndLoadRoundTripsRoutes`：开放路线（`.gpx`）与闭环路线（`.drawn`）各一条，逐字段断言 `id`、`name`、`points`（每个坐标的 `latitude`、`longitude`）、`isClosed`、`source`、`createdAt`、`updatedAt`，并额外断言第 0 条开放、第 1 条闭环
  - `testSaveCreatesParentDirectory`：写 `<UUID>/route/library/nested/routes.json` 这条尚不存在的三级父目录，save 后用 `FileManager.fileExists(atPath:isDirectory:)` 确认目录已建且是目录，再 load 回读比对
  - `testCorruptedFileThrowsAndRemainsUnchanged`：四个坏样本（截断 JSON、缺字段、`routes` 类型错误、日期非法）逐个写入后 `load()`，断言错误等于 `.corruptedFile`，并逐字节比较文件内容与写入前完全一致
  - `testUnsupportedSchemaThrows`：写入 `schemaVersion = 2`，断言错误等于 `.unsupportedSchema(2)`，字节不变
  - `testSaveUsesAtomicReplacement`：先保存一条旧路线，再保存两条新路线，断言只有新内容、旧 `id` 不残留，且目录里只有 `routes.json`、没有残留临时文件
  - `testSaveAndLoadEmptyLibrary`：保存 `[]` 后重新 `load()` 得到 `[]`，并直接解析 JSON 断言 `schemaVersion == currentSchemaVersion`、`routes` 为空
  - `testLiveFileURLPointsAtRoutesJSON`：断言 `liveFileURL` 最后两个路径分量是 `RoamControl` 与 `routes.json`
- 断言方式：错误一律用 `XCTAssertEqual(error as? RouteStoreError, …)`（经测试内的 `errorThrown(by:)` 辅助方法取错误），不只判断是否抛错
- 红灯命令：`xcodebuild test -project RoamControl.xcodeproj -scheme RoamControl -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -only-testing:RoamControlTests CODE_SIGNING_ALLOWED=NO`
- 红灯结果：run `41065883068`（提交 `4997259`）、job `124097039283`，编译期失败 `RouteStoreTests.swift:28:21: error: cannot find 'RouteStore' in scope`、`RouteStoreTests.swift:221:61: error: cannot find type 'RouteStoreError' in scope`，共 12 处 `cannot find 'RouteStore' in scope`，全部报错都指向尚不存在的存储类型，结果为 `** TEST FAILED **`
- 绿灯结果：run `41066742147`（提交 `1ae3e98`）、job `124099979698`、Xcode 27.1（build `27A9275`）；`RouteStoreTests` 8 个用例逐个通过（最慢 `testSaveUsesAtomicReplacement` 0.078 秒），全量 `RoamControlTests` 45 个用例 0 失败，`** TEST SUCCEEDED **`
- 构建命令：`xcodebuild build -project RoamControl.xcodeproj -scheme RoamControl -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`
- 构建结果：同一 run 的 `Build Debug` 步骤 `** BUILD SUCCEEDED **`
- 定向测试取证方式：本地为 Windows 且没有 `xcodebuild`、没有 `swiftc`，CI 工作流固定执行 `-only-testing:RoamControlTests`，因此只跑 `-only-testing:RoamControlTests/RouteStoreTests` 的命令没有实际执行；8 个用例的通过记录是从 run 日志逐条提取的，工作流文件未改动
- 日志取证限制：失败 job 的日志归档首次请求返回 `403`，随后一次返回 `ServerBusy`（`Egress is over the account limit`），重试后才取到；同一时段 `test` 步骤的 check-run 注解只有 `Process completed with exit code 65`，编译错误文本来自 job 日志本身
- 静态检查：`git diff --check` 通过；实现只导入 Foundation，不含第三方依赖、`UserDefaults`、`try!`、`as!`、`precondition` 或静默 `try?`；测试文件同样没有这些写法
- 未验证内容：不涉及真实设备会话、真实定位、后台恢复与 UI；`unsupportedSchema` 只覆盖“更新的 schema”，更旧的版本迁移尚未实现
- 已知风险：`liveFileURL` 依赖宿主进程的 `Application Support` 容器，测试与真机路径不同，只有注入 `fileURL` 的用例能本地验证；ISO-8601 整秒截断会让两次修改落在同一秒内的 `updatedAt` 变化不可见；`save` 在目录创建成功后、写盘失败时可能留下空目录，属于可接受的部分成功状态
- Task 6 前置状态：`load()` 返回 `[RouteDefinition]`、`save(_:)` 接收整份数组，状态模型可以直接持有路线数组并整体落盘；错误枚举已经区分“文件损坏”“版本过新”“写失败”三种可展示状态，无需再包一层；空库语义已定（缺失文件等于空库），首启动不需要预置文件
- 验证提交：`1ae3e98`（实现）；同任务另含 `4997259`（红灯测试）
- 工作流：https://github.com/FaHits/Roam-Control/actions/runs/41066742147
- 下一步第一条命令或动作：下一窗口先核对 Git 状态与本文件，再读取 Task 6 章节并把 Task 6 标记为 `in_progress`
- 更新时间：2026-10-30

### 2026-10-30 Task 6 完成记录

- 任务：Task 6 - 路线库状态模型
- 状态：`completed`
- 分支与基线：`feat/manual-running-routes`，源码基线 `0a6c0a548c891daddd3f3fd7af2922e1e0a91354`
- 修改文件：
  - `RoamControl/Features/Routes/State/RouteLibraryModel.swift`
  - `RoamControlTests/RouteLibraryModelTests.swift`
  - `Documentation/ImplementationStatus.md`
- 接口：`@MainActor @Observable final class RouteLibraryModel`，`routes`、`isLoading`、`errorMessage` 均为 `private(set)`；`init(store: RouteStore = RouteStore())`、`load()`、`upsert(_:)`、`delete(id:)`、`route(id:)`、`clearError()`。store 用 `@ObservationIgnored` 持有，不进入观察图
- 加载规则：`init` 保存 store 后 `routes = []`、`isLoading = false` 并调用一次 `load()`；`load()` 用 `defer` 在结束时恢复 `isLoading = false`；成功时替换为排序后的 `store.load()` 结果并清空错误；失败只写 `errorMessage`，不调用 `save`、不改动已有 `routes`，因此首次失败保持空数组、已有数据后失败保留旧数组
- 排序规则：私有 `sorted(_:)` 按 `updatedAt` 降序，相同时按 `id.uuidString` 升序，`load`、`upsert`、`delete` 成功后共用
- 写入规则：`upsert` 先 `trimmingCharacters(in: .whitespacesAndNewlines)` 清洗名称并写回候选；为空则设 `Route name cannot be empty.` 直接返回，不入库、不改 `routes`；否则从当前 `routes` 复制候选，同 `id` 替换、无 `id` 追加；`delete` 对不存在的 `id` 直接返回且不写盘；两者都先 `store.save(候选)`，成功后才用排序后的候选替换 `routes` 并清空错误，失败保留原数组。模型不改 `id`、`createdAt`、`updatedAt`
- 错误文案：`Route name cannot be empty.`（精确）、`Could not save routes.`（保存与删除失败）、`Routes file is corrupted.`、`Routes file uses unsupported schema version \(version).`、`Could not load routes.`（其他加载失败）；映射集中在私有 `loadErrorMessage(for:)`，没有为文案引入协议或抽象层
- 测试覆盖：12 个用例
  - `testLoadSortsRoutesByUpdatedAtDescending`：三条路线断言条数与 `["Newest", "Middle", "Oldest"]` 顺序，另断言 `isLoading == false`、`errorMessage == nil`
  - `testLoadBreaksUpdatedAtTiesByIdentifier`：两条 `updatedAt` 相同、UUID 为 `…00AA` 与 `…00BB` 的路线，断言按 `id.uuidString` 升序，并断言第二次加载顺序一致
  - `testUpsertAddsAndReplacesByStableID`：新路线使条数 0→1→2；同 `id` 替换后仍为 1 条，断言 `id`、`createdAt` 不变而 `name`、`points`、`isClosed`、`source`、`updatedAt` 取新值，并回读文件确认只存新名称
  - `testUpsertTrimsNameAndRejectsEmptyName`：`"  Riverside loop \n"` 存成 `"Riverside loop"`（内存与文件都对）；纯空白名称被拒，`routes` 与文件条数不变，错误文案精确匹配
  - `testDeleteRemovesOnlyRequestedRoute`：三条中删一条，内存与文件都只剩另外两条的 `id`
  - `testDeleteOfUnknownIdentifierLeavesFileAndStateAlone`：随机 `id` 删除后 `routes` 不变，文件字节完全相同
  - `testFailedSaveKeepsPreviousInMemoryState`：先成功加载一条，把父目录替换成普通文件使 `createDirectory` 失败，断言 `routes` 仍等于旧数组、错误为 `Could not save routes.`
  - `testDeleteFailureKeepsPreviousInMemoryState`：同样的父路径破坏方式覆盖删除失败路径
  - `testCorruptedStoreExposesErrorWithoutClearingRoutes`：初始化即损坏时 `routes == []` 且错误可见；先正常加载再写入非法 JSON 并 `load()`，断言 `routes` 保留旧数组、错误非空、`isLoading` 回到 false、文件字节未被改写
  - `testUnsupportedSchemaMessageNamesVersion`：`schemaVersion = 2` 时错误为 `Routes file uses unsupported schema version 2.`，文件字节不变
  - `testSuccessfulOperationsClearPreviousError`：先制造空名称错误，再成功 upsert 与 delete，两步后 `errorMessage` 均为 `nil`
  - `testRouteLookupAndClearError`：`route(id:)` 命中与未命中、`clearError()` 只清错误不改 `routes`
- 测试隔离：每个用例用 `addTeardownBlock` 创建并删除自己的 `temporaryDirectory/RouteLibraryModelTests-<UUID>/library/routes.json`，不共用文件，也不触碰真实 `liveFileURL`；没有引入一方法的存储协议
- 红灯命令：工作流固定执行 `xcodebuild test -project RoamControl.xcodeproj -scheme RoamControl -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -only-testing:RoamControlTests CODE_SIGNING_ALLOWED=NO`
- 红灯结果：run `41069921430`（提交 `016046f`）编译期失败，唯一错误是 `RouteLibraryModelTests.swift:27:46: error: cannot find type 'RouteLibraryModel' in scope`，结果为 `** TEST FAILED **`
- 绿灯结果：run `41070257714`（提交 `f15353b`）、Xcode 27.1；`RouteLibraryModelTests` 12 个用例逐个通过（0.002–0.329 秒），全量 `RoamControlTests` 57 个用例、`Test case … failed` 计数为 0，结果为 `** TEST SUCCEEDED **`
- 构建命令：`xcodebuild build -project RoamControl.xcodeproj -scheme RoamControl -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`
- 构建结果：同一 run 的 `Build Debug` 步骤 `** BUILD SUCCEEDED **`
- 定向测试取证方式：本地为 Windows 且没有 `xcodebuild`，CI 工作流固定执行 `-only-testing:RoamControlTests`，因此只跑 `-only-testing:RoamControlTests/RouteLibraryModelTests` 的命令没有实际执行；12 个用例的通过记录是从 run 日志逐条提取的，工作流文件未改动
- 静态检查：`git diff --check` 通过；实现只导入 `Foundation` 与 `Observation`，不含 SwiftUI、MapKit、`AppModel`、`UserDefaults`、第三方依赖、`try!`、`as!`、`precondition` 或静默 `try?`
- 未验证内容：没有 UI、路线编辑器和设备会话；`isLoading` 只在同步加载期间变化，尚未验证真实磁盘慢速读取下的界面表现
- 已知风险：`load()` 失败后 `errorMessage` 会一直保留，直到下一次成功操作或 `clearError()`，界面需要主动展示并允许清除；保存失败一律显示 `Could not save routes.`，不区分磁盘满、权限或编码问题，后续如需要更细分类再扩展映射；`updatedAt` 相同时依赖 `UUID` 字符串升序，跨平台稳定性取决于字符串形式而非 UUID 字节序
- Task 7 前置状态：`RouteEditorModel` 可以直接构造 `RouteDefinition` 后调用 `RouteLibraryModel.upsert(_:)`，由模型负责清洗名称、排序与落盘；`route(id:)` 可用于编辑前取现有路线，`errorMessage` 与 `clearError()` 可直接复用于编辑器错误展示；编辑器不得自行写 `RouteStore`，也不要重复实现排序
- 验证提交：`f15353b`（实现）；同任务另含 `016046f`（红灯测试）
- 工作流：https://github.com/FaHits/Roam-Control/actions/runs/41070257714
- 下一步第一条命令或动作：下一窗口先核对 Git 状态与本文件，再读取 Task 7 章节并把 Task 7 标记为 `in_progress`
- 更新时间：2026-10-30

### 2026-10-30 Task 7 完成记录

- 任务：Task 7 - 路线编辑器状态模型
- 状态：`completed`
- 分支与基线：`feat/manual-running-routes`，源码基线 `9786ced4caed200710f43981d2fc232213a081ca`
- 修改文件：
  - `RoamControl/Features/Routes/State/RouteEditorModel.swift`
  - `RoamControlTests/RouteEditorModelTests.swift`
  - `Documentation/ImplementationStatus.md`
- 接口：`@MainActor @Observable final class RouteEditorModel`；`name`、`isClosed` 可写，`points`、`errorMessage` 为 `private(set)`；`init(route: RouteDefinition? = nil)`、`appendPoint(_:)`、`undoLastPoint()`、`clear()`、`throws -> RouteDefinition` 的 `makeRoute(existing:)`；派生属性 `canSave`、`effectivePointCount`、`totalDistance`、`canUndo`。只导入 `Foundation` 与 `Observation`
- 初始化规则：`route` 为 `nil` 时名称为 `New Route`、点为空、`isClosed = true`、无错误；传入路线时复制 `name`、`points`、`isClosed`，不持有 `RouteDefinition` 引用，也不修改入参
- 派生规则：`canSave` 与 `totalDistance` 共用一个私有探针 `temporaryGeometry`，成功构造 `RouteGeometry(points:isClosed:)` 才算可保存，失败时距离为 0；`effectivePointCount` 复用 `RouteGeometry.duplicateDistanceThreshold` 折叠连续点、闭环再去掉与首点过近的末点，因为点数不足时 `RouteGeometry` 会抛错而不能拿它来数点数；`canUndo` 等于 `points` 非空
- 加点规则：非有限坐标、纬度越 `±90`、经度越 `±180` 时拒绝并把错误设为 `Point is outside valid coordinates.`；与最后一个点距离小于阈值时静默忽略且不动已有错误，只与末点比较、不与更早顶点比较；成功追加后清空错误
- 撤销与清空：`undoLastPoint()` 非空时移除末点并清空错误，空数组直接返回；`clear()` 清空点与错误，保留名称和闭环开关
- 保存规则：`makeRoute(existing:)` 先 `trimmingCharacters(in: .whitespacesAndNewlines)`，为空则写 `Route name cannot be empty.` 并抛 `RouteEditorError.emptyName`，点保持不变；否则回写清洗后的名称、构造几何，几何失败先写展示文案再原样 `throw` 该 `RouteGeometryError`；存储点用 `geometry.points.dropLast()`（闭环）或 `geometry.points`（开放），因此不写重复首点，闭合只由 `isClosed` 表达；`id`、`createdAt`、`source` 有 `existing` 时保留，否则 `UUID()`、`Date.now`、`.drawn`；`updatedAt` 始终为 `Date.now`；成功返回并清空错误，全程不触碰 `RouteStore`、`RouteLibraryModel` 或任何持久化代码
- 错误类型与文案：`enum RouteEditorError: Error, Equatable, Sendable { case emptyName }`；几何错误仍用 `RouteGeometryError`。文案集中在私有静态常量：`Route name cannot be empty.`、`Point is outside valid coordinates.`、`A route needs at least 2 points.`、`A closed route needs at least 3 points.`、`A route must have a non-zero length.`、`The route could not be built.`（非几何错误的兜底）。`.zeroLength` 时会额外判断有效点数是否仍不足最小要求，不足则改报点数文案，避免“1 个点的闭环”显示长度错误
- 测试覆盖：21 个用例
  - `testNewEditorStartsWithClosedModeAndDefaultName`：新编辑器断言名称、`isClosed`、空点、`canSave == false`、`effectivePointCount == 0`、`totalDistance == 0`、`canUndo == false`、`errorMessage == nil`
  - `testEditingInitializesFromRouteWithoutLosingFields`：从现有路线进入后名称、点、闭环开关一致
  - `testAppendPointIgnoresConsecutivePointsCloserThanHalfMetre`：先加一点，再加相距 0.2 米的点，点数不变；再加相距 30 米的点，点数增加
  - `testAppendPointRejectsInvalidCoordinates`：`NaN`、纬度 `91`、经度 `181` 三种坐标都不追加并设置错误文案
  - `testDuplicatePointRejectionKeepsExistingError`：先制造坐标错误，再加过近点，错误文案保持不变
  - `testAppendAfterInvalidCoordinateClearsError`：之后一次成功追加清空错误
  - `testUndoRemovesOnlyLastPoint`：三点 undo 后剩两点，连续 undo 到空数组不崩溃
  - `testUndoClearsError`：有错误且有可移除点时，undo 后错误清空
  - `testClearRemovesAllPoints`：清空后点为 0、`canUndo == false`，名称与 `isClosed` 不变
  - `testCanSaveRequiresMinimumEffectivePoints`：开放路线 1 点不可保存、2 点可保存
  - `testClosedRouteRequiresThreeEffectivePoints`：闭环 2 点不可保存、3 点可保存
  - `testEffectivePointCountCollapsesConsecutiveDuplicates`：4 个原始点（含 1 个连续重复）折叠为 3 个有效点
  - `testClosedDistanceIncludesClosingSegment`：同顶点闭环与开放路线比较，闭环总长更大，证明闭合段被计入
  - `testClosedSaveStoresVerticesWithoutDuplicateClosingPoint`：闭环三点保存后 `points.count == 3`，不等于 4，也不含重复首点
  - `testSaveCollapsesConsecutiveDuplicatePoints`：含连续重复点的路线保存后重复点被折叠
  - `testSavePreservesExistingIDAndCreationDate`：`id` 与 `createdAt` 精确保留，`updatedAt` 更新为当前时间
  - `testSavePreservesImportedSource`：`existing` 为 `.gpx` 与 `.appleMaps` 时 `source` 保留
  - `testNewRouteSaveUsesDrawnSource`：新路线 `source == .drawn`
  - `testSaveRejectsBlankName`：纯空白名称抛 `RouteEditorError.emptyName`，错误文案精确匹配，点未被修改
  - `testGeometryFailureThrowsAndLeavesMessage`：闭环只有 2 点时抛 `RouteGeometryError.tooFewPoints(minimum: 3)` 且留下非空文案
  - `testSuccessfulSaveClearsPreviousError`：先制造错误，成功保存后 `errorMessage == nil`
- 测试数据：`@MainActor final class RouteEditorModelTests: XCTestCase`；上海附近基准坐标，用 `point(north:east:)` 辅助方法按 `1 纬度 ≈ 111 320 米`、经度按 `cos(纬度)` 缩放构造指定米级偏移，距离断言用 `GeoCoordinate.distance(to:)`，不依赖真实地图或网络
- 红灯命令：工作流固定执行 `xcodebuild test -project RoamControl.xcodeproj -scheme RoamControl -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -only-testing:RoamControlTests CODE_SIGNING_ALLOWED=NO`
- 红灯结果：run `41074597846`（提交 `e4d0638`）编译期失败，唯一错误是 `RouteEditorModelTests.swift:45:58: error: cannot find type 'RouteEditorModel' in scope`，结果为 `** TEST FAILED **`
- 绿灯结果：run `41075730246`（提交 `c1be8b2`）、job `124131262022`、Xcode 27.1；`RouteEditorModelTests` 21 个用例逐个通过（0.000–1.308 秒，最慢 `testAppendAfterInvalidCoordinateClearsError`），全量 `RoamControlTests` 78 个用例、`Test case … failed` 计数为 0，结果为 `** TEST SUCCEEDED **`
- 构建命令：`xcodebuild build -project RoamControl.xcodeproj -scheme RoamControl -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`
- 构建结果：同一 run 的 `Build Debug` 步骤 `** BUILD SUCCEEDED **`
- 定向测试取证方式：本地为 Windows 且没有 `xcodebuild`，CI 工作流固定执行 `-only-testing:RoamControlTests`，因此只跑 `-only-testing:RoamControlTests/RouteEditorModelTests` 的命令没有实际执行；21 个用例的通过记录是从 run 日志逐条提取并按测试类计数（`Test case 'RouteEditorModelTests.…'` 共 21 行、`failed` 0 行），工作流文件未改动
- 静态检查：`git diff --check` 通过；实现只导入 `Foundation` 与 `Observation`，不含 SwiftUI、MapKit、`UserDefaults`、第三方依赖、`try!`、`as!`、`precondition` 或静默 `try?`；`temporaryGeometry` 用显式 `do/catch` 返回 `nil`，不用 `try?`
- 未验证内容：没有 UI、没有设备会话、没有真实磁盘写入；`RouteEditorModel` 与 `RouteLibraryModel` 的串联（保存后入库、排序、落盘）留到后续任务
- 已知风险：`points` 保留的是原始点击点（含被折叠的近重复点），`makeRoute` 才折叠，因此保存前界面上的点数可能多于保存后的顶点数，Task 8 若显示计数应以 `effectivePointCount` 为准；`appendPoint` 只与末点比较，先画远点再折返贴到早期顶点附近不会被拦截，这是任务约定的行为，几何层会自行折叠；`errorMessage` 在成功操作前不会自动消失，界面需要展示并允许下一次操作覆盖
- Task 8 前置状态：`RouteEditorView(existingRoute:onSave:onCancel:)` 可以直接持有 `RouteEditorModel(route:)`，把点击映射到 `appendPoint(_:)`、撤销映射到 `undoLastPoint()`、清空映射到 `clear()`，用 `canSave`、`canUndo`、`effectivePointCount`、`totalDistance` 驱动按钮与文案；保存按钮调用 `makeRoute(existing:)` 后把结果交给上层，由上层调用 `RouteLibraryModel.upsert(_:)`，编辑器本身不写存储；错误展示读 `errorMessage`，几何错误与空名称都会同时以文案和抛出的错误两种形式出现
- 验证提交：`c1be8b2`（实现）；同任务另含 `e4d0638`（红灯测试）
- 工作流：https://github.com/FaHits/Roam-Control/actions/runs/41075730246
- 下一步第一条命令或动作：下一窗口先核对 Git 状态与本文件，再读取 Task 8 章节并把 Task 8 标记为 `in_progress`
- 更新时间：2026-10-30

### 2026-10-30 Task 8 完成记录

- 任务：Task 8 - 手动路线编辑界面
- 状态：`completed`；实现提交 `6daa6b1`（`feat(routes): add manual route editor UI`），本条记录单独提交 `docs(routes): record Task 8 completion`
- 新增文件：`RoamControl/Features/Routes/Views/RouteEditorView.swift`；未修改 `RoamControl.xcodeproj/project.pbxproj`（工程使用 `PBXFileSystemSynchronizedRootGroup`，新文件自动进入 App target）
- 对外接口：`struct RouteEditorView` 只持有 `existingRoute: RouteDefinition?`、`onSave: (RouteDefinition) -> Void`、`onCancel: () -> Void`；内部用 `@State` 持有 `RouteEditorModel(route: existingRoute)`，用 `@Bindable` 绑定 `name` 与 `isClosed`
- 地图行为：全屏 `MapReader` + `Map`，`cameraPosition` 为 `@State`；`existingRoute` 多于一个点时按经纬度 min/max 取中心、`padding = 1.4`、最小 span `0.002`，否则 `.userLocation(fallback: .automatic)`；每个点一个 12pt 蓝色 `Circle` `Annotation`，点间 `MapPolyline(lineWidth: 5)`；预览线优先 `try? RouteGeometry(points:isClosed:)` 的 `points`（闭环自动含闭合段），几何无效时退回 `model.points`，未复制 `0.5` 米折叠逻辑
- 加点路径：`onTapGesture` → `proxy.convert(location, from: .local)` → `GeoCoordinate` → `model.appendPoint(_:)`；未调用 `MapViewModel.selectDroppedPin`，未改动 `MapViewModel`；`GeoCoordinate` 没有 `coordinate` 属性，视图内用 `clCoordinate` 扩展转换
- 浮层：顶部 `TextField("Route name")`；底部面板显示 `effectivePointCount` 与 `totalDistance`（`< 1000` 米显示 `m`，否则 `km`）、`Toggle("Closed loop")`、`model.errorMessage` 红字、`Undo`/`Clear`/`Cancel`/`Save`；`Undo` 在 `!canUndo` 时禁用，`Clear` 在 `points.isEmpty` 时禁用且非空时先走 `confirmationDialog` 确认，`Save` 在 `!canSave` 时禁用并调用 `try model.makeRoute(existing:)` 后把结果交给 `onSave`，编辑器不写 `RouteStore`/`RouteLibraryModel`
- 无障碍与 Dynamic Type：六个 accessibilityLabel（`Route name`、`Closed loop`、`Undo last point`、`Clear route`、`Cancel route editing`、`Save route`）；`dynamicTypeSize.isAccessibilitySize` 时底部面板包进 `ScrollView` 并限制 `maxHeight: 460`；卡片沿用 `.padding(18)` + `.regularMaterial` + 连续圆角 24 + 阴影，与 `WalkingRoutePreviewCard` 一致
- 文案与样式：全英文；直接 `.mapStyle(.standard(elevation: .realistic))`，未依赖 `HomeView.swift` 里的 private `roamControlMapStyle`
- 测试命令：`xcodebuild test -project RoamControl.xcodeproj -scheme RoamControl -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' CODE_SIGNING_ALLOWED=NO`
- 测试结果：GitHub Actions `Xcode 27 verification` run `41079471220`、job `124144408266`，8 分 30 秒通过；日志 `Test case … passed` 78 行、`Test case … failed` 0 行，`** TEST SUCCEEDED **`。本任务只新增视图，没有新增测试，78 与 Task 7 全量一致
- 构建结果：同一 run 的 `Build Debug` 步骤 `** BUILD SUCCEEDED **`
- 本地无法验证的事实：本机是 Windows 且没有 `xcodebuild`，全量测试与 Debug 构建都在 `xcode-27` runner 上完成；没有提交任何本地验证通过的结论
- 未完成的界面手工检查：模拟器里画四个点形成矩形、开闭环看闭合段、Undo 后计数与折线同步、Clear 弹确认、空名称时 Save 禁用、保存后 `onSave` 收到 `RouteDefinition`。Windows 环境无法运行模拟器，这些检查留给 Task 9 接入后的真机/模拟器验收
- 遗留限制：视图尚未接入 `HomeView`，`onSave`/`onCancel` 的调用方是 Task 9；相机只在初始化时按 `existingRoute` 定一次，编辑中加点不会自动跟随；无自由手绘笔刷、无路线库列表，均按任务边界不做
- 工作流：https://github.com/FaHits/Roam-Control/actions/runs/41079471220
- 下一步第一条命令或动作：下一窗口先核对 Git 状态与本文件，再读取 Task 9 章节并把 Task 9 标记为 `in_progress`
- 更新时间：2026-10-30

### 2026-10-31 Task 8 验收修正

- 触发问题：`RouteEditorModel.canSave` 原先只检查 `temporaryGeometry != nil`，名称清空后仍为 `true`，`RouteEditorView` 的 Save 只绑定 `!model.canSave`，因此空名称时按钮仍可点击，只在按下后由 `makeRoute` 抛 `RouteEditorError.emptyName` 并显示错误；Task 8 验收项「空名称时 Save 禁用」当时未满足
- 修改：`RoamControl/Features/Routes/State/RouteEditorModel.swift` 的 `canSave` 改为
  ```swift
  var canSave: Bool {
      temporaryGeometry != nil && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  ```
  名称判定与 `makeRoute` 使用同一套 trim 规则，按钮可用性与保存结果因此一致
- 未改动：`makeRoute` 行为保持不变（仍负责 trim、空名抛 `RouteEditorError.emptyName`、写入 `errorMessage`）；`RouteEditorView` 逻辑未动，仍是 `.disabled(!model.canSave)`；未改 `RouteLibraryView`、`RouteRunSetupView`、`project.pbxproj`
- 新增测试：`RoamControlTests/RouteEditorModelTests.swift` 增加 `testCanSaveRequiresNonBlankName`（三点闭环 + 有效名称时为 `true`，`""` 与 `"   \n"` 均为 `false`）和 `testCanSaveRecoversAfterNameIsRestored`（名称设为 `"Riverside loop"` 为 `true`，清空为 `false`，恢复后回到 `true` 且 `errorMessage` 仍为 `nil`）
- 现有覆盖：`makeRoute` 空名抛错的既有测试未改，仍全绿；测试数从 78 增至 80
- 提交：`aec2038`（`fix(routes): require a route name before saving`），本记录单独提交 `docs(routes): record Task 8 acceptance fix`
- CI：run `41088976344`、job `124177498609`，12 分 24 秒；`Test case … passed` 80 行、`failed` 0 行，`** TEST SUCCEEDED **`，`Build Debug` `** BUILD SUCCEEDED **`；两个新用例在日志中逐条通过
- 本地无法验证的事实：本机是 Windows 且没有 `xcodebuild`，全量测试与 Debug 构建都在 `xcode-27` runner 上完成
- 验收状态：`空名称时 Save 禁用` 现由模型测试保证，不再依赖模拟器手工确认；模拟器侧其余手工检查（四点矩形、闭环闭合段、Undo 同步、Clear 确认、`onSave` 收包）仍留给 Task 9 接入后验证
- 工作流：https://github.com/FaHits/Roam-Control/actions/runs/41088976344
- 更新时间：2026-10-31

### 2026-10-31 Task 9 完成记录

- 新增文件：`RoamControl/Features/Routes/Views/RouteLibraryView.swift`、`RoamControl/Features/Routes/Views/RouteRunSetupView.swift`、`RoamControlTests/RouteProfileStoreTests.swift`
- 修改文件：仅 `Documentation/ImplementationStatus.md`。未改 `HomeView.swift`、`AppModel.swift`、`RouteEditorView.swift`、`RouteLibraryModel.swift` 和 `RoamControl.xcodeproj/project.pbxproj`；工程使用 `PBXFileSystemSynchronizedRootGroup`，新文件自动进入 App 与测试 target
- `RouteLibraryView` 接口：
  ```swift
  struct RouteLibraryView: View {
      let isRouteActive: Bool
      let isPaired: Bool
      let onRun: (RouteRunConfiguration) -> Void
      let onClose: () -> Void
      let onEditActiveRoute: () -> Void
  }
  ```
  内部用 `@State private var model` 持有 `RouteLibraryModel()`，所有读写都经 `model.upsert`、`model.delete`、`model.clearError`，不直接访问 `RouteStore`
- `RouteRunSetupView` 接口：
  ```swift
  struct RouteRunSetupView: View {
      let route: RouteDefinition
      let isPaired: Bool
      let onRun: (RouteRunConfiguration) -> Void
      let onCancel: () -> Void
  }

  struct RouteRunConfiguration: Equatable, Sendable {
      let route: RouteDefinition
      let profile: RunProfile
      let mode: RouteRunMode
  }
  ```
- `RunProfileStore` 接口与行为：
  ```swift
  struct RunProfileStore {
      static let storageKey = "routeRunProfile"
      let defaults: UserDefaults
      init(defaults: UserDefaults = .standard)
      func load() -> RunProfile
      func save(_ profile: RunProfile)
  }
  ```
  只使用一个 `Data` key `routeRunProfile`。`load()` 先取 `Data` 再 `JSONDecoder` 解码，随后调用 `profile.validate()`；缺值、解码失败或字段越界任一发生都回退 `.running`。`save()` 先 `validate()` 再编码，校验或编码失败直接返回、不抛错，也不覆盖已有值。没有引入协议
- 路线库界面：`NavigationStack` + `List`，标题 `Routes`；顶部关闭按钮调 `onClose`，工具栏 `New Route` 以 sheet 打开 `RouteEditorView(existingRoute: nil)`。每行显示路线名、格式化距离、`Closed`/`Open`、最后更新时间；距离由 `RouteGeometry(points:isClosed:)` 的 `totalDistance` 计算，几何失败显示 `—`，小于 1000 米用米，否则公里保留一位小数。空状态精确为 `Draw a route to start a repeatable run.`
- 重命名与删除：左滑 `Rename` / `Delete`；删除先弹 `confirmationDialog` 再 `model.delete`；重命名用带 `TextField` 的 alert，复制原路线、只改 `name` 并把 `updatedAt` 设为 `.now`，保留 `id`、`createdAt`、`source` 后 `model.upsert`
- 编辑器保存：回调先 `model.upsert(route)`，仅当 `model.errorMessage == nil` 才关闭编辑器；失败时编辑器保持打开，库错误条同时内嵌在编辑器 sheet 顶部展示原因。库页错误条带 `Dismiss`，调用 `model.clearError()`
- 活跃路线限制：`isRouteActive` 为 `true` 时统一禁用所有行的点按、`Rename` 和 `Delete`，顶部显示精确文案 `Stop the active run before changing this route.`，并提供 `View active run` 按钮调用 `onEditActiveRoute`；因接口没有 `activeRouteID`，未新增该参数，也未尝试识别具体活跃路线
- 运行设置页面：初始化时用 `RunProfileStore().load()` 填入 `@State profile`；闭环默认 `.continuous`，开放路线强制 `.once`。标题 `Run Setup`，`Cancel` 调 `onCancel`，内容用始终可滚动的 `ScrollView`，样式为 `.padding(18)`、`.regularMaterial`、连续圆角 `24`、`.borderedProminent`、`.controlSize(.large)`
- 参数范围：速度 `1.0...6.0 m/s`（步进 `0.1`）、步频 `120...210 spm`（步进 `1`）、速度波动 `0...15%`（步进 `1%`）、步频波动 `0...15%`（步进 `1%`）、GPS 抖动 `0...5 m`（步进 `0.1`）
- 模式规则：闭环显示 `Once` / `Continuous` / `Laps`，选 `Laps` 时出现 `1...100` 的步进器；开放路线只显示 `Once`
- 开始禁用条件：开始按钮要求路线几何有效、`isPaired == true`、`profile.validate()` 通过、`mode.validated()` 通过，任一不满足即禁用并显示原因。未配对为 `Pair this iPhone before starting a run.`；几何无效为 `This route cannot be run.`；另外 profile 校验失败显示 `These run settings are invalid.`，模式校验失败显示 `This run mode is invalid.`
- 开始行为：点击开始只调用 `RunProfileStore().save(profile)`，再调用 `onRun(RouteRunConfiguration(route:profile:mode:))`；不调用 `AppModel`，不启动设备会话。页面消失时再保存一次 profile，避免调完参数直接返回时丢设置
- 新增测试：`RoamControlTests/RouteProfileStoreTests.swift` 共 3 个用例，`testLoadReturnsRunningWhenNothingWasSaved`、`testSaveAndLoadRoundTripsAllProfileFields`、`testLoadFallsBackToRunningForInvalidStoredData`。每个用例使用唯一的 `UserDefaults(suiteName: "RouteProfileStoreTests-\(UUID().uuidString)")`，在 `addTeardownBlock` 里 `removePersistentDomain(forName:)`，不访问 `.standard`。测试数从 80 增至 83
- 红灯：提交 `8d74c7a`（`test(routes): define run profile store behavior`），run `41095140153` 编译失败，错误为 `cannot find 'RunProfileStore' in scope`，符合预期
- 实现提交：`91c4bb2`（`feat(routes): add route library and run setup`）
- CI：run `41095688833`、job `124200712117`，Xcode 27.1，7 分 35 秒；日志 `Test case … passed` 83 行、`failed` 0 行，`** TEST SUCCEEDED **`，同一 run 的 `Build Debug` 为 `** BUILD SUCCEEDED **`；3 个新用例逐条通过
- 本地无法验证的事实：本机是 Windows 且没有 `xcodebuild`，全量测试与 Debug 构建都在 `xcode-27` runner 上完成，没有本地测试通过的结论
- 未验证项：`HomeView` 尚未接入任何路线库或运行设置回调；模拟器手工检查（空状态、新建路线、重命名、删除、闭环默认 `Continuous`、开放路线强制 `Once`、开始按钮禁用状态）留到 Task 12 集成验收
- 工作流：https://github.com/FaHits/Roam-Control/actions/runs/41095688833
- 下一步：Task 10 - 恢复模型与设备会话基础
- 更新时间：2026-10-31

### 2026-10-31 Task 10 完成记录

- 新增文件：`RoamControl/Features/Routes/State/RouteSessionModel.swift`、`RoamControlTests/RouteRecoveryTests.swift`、`RoamControlTests/RouteSessionModelTests.swift`
- 修改文件：`RoamControl/Models/SessionRecoveryRecord.swift`、`RoamControl/App/AppModel.swift`、`Documentation/ImplementationStatus.md`。未改 `RoamControl.xcodeproj/project.pbxproj`（`PBXFileSystemSynchronizedRootGroup` 让新文件自动进 target），未改 `HomeView.swift`、`RouteRunCard.swift`、`RouteLibraryView.swift`、`RouteRunSetupView.swift`，未改版本号与 build number
- `SessionRecoveryRecord` 扩展：
  ```swift
  enum Kind: String, Codable { case fixedLocation; case walkingRoute; case savedRoute }

  var savedRoute: RouteDefinition? = nil
  var routeProgress: RouteRunProgress? = nil
  var runProfile: RunProfile? = nil
  var runMode: RouteRunMode? = nil

  var isSavedRoute: Bool { kind == .savedRoute }
  var isRouteSession: Bool { kind == .walkingRoute || kind == .savedRoute }

  static func savedRoute(
      route: RouteDefinition,
      at initialTarget: LocationTarget,
      progress: RouteRunProgress,
      profile: RunProfile,
      mode: RouteRunMode
  ) -> SessionRecoveryRecord
  ```
  四个新字段都声明在 `updatedAt` 之后并带 `nil` 默认值，`fixed(at:)` 与 `walking(from:to:paceMetresPerSecond:)` 的字段和取值完全不变；旧 JSON 缺少新键时由 `Codable` 合成为 `nil`
- `AppModel` 新接口：
  ```swift
  func startRouteLocationSession(
      at initialTarget: LocationTarget,
      route: RouteDefinition,
      profile: RunProfile,
      mode: RouteRunMode
  ) async

  func updateActiveRouteRecovery(at target: LocationTarget, progress: RouteRunProgress)
  func finishActiveRouteRecovery(at target: LocationTarget)
  ```
- `startRouteLocationSession` 复用 private `startLocationSession(at:selectedTarget:historyTarget:recovery:)`：`deviceTarget` 与 `historyTarget` 都取 `initialTarget`，`selectedTarget` 用路线名构造，`recovery` 用 `.savedRoute(...)`，起始进度固定为 `.init(distanceInLap: 0, completedLaps: 0, elapsedTime: 0)`。路线运行不再有任何路径使用 `.fixed(at:)` 作为起始记录
- 恢复写入：`persistActiveSessionRecovery` 原有的 5 秒节流逻辑抽成 `saveActiveSessionRecoveryIfDue(at:)`，`updateActiveRouteRecovery` 复用同一节流，没有新增计时器；`finishActiveRouteRecovery` 在同一目录立即编码写盘并同步 `lastRecoverySaveDate`，崩溃不会丢掉最后一个模拟点
- `applyDeviceSessionPhase(.failed)` 增加例外：`activeSessionRecovery?.isSavedRoute != true` 才调用 `clearActiveSessionRecovery()`，路线运行失败时保留 `.savedRoute` 恢复记录；`.idle` 分支的清理由用户主动停止后的真实位置恢复路径继续沿用，未改
- `RouteSessionModel` 接口：
  ```swift
  enum RouteSessionPhase: Equatable { idle, preparing, running, paused, finished, stopping, failed(String) }
  enum RouteSessionError: Error, Equatable { notPrepared, invalidProgress }

  @MainActor @Observable final class RouteSessionModel {
      private(set) var phase: RouteSessionPhase
      private(set) var route: RouteDefinition?
      private(set) var snapshot: RouteRunSnapshot?
      private(set) var errorMessage: String?

      var locksRouteInput: Bool
      var completedLaps: Int
      var lapProgress: Double
      var totalDistance: Double

      func prepare(route:profile:mode:progress:) throws
      func start(using appModel: AppModel) async
      func togglePause()
      func stop(using appModel: AppModel)
      func handleDeviceSessionPhase(_ phase: DeviceSessionPhase, appModel: AppModel)
      func reset()
  }
  ```
- `prepare` 顺序固定为：`RouteGeometry(points:isClosed:)` → `mode.validated()` → `profile.validate()` → 自校验 `progress`（`distanceInLap`、`elapsedTime` 必须有限且非负，`completedLaps` 必须非负，否则 `throw RouteSessionError.invalidProgress`）→ `RouteRunner(geometry:profile:mode:progress:)`。`prepare` 不调用设备、不启动 tick、不修改 `phase`（保持 `.idle`）
- `start` 行为：未配对直接 `.failed("Pair this iPhone before starting a route.")`；`.preparing/.running/.paused/.stopping` 期间不重复启动；设 `.preparing` 后用 `snapshot.groundCoordinate` 构造 `LocationTarget` 并调用 `appModel.startRouteLocationSession(...)`；设备仍 `.idle` 时 `.failed("Roam Control could not start the route session.")`；设备已 `.active` 时主动调用一次 `handleDeviceSessionPhase(.active(target))`；启动成功后用当前进度写一次种子 `updateActiveRouteRecovery`，不做每 tick 持久化（Task 11）
- 设备阶段幂等规则：`.active` 只在 `phase == .preparing` 且 `movementTask == nil` 时开循环，所以每次 `updateLocation` 触发的 `.active` 回调不会重复启动第二个循环；`.failed(message)` 只在 `.preparing/.running/.paused/.stopping` 时生效，取消循环、写 `errorMessage`、进 `.failed`，不调用 `finishActiveRouteRecovery`；`.idle` 在 `.stopping` 时取消并 `reset()`，在 `.running/.preparing` 时进 `.failed("The active location session ended before the route finished.")`；`.openingLocalDevVPN/.discovering/.connecting/.stopping` 只更新等待状态
- 移动循环：整个 active 会话只有一个 `@MainActor` `movementTask`，每轮 `Date.now` 算真实 delta 并传给 `runner.advance(by:)`，`sleep` 约 1 秒，不固定 1.0、不截断；暂停时只重置 `lastTick` 不推进，恢复不重建循环；`RouteRunner` 作为 `var runner` 原地推进，不是每 tick 新建
- 坐标分流：`snapshot.groundCoordinate` 只用于路线进度与恢复种子，`snapshot.reportedCoordinate` 才用于构造发给设备的 `LocationTarget`，名称 `Running <route name>`，subtitle 为 `<laps> laps · <speed> m/s · <cadence> spm`
- 终止路径：`updateLocation` 结果不是 `.updated` 立即失败并取消循环；runner 进入 `.finished` 时设 `.finished`、取消循环、调用 `finishActiveRouteRecovery(at: 最后一个 target)`；`stop(using:)` 取消循环、设 `.stopping`、调用 `deviceSession.stop()`，不调用 `finishActiveRouteRecovery`；`reset()` 只清状态不碰设备
- `locksRouteInput`：`.preparing/.running/.paused/.stopping/.finished` 为 `true`，`.idle/.failed` 为 `false`
- 新增测试：`RouteRecoveryTests` 6 个用例（`testExistingFixedLocationRecordStillDecodes`、`testExistingWalkingRecordStillDecodes`、`testSavedRouteRecordRoundTripsSnapshotAndProgress`、`testSavedRouteRecordContainsRouteGeometry`、`testRouteModeAndProfileRemainDeterministicAfterDecoding`、`testFixedFactoryKeepsLegacyShape`），旧 JSON 用 `JSONSerialization` 手写字典并省略新键；`RouteSessionModelTests` 3 个用例（`testPrepareRejectsInvalidModeBeforeDeviceCall`、`testPrepareBuildsSnapshotAtSuppliedProgress`、`testPrepareRejectsNegativeProgress`）。测试数从 83 增至 92
- 红灯：提交 `afcd14d`（`test(routes): define route recovery and session contracts`），run `41102232658` 编译失败，错误为 `value of type 'SessionRecoveryRecord' has no member 'savedRoute'`（同类 9 条），失败原因是符号缺失而不是测试逻辑
- 实现提交：`8193394`（`feat(routes): connect route runner to device session`）
- CI：run `41102340345`、job `124221570276`，Xcode 27.1，6 分 40 秒；`Test case … passed` 92 行、`failed` 0 行，`** TEST SUCCEEDED **`，同一 run 的 `Build Debug` 为 `** BUILD SUCCEEDED **`；9 个新用例逐条通过
- 偏差：`startLocationSession` 里既有的 `pendingSessionAnalyticsEvent` 三元表达式未改，`.savedRoute` 启动时仍记为 `fixedLocationStarted`，没有新增路线专属事件，避免扩大本任务范围
- 本地无法验证的事实：本机是 Windows 且没有 `xcodebuild`，全量测试与 Debug 构建都在 `xcode-27` runner 上完成，没有本地测试通过的结论
- 未验证项：真实设备会话（配对、Local DevVPN 连接、`updateLocation` 逐秒回传）、失败后恢复记录的跨启动恢复、后台长跑与每 tick 进度持久化（Task 11）、`HomeView` 与 `RouteRunCard` 整合（Task 12）、模拟器/真机手工验收
- 工作流：https://github.com/FaHits/Roam-Control/actions/runs/41102340345
- 下一步：Task 11 - 运行中进度持久化
- 更新时间：2026-10-31

### 2026-10-31 Task 11 完成记录

- 修改文件：`RoamControl/Features/Routes/State/RouteSessionModel.swift`（+2）、`RoamControl/App/AppModel.swift`（+17，`#if DEBUG` 测试入口）、`RoamControlTests/RouteRecoveryTests.swift`、`Documentation/ImplementationStatus.md`。未改 `RoamControl.xcodeproj/project.pbxproj`，未改 `HomeView.swift`、`RouteRunCard.swift`、`RouteLibraryView.swift`、`RouteRunSetupView.swift`，未改版本号与 build number
- 每 tick 持久化：`advance(by:using:)` 仍在最前面 `guard appModel.deviceSession.updateLocation(target) == .updated`，失败保持原 `fail(...)` 路径且不写进度；设备接受后只在 `next.phase != .finished` 时调用 `appModel.updateActiveRouteRecovery(at: target, progress: progress(of: next))`。写入的 `target` 就是设备接受的那一个，进度取自 `advance` 之后的 `next` 快照，不是上一帧
  ```swift
  if next.phase == .finished {
      finish(at: target, using: appModel)
  } else {
      appModel.updateActiveRouteRecovery(at: target, progress: progress(of: next))
  }
  ```
- 不写进度的路径：移动循环只在 `phase == .running` 时推进（`beginMovement` 的 switch），`togglePause()` 不碰恢复记录，`.preparing` 阶段的唯一写入是 `start` 里已有的种子调用，`.finished` 分支直接走 `finish(at:using:)`，`.failed` 走取消路径。没有新增第二个定时器，仍是原来的 1 秒 `movementTask` + `saveActiveSessionRecoveryIfDue` 的 5 秒节流
- 完成转 fixed：`finish(at: target, using:)` → `appModel.finishActiveRouteRecovery(at: target)`，内部 guard `recovery.kind == .savedRoute` 后替换成 `.fixed(at: target)`，同步 `lastRecoverySaveDate = .now` 并立即编码写盘，`savedRoute`/`routeProgress`/`runProfile`/`runMode` 全部变 `nil`
- 停止与失败：`stop(using:)` 仍只取消循环、设 `.stopping`、调用 `deviceSession.stop()`，设备回到 `.idle` 时由 `applyDeviceSessionPhase(.idle)` 里既有的 `clearActiveSessionRecovery()` 清理，没有新增清理路径；`.failed` 分支的 `activeSessionRecovery?.isSavedRoute != true` 例外保持不变，路线运行失败时保留 `.savedRoute` 记录
- 名称撞车：`persistActiveSessionRecovery` 只把 `kind == .walkingRoute` 且 `destination.id == target.id` 的记录转成 `.fixed`，且 `savedRoute` 记录的 `destination` 恒为 `nil`，所以路线名等于目的地名也不会被转成 fixed
- `AppModel` 新增（仅 `#if DEBUG`，不改变生产路径、不扩大公开 API）：
  ```swift
  var debugActiveSessionRecovery: SessionRecoveryRecord? {
      get { activeSessionRecovery }
      set {
          activeSessionRecovery = newValue
          lastRecoverySaveDate = nil
          guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
              preferences.removeObject(forKey: Self.activeSessionRecoveryKey)
              return
          }
          preferences.set(data, forKey: Self.activeSessionRecoveryKey)
      }
  }
  ```
  写入口把 `lastRecoverySaveDate` 置空，等价于“刚从磁盘恢复、下一次保存仍然到期”，否则 5 秒节流会吞掉测试里的第一次断言
- 新增测试（`RouteRecoveryTests`，类上加 `@MainActor`，`StubPairingService` 在本文件内最小实现）4 个：`testUpdatingProgressPreservesRouteSnapshot`、`testCompletedRunConvertsRecoveryToFinalFixedLocation`、`testFailedRunRetainsSavedRouteRecovery`、`testRouteNameMatchingDestinationDoesNotConvertSavedRoute`。断言统一用 `UserDefaults(suiteName:)` 的 `"activeSessionRecovery"` 键读回并解码，与生产同一个 key
- 红灯：提交 `78ea0b5`（`test(routes): define route progress recovery`），run `41156364350` 编译失败，错误为 `RoamControlTests/RouteRecoveryTests.swift:203:18: error: value of type 'AppModel' has no member 'debugActiveSessionRecovery'`，失败原因是符号缺失而不是测试逻辑
- 实现提交：`0c32526`（`feat(routes): persist route progress during runs`）
- CI：run `41156408775`，Xcode 27.1，`Test case … passed` 96 行、`failed` 0 行，`** TEST SUCCEEDED **`，同一 run 的 `Build Debug` 为 `** BUILD SUCCEEDED **`；4 个新用例逐条通过，测试数从 92 增至 96
- 本地无法验证的事实：本机是 Windows 且没有 `xcodebuild`，全量测试与 Debug 构建都在 `xcode-27` runner 上完成，没有本地测试通过的结论
- 未验证项：真实设备会话（配对、Local DevVPN 连接、`updateLocation` 逐秒回传）、真机后台长跑的 5 秒节流节奏、`HomeView` 与 `RouteRunCard` 展示运行进度（Task 12）、中断后从 `.savedRoute` 恢复继续跑（Task 13）、模拟器/真机手工验收
- 工作流：https://github.com/FaHits/Roam-Control/actions/runs/41156408775
- 下一步：Task 12 - 运行卡片与主页整合
- 更新时间：2026-10-31

### 2026-10-31 Task 12 完成记录

- 修改文件：`RoamControl/Features/Routes/Views/RouteRunCard.swift`（新建，354 行）、`RoamControl/Features/Map/MapViewModel.swift`（+46）、`RoamControl/Features/Home/HomeView.swift`（+144/-3）、`Documentation/ImplementationStatus.md`。未改 `RoamControl.xcodeproj/project.pbxproj`（工程用 `PBXFileSystemSynchronizedRootGroup`，新 Swift 文件自动纳入编译）、未改 `RouteSessionModel.swift`、`RouteRunner.swift`、`RouteGeometry.swift`、`RouteLibraryView.swift`、`RouteRunSetupView.swift`、`RouteEditorView.swift`、`AppModel.swift`、`SessionRecoveryRecord.swift`，未改版本号与 build number
- 实现提交：`45b439a`（`feat(routes): add route run card`）、`072ee7e`（`feat(routes): integrate manual routes into home`）
- 相机：`MapViewModel.show(_ geometry: RouteGeometry)` 用 `geometry.points` 的经纬度 min/max 求中心，`padding` 通过 `× 1.5`（即四周各 25%）实现，`minimumSpan` 为 `0.002`；空点集或任一 delta 非有限时退回 `.automatic`，不产生 NaN
  ```swift
  let latitudeDelta = max((maximumLatitude - minimumLatitude) * 1.5, minimumSpan)
  cameraPosition = .region(MKCoordinateRegion(center: centre, span: MKCoordinateSpan(...)))
  ```
- 卡片：`RouteRunCard(route:session:isPaired:onStart:onTogglePause:onStop:onDone:)` 只读 `RouteSessionModel`，不持有运行逻辑。header 显示路线名与 phase 标题，`ProgressView(value: session.lapProgress)`，六个 metric（Laps、Lap 百分比、Distance、Speed m/s、Cadence spm、Elapsed）。按钮按 phase 分派：`.idle`→Start，`.failed`→Try Again（同样调用 `onStart`），`.preparing`→ProgressView 文案并禁用，`.running`→Pause + Stop，`.paused`→Resume + Stop，`.finished`→Done，`.stopping`→恢复真实位置文案并禁用。Stop 走 `confirmationDialog`（"Stop & Restore" destructive / "Keep Running" cancel），Done 只在 `.finished` 出现
- 卡片样式：`@Environment(\.dynamicTypeSize)`，`isAccessibilitySize` 时 `ScrollView` + `.frame(maxHeight: 460)`，卡片 `.padding(18).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))`，主按钮 `.borderedProminent` + `.controlSize(.large)`，与 `WalkingRoutePreviewCard` 一致。Start、Pause、Resume、Stop、Done 均设置 `accessibilityLabel`
- 主页入口：`HomeView` 新增 `routeSession`/`isShowingRouteLibrary`/`routeLibraryError` 三个 `@State`，Favourites 左侧新增 `point.topleft.down.to.point.bottomright.curvepath` 按钮（`accessibilityLabel("Routes")`）；`Favourites` 按钮在 `routeSession.locksRouteInput` 时禁用
- onRun 顺序（`startRouteRun(_:)`）：关库 → `walkingSimulation.reset()` + `walkingRoutePlanner.clear()` → `mapModel.clearSelectedLocation()` → `routeSession.prepare(route:profile:mode:progress:)`（progress 全零）→ 成功后 `mapModel.show(try RouteGeometry(...))` → `Task { await routeSession.start(using: appModel) }`；`prepare` 或几何构造抛错时设置 `routeLibraryError` 并 `return`，不启动设备、不碰 `deviceSession`
- 地图：`activeRouteGeometry` 由 `routeSession.route` 用 `try?` 构造，`MapPolyline(coordinates:)` 蓝色 `lineWidth 6`；`routeSession.snapshot` 存在时用 `reportedCoordinate` 画 `figure.run.circle.fill` 的 "Running location" 标注，样式与 "Walking location" 相同。固定点 `Marker` 增加 `routeSession.route == nil` 条件；Apple `MKRoute` 与手绘路线不会同时出现，因为开跑前已 `walkingRoutePlanner.clear()`
- 互斥：地图点击 `onTapGesture` 增加 `guard !routeSession.locksRouteInput`，搜索栏 `.disabled` 与建议列表条件都并入 `locksRouteInput`，`SavedPlacesView.onSelect` 同样加 guard；`LocationSelectionCard.onStart` 先 `routeSession.reset()`。卡片优先级为 RestoringRealLocationCard → RouteRunCard（`routeSession.route != nil`）→ WalkingRoutePreviewCard → LocationSelectionCard，因此路线运行期间不会出现固定位置卡
- 设备阶段：`.onChange(of: appModel.deviceSession.phase)` 里在 `walkingSimulation.handleDeviceSessionPhase` 之后加 `routeSession.handleDeviceSessionPhase(newPhase, appModel: appModel)`，两个流程各自按 phase guard 只处理自己的运行；`routeSession` 的 `.idle`/`.failed` 不触碰 `selectedLocation`，固定位置 UI 仍由既有 `LocationSelectionCard` 驱动
- Done 与重入：`onDone` 先 `routeSession.reset()` 再 `mapModel.clearSelectedLocation()`，随后仅当 `deviceSession.phase` 为 `.active`/`.stopping` 才设置 `shouldClearLocationAfterRestoration = true` 并调用 `appModel.stopLocationSession()`，`.idle` 等状态直接跳过；`.finished` 状态下卡片只提供 Done，没有再启动入口
- 新增测试：无。本任务只新增视图并调用 Task 10/11 已覆盖的 `RouteSessionModel` 与 `AppModel` 接口，未新增可失败的逻辑；测试数维持 96
- CI：run `41160737660`，head `072ee7e`，`conclusion=success`，`Test case … passed` 96 行、`failed` 0 行，`** TEST SUCCEEDED **`，同一 run 的 `Build Debug` 为 `** BUILD SUCCEEDED **`；run `41160737660` 对应实现提交，文档提交由后续 run 验证
- 本地无法验证的事实：本机是 Windows 且没有 `xcodebuild`，全量测试与 Debug 构建都在 `xcode-27` runner 上完成，没有本地测试通过的结论；也没有 iOS 模拟器，未做手工交互验收
- 未验证项：真实设备会话下的路线运行（`updateLocation` 逐秒回传、暂停后坐标确实不再变化、Stop 后真实位置恢复）、有限圈完成到 Done 的动画与折线消失、固定位置与路线之间连续切换的实际表现、Dynamic Type accessibility 尺寸下的卡片滚动、`onEditActiveRoute` 在路线库仍展示时设置的错误提示要等 sheet 关闭后才可见
- 工作流：https://github.com/FaHits/Roam-Control/actions/runs/41160737660
- 下一步：Task 13 - 中断路线恢复
- 更新时间：2026-10-31

### 2026-10-31 Task 12 返工：主页 Routes 按钮空图标

- 状态：`implemented_unverified`。自动化证据齐全，真机截图验收未做，不宣布验收通过
- 根因：`HomeView` 的 Routes 按钮用的 SF Symbol 名称把末段写成了 `point.right`（正确是 `point.bottomright`），该名称不存在，SwiftUI 静默渲染为空圆圈；`SessionRecoveryView` 的 savedRoute 图标与详情行用的是同一个错名
- 修复：新增 `RoamControl/Features/Routes/Views/RouteSymbol.swift`，`RouteSymbol.library = "point.topleft.down.to.point.bottomright.curvepath"`（`RouteLibraryView` 空状态原本就在用的有效名称）；`HomeView`、`RouteLibraryView`、`SessionRecoveryView`（详情行与 `recoveryIcon` 两处）共 4 处改为引用该常量。按钮的 44×44 尺寸、位置、`regularMaterial` + 阴影、`accessibilityLabel("Routes")` 与点击动作未改
- 文档同步：`Documentation/Plans/ManualRunningRoutesImplementation.md` 的 Task 12 原文与本文件历史记录里同样的无效名称一并改正
- 验证命令：`rg -n "point\.topleft\.down\.to\.point\.right\.curvepath" .` → 0 命中
- 红灯：提交 `79e1157`（`test(routes): assert the route library SF Symbol resolves`），run `41193155586` `conclusion=failure`，报错 `RoamControlTests/RouteSymbolTests.swift:8:33: error: cannot find 'RouteSymbol' in scope`，`** TEST FAILED **`
- 实现提交：`a272bf2`（`fix(routes): use a real SF Symbol for the route entry`）
- 绿灯 CI：run `41193407036`，head `a272bf2`，`conclusion=success`；`Test case … passed` 114 行、`failed` 0 行，`** TEST SUCCEEDED **`；`Build Debug` 与 `Build Release` 均为 `** BUILD SUCCEEDED **`；`unsigned-ipa` 与 `unsigned-ipa-debug` 两个作业均 success
- 新测试：`RoamControlTests/RouteSymbolTests.swift` 1 个（`testLibrarySymbolExists`，`UIImage(systemName: RouteSymbol.library)` 非 nil），测试数 113 → 114
- 产物：Release 未签名 IPA artifact `13039403715`（`RoamControl-unsigned-ipa`，3,092,461 B ≈ 2.95 MiB）；Debug 未签名 IPA artifact `13039154180`（`RoamControl-unsigned-debug-ipa`，4,652,173 B）
- 未验证项：真机安装 Release IPA 后主页右上角三个按钮的截图（要求文件名 `Task12-routes-icon.png`）与点击进入 `RouteLibraryView` 的目视确认。本机为 Windows，没有 macOS、`xcodebuild`、iOS 模拟器或真机连接链路，截图未生成，`implemented_unverified`
- 版本：仍为 `0.9.2` / `61`，未改 `project.pbxproj`
- 工作流：https://github.com/FaHits/Roam-Control/actions/runs/41193407036
- 下一步：在有 macOS + Xcode 27 + 真机的环境上装 `RoamControl-unsigned-ipa`（artifact `13039403715`），截 `Task12-routes-icon.png` 并回填本文件
- 更新时间：2026-10-31

### 2026-10-31 Task 13 完成记录

- 任务：Task 13 - 中断路线恢复
- 状态：`completed`
- 分支与基线：`feat/manual-running-routes`，基线 `fab1444`
- 修改文件：`RoamControl/Features/Home/SessionRecoveryView.swift`（+65/-8）、`RoamControl/Features/Home/HomeView.swift`（+44）、`RoamControlTests/RouteRecoveryTests.swift`（+51）、`Documentation/ImplementationStatus.md`。未改 `project.pbxproj`、`RouteSessionModel.swift`、`RouteRunner.swift`、`RouteGeometry.swift`、`RouteDefinition.swift`、`RunProfile.swift`、`HumanizedMotionModel.swift`、`SessionRecoveryRecord.swift`、`AppModel.swift`、`RouteLibraryView.swift`、`RouteRunSetupView.swift`、`RouteEditorView.swift`、`RouteRunCard.swift`，未改版本号与构建号
- 提交：`0b2331d`（`test(recovery): define saved route restoration`）、`e71bda8`（`feat(recovery): restore interrupted route runs`）、本文档提交（`docs(routes): record Task 13 completion`）
- 恢复卡展示（`SessionRecoveryView`）：只按 `recovery.isSavedRoute` 增加分支，未引入新模型。图标 `recoveryIcon` 为 savedRoute → `point.topleft.down.to.point.bottomright.curvepath`、walking → `figure.walk.motion`、fixed → `location.fill`；详情用 `Route`（`recovery.savedRoute?.name ?? "Saved route"`）替换 savedRoute 的 Last location 行，不显示 Destination；`routeProgressText` 用 `routeProgress.distanceInLap` 除以 `RouteGeometry(points:isClosed:).totalDistance` 现算百分比（clamp 到 0...1，`Int((f * 100).rounded())`），输出如 `3 completed · 42% of lap`，几何不可用时退化为 `N completed laps`；标题仍为 `Previous Session Interrupted`；`resumeTitle` 与 `resumeSystemImage` 按 savedRoute/walking/fixed 三分支返回 `Resume Route Run`+`figure.run`、`Resume Walking`+`figure.walk`、`Resume Location`+`arrow.clockwise`；`summaryText` 为 savedRoute 单独文案，不含 Apple route 或 walking 字样。`Restore Real Location`、`Already Restored`、`isPaired` 禁用、Dynamic Type 分支、错误文案与 `isResuming` 的 `Preparing the route…` 均未改动
- 恢复流程（`HomeView.resumeInterruptedSession`）：函数开头先判 `if recovery.isSavedRoute { resumeSavedRoute(recovery); return }`，之后才是原来的 `guard recovery.isWalkingRoute, let destination` 分支，savedRoute 不会落到 fixed 的 `startLocationSession(at: recovery.lastReportedLocation)`
- 新增 `private func resumeSavedRoute(_:)`：置空 `recoveredWalkError`；`guard let route/profile/mode/progress` 四件齐全，否则设置 `The saved route run could not be restored.` 并直接 return（不 dismiss recovery、不启动设备）；随后 `routeSession.reset()` → `walkingSimulation.reset()` → `walkingRoutePlanner.clear()`；`try routeSession.prepare(route:profile:mode:progress:)` 传入保存的 `routeProgress`（不归零），成功后 `mapModel.show(try RouteGeometry(points:isClosed:))`；然后 `appModel.dismissInterruptedSessionRecovery()`、`isPreparingRecoveredWalk = false`，最后 `Task { await routeSession.start(using: appModel) }`。`prepare` 或几何构造抛错时 `routeSession.reset()` + `recoveredWalkError = "The saved route run could not be restored."` + `isPreparingRecoveredWalk = false`，不 dismiss、不启动设备，`Restore Real Location` 仍可用
- 快照优先：全程只用 `recovery.savedRoute` 的 `points`/`isClosed`，不按 `route.id` 查路线库、不调用 `walkingRoutePlanner.preview`、不改 `progress` 的圈数与圈内距离；`isPreparingRecoveredWalk`、`RouteRunCard`、`DeviceSessionPhase` 转发都没有新增第二个状态或第二条运行循环
- fixed 与 walking 恢复未变：`startLocationSession(at:)` 一次性定位与 `walkingRoutePlanner.preview` + pace 恢复 + `walkingSimulation.start(using:)` 的代码路径逐字保留，仅在其前面增加了 savedRoute 提前返回
- 新增测试（`RouteRecoveryTests`，类已是 `@MainActor`）2 个：`testSavedRouteRecoveryKeepsSnapshotWhenLibraryEntryIsMissing`（savedRoute 记录编码再解码后 `savedRoute`/`runProfile`/`runMode`/`routeProgress` 齐全，`RouteGeometry` 可构造且 `totalDistance`、`coordinate(atDistance:)` 与原始路线一致，全程不读 `RouteStore`，等价于路线库条目已删除）、`testSavedRouteRecoveryWithoutRunSettingsCannotBeRestored`（去掉 `runProfile`/`runMode`/`routeProgress` 键后解码得到 `nil`，即 `resumeSavedRoute` 的 guard 会走错误分支）。invalid-progress 用例未重复写：`RouteSessionModelTests.testPrepareRejectsNegativeProgress` 已用 `distanceInLap: -1`、`completedLaps: -1`、`elapsedTime: -1` 断言 `RouteSessionError.invalidProgress`，且 `prepare` 抛错前不触碰 `deviceSession`
- 无新增可失败逻辑：两个新测试在旧代码（`fab1444`）上同样通过，因为模型层（`SessionRecoveryRecord`、`RouteSessionModel.prepare`）在 Task 10/11 已实现，Task 13 缺的是视图分支与 `HomeView` 接线，而这两处不属于 XCTest 可覆盖范围。没有伪造红灯
- CI：run `41162486040`，head `e71bda8`，`conclusion=success`；`Test case … passed` 98 行、`failed` 0 行、`** TEST SUCCEEDED **`，同一 run 的 `Build Debug` 为 `** BUILD SUCCEEDED **`；测试从 96 增至 98；日志仅两条既有的 `appintentsmetadataprocessor` 提示，无源码警告。测试提交 `0b2331d` 的 run `41162481900` 同样 `conclusion=success`
- 本地无法验证的事实：本机是 Windows 且没有 `xcodebuild`，全量测试与 Debug 构建都在 `xcode-27` runner 上完成，没有本地测试通过的结论；也没有 iOS 模拟器
- 未验证项：模拟器手工验收（开始 continuous 路线并跨点、5 秒恢复写入、强制退出重启、确认恢复卡显示路线名/圈数/圈内进度/`Resume Route Run`、点击后从保存圈数与圈内位置继续），真实设备会话下中断后恢复的实际坐标与节流节奏，损坏快照在 UI 上真实显示的文案
- 已知风险：`resumeSavedRoute` 是同步执行，`isPreparingRecoveredWalk` 只在异常路径上被显式置回，正常路径置回后立即 dismiss，因此 `Preparing the route…` 在 savedRoute 上通常只有一帧；恢复后圈数与圈内距离直接来自快照，若快照的 `distanceInLap` 大于几何总长，`RouteRunner` 首次推进会把进度夹到圈末而不是拒绝，这属于模型既有行为，本任务未改
- 工作流：https://github.com/FaHits/Roam-Control/actions/runs/41162486040
- 后续走向（历史陈述）：Task 14 - 完整验证，其 A 段已于 2026-11-01 交付，B 段 19 项真机行为待用户执行
- 更新时间：2026-10-31

### 2026-10-31 Task 13 流程偏差

- 任务：Task 13 - 中断路线恢复（状态保持 `completed`，本节只记录交付流程上的偏差，不改任务状态值）
- 偏差事实：Task 13 的文档提交原始哈希是 `82354ee`（`docs(routes): record Task 13 completion`），已经推送到个人 fork 后，为了修正文档正文里写错的 `+/-` 行数，改用 `git commit --amend` 改写成 `8b4dcb3`，并用 `git push --force-with-lease` 强推
- 强推范围：只有个人 fork `fork` 的 `feat/manual-running-routes` 分支，没有触碰 `origin`，也没有触碰其他分支
- 受影响内容：仅是 `Documentation/ImplementationStatus.md` 里的文档 diffstat 数字（`SessionRecoveryView.swift` +55/-10 → +65/-8、`HomeView.swift` +49 → +44、`RouteRecoveryTests.swift` +53 → +51）。代码提交 `0b2331d`（`test(recovery): define saved route restoration`）和 `e71bda8`（`feat(recovery): restore interrupted route runs`）没有被改写，`RoamControl/`、`RoamControlTests/` 与 `project.pbxproj` 的内容在这次强推前后完全一致
- CI 影响：改写后的 docs 提交 run `41163895262`（head `8b4dcb3`）`conclusion=success`，98 passed / 0 failed，`** TEST SUCCEEDED **` 和 `** BUILD SUCCEEDED **`；被覆盖的 run `41163866675`（head `82354ee`）随之作废。代码与测试结论不受影响
- 被违反的规则：`Documentation/AIDevelopment.md` 第 107 行“不强制推送，不改写已推送历史”
- 后续处理：不再改写 `feat/manual-running-routes` 的已推送历史；之后发现已推送提交有误时，只追加新的修复提交，不改写远端历史；推送前用 `git log --oneline fork/<分支>..HEAD` 确认待推内容，若发现要改的是已推送提交，停止并报告，不自行强推
- 规则加固：`Documentation/AIDevelopment.md` 第 7 节和 `AGENTS.md` 的“自动完成与同步”已把 `git commit --amend`、`git rebase`、`git push --force`、`git push --force-with-lease` 明确列为对已推送历史的禁止操作，并规定远端拒绝普通 push 时停止报告而不是改用 force
- 更新时间：2026-10-31

### 2026-10-31 Task 14 验证记录（已被 2026-11-01 记录取代）

- 任务：Task 14 - 完整验证
- 状态：`superseded`（只保留当时证据；当前状态见文末 2026-11-01 记录）
- 分支与基线：`feat/manual-running-routes`，验证前 HEAD `25129d9`，与 `fork` 远端一致，工作树干净；整体差异基线 `b68dac0`
- 修改文件：`.github/workflows/xcode-27.yml`（+10，仅追加 `Build Release` 步骤）、`Documentation/ImplementationStatus.md`。未改 `RoamControl/`、`RoamControlTests/`、`project.pbxproj`、版本号与构建号：本次验证没有发现真实缺陷，因此没有补测试也没有改代码
- 提交：`9b4984a`（`ci: verify release build`）、本文档提交（`docs(routes): record Task 14 verification`）。无 `fix` 提交
- 架构边界检查：`rg -n "import (SwiftUI|MapKit)|AppModel" RoamControl/Features/Routes/Core RoamControl/Features/Routes/Models` 无输出、`exit=1`；`rg -n "MKRoute|MKMapPoint|MKPolyline" RoamControl/Features/Routes/Core RoamControl/Features/Routes/Models` 无输出、`exit=1`。同一目录下 `rg -c "import Foundation"` 命中 7 个文件，证明两条检查确实扫描到目标目录而不是空扫。`Routes/Views/` 内的 `import MapKit`/`import SwiftUI` 属于 UI 层，不在边界检查范围内，未作违规记录
- CI 缺口与补丁：`.github/workflows/xcode-27.yml` 原本只有 `Run RoamControlTests` 与 `Build Debug`，没有 Release 构建，Release 配置此前从未在 CI 上验证过。已按计划追加最小 `Build Release` 步骤（`-configuration Release`、`-destination 'generic/platform=iOS Simulator'`、`CODE_SIGNING_ALLOWED=NO`、`set -o pipefail`），未改动任何既有 test/Debug 步骤
- CI 结果：run `41166020073`，head `9b4984a`，`conclusion=success`；步骤 `Run RoamControlTests` success、`Build Debug` success、`Build Release` success。日志内 `** TEST SUCCEEDED **`、`** BUILD SUCCEEDED **` 各 1 次（Debug）、1 次（Release）；`Test case '…' passed` 98 行、`Test case '…' failed` 0 行；Xcode 27.1（Build 27A9275）。10 个测试套件：`BaselineTests` 1、`HumanizedMotionModelTests` 8、`RouteEditorModelTests` 23、`RouteGeometryTests` 10、`RouteLibraryModelTests` 12、`RouteProfileStoreTests` 3、`RouteRecoveryTests` 12、`RouteRunnerTests` 18、`RouteSessionModelTests` 3、`RouteStoreTests` 8，合计 98，与仓库内 `func test` 计数一致
- 新增测试：0。本次只验证，没有失败用例可复现，因此没有为了凑数写测试
- 日志警告：路线相关文件无警告；仅有既有的 `Ignoring --strip-bitcode because --sign was not passed` 与 `appintentsmetadataprocessor` 提示，与路线代码无关
- 本地无法验证的事实：本机为 Windows（`uname` 为 MINGW64），`which xcodebuild` 与 `which swift` 均为空，测试与 Debug/Release 构建全部在 `xcode-27` runner 上完成，本地没有任何 `xcodebuild` 结果
- 未验证内容（模拟器与真机，当时全部未做）：逐项清单已由交接文档第 7 节 19 行取代，不再在此重复；当时本机无 macOS、模拟器与配对真机
- 单元级证据（不能替代手工验收）：暂停不改进度 `RouteRunnerTests.testPauseDoesNotAdvanceProgress`、`testResumeContinuesFromPausedCoordinate`；接缝 `testContinuousRouteWrapsWithoutASeamJump`、`testCompletedLapIncrementsExactlyOnceAtSeam`、`testLargeAdvanceCanCrossMultipleLaps`、`testThousandLapsDoNotAccumulateLapError`；抖动 `testZeroJitterReturnsExactGroundCoordinate`、`testJitterNeverExceedsRadius`、`testJitterRemainsSmoothBetweenOneSecondSamples`；有限圈 `testFiniteLapRunFinishesAfterRequestedLapCount`、`testFinishedRunnerIsTerminal`；持久化 `RouteStoreTests.testSaveAndLoadRoundTripsRoutes`、`testSaveUsesAtomicReplacement`、`testCorruptedFileThrowsAndRemainsUnchanged`；固定位置与 Apple walking 兼容 `RouteRecoveryTests.testExistingFixedLocationRecordStillDecodes`、`testExistingWalkingRecordStillDecodes`、`testFixedFactoryKeepsLegacyShape`
- 固定位置与 Apple walking 回归（静态检查）：`git diff b68dac0 -- RoamControl/Features/Home/HomeView.swift` 只在这些流程原有的 guard 上并列增加 `routeSession.locksRouteInput`，并在启动/恢复路线时调用 `walkingSimulation.reset()` 与 `walkingRoutePlanner.clear()`；`startLocationSession(at:)`、`walkingRoutePlanner.preview`、`walkingSimulation.start` 的调用链没有逻辑改动，`locksRouteInput` 在 `.idle`/`.failed` 为 false，未跑路线时行为与改动前一致。`SessionRecoveryRecord` 中 fixed 与 walking 的解码路径保留并有测试覆盖。运行时行为仍属未验证
- 已知风险：自动化只覆盖模型层，`HomeView`/`RouteRunCard`/`RouteLibraryView`/`RouteRunSetupView`/`SessionRecoveryView` 的接线没有 XCTest 覆盖，手工项未做即无 UI 层证据；Release 配置到本次才纳入 CI，此前是空缺而非“一直通过”；真机设备会话（配对、LocalDevVPN、`updateLocation` 逐秒回传）与后台节流从未在真实设备上验证，是当前最大未知
- 工作流：https://github.com/FaHits/Roam-Control/actions/runs/41166020073
- 当时设想的下一步（历史陈述）：在有 macOS + Xcode 27 + iOS 27 模拟器的环境跑 `xcodebuild test … -only-testing:RoamControlTests` 并按 Task 14 模拟器清单验收；测试与 Debug/Release 构建后来改由 `xcode-27` runner 覆盖，模拟器与真机手工项仍由用户执行
- 更新时间：2026-10-31

### 2026-10-31 Task 10 返工记录：路线启动不再污染地点历史

- 任务：Task 10 - 恢复模型与设备会话基础（返工，状态 `implemented_unverified`）
- 分支与基线：`feat/manual-running-routes`，返工前 HEAD `10cc890`，与 `fork` 一致，工作树干净
- 缺陷：`startRouteLocationSession` 传 `historyTarget: initialTarget`，私有 `startLocationSession` 无条件 `addToHistory(historyTarget)`（改前 `AppModel.swift:392`），因此每次启动路线都会把起点写进 Saved Places 历史；路线应只由 My Routes 承载
- 修改文件：`RoamControl/App/AppModel.swift`（+6/-3：`historyTarget` 改 `LocationTarget?`、`addToHistory` 加 `if let`、路线调用传 `nil` 并加注释）、新增 `RoamControlTests/RouteHistoryTests.swift`（87 行，2 例）、`Documentation/Plans/ManualRunningRoutesImplementation.md`（Step 3 的 History target 说明改为「none」）、`Documentation/ImplementationStatus.md`。未改 `project.pbxproj`、`HomeView.swift`、`RouteRunCard.swift`、`RouteLibraryView.swift`、`RouteRunSetupView.swift`、`RouteSessionModel.swift`；未改版本号与构建号（仍 `0.9.2` / `61`）
- 提交：`b163951`（`test(routes): assert route runs stay out of Saved Places history`，红灯）、`80af1a7`（`fix(routes): keep route runs out of Saved Places history`，绿灯）、本文档提交（`docs(routes): record the Task 10 history fix`）
- 回归测试（不新增生产 test seam）：`RouteHistoryTests` 复用既有 `AppModel(pairingService:preferences:)` 注入点，新增 `PairedStubPairingService`（`storedRecord()` 返回一条 `PairingRecordSummary`）配合 `restorePairingStatus()` 进入 `.paired`，再走公开的 `startRouteLocationSession` / `startLocationSession(at:)` 断言 `locationHistory`。`testStartingRouteRunDoesNotWriteLocationHistory` 断言路线启动后历史为空；`testStartingFixedLocationSessionStillWritesLocationHistory` 断言固定位置启动后历史恰好等于该 target
- 红灯证据：run `41195523226`（head `b163951`）`test` job 失败，`** TEST FAILED **`，唯一失败用例是 `RouteHistoryTests.testStartingRouteRunDoesNotWriteLocationHistory()`，115 passed / 1 failed；该提交未含 AppModel 修改，说明测试确实能抓住原缺陷，而非测试自身写错
- 绿灯证据：run `41195528908`（head `80af1a7`）`conclusion=success`，三个 job 全 success（`test` 419s、`unsigned-ipa` 68s、`unsigned-ipa-debug` 40s）；日志 `Test case … passed` 116 行、`failed` 0 行、`** TEST SUCCEEDED **` 1 次，`Build Debug` 与 `Build Release` 各 1 次 `** BUILD SUCCEEDED **`；测试总数 114 → 116
- 产物：Release IPA artifact `RoamControl-unsigned-ipa` id `13040706415` / 3,093,454 字节；Debug IPA artifact `RoamControl-unsigned-debug-ipa` id `13040422834` / 4,654,993 字节；Debug job 自检 `self-check 'Probe (Debug)' hits: 2`
- 计划文档同步：`Documentation/Plans/ManualRunningRoutesImplementation.md` 的 Task 10 Step 3 里 “History target: the same initial ground coordinate.” 已改为「none」，并写明私有方法签名是 `historyTarget: LocationTarget?`
- 本地无法验证的事实：本机为 Windows，无 `xcodebuild`、无 iOS 模拟器、无配对真机；测试与三项构建全部在 `xcode-27` runner 上完成，本文件不声称本地通过
- 未验证项（真机，待验收）：① 启动任一手绘路线后立即 Stop & Restore，Saved Places 中不得出现名为该路线点位的条目；② 同一台设备先跑一次固定位置，Saved Places 应正常出现该点，证明固定位置流程未被破坏；③ 路线运行中 `RouteRunCard` 进度、暂停、恢复、完成后 `finishActiveRouteRecovery` 行为；④ 设备失败时 `.savedRoute` 恢复记录仍保留；⑤ 截图 `Task10-saved-places-history.png`（Saved Places 列表，路线点位缺席、固定位置点位在场）与 `Task10-home-routes-icon.png`（HomeView 的 Routes 入口图标）均未截
- 已知风险：`startLocationSession` 的参数语义从「必有历史目标」变成「可选」，调用方若漏传会静默不写历史；当前只有三个调用点（固定位置、Apple walking、路线），均由本任务逐一核对
- 工作流：https://github.com/FaHits/Roam-Control/actions/runs/41195528908
- 下一步：在配对的真机上按上面 5 项与两张截图做验收，通过后由验收方把 Task 10 升为 `completed`；本任务不做 Task 11 的每 tick 持久化
- 更新时间：2026-10-31

### 2026-10-31 Task 16 实现记录：简体中文与语言切换

- 任务：Task 16 - 简体中文本地化与 Settings 语言切换
- 状态：`implemented_unverified`
- 分支与基线：`feat/manual-running-routes`，改动前 HEAD `d77bdaf`，工作树干净
- 语言机制：新增 `AppLanguage`（`system` / `english` / `simplifiedChinese`），选择存 `UserDefaults` 的 `appLanguage`，默认 `.system`。`.system` 删除 `AppleLanguages`；`.english` 写 `["en"]`；`.simplifiedChinese` 写 `["zh-Hans"]`。切换只写偏好并提示重启，不调用 `exit(0)`，当前界面不热切换；重启后 `Bundle.main` 按新语言加载
- 修改文件（生产代码）：`RoamControl/Features/Settings/AppLanguage.swift`（新增）、`RoamControl/Models/StringLocalization.swift`（新增，`String.localized` 走 `NSLocalizedString`）、`RoamControl/Features/Settings/SettingsView.swift`、`RoamControl/Models/AppPreferences.swift`、`RoamControl/Features/Home/{HomeView,StatusCard,MobileDataGuidanceView,SessionRecoveryView}.swift`、`RoamControl/Features/Map/{SavedPlacesView,ConnectionBadge,LocationSelectionCard,MapViewModel,WalkingRoutePlanner,WalkingRoutePreviewCard,WalkingSimulationController}.swift`、`RoamControl/Features/Onboarding/OnboardingView.swift`、`RoamControl/Features/Pairing/PairingSetupView.swift`、`RoamControl/Features/Routes/State/{RouteEditorModel,RouteLibraryModel,RouteSessionModel}.swift`、`RoamControl/Features/Routes/Views/{RouteRunCard,RouteRunSetupView}.swift`、`RoamControl/Features/Settings/{AboutRoamControlView,ConnectionHealthView,CoordinateDiagnosticsView}.swift`
- 新增资源：`RoamControl/Resources/Localizable.xcstrings`（`sourceLanguage` = `en`，609 个 key，每个 key 同时带 `en` 与 `zh-Hans`）、`RoamControl/Resources/InfoPlist.xcstrings`（`NSLocalNetworkUsageDescription`、`NSLocationWhenInUseUsageDescription` 两条中文）
- 工程与 CI：`project.pbxproj` 的 `knownRegions` 追加 `"zh-Hans"`，`developmentRegion` 仍为 `en`；两个 `.xcstrings` 位于 `RoamControl/Resources/`，由既有 `PBXFileSystemSynchronizedRootGroup` 自动进入 target；`.github/workflows/xcode-27.yml` 的 `test` job 在 `Run RoamControlTests` 之前插入 `Check localization catalogs`（`python3 scripts/check_localizations.py`）
- 脚本路径偏差：任务书写作 `Scripts/check_localizations.py`，仓库既有脚本目录是小写 `scripts/`，且 GitHub runner 区分大小写，实际落地为 `scripts/check_localizations.py`，CI 调用同一路径
- 检查脚本：`scripts/check_localizations.py`（仅 Python 标准库）。校验 `sourceLanguage`、每个 key 的 `en`/`zh-Hans` 非空、plural 变体逐个校验、两种语言的格式占位符集合一致、Swift 里 `String(localized:)` 与 `NSLocalizedString(` 引用的 key 必须存在于 catalog。本地输出：`Localizable.xcstrings: 609/609 keys translated (100.0%)`、`InfoPlist.xcstrings: 2/2 keys translated (100.0%)`、`All 611 keys have non-empty zh-Hans values.`，`exit=0`
- 动态字符串处理：UI 层 computed `String` 保持返回类型，在返回处用 `String(localized:)`，插值改用 `String(format: String(localized: "…%@/…%lld…"), …)`；跨层传入的显示文本在渲染边界加 `.localized`；`AppLanguage.title` 返回 `LocalizedStringKey`；`ModeSelection`、`ProbeCandidate` 等 rawValue 用于持久化或匹配的枚举一律不改 rawValue，只在显示处本地化
- Services 层刻意不改英文原文：`UsageAnalyticsService.classify` 用 `switch message` 精确匹配约 60 条英文错误原文，`LocalDeviceSessionCoordinator.isRecoverableTunnelConnectionFailure` 用 `localizedCaseInsensitiveContains`，`AppModel` 用 `contains("localdevvpn")` / `contains("prepare")`，`LocationSelectionCard.shouldOfferLocalDevVPN` 用 `localizedCaseInsensitiveContains("Install LocalDevVPN")`。这些英文只作为 key 进入 catalog，显示点用 `NSLocalizedString` 查表，源码字面量保持原样，行为不变
- 刻意不翻译：纯单位与格式串（`%.0f m`、`%.2f km`、`%.1f m/s`、`%.0f spm`、`%.0f%%`、`%d:%02d`、`%d:%02d:%02d`、`—`、`0 m`、` mi`、`%lld yd`）、`"\(title), \(value)"` 形式的 accessibility 拼接、`ROAM CONTROL` 品牌字、`AppleLanguages`/`CFBundle*`/telemetry 事件名/URL/`Probe (Debug)` 等内部标识；`CFBundleDisplayName` 保持 `Roam Control`，未进入 catalog
- CI 调试探针保持：`CoordinateDiagnosticsView.swift` 中的字面量 `Probe (Debug)` 未被移到 catalog，`unsigned-ipa-debug` 的 `strings -a | grep -cF 'Probe (Debug)'` 仍然有命中
- 新增测试：`RoamControlTests/AppLanguageTests.swift` 3 例，使用独立 `UserDefaults` suite：`testSimplifiedChineseWritesSimplifiedChineseIdentifier`（`["zh-Hans"]`）、`testEnglishWritesEnglishIdentifier`（`["en"]`）、`testSystemRemovesOverride`（移除 `AppleLanguages`）。仓库内 `func test` 计数 116 → 119
- 测试写法修正：首次 CI（run `41198446319`）唯一失败为 `AppLanguageTests.testSystemRemovesOverride`，原因是 `UserDefaults.object(forKey: "AppleLanguages")` 会回落到系统域，删除后仍返回系统值，断言 nil 永不成立。改为读取该 suite 自身域（`persistentDomain(forName:)["AppleLanguages"]`）后通过；`AppLanguage.apply` 逻辑未改
- 版本：未改动，仍 `0.9.2` / `61`
- 已验证（GitHub Actions，本机为 Windows 无法本地运行）：run [41199478310](https://github.com/FaHits/Roam-Control/actions/runs/41199478310) 全绿 —— `Check localization catalogs` 通过、`test` 8m31s（`** TEST SUCCEEDED **`，119 例通过、0 失败，含 `Build Debug` 与 `Build Release`）、`unsigned-ipa` 1m16s、`unsigned-ipa-debug` 40s（`Probe (Debug)` 探针仍命中）。产物：`RoamControl-unsigned-ipa`（artifact `13042680271`，3,138,658 字节）、`RoamControl-unsigned-debug-ipa`（artifact `13042600461`，4,707,768 字节）
- 仍未验证：`xcstrings` 编译期是否存在重复 key 警告（构建通过但未逐条查看警告）；SwiftUI 自动提取的 key 与 catalog 是否存在大小写或占位符不匹配（脚本只覆盖显式引用与 catalog 自身一致性）
- 未验证内容（真机）：Settings > Language 切换后重启是否整体生效、Home / Saved Places / Settings / My Routes / Route Editor / Route Run / Recovery / 弹窗与错误提示是否全中文且无截断、切回 English 与 Follow System 是否恢复、`NSLocalNetworkUsageDescription` 与 `NSLocationWhenInUseUsageDescription` 是否显示中文
- 未做回归（静态检查，运行时未验证）：Task 15 的 `DeviceCoordinateAdapter.live` 取 `.gcj02ToWGS84`，Task 10 的路线历史逻辑与 `startLocationSession` 签名未改，本轮改动只触及字符串与渲染层
- 已知风险：`String.localized` 对用户数据（地点名、路名、路线名）也做一次 catalog 查表，未命中时回退原文，若某条用户数据恰好与某个 key 相同会被翻译成中文；`diagnosticsText` 复制出的诊断报告沿用本地化后的状态词，未拆出英文专用副本
- 下一步：只剩真机验收 —— 安装 Release 产物，按 Settings > Language 三项切换（简体中文 / English / Follow System）各重启一次，检查 Home、Saved Places、Settings、My Routes、Route Editor、Route Run、Recovery、全部弹窗与错误提示，并按任务书截 7 张图；顺带回归 Task 10 历史与 Task 12 Routes 图标。验收通过后由验收方把本任务升为 `completed`
- 更新时间：2026-10-31
### 2026-10-31 Task 14 最终验收：0.10.0 / 62（已被 2026-11-01 记录取代）

- 取代说明：本节状态改为 `superseded`，只保留当时证据；当前有效状态与真机清单见文末 2026-11-01 记录与交接文档第 7 节

- 任务：Task 14 - 完整验证（0.10.0 / 62 最终验收）
- 状态：`superseded`
- 分支与基线：`feat/manual-running-routes`，验证前 HEAD `ff1d3bc`，与 `fork` 远端一致，工作树干净；整体差异基线 `b68dac0`
- 版本：`MARKETING_VERSION = 0.10.0`、`CURRENT_PROJECT_VERSION = 62`，Debug 与 Release 两个配置都改（`project.pbxproj:248`、`:253`、`:273`、`:278`）。静态确认：`rg -c "= 61;"` 与 `rg -c "0\.9\.2"` 在 pbxproj 内均 0 命中，`CURRENT_PROJECT_VERSION = 62;` 与 `MARKETING_VERSION = 0.10.0;` 各 2 处。本机为 Windows 无 `xcodebuild`，`-showBuildSettings` 没有运行；版本值由 pbxproj 静态检查与 `PYTHONUTF8=1 python scripts/test-release-invariants.py`（输出 `Build 62 release, scheduler and consent-gate source checks passed`，exit 0）覆盖，`scripts/test-release-invariants.py` 的 3 处版本断言随之更新
- 文档状态修正：`DeviceCoordinateAdapter.live` 的三处过期描述（`:13`、`:86`、`:765`）由 `.none` 改为 `.gcj02ToWGS84`；`rg -n "保持 \.none|仍为 \.none" Documentation` 0 命中（exit=1）；代码侧确认 `RoamControl/Services/Location/DeviceCoordinateAdapter.swift:37` 为 `static let live = DeviceCoordinateAdapter(conversion: .gcj02ToWGS84)`，与 Task 15 真机 A/B 结论一致
- 修改文件：`RoamControl.xcodeproj/project.pbxproj`（4 行版本号）、`scripts/test-release-invariants.py`（3 处版本断言）、`Documentation/ImplementationStatus.md`。未改 `RoamControl/` 与 `RoamControlTests/`、未改 `.github/workflows/xcode-27.yml`：本轮只验证，没有发现真实缺陷，因此没有 `fix` 提交，也没有新增测试
- 提交：`fe01fb9`（`chore(release): bump to 0.10.0 build 62`）、本文档提交（`docs(routes): record Task 14 verification`）
- 自动化门禁（本机 Windows 可跑部分）：`python scripts/check_localizations.py` → `609/609` + `2/2`，`All 611 keys have non-empty zh-Hans values.`，exit 0；`rg -n "import (SwiftUI|MapKit)|AppModel" RoamControl/Features/Routes/Core RoamControl/Features/Routes/Models` 无输出 exit=1；`rg -n "MKRoute|MKMapPoint|MKPolyline"` 同两目录无输出 exit=1；同一目录 `rg -c "import Foundation"` 命中 7 个文件，证明不是空扫；`rg -n "point\.topleft\.down\.to\.point\.right\.curvepath" RoamControl` 0 命中（任务书该串少写 `bottom`，实际在用的 `point.topleft.down.to.point.bottomright.curvepath` 仍有 2 处：`RoamControl/Features/Routes/Views/RouteSymbol.swift:6`、`RoamControl/Features/Map/WalkingRoutePreviewCard.swift:118`，属 Task 12 已修的正确符号名，未改动）
- CI 结果：run [41203728405](https://github.com/FaHits/Roam-Control/actions/runs/41203728405)，head `fe01fb9`，`conclusion=success`。`test` job 13:02:12Z→13:11:53Z：`Check localization catalogs` 通过、119 行 `Test case … passed`、0 行 `failed`、`** TEST SUCCEEDED **`、`Build Debug` 与 `Build Release` 均 `** BUILD SUCCEEDED **`。`unsigned-ipa` 13:11:55Z→13:12:51Z success，artifact `RoamControl-unsigned-ipa` id `13043941317`，3,138,686 字节。`unsigned-ipa-debug` 13:11:56Z→13:12:30Z success（`Probe (Debug)` self-check 命中），artifact `RoamControl-unsigned-debug-ipa` id `13044041974`，4,707,863 字节
- 新增测试：0。119 用例全部为既有用例（Task 15 后由 98 增至 113，Task 10/16 各补用例后为 119）
- 真机与模拟器验收：当时全部 `not_run`（本机 Windows，无 `xcodebuild` / `xcrun` / `simctl` / `idevice_id`，无模拟器与配对真机）；这段逐项清单已由交接文档第 7 节 19 行取代，不再在此重复
- 状态判定：自动化门禁 + 单元测试 + Debug + Release 全过，但真机手工清单与截图未做，按任务书不得写 `completed` → Task 14 保持 `implemented_unverified`。Task 15 / 10 / 12 / 16 同样保持 `implemented_unverified`，未因 CI 绿而升级；Task 13 保持 `completed`（其真机强制退出恢复项仍属未验证）
- 已知风险：版本号已标 0.10.0 / 62，但该版本没有任何真机运行证据，产物 IPA 只有 14 天保留期；版本升级本身没有改动任何路线、恢复、设备会话代码，所以 CI 绿不代表四项真机验收已过
- 当时设想的下一步（历史陈述）：按顺序补真机项 —— Task 15 坐标与 Stop、Task 10/11/12/13 路线系统、Task 16 语言；这些项已并入交接文档第 7 节 19 行，由用户统一执行
- 更新时间：2026-10-31

### 2026-10-31 Task 9R 返工记录：删除动画与微信输入法重命名

- 任务：Task 9R - 路线库删除动画与微信输入法重命名
- 状态：`implemented_unverified`（代码与 CI 通过；真机 6 项截图未做）
- 分支与基线：`feat/manual-running-routes`，返工前 HEAD `0f63d1f195eae66da0b193d862e7bef75b1dddb5`，版本仍 `0.10.0` / `62`；改前工作树只有交接文档与状态文件待提交
- 提交：`ad08d1ad5dff2f628bd7e1538b719481da85da7e`（`docs(handoff): record the 2026-10-31 rework handoff`，单独提交既有交接文档）、`2be0f2510eabaaf89e35b11ee2faced135fe5fa6`（`test(routes): cover route name normalization`，红灯）、`b50fe688697482dd9072565bcc120ea7c6b4c310`（`fix(routes): stabilize delete swipe and accept marked rename text`，绿灯）、本文档提交（`docs(routes): record Task 9R rework`）
- 修改文件：新增 `RoamControl/Features/Routes/State/RouteNameValidator.swift`；修改 `RoamControl/Features/Routes/State/RouteLibraryModel.swift`、`RoamControl/Features/Routes/Views/RouteLibraryView.swift`、`RoamControlTests/RouteLibraryModelTests.swift`、`Documentation/ImplementationStatus.md`。未改 `RouteRunSetupView.swift`、`RouteEditorView.swift`、`AppModel.swift`、`DeviceCoordinateAdapter.swift`、`project.pbxproj`；`RoamControl/Services/Location/DeviceCoordinateAdapter.swift:37` 仍为 `.gcj02ToWGS84`
- 删除动画（Fix A）：根因是 `RouteLibraryView` 的 swipeActions 使用了 `Button("Delete", role: .destructive)`，SwiftUI 在点击 destructive swipe action 时立即播放行移除/折叠动画，即使数据只是标记为待删除。现改为普通 `Button("Delete") { routePendingDeletion = route }.tint(.red)`，不提前调用 `model.delete`，也不改 `RouteLibraryModel.delete(id:)` 语义；确认弹窗里的 `Delete Route` 仍保留 `role: .destructive`，只负责按钮样式。因此确认框打开期间列表数据与行数不变，取消不快排，确认后才删除
- 重命名（Fix B）：根因是 Rename 的可用状态绑定 `renameText`，微信输入法未提交的 marked text 不进入 SwiftUI binding，字段显示“神秘”时 binding 仍为空，按钮被 `trimmingCharacters(in: .whitespacesAndNewlines).isEmpty` 置灰。现改为自定义 `RouteRenameSheet`：Rename 按钮始终可点，点击时通过 `RouteRenameTextFieldHandle.currentText` 读取 `UITextField` 的 `text(in: beginningOfDocument..<endOfDocument)`（包含 marked text），再交给 `RouteNameValidator` 校验；有效名称才写入。Apple 输入法走同一 `UITextField`，行为未改
- 名称规则：新增纯函数 `RouteNameValidator.normalizedName(from:)`，先 `trimmingCharacters(in: .whitespacesAndNewlines)`，空串返回 `nil`，否则返回 trim 后的值；`RouteLibraryModel.upsert` 改为复用该函数，模型与视图不再各自复制规则。空名称或纯空白点击 Rename 时按钮保持可点，但显示 `Route name cannot be empty.` 且不写入路线，不出现空名路线
- 新增测试：`RoamControlTests/RouteLibraryModelTests.swift` 增加 4 例 —— `testNormalizedNameRejectsEmptyName`、`testNormalizedNameRejectsWhitespaceAndNewlines`、`testNormalizedNameAcceptsOrdinaryName`、`testNormalizedNameTrimsSurroundingWhitespace`。测试总数 119 → 123，0 失败；119 条既有测试全部保留并通过
- 红灯证据：run `41214550560`（head `2be0f25`，job `124576223538`）`Run RoamControlTests` 失败，`RouteLibraryModelTests.swift:158:22: error: cannot find 'RouteNameValidator' in scope`（4 处引用），说明测试先于实现存在
- 绿灯证据：run [41214754177](https://github.com/FaHits/Roam-Control/actions/runs/41214754177)（head `b50fe68`）`conclusion=success`，三个 job 全 success：`test` 8m56s（`RouteLibraryModelTests` 16 例通过，全量 123 例通过 / 0 失败，`** TEST SUCCEEDED **`，`Build Debug` 与 `Build Release` 均 `** BUILD SUCCEEDED **`，`Check localization catalogs` 通过）、`unsigned-ipa` 43s、`unsigned-ipa-debug` 42s。唯一注解是 actions/checkout@v4 的 Node.js 20 弃用提示
- 产物：Release IPA artifact `RoamControl-unsigned-ipa` id `13048490403` / 3,146,349 字节；Debug IPA artifact `RoamControl-unsigned-debug-ipa` id `13048205807` / 4,731,525 字节
- 本地无法验证：本机为 Windows，无 `xcodebuild`、无 iOS 模拟器、无配对真机；测试、Debug/Release 构建与产物全部来自 `xcode-27` GitHub Actions，本文件不声称本地通过
- 未验证项（真机，逐项 `not_run`）：① 右滑 Delete 后等待 2 秒，确认框打开期间行仍在原位、不折叠、不塌陷；② 点 Cancel 后行仍在、顺序与滚动位置不变；③ 再次 swipe + 确认后路线消失，其余路线顺序稳定；④ 微信输入法在空字段输入“神秘”，marked text 未提交时 Rename 仍可点，点击后列表显示“神秘”；⑤ Apple 输入法重复同样重命名，行为不回归；⑥ 空名称或纯空白时 Rename 可点但点击不写入，并显示 `Route name cannot be empty.`。对应截图 `Task9R-delete-hold.png`、`Task9R-delete-cancel.png`、`Task9R-delete-confirm.png`、`Task9R-wechat-ime.png`、`Task9R-apple-ime.png`、`Task9R-empty-name.png` 均未产出
- 自动化边界：删除动画与 UIKit `UITextField` marked text 读取无法在当前 Windows 环境单元测试，只能真机验证；本次 XCTest 只覆盖 `RouteNameValidator` 的 4 条纯函数规则，不构成 UI 证据
- 已知风险：`text(in: beginningOfDocument..<endOfDocument)` 在第三方输入法 marked text 阶段的返回值依赖系统文本输入栈，已按最接近输入法的 API 取值，但 iOS 27 真机未跑；若某输入法不把 marked text 暴露给 `UITextInput`，仍可能读不到未提交文字，需要真机确认
- 下一步：安装 Release 产物到已配对真机，准备至少 3 条路线，按上面 6 项完成截图并把 Task 9R 升为 `completed`；Task 14 继续保持 `fail`，返工顺序按交接文档进入 Task 19
- 更新时间：2026-10-31

### 2026-11-01 Task 19 / 19F 完成记录：移除匿名统计/共享数据全链路

- 任务：Task 19 - 移除匿名统计/共享数据全链路；Task 19F - 收尾补正（删死回调、孤儿本地化 key、证据链对齐最终 CI）
- 状态：`implemented`（CI 三 job 全绿 + 两端 unsigned IPA 产物齐备；真机表现登记在交接文档第 7 节，随 Task 14 批量验证）
- 分支与基线：`feat/manual-running-routes`，Task 19 改前 HEAD `88170fede50219a78ebb99e6e2f0f21e40ceeee9`，Task 19F 起点 `9a9cf784e7f7150cb8f726fc6ad51329b27312ae`；版本仍 `0.10.0` / `62`（`project.pbxproj:248`、`:253`、`:273`、`:278`）；`RoamControl/Services/Location/DeviceCoordinateAdapter.swift:37` 仍为 `static let live = DeviceCoordinateAdapter(conversion: .gcj02ToWGS84)`，本任务未触碰坐标代码
- 提交：
  - `4b64a3850c39b2e141d75b9161b14bdc62f1dfe6`（`refactor(privacy): remove anonymous usage statistics end to end`）
  - `9a9cf784e7f7150cb8f726fc6ad51329b27312ae`（`docs(privacy): record Task 19 removal`）
  - `2d48c6e7cc399f94ebb390dd91c167a6ad782012`（`refactor(diagnostics): drop dead failure callbacks and orphan privacy key`）
  - 本文档提交（`docs(privacy): align Task 19 evidence with final CI`）
- 删除文件：`RoamControl/Services/UsageAnalyticsService.swift`（643 行）、`RoamControl/Features/Settings/UsageStatisticsPrivacyView.swift`（71 行）
- 新增文件：`RoamControl/Services/FailureDiagnostics.swift`。Task 19 建文件时保留四个诊断类型，Task 19F 复核 `rg -n "failureSnapshot\(|FailureDiagnosticSnapshot"` 无输出后收敛为三个：`FailureStage`、`FailureDisposition`、`SchedulerFailureReason`。`FailureDiagnosticSnapshot` 只服务被删的死回调，连同两个私有 `failureSnapshot(...)` 工厂一并移除；文件现 131 行，头部注明不携带坐标、搜索、配对数据与错误原文，`import Foundation` 只剩 `NSError` 依赖
- 修改文件（Task 19）：`RoamControl/App/AppModel.swift`（-153 行：删 `sharesAnonymousUsageStatistics`、`setSharesAnonymousUsageStatistics`、`anonymousUsageStatisticsKey`、`pendingSessionAnalyticsEvent`、`usageAnalytics`、`initialUsageStatisticsPreference`、`analyticsEvent(forLocationStartFailure:)`、`appBecameActive()` 与全部上报调用）、`RoamControl/App/RoamControlApp.swift`（删 `scenePhase` 环境值与 `appBecameActive()` 调用）、`RoamControl/Features/Settings/SettingsView.swift`（删整段 Privacy Section 与 `anonymousUsageStatisticsBinding`）、`RoamControl/Features/Onboarding/OnboardingView.swift`（删共享卡与第 4 页）、`RoamControl/Services/Tunnel/LocalDeviceSessionCoordinator.swift`（-22 行：删 `onBackgroundEvent`、`onConnectionEvent`、`retryTelemetry` 与 6 处上报点）、`RoamControl/Services/BackgroundLocationKeepAlive.swift`（删已成为统计专用钩子的 `onChange`）、`RoamControl/Resources/Localizable.xcstrings`（-4 key / -64 行）、`RoamControl/Resources/PrivacyInfo.xcprivacy`（`NSPrivacyCollectedDataTypes` 变空数组）
- 修改文件（Task 19F，纯删除 86 行、无新增）：`LocalDeviceSessionCoordinator.swift` -18 行（删 `var onRecoveryNeeded`、`var onFailure`、私有 `failureSnapshot(...)` 与 3 处自调用）、`RoamControl/Services/Pairing/OnDevicePairingCoordinator.swift` -15 行（删同名 `var onFailure`、私有 `failureSnapshot(...)` 与 1 处自调用）、`RoamControl/Services/FailureDiagnostics.swift` -37 行、`Localizable.xcstrings` -16 行（删孤儿 key `Privacy`）
- 死回调判定：`rg -n "onFailure|onRecoveryNeeded" RoamControl RoamControlTests` 复核后，三个回调无任何外部赋值，只有定义与协程内部自调用；删除后剩余命中均为无关同名项——`PairingBonjourPublisher` 的 `onFailure: (() -> Void)?`（`OnDevicePairingCoordinator.swift:364` 定义、`:400` 调用、`:80` 赋值，mDNS 发布失败，必须保留）、`reportSchedulerObservationFailure()` / `isRecoverableTunnelConnectionFailure(_:)` 属于子串误命中、`RouteGeometry.swift:62` 的 `preconditionFailure`
- 失败诊断保留路径：`lastFailureStage`、`lastFailureDisposition`、`schedulerFailureReason` 的赋值全部保留（`LocalDeviceSessionCoordinator.swift:56-57`、`:538-540`、`:669-672`；`OnDevicePairingCoordinator.swift:38`），`ConnectionHealthView.swift:324-332` 的诊断文本继续读取这些属性快照；`taskConfigurationStatus` / `taskRegistrationStatus` 继续供 `backgroundTelemetry`（`LocalDeviceSessionCoordinator.swift:74`）使用
- Onboarding 选择：删整页，"Private by design" 第 4 页整页只为共享卡服务；页数由 `pages.count` 派生（4 → 3），TabView、页点与 `Page N of M` 无障碍标签自动跟随，无需额外改动
- 保留决定：`BackgroundSessionTelemetry`（`BackgroundLocationKeepAlive.swift:5`）保留为后台调度诊断，`LocalDeviceSessionCoordinator.swift:70-71` 的 `backgroundTelemetry` 与 `ConnectionHealthView.swift:339` 继续使用；`PrivacyInfo.xcprivacy` 的 `NSPrivacyAccessedAPICategoryUserDefaults` / `CA92.1` 保留
- 验收命令与结果：`rg -n "UsageAnalytics|sharesAnonymousUsageStatistics|AnonymousUsage|What Is Shared|Share Anonymous" RoamControl RoamControlTests` exit 1（0 命中）；`rg -n "Telemetry"` 只剩上述 4 处 `BackgroundSessionTelemetry`；`rg -n "failureSnapshot\(|FailureDiagnosticSnapshot"` exit 1；`rg -n '"Privacy"' RoamControl --glob '!*.xcstrings'` exit 1；`rg -n "UsageStatisticsPrivacyView" RoamControl RoamControlTests` 无输出；`rg -n "ProductInteraction|DeviceID|PurposeAnalytics" RoamControl/Resources/PrivacyInfo.xcprivacy` exit 1；`python -c "plistlib.load(...)"` 输出 `NSPrivacyCollectedDataTypes: []`；`rg -n "seanhowarthdev/Roam-Control" RoamControl` 仍为既有 3 处（`ReleaseUpdateChecker.swift:36`、`SettingsView.swift:5`、`:8`）
- 本地化：`python scripts/check_localizations.py` → `Localizable.xcstrings: 604/604 keys translated (100.0%)`、`InfoPlist.xcstrings: 2/2`、`All 606 keys have non-empty zh-Hans values.`，exit 0。Task 19 删 4 个统计相关 key（611 → 607），Task 19F 删孤儿 key `Privacy`（607 → 606）
- 测试：总数 123 / 删除 0 / 新增 0 / 失败 0。`RoamControlTests` 内 0 处统计关键词命中，没有仅测统计的用例；Task 19F 只删死代码与孤儿 key，未新增或用例改写断言，测试数保持 123
- CI（最终代码状态）：run [41223835438](https://github.com/FaHits/Roam-Control/actions/runs/41223835438)（head `3ffd8341b34ef6fc92ebdd0e3f4a8c7164e24cda`，本文档提交的父提交）`conclusion=success`；`test` success（123 个 Test case 全 passed，`** TEST SUCCEEDED **`，`Build Debug` 与 `Build Release` 均 `** BUILD SUCCEEDED **`，`Check localization catalogs` 通过）、`unsigned-ipa` success、`unsigned-ipa-debug` success
- 产物（最终代码状态）：Release IPA artifact `RoamControl-unsigned-ipa` id `13050992072` / 3,101,262 字节；Debug IPA artifact `RoamControl-unsigned-debug-ipa` id `13051995426` / 4,623,883 字节；两者均为 unsigned，供 Task 14 装机。字节取自 `gh api repos/FaHits/Roam-Control/actions/artifacts/<id> --jq '.size_in_bytes'`，不是手抄
- 证据口径：`Documentation/` 是 `RoamControl` target 之外的纯文档，其后任何仅文档的提交都会触发新的 run 但不改构建输入，unsigned IPA 每次重新打包有 ±几字节漂移；因此本记录固定为「最终代码改动所在的 run」，即本文档提交的父提交（`3ffd834`），后续纯文档提交的 run 只证明测试与构建仍全绿，不重写产物字节
- 过程记录（不是最终 head 的证据，仅保留排查轨迹）：run [41223326114](https://github.com/FaHits/Roam-Control/actions/runs/41223326114)（head `64a7a85`）三 job success，Release artifact `13050743653` / 3,101,247 字节、Debug `13051035585` / 4,623,875 字节；run [41222309124](https://github.com/FaHits/Roam-Control/actions/runs/41222309124)（head `2d48c6e`）三 job success，Release artifact `13050857137` / 3,101,249 字节、Debug `13050633591` / 4,623,877 字节（被文档提交 run 取代）；run [41219908233](https://github.com/FaHits/Roam-Control/actions/runs/41219908233)（head `4b64a38`）三 job success，Release artifact `13050340159` / 3,103,305 字节、Debug `13049224691` / 4,631,895 字节；run [41220878795](https://github.com/FaHits/Roam-Control/actions/runs/41220878795)（head `9a9cf78`）三 job success，Release artifact `13050520928` / 3,103,325 字节、Debug `13050391189` / 4,631,883 字节
- 本地无法验证：本机为 Windows，无 `xcodebuild`、无 iOS 模拟器、无配对真机；测试、Debug/Release 构建与产物全部来自 `xcode-27` GitHub Actions
- 未验证项（真机，沿用 Task 19 登记，未新增）：① Settings 页不再出现 Privacy 分区与 Share Anonymous Usage Statistics 开关；② Onboarding 只有 3 页且页点为 3，第 4 页 Private by design 不存在；③ 配对失败与后台调度失败时 Connection Health 仍能显示失败阶段与调度原因（属性快照路径未破坏）
- 下一步：按 `Documentation/Handoffs/2026-10-31-rework-handoff.md` 第 3 节进入 **Task 16R**，顺序为 9R → 19 → 16R → 20 → 17 → 18 → 14
- 更新时间：2026-11-01

### 2026-11-01 Task 16R 实现记录：语言弹窗与剩余英文残留

- 任务：Task 16R - 语言与英文残留返工（Task 16 的返工任务）
- 状态：`implemented`（按交接文档约定，Task 14 批量真机验收前不得标 `completed`）
- 分支与基线：`feat/manual-running-routes`，起点 HEAD `f6b990b`；代码提交 `b7797d1`
- 逐项结果

| 项 | 结论 | 证据 |
| --- | --- | --- |
| 1.1 只在生效语言真正改变时弹窗 | pass | `RoamControl/Features/Settings/AppLanguage.swift:36-70` 的 `effective(from:systemIdentifiers:)` / `effective(overrideIdentifiers:systemIdentifiers:)` / `matching(identifiers:)` / `requiresRestart(comparedTo:)`；`SettingsView.swift:49-53` 的 `onChange` 先 `guard newLanguage.requiresRestart(comparedTo: AppLanguage.effective())` 再 `apply()` 与弹窗 |
| 1.2 Onboarding 三页文案 | pass | `OnboardingView.swift:188-205` 的 `OnboardingPage.title/message` 与 init 参数均为 `LocalizedStringKey`；6 条文案 `:210-223`；页点与 `Page N of M` 仍由 `pages.count` 派生（`:65-76`、`:98`） |
| 1.3 PairingSetupView 行文案 | pass | `PairingSetupView.swift:240` `requirementRow(number:text: LocalizedStringKey)`、`:257` `instructionRow(_ text: LocalizedStringKey)`、`:271-273` `pairingDetail(title: LocalizedStringKey, value: String, ...)`；`value`（指纹、日期）仍 `String` |
| 1.4 连接检查页不再渲染内部英文状态 | pass | `ConnectionHealthView.swift:36-40` 改为 `Text(Self.restorationText(for:))`；映射函数 `ConnectionHealthView.swift:132-149` 覆盖四个内部状态并原样透传未知值；`LocalDeviceSessionCoordinator.swift:79/159/330/650/656` 的内部英文取值未改；`"None"` 显示点 `:43`、`:158` 改 `String(localized: "None")`；`healthRow(title: LocalizedStringKey)`（`:277`） |
| 1.5 白名单保持英文 | pass | `ROAM CONTROL`、`LocalDevVPN`、`GCJ-02 → WGS-84`、`WGS-84 → GCJ-02`、罗盘 `N/E/S/W` 未进 catalog |

- 设计要点（复核用）：iOS 只在启动时解析 `Bundle.main` 本地化，因此「当前生效语言」不能从 bundle 读取，只能由 `AppleLanguages` 覆盖值推导；没有覆盖时用系统偏好列表，映射规则为 `zh-hans*`/`zh-cn`/`zh-sg` → 简体中文，`en*` → English，其它 → `system`。因此「系统英文 + 选择 English」判为未变更，不写 key、不弹窗。
- 本地化资源：`RoamControl/Resources/Localizable.xcstrings` 604 → 609 key，新增 `Not requested`、`Stop requested; awaiting device response`、`Stop not confirmed; real location unverified`、`Stop command acknowledged; real location reacquisition unverified` 四条恢复状态文案与 `%@, %@`（辅助功能标签的逗号）；`InfoPlist.xcstrings` 仍 2 条，合计 611
- 检查脚本：`python scripts/check_localizations.py` → `609/609 keys translated (100.0%)`、`2/2 keys translated (100.0%)`、`All 611 keys have non-empty zh-Hans values.`，exit 0；CI 上同一输出（`Check localization catalogs` 步骤）
- 静态证据：`rg -n 'title: "[A-Za-z]|message: "[A-Za-z]' RoamControl --glob '*.swift'` 在 Onboarding 与 PairingSetup 的命中均为已声明为 `LocalizedStringKey` 的字面量（源码类型证据即上表 1.2 / 1.3），其余命中为既有的 `.localized` 或 `LocalizedStringKey` 调用；`rg -n ""None"" RoamControl --glob '*.swift'` 可见 UI 归零，剩余 7 处全在 `diagnosticsText` 与 `permittedBackgroundTasks` 默认值内
- 测试：新增 6 例（`testEffectiveLanguageFollowsSystemPreferenceWhenNoOverride`、`testEffectiveLanguagePrefersStoredOverride`、`testEnglishSelectionUnderEnglishSystemIsNotAChange`、`testSelectingAnotherLanguageRequiresRestartAndWritesOverride`、`testSelectingCurrentSimplifiedChineseIsNotAChange`、`testRestorationStatusMapsToNonEmptyCopy`）。基线 123 + 新增 6 = 129，CI 实测 129 例通过、0 失败
- CI：run [41227597504](https://github.com/FaHits/Roam-Control/actions/runs/41227597504)（head `b7797d1`）—— `test` 5m48s（`** TEST SUCCEEDED **`，含 `Build Debug` / `Build Release`）、`unsigned-ipa` 1m37s、`unsigned-ipa-debug` 56s，`Check localization catalogs` 通过
- 产物（该 run 实测）：`RoamControl-unsigned-ipa` artifact `13052626294`，3,104,532 字节；`RoamControl-unsigned-debug-ipa` artifact `13053106037`，4,626,145 字节。IPA 未签名，可自行签名用于 Task 14 装机
- 版本：未改动，仍 `0.10.0` / `62`（`project.pbxproj:248/253/273/278`）
- 坐标未动：`RoamControl/Services/Location/DeviceCoordinateAdapter.swift:37` 仍 `.gcj02ToWGS84`，该文件不在本次 diff 内
- 保留英文及理由：`diagnosticsText`（`ConnectionHealthView.swift:325-` 起）整段保持英文——它是开发者诊断快照，供贴到 issue 里比对，翻成中文会让同一份报告在不同语言下无法对照；其可见入口「Run Connection Check」按钮、`Copy Diagnostics` 等文案已本地化。另：单位与格式串（`%.0f m`、`%.1f m/s`、`%.0f spm` 等）、`AppleLanguages` 等内部标识、`Probe (Debug)` 仍保持英文
- 真机待验（登记到交接文档第 7 节，随 Task 14 批量验证）：① 英文系统下 Settings → Language 选 English 不弹重启提示；② 切到简体中文弹一次，重启后界面中文；③ 重启后再进该页不重复弹窗；④ 中文下 Onboarding 3 页全中文、页点 3 个；⑤ 中文下配对设置页 Requirements/Instructions 全中文，指纹与日期正常；⑥ 中文下 Connection Health 的 Restoration 行与 Place 空值不再是英文 `Not requested` / `None`
- 下一步：按交接文档第 3 节进入 **Task 20**（更新/反馈仓库地址）
- 更新时间：2026-11-01

### 2026-11-01 Task 20 实现记录：更新/反馈仓库地址

- 任务：Task 20 - 更新/反馈仓库地址（App 面向用户的仓库地址统一到 `FaHits/Roam-Control`，无 release 时明确提示「未发布」）
- 状态：`implemented`（按交接文档约定，Task 14 批量真机验收前不得标 `completed`）
- 分支与基线：`feat/manual-running-routes`，起点 HEAD `3ef5fa7abc284046889913a2d6869b021381f939`，代码提交 `c75f2b0a49085b8346caa342c71bdb5ab8202ec0`（`feat(settings): point feedback and update checks at the fork repository`）
- 逐项结果

| 项 | 结论 | 证据 |
| --- | --- | --- |
| 1.1 统一仓库常量 | pass | `RoamControl/Services/AppRepository.swift:6` `owner = "FaHits"`、`:7` `repo = "Roam-Control"`、`:9-11` `webURL`、`:13-15` `latestReleaseAPIURL`、`:18-22` `issuesURL(template:)`（`URLComponents` 拼 query）；`SettingsView.swift:4-5` 与 `ReleaseUpdateChecker.swift:35` 均只引用常量 |
| 1.2 反馈入口指向目标仓库 | pass | `SettingsView.swift:4` `bugReportURL = AppRepository.issuesURL(template: "bug_report.yml")`、`:5` `featureRequestURL = AppRepository.issuesURL(template: "feature_request.yml")`；`Report a Bug`（`:119-121`）、`Request a Feature`（`:123-125`）文案与布局未改 |
| 1.3 无 release 时明确提示 | pass | `ReleaseUpdateChecker.swift:49-64` 的 `result(statusCode:body:)`：非 200 时 404 → `.noPublishedRelease`、其他 → `.unavailable`；`SettingsView.swift:361-364` 把 `.noPublishedRelease` 与网络失败分开 catch；`SettingsView.swift:337-339` 文案 `This repository has no published release yet.` /「该仓库尚未发布版本。」；无任何上游兜底路径 |
| 1.4 为可测性加最小接缝 | pass | `ReleaseUpdateChecker.swift:34-40` `latestRelease()` 只发请求后调用 `Self.result(...)`；`static func result(statusCode: Int, body: Data) throws -> PublishedRelease`（`:49`）为唯一纯函数接缝，未引入协议、容器或 mock 框架 |

- 新增文件：`RoamControl/Services/AppRepository.swift`（24 行）、`RoamControlTests/ReleaseUpdateCheckerTests.swift`（6 例 91 行）
- 修改文件：`RoamControl/Features/Settings/SettingsView.swift`（-8/+3 行）、`RoamControl/Services/ReleaseUpdateChecker.swift`（-10/+14 行）、`RoamControl/Resources/Localizable.xcstrings`（key 重命名 `No public GitHub release has been published yet.` → `This repository has no published release yet.`，zh-Hans 改为「该仓库尚未发布版本。」，6 行变更、key 总数不变）
- 测试：新增 6 例 `ReleaseUpdateCheckerTests`（`testIssueURLsPointAtForkRepositoryWithTemplate`、`testLatestReleaseAPIURLPointsAtForkRepository`、`testResultDecodesPublishedRelease`、`testResultFallsBackToTagWhenNameIsBlank`、`testResultMaps404ToNoPublishedRelease`、`testResultMapsOtherStatusCodesToUnavailable`）。基线 129 + 新增 6 = 135，CI 实测 135 个 `Test case ... passed`、0 failed
- 静态证据：`rg -n "seanhowarthdev/Roam-Control" RoamControl` exit 1（0 命中）；`rg -n "FaHits" RoamControl --glob '*.swift'` 只剩 `AppRepository.swift:7`；`rg -n "https://" RoamControl --glob '*.swift'` 只剩 `AppRepository.swift:11`、`:15`、`:18` 与既有两处 LocalDevVPN App Store 链接，无硬编码 issues/releases URL；`rg -n "noPublishedRelease" RoamControl` 命中 `ReleaseUpdateChecker.swift:15`、`:22`、`:54`、`:87` 与 `SettingsView.swift:337`、`:361`、`:362`；`rg -n "MARKETING_VERSION|CURRENT_PROJECT_VERSION" RoamControl.xcodeproj/project.pbxproj` 仍 `0.10.0` / `62`（`:248`、`:253`、`:273`、`:278`）；`git diff --stat` 不含 `DeviceCoordinateAdapter.swift`、`ChinaCoordinateTransform.swift`，`:37` 仍 `.gcj02ToWGS84`
- 本地化：`python scripts/check_localizations.py` → `Localizable.xcstrings: 609/609`、`InfoPlist.xcstrings: 2/2`、`All 611 keys have non-empty zh-Hans values.`，exit 0；CI `Check localization catalogs` 步骤输出相同
- CI：run [41231501665](https://github.com/FaHits/Roam-Control/actions/runs/41231501665)（head `c75f2b0a49085b8346caa342c71bdb5ab8202ec0`）`conclusion=success`；`test` success（`** TEST SUCCEEDED **`，`Build Debug` 与 `Build Release` 均 `** BUILD SUCCEEDED **`，135 例全 passed）、`unsigned-ipa` success、`unsigned-ipa-debug` success
- 产物（该 run 实测）：Release IPA artifact `RoamControl-unsigned-ipa` id `13053863895` / 3,105,244 字节；Debug IPA artifact `RoamControl-unsigned-debug-ipa` id `13054018030` / 4,628,549 字节；字节取自 `gh api repos/FaHits/Roam-Control/actions/artifacts/<id> --jq '.size_in_bytes'`。unsigned IPA 字节不可复现，记录的是该 run 实测值
- 后续文档提交 run [41232483028](https://github.com/FaHits/Roam-Control/actions/runs/41232483028)（head `7a11b73`，仅改本文件）三 job 同样 success，产物 3,105,231 / 4,628,548 字节；除本次共用的这段完成记录外无其他改动，`Documentation/` 变化不进入 IPA 打包输入，字节差异只是重新打包漂移
- 目标仓库现状：`gh release list -R FaHits/Roam-Control` 输出为空，`FaHits/Roam-Control` 当前没有任何已发布 release，因此真机上点 `Check for Updates` 走的是 `.noPublishedRelease` 分支（注意：GitHub 对「有仓库但无 release」返回 404，正好映射到该分支）
- 本地无法验证：本机为 Windows，无 `xcodebuild`、无 iOS 模拟器、无配对真机；测试、Debug/Release 构建与产物全部来自 `xcode-27` GitHub Actions
- 未验证项（真机，登记在交接文档第 7 节第 12–15 行，随 Task 14 批量验证）：① 中文下 Report a Bug 打开 `github.com/FaHits/Roam-Control/issues/new` 且模板为 bug_report；② Request a Feature 同仓库 feature_request 模板；③ Check for Updates 显示「该仓库尚未发布版本。」且不显示上游版本号；④ 断网后 Check for Updates 显示不可用文案、不崩溃
- 下一步：按交接文档第 3 节进入 **Task 17**（折返/往返次数）
- 更新时间：2026-11-01

### 2026-11-01 Task 17 实现记录：开放路线折返（单程趟数）

- 任务：Task 17 - 开放路线折返。开放路线可按「单程趟数」跑，偶数趟回到起点、奇数趟停在终点；闭环路线的 `laps` / `continuous` / `once` 行为与文案不变
- 状态：`implemented`（按交接文档约定，Task 14 批量真机验收前不标 `completed`）
- 分支与基线：`feat/manual-running-routes`，起点 HEAD `03f9a92`；代码提交 `20ef07f`（`feat(routes): run open routes out and back by trip count`）、测试提交 `76d41f1`（`test(routes): cover out-and-back trips`）、文档提交与本节同批（`docs(repo): record the Task 17 out-and-back results`）
- 逐项结果

| 项 | 结论 | 证据 |
| --- | --- | --- |
| 1. `.outAndBack(trips:)` 与 trips 校验 | pass | `RoamControl/Features/Routes/Models/RouteRunMode.swift:22` 新 case；`:31-33` `trips < 1` 抛 `invalidTripCount`（`:7`）；`Codable` 仍为合成实现，测试 `testOutAndBackSurvivesAnEncodingRoundTrip` 覆盖 `.outAndBack(trips: 3)` 往返 |
| 2. 只允许开放路线 | pass | `RoamControl/Features/Routes/Core/RouteRunner.swift:91-102` 按模式分派：`.once` 不校验、`.outAndBack` 要求 `!geometry.isClosed` 否则 `requiresOpenRoute`（`RouteRunMode.swift:11`）、`.laps`/`.continuous` 仍要求闭环；测试 `testClosedRouteRejectsOutAndBack`、`testOpenRouteRejectsLapsMode`、`testOpenRouteRejectsContinuousMode` |
| 3. 复用 `targetLaps` | pass | `RouteRunner.swift:59-70` `.outAndBack → trips`；`:203-205` `completedLaps >= targetLaps` 进 `.finished`；`:227-231` 覆盖距离被夹到最后目标 |
| 4. 奇偶决定方向 | pass | `RouteRunner.swift:79-82` `isReturnTrip`；`:247-249` 奇数趟取 `coordinate(atDistance: lapLength - distanceInLap)`，偶数趟取 `coordinate(atDistance: distanceInLap)`；测试 `testOutAndBackFirstTripLandsOnTheLastPoint`、`testOutAndBackSecondTripRunsBackwards` |
| 5. 恢复与夹紧 | pass | `RouteRunner.swift:111-125` 按 `completedLaps` 奇偶还原方向，`.outAndBack` 的 `completedLaps` 夹到 `trips` 且不抛错；测试 `testOutAndBackRecoveryResumesInTheReturnDirection`、`testOutAndBackRecoveryClampsTripsBeyondTheTarget` |
| 6. 设置页趟数 Stepper | pass | `RouteRunSetupView.swift:47` `@State private var tripCount = 1`；`:176` `Stepper("Trips: \(tripCount)", value: $tripCount, in: 1...100)`；`:180-182` 偶数趟 `Ends at the start point.` / 奇数趟 `Ends at the finish point.`；`:224` `tripCount == 1 ? .once : .outAndBack(trips: tripCount)` |
| 7. 运行卡趟数指标 | pass | `RouteRunCard.swift:109-117` 有趟数时 `Trips` + `index/count`（如 `2/3`），否则原 `Laps` + `completedLaps`；进度条仍用 `session.lapProgress`（本趟进度），`:48` 未改 |
| 8. 新增中文文案 | pass | `Localizable.xcstrings:2308` `Ends at the finish point.`（结束时停在终点。）、`:2324` `Ends at the start point.`（结束时回到起点。）、`:9012` `Trips`（趟数）、`:9028` `Trips: %lld`（趟数：%lld）；闭环既有 5 个 key 未改 |

- 测试：基线 135 → 147（新增 12 例，只加不删）。`RouteRunnerTests` 9 例 `testOutAndBackFirstTripLandsOnTheLastPoint`、`testOutAndBackSecondTripRunsBackwards`、`testEvenTripCountFinishesAtTheStartPoint`、`testOddTripCountFinishesAtTheFinishPoint`、`testOutAndBackTotalDistanceIsMonotonicAcrossTrips`、`testSingleTripMatchesOnceOnAnOpenRoute`、`testOutAndBackRejectsZeroTrips`、`testClosedRouteRejectsOutAndBack`、`testOutAndBackSurvivesAnEncodingRoundTrip`；`RouteRecoveryTests` 2 例 `testOutAndBackRecoveryResumesInTheReturnDirection`、`testOutAndBackRecoveryClampsTripsBeyondTheTarget`；`RouteSessionModelTests` 1 例 `testTripCountAndIndexFollowCompletedTrips`。CI `Run RoamControlTests` 输出 147 行 `Test case … passed`、0 行 `failed`，`** TEST SUCCEEDED **`
- 编译与构建：同一 run `Build Debug` 与 `Build Release` 均 `** BUILD SUCCEEDED **`
- 本地化：`python scripts/check_localizations.py` → `Localizable.xcstrings: 613/613 keys translated (100.0%)`、`InfoPlist.xcstrings: 2/2 keys translated (100.0%)`、`All 615 keys have non-empty zh-Hans values.`，exit 0；CI `Check localization catalogs` 步骤输出相同
- CI：run [41236893110](https://github.com/FaHits/Roam-Control/actions/runs/41236893110)（head `76d41f1710d3077f9535f7ac86ec3324b938b50e`）`conclusion=success`；`test` success、`unsigned-ipa` success、`unsigned-ipa-debug` success
- 产物（该 run 实测）：Release IPA artifact `RoamControl-unsigned-ipa` id `13055889161` / 3,107,748 字节；Debug IPA artifact `RoamControl-unsigned-debug-ipa` id `13055378342` / 4,635,484 字节；字节取自 `gh api repos/FaHits/Roam-Control/actions/runs/41236893110/artifacts` 的 `size_in_bytes`，unsigned IPA 字节不可复现，记录的是该 run 实测值
- 静态证据：`rg -n "outAndBack" RoamControl | wc -l` → 16（`RouteRunMode.swift` 3、`RouteRunner.swift` 9、`RouteSessionModel.swift` 2、`RouteRunSetupView.swift` 1、`RouteRunCard.swift` 1 附近）；`rg -n "outAndBack" RoamControlTests | wc -l` → 16；`rg -n "gcj02ToWGS84|offsetDegrees|coordinateOffset" RoamControl | wc -l` → 8，与 `git grep -h -n -E "gcj02ToWGS84|offsetDegrees|coordinateOffset" 03f9a92 -- RoamControl | wc -l` 的 8 相同，坐标适配层零改动，`DeviceCoordinateAdapter.swift:37` 仍 `.gcj02ToWGS84`；`rg -n "MARKETING_VERSION|CURRENT_PROJECT_VERSION" RoamControl.xcodeproj/project.pbxproj` 仍 `0.10.0` / `62`
- 未改动：`RouteStore.schemaVersion`、`RouteRunCard` 进度条、闭环 `.laps` / `.continuous` 的计数与文案、`.once` 的 `distanceInLap` 语义（跑完仍为本趟全长，`.outAndBack` 则在 seam 处归零进入下一趟，两者差异由 `testSingleTripMatchesOnceOnAnOpenRoute` 用坐标/距离/相位逐帧锁定）
- 本地无法验证：本机为 Windows，无 `xcodebuild`、无 iOS 模拟器、无配对真机；测试、Debug/Release 构建与产物全部来自 `xcode-27` GitHub Actions
- 未验证项（真机，登记在交接文档第 7 节第 16 行，随 Task 14 批量验证）：开放路线分别设 1 / 2 / 3 趟跑完，地图上去程与回程方向可见且落点符合奇偶（2 趟停在起点、3 趟停在终点），运行卡第二行显示 `1/3`、`2/3` 类趟数指标而不是 `Laps`
- 下一步：按交接文档第 3 节进入 **Task 18**（路线选点卫星底图）
- 更新时间：2026-11-01

### 2026-11-01 Task 18 实现记录（路线编辑器卫星/混合底图）

- 状态：`implemented`
- 目标：路线编辑器的底图不再固定标准样式，而是跟随全局 `appModel.mapDisplayStyle`，并在编辑面板内提供标准 / 卫星 / 混合切换；样式映射收敛为一处，Home 与编辑器共用
- 改动文件：
  - `RoamControl/Models/AppPreferences.swift`：`MapDisplayStyle` 增加 `var mapStyle: MapStyle`，唯一实现点（`:47`），三分支在 `:49-51`；文件头补 `import MapKit` 与 `import SwiftUI`，注释说明 `MapStyle` 位于 `_MapKit_SwiftUI` 交叉导入 overlay，缺 `SwiftUI` 时 CI 报 `cannot find type 'MapStyle' in scope`
  - `RoamControl/Features/Home/HomeView.swift`：`roamControlMapStyle(_:)`（原 `:826-838` 的 `private extension View`）整体删除，调用点 `:78` 改为 `.mapStyle(appModel.mapDisplayStyle.mapStyle)`，视觉与行为不变
  - `RoamControl/Features/Routes/Views/RouteEditorView.swift`：`:15` 注入 `@Environment(AppModel.self)`；`:53` 底图改用共享映射；`:131` 在面板 `VStack` 首位插入 `stylePicker`；`:167` 定义 `private var stylePicker`，无障碍字号时 `.pickerStyle(.menu)`，否则 `.segmented` + `.labelsHidden()`；`:186` 定义 `mapStyleBinding`，`get` 读 `appModel.mapDisplayStyle`，`set` 调 `appModel.setMapDisplayStyle`
  - `RoamControlTests/MapDisplayStyleTests.swift`（新增）：5 个用例
  - `RoamControlTests/RouteEditorModelTests.swift`：新增 `testSavedRouteIsIndependentOfMapStyle`
- 逐项结果：

| # | 要求（prompt §2） | 状态 | 证据 |
| --- | --- | --- | --- |
| 1 | 编辑器底图跟随全局样式，含紧凑切换器 | implemented | `RoamControl/Features/Routes/Views/RouteEditorView.swift:53`、`:131`、`:167` |
| 2 | 单一真源，切换写回 `appModel.setMapDisplayStyle`，无私有覆盖、无第二个持久化键 | implemented | `RoamControl/Features/Routes/Views/RouteEditorView.swift:186-192`；`rg -n "mapDisplayStyle" RoamControl` → 12 处，均在 `AppModel`、`HomeView:78`、`SettingsView:269`、`ConnectionHealthView:362`、`RouteEditorView:53/188`；键名与 rawValue 未改 |
| 3 | 映射迁入 `AppPreferences`，Home 与编辑器共用，Home 视觉不变 | implemented | `RoamControl/Models/AppPreferences.swift:47-51`、`RoamControl/Features/Home/HomeView.swift:78` |
| 4 | 卫星/混合下折线、锚点、点击、清除、保存照旧；`MapReader` / `proxy.convert(location, from: .local)` 取点路径不动 | implemented | `RoamControl/Features/Routes/Views/RouteEditorView.swift:55` 取点一行未改；本次 diff 未触及 `RouteEditorModel.swift` 与坐标适配层 |
| 5 | 无障碍动态字号下降级为 `.menu` Picker | implemented | `RoamControl/Features/Routes/Views/RouteEditorView.swift:167-184`，判据 `.isAccessibilitySize`，与 `SettingsView.swift:225-241` 同模式 |
| 6 | 样式切换不改动任何 `RouteEditorModel` 状态 | implemented | `RouteEditorModel.swift` 无改动；`RouteEditorModelTests.testSavedRouteIsIndependentOfMapStyle` 取值前后点位/闭环/名称全等 |

| # | 测试（prompt §5） | 状态 | 证据 |
| --- | --- | --- | --- |
| 1 | 空偏好下默认 `.standard` | implemented | `MapDisplayStyleTests.testDefaultStyleIsStandardWithoutStoredValue` |
| 2 | 写入 `.satellite` → 偏好字符串 `satellite`，新建 `AppModel` 读到 `.satellite` | implemented | `MapDisplayStyleTests.testStoredSatelliteStyleIsReadAtLaunch`、`testSettingStylePersistsRawValueAndReloads`（该用例写 `.hybrid`，断言存储值 `hybrid`） |
| 3 | 非法值 `terrain` / 空串回落 `.standard` 且不崩溃 | implemented | `MapDisplayStyleTests.testUnknownOrEmptyStoredValueFallsBackToStandard` |
| 4 | `allCases` 为 3，rawValue 与标题非空 | implemented | `MapDisplayStyleTests.testCasesRawValuesAndTitles` |
| 5 | 保存结果与样式无关 | implemented | `RouteEditorModelTests.testSavedRouteIsIndependentOfMapStyle` |

- 测试：147 → 153（+6），`Test case … passed` 153 次、`failed` 0 次、`TEST SUCCEEDED` 1 次、`BUILD SUCCEEDED` 2 次
- CI：run [41263004257](https://github.com/FaHits/Roam-Control/actions/runs/41263004257)（head `94cc7a9450f42445171580646d3badc14dff9350`）`conclusion=success`；`test` success、`unsigned-ipa-debug` success、`unsigned-ipa` success
- 产物（该 run 实测）：Release IPA artifact `RoamControl-unsigned-ipa` id `13066740244` / 3,109,098 字节；Debug IPA artifact `RoamControl-unsigned-debug-ipa` id `13065689661` / 4,637,760 字节；字节取自 `gh api repos/FaHits/Roam-Control/actions/runs/41263004257/artifacts` 的 `size_in_bytes`，unsigned IPA 字节不可复现
- 文档提交 run [41263513561](https://github.com/FaHits/Roam-Control/actions/runs/41263513561)（head `69568597e76fd482fd33453ec94c1a24afd19962`）`conclusion=success`，三 job 同样 success；产物 Release `RoamControl-unsigned-ipa` id `13065884756` / 3,109,105 字节、Debug `RoamControl-unsigned-debug-ipa` id `13066201608` / 4,637,760 字节
- 静态证据：`rg -n "roamControlMapStyle" RoamControl | wc -l` → 0（私有覆盖已删除）；`rg -n "elevation: .realistic" RoamControl | wc -l` → 3（全部在 `AppPreferences.swift:46-48` 同一 switch 内，即 1 处映射实现）；`rg -n "gcj02ToWGS84|offsetDegrees|coordinateOffset" RoamControl | wc -l` → 8，与 baseline 一致，`DeviceCoordinateAdapter.swift:37` 仍 `.gcj02ToWGS84`；`python scripts/check_localizations.py` → `613/613`、`2/2`、`All 615 keys have non-empty zh-Hans values.`，exit 0（未新增本地化键）
- 未改动：`MapDisplayStyle` 的 rawValue 与 `"mapDisplayStyle"` 存储键、Home 相机与镜头逻辑、`RouteEditorModel`、`DeviceCoordinateAdapter`、`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`（仍 `0.10.0` / `62`）
- 本地无法验证：本机为 Windows，无 `xcodebuild`、无 iOS 模拟器、无配对真机；测试、Debug/Release 构建与产物全部来自 `xcode-27` GitHub Actions
- 未验证项（真机，登记在交接文档第 7 节第 17、19 行，随 Task 14 批量验证）：
  - 编辑器切换 standard / satellite / hybrid 三种均渲染；卫星底图下点 4 点闭环保存后几何不变
  - 系统字号调到无障碍字号后，样式控件退化为 `Map Style` 菜单（不再分段），编辑面板无挤压、无截断
  - 卫星底图与 GCJ-02 坐标偏移是否目视不一致：按 prompt 明确不在本任务调坐标或加校准常量，仅作为观察项记录，若不一致另开任务处理
- 后续走向（历史陈述）：Task 18 之后进入 Task 14，其 A 段已于 2026-11-01 交付，B 段 19 项真机行为待用户执行
- 更新时间：2026-11-01

### 2026-11-01 Task 14 最终回归记录：A 段交付与 B 段真机清单

- 任务：Task 14 - 完整验证（A 段 = 自动化门禁与交付物；B 段 = 交接文档第 7 节 19 项真机行为，由用户执行）
- 状态：`implemented`（A 段全部完成；B 段 19 项尚未执行，因此不写 `completed`）
- 分支与基线：`feat/manual-running-routes`，起点 HEAD `a7b68b2`，与 `fork` 远端一致，工作树干净；整体差异基线 `b68dac0`
- 修改文件：`README.md`（删掉未发布的 beta 下载与 Build 61 说法，下载说明改为「fork 未发布、CI 产 unsigned IPA 需自签」，版本徽章指向 0.10.0 / 62，统计与安全链接指向 fork 与 CHANGELOG）、`CHANGELOG.md`（新增 `[0.10.0] - 待发布（真机验收进行中）` 条目）、`.github/ISSUE_TEMPLATE/config.yml`（安全报告链接指向 fork 的 security advisories）、`Documentation/ImplementationStatus.md`、`.planning/2026-10-30-roam-route-system/progress.md`。未改 `RoamControl/`、`RoamControlTests/`、`project.pbxproj`、版本号与构建号、坐标适配层、CI workflow：本轮只验证与文档收尾，没有发现真实缺陷，因此没有 `fix` 提交
- 提交：`c027584`（`docs(repo): drop stale beta-preview claims and point docs at the fork`，纯文档提交、非装机源）、`28472c6`（`docs(routes): record the Task 14 final verification`）
- 自动化门禁（10 条，逐条实测，本机 Windows 可跑部分）

| # | 门禁 | 结果 |
| --- | --- | --- |
| 1 | `python scripts/check_localizations.py` | pass：`Localizable.xcstrings: 613/613`、`InfoPlist.xcstrings: 2/2`、`All 615 keys have non-empty zh-Hans values.`，exit 0 |
| 2 | 匿名统计残留 `rg -n "UsageAnalytics\|ProductInteraction\|DeviceID\|PurposeAnalytics" RoamControl RoamControlTests` | pass：0 命中（exit 1） |
| 3 | 架构边界 `rg -n "import (SwiftUI\|MapKit)\|AppModel" RoamControl/Features/Routes/Core RoamControl/Features/Routes/Models` | pass：0 命中（exit 1） |
| 4 | 架构边界 `rg -n "MKRoute\|MKMapPoint\|MKPolyline" RoamControl/Features/Routes/Core RoamControl/Features/Routes/Models` | pass：0 命中（exit 1） |
| 5 | 坐标适配 `DeviceCoordinateAdapter.live` | pass：`RoamControl/Services/Location/DeviceCoordinateAdapter.swift:37` 为 `static let live = DeviceCoordinateAdapter(conversion: .gcj02ToWGS84)` |
| 6 | 版本残留 `rg -n "0\.9\.2\|CURRENT_PROJECT_VERSION = 61" Documentation RoamControl.xcodeproj README.md` | pass：0 命中；pbxproj `:248`/`:273` 为 `CURRENT_PROJECT_VERSION = 62;`，`:253`/`:278` 为 `MARKETING_VERSION = 0.10.0;` |
| 7 | 旧仓库名 `rg -n "seanhowarthdev" RoamControl RoamControlTests .github README.md Documentation` | pass：0 命中（改前 README.md:61、README.md:127、config.yml:4 三处已改） |
| 8 | Issues 开关 `gh api repos/FaHits/Roam-Control --jq .has_issues` | pass：`true` |
| 9 | 私密漏洞报告 `gh api repos/FaHits/Roam-Control/private-vulnerability-reporting` | pass：`{"enabled":true}` |
| 10 | 全量单元测试 + Debug/Release 构建 | pass：见下条 CI（本机无 `xcodebuild`，全部来自 `xcode-27` runner） |

- CI：run [41271600000](https://github.com/FaHits/Roam-Control/actions/runs/41271600000)（head `28472c6`）`conclusion=success`；`test` job `Check localization catalogs` 通过、153 行 `Test case … passed`、0 行 `failed`、`** TEST SUCCEEDED **`、`Build Debug` 与 `Build Release` 均 `** BUILD SUCCEEDED **`；`unsigned-ipa` success、`unsigned-ipa-debug` success。同代码状态的过程记录 run `41271064818`（head `c027584`）三 job 同样 success，非装机源
- 产物（B 段装机源，取自该 run）：Release IPA artifact `RoamControl-unsigned-ipa` id `13069906753` / 3,109,112 字节；Debug IPA artifact `RoamControl-unsigned-debug-ipa` id `13069387607` / 4,643,768 字节；字节取自 `gh api repos/FaHits/Roam-Control/actions/runs/41271600000/artifacts` 的 `size_in_bytes`，unsigned IPA 字节不可复现。过程记录 run `41271064818` 的 artifact `13068894830` / `13069935430` 非装机源。IPA 只有 14 天保留期，过期后从同 head 的 run 重新下载
- 新增测试：0（153 用例全部为既有用例）。本轮没有失败用例可复现，因此没有为凑数补测试
- 未验证项（19 项真机行为，全部 `未验证`）：逐条登记在 [`Documentation/Handoffs/2026-10-31-rework-handoff.md`](Handoffs/2026-10-31-rework-handoff.md) 第 7 节，#1–#7 = 9R、#8–#9 = 19、#10–#11 = 16R、#12–#15 = 20、#16 = 17、#17 与 #19 = 18、#18 = 历史回归（15/10/12/13）。本机为 Windows，`which xcodebuild` / `xcrun` / `simctl` / `idevice_id` 全为空，没有 macOS、iOS 模拟器与配对真机，未产生任何运行时证据；CI 绿只证明测试与 Debug/Release 构建通过，不代表任何一项真机行为通过
- 已知风险：153 个用例只覆盖模型层与纯逻辑，`HomeView` / `RouteRunCard` / `RouteLibraryView` / `RouteRunSetupView` / `SessionRecoveryView` 的接线仍无 UI 层自动化；真机设备会话（配对、LocalDevVPN、后台节流、强制退出恢复）从未在任何构建上跑过；`Documentation/Privacy.md` 仍在描述已删除的匿名统计，属于规划会话的权限范围，本轮未改，登记为遗留
- 下一步：用户按第 7 节顺序执行 B 段（坐标与 Stop → 9R → 19 → 16R → 20 → 17 → 18 → 历史回归 → 无障碍字号），逐行把 `未验证` 改成 `pass` 或 `fail`；全部 pass 后由验收方把 Task 14 升为 `completed`，出现 fail 时另开 `fix` 任务
- 更新时间：2026-11-01
