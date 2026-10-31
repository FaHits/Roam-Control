# Roam Control 大返工交接（2026-10-31）

这份文档交给下一个“策划 + 验收”会话。它不负责直接改代码，负责按顺序生成执行 prompt、验收执行方交付、决定是否进入下一项。

## 0. 给下一个会话的硬性指令

1. 先读本文件，再读 `Documentation/ImplementationStatus.md` 和 `.planning/2026-10-30-roam-route-system/task_plan.md`。
2. 先检查仓库基线：分支、HEAD、工作树、版本号、最近 CI。不要假设本文件里的提交号仍然是最新。
3. 一次只给一个 Task 的 prompt，按本文第 4 节的顺序推进。
4. 只有当前 Task 验收通过，才生成下一个 Task 的 prompt；不通过就生成“完善当前 Task”的 prompt，不跳项。
5. 每条 prompt 都必须要求执行方输出便于本会话验收的信息：提交哈希、测试数量、CI run、产物 id/大小、真机步骤与截图、逐项状态矩阵、未验证项。
6. 不要在执行方没有真机证据时把任务标成 `completed`；代码和自动化通过只能标 `implemented_unverified`。
7. 用户要求改代码或文档前，先用中文说明设计与改动范围，得到认可再动手。验收会话本身不要直接修代码。
8. 不要回退 Task 15 的坐标方向：`DeviceCoordinateAdapter.live = .gcj02ToWGS84`，只在注入边界转换一次，禁止硬编码 ±500m 偏移。

## 1. 当前基线

- 仓库：`E:\Ai_Agent\RUN\roam-src`
- 分支：`feat/manual-running-routes`
- HEAD：`0f63d1f docs(routes): record Task 14 verification`
- 工作树：交接前干净；本次新增本文件并修改 `ImplementationStatus.md` 顶部，尚未提交
- 版本：`0.10.0` / build `62`
- 最近完整 CI：run `41204687369`，三个 job 全绿
- Release 产物：`RoamControl-unsigned-ipa`，artifact `13044133307`，3,138,706 B
- Debug 产物：`RoamControl-unsigned-debug-ipa`，artifact `13043767710`，4,707,871 B
- 测试基线：119 tests / 0 failures
- 坐标：`RoamControl/Services/Location/DeviceCoordinateAdapter.swift:37` 为 `.gcj02ToWGS84`

### 状态口径

用户这轮在真机上把所有验收项都试了，只提交不通过项，并明确“没有 not_run”。因此：

- Task 15 坐标与 Stop：按用户口径通过，可关闭。
- Task 10 路线历史：按用户口径通过，可关闭。
- Task 12 路线图标：按用户口径通过，可关闭。
- Task 13 中断恢复：按用户口径通过，可关闭。
- Task 9 路线库：重新打开，删除动画与重命名 IME 两个失败项。
- Task 16 本地化：重新打开，语言弹窗与英文残留失败。
- Task 14 整体：仍是 `fail`，不能因为其他项通过就标 `completed`。
- Task 17–20：本轮新增的返工/产品改动任务，尚未开始。

### 文档陈旧警告

`Documentation/ImplementationStatus.md` 顶部已改为 `fail` 并指向本文件；但文末 Task 14 记录仍保留旧 CI run 与“真机验收项均为 not_run”的历史表述。不要用文末旧记录覆盖本文件；最终 Task 14 回归时必须统一更新，不能保留 `not_run`。

## 2. 本轮确认的问题与证据

### 2.1 开放路线只能单程，不能折返

- 证据：`RoamControl/Features/Routes/Views/RouteRunSetupView.swift:160-177` 对非闭环路线只显示 `Text("Once")`，不显示模式 Picker；`RoamControl/Features/Routes/Models/RouteRunMode.swift:12-16` 只有 `.once`、`.laps(Int)`、`.continuous`，后两者只对闭环有效。
- 性质：不是回归 bug，是原始设计边界/功能缺口。
- 对应：新 Task 17。

### 2.2 路线选点地图没有卫星图

- 证据：`RoamControl/Features/Routes/Views/RouteEditorView.swift:52` 硬编码 `.mapStyle(.standard(elevation: .realistic))`；主页地图支持 standard/satellite/hybrid（`RoamControl/Features/Home/HomeView.swift:828-835`），`MapDisplayStyle` 已存在（`RoamControl/Models/AppPreferences.swift:28-38`），但路线编辑器没有接入。
- 性质：功能缺口，不是地图数据问题。
- 对应：新 Task 18。

### 2.3 更新、反馈指向原版仓库

- 证据：`RoamControl/Features/Settings/SettingsView.swift:4-9` 的 bug report / feature request URL 指向 `https://github.com/seanhowarthdev/Roam-Control/issues/...`；`RoamControl/Services/ReleaseUpdateChecker.swift:35-36` 指向 `https://api.github.com/repos/seanhowarthdev/Roam-Control/releases/latest`。
- 用户 fork：`FaHits/Roam-Control`。当前代码没有指向它。
- 性质：配置/产品错误。
- 对应：新 Task 20。

### 2.4 共享匿名统计

- 证据：`SettingsView.swift:86-103` 有 Privacy 区、`Share Anonymous Usage Statistics` 开关和 `What Is Shared`；`OnboardingView.swift:187-210` 有共享卡片；`AppModel.swift:14/28/66/207-230` 有统计属性和开关；`UsageAnalyticsService.swift:34+` 有发送器；`PrivacyInfo.xcprivacy` 声明 ProductInteraction/DeviceID 用于 Analytics。
- 当前工程没有找到 `RoamControlTelemetry*` 的 Info.plist 配置键，所以当前构建可能不会真正发送；但 UI、调用路径、隐私声明都在。
- 用户要求整段删除，不只是隐藏开关。
- 对应：新 Task 19。

### 2.5 路线卡片删除动画

- 证据：`RouteLibraryView.swift:131-140` 的 `.swipeActions` 内是 `Button("Delete", role: .destructive)`，只设置 `routePendingDeletion`；真正删除在 `:291-296` 的 `deletePendingRoute()`，确认后才 `model.delete`。
- 代码没有提前删数据；`destructive` swipe action 触发 SwiftUI 行移除动画，取消后数据仍在、行恢复。
- 性质：交互/动画 bug，不是数据 bug。
- 对应：Task 9 返工（9R）。

### 2.6 微信输入法重命名按钮灰色

- 证据：`RouteLibraryView.swift:92-100` 的 Rename 按钮按 `renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty` 禁用；`:276-289` 的 `beginRename` 设 `renameText = route.name`。
- 截图显示输入框有“神秘”但按钮灰色：微信输入法 marked text 尚未提交到 binding 时，校验读到空串；苹果输入法直接提交所以正常；在已有文字后追加不会经历“空串瞬间”，所以也不触发。
- 性质：真实 IME 兼容 bug。
- 对应：Task 9 返工（9R）。

### 2.7 语言弹窗没有判断

- 证据：`SettingsView.swift:42-46` 的 `.onChange(of: appLanguage)` 无条件 `newLanguage.apply()` 并 `isShowingRestartAlert = true`，没有比较当前生效语言。
- 切回当前界面语言仍弹窗，并重复写 `AppleLanguages`。
- 性质：真实状态判断 bug。
- 对应：Task 16 返工（16R）。

### 2.8 英文残留

- Onboarding：`OnboardingView.swift:139-147` 用 `Text(page.title)` / `Text(page.message)`，`OnboardingPage.title/message` 是 `String`（`:241-260`），不走本地化；按钮用 `String(localized:)`，所以出现“中文按钮 + 英文正文”。
- 设备设置：`PairingSetupView.swift:200-226` 把英文 `String` 传给 `requirementRow` / `instructionRow`，helper 在 `:248`/`:263` 用 `Text(text)`，未本地化。
- 连接检查：`LocalDeviceSessionCoordinator.swift:89/189/361/686/692` 的 `restorationStatus` 是硬编码英文；`ConnectionHealthView.swift:37` 直接 `Text(...)` 显示；`:46` 的 `"None"` 也未本地化。
- 匿名统计：`UsageStatisticsPrivacyView.swift:19-37` 的 `privacyRow(String)` 用 `Label(title,...)`，未本地化；如果 Task 19 删除该页，此项自动消失。
- 性质：真实本地化覆盖 bug。
- 对应：Task 16 返工（16R）。

## 3. 返工顺序

1. **Task 9R**：路线库删除动画 + 重命名 IME。
2. **Task 19**：移除匿名统计/共享数据全链路。
3. **Task 16R**：语言弹窗 + 剩余英文残留。
4. **Task 20**：更新/反馈仓库地址。
5. **Task 17**：开放路线折返/往返次数。
6. **Task 18**：路线编辑器卫星/混合底图。
7. **Task 14**：全量回归、状态与文档收尾。

顺序理由：9R 直接阻塞路线库验收；19 会删掉匿名统计页，先做可避免 16R 白翻一页；20 是小型配置修复；17/18 是较大的功能改动，放在验收 bug 之后；Task 14 必须最后跑。

## 4. 每个 Task 的范围与验收

### Task 9R — 路线库 UI 返工

目标：

- 删除 swipe 后，确认前不播放行移除动画；取消后行保持原位。
- 微信输入法在空输入框直接输入时，Rename 按钮不会因 marked text 变灰；点击后能提交有效名称。

约束：

- 不改 `RouteLibraryModel` 的删除语义，不提前删数据。
- 不引入新的路线功能；只修 `RouteLibraryView` 的交互与校验。
- 重命名校验仍要拒绝空串/纯空白；不要为了绕过 IME 而允许空名称。

建议实现方向：

- 删除：把 swipe 按钮从 `role: .destructive` 改为普通红色按钮，或自定义确认动作；确认后再调用 `model.delete`。
- 重命名：不要在 marked text 阶段用实时 binding 决定禁用；可改为点击 Rename 时校验，或桥接 `UITextField` 读取提交后的文本。

验收证据：

- 单测：名称校验（空、空白、正常）覆盖；现有 119 tests 全绿。
- CI：test / unsigned-ipa / unsigned-ipa-debug 全绿，给出 run 与 artifact。
- 真机：删除→取消（行不消失、不塌陷）、删除→确认（真正删除）各一张；微信输入法空框输入“神秘”后按钮可用并成功改名；苹果输入法回归一张。
- 报告：逐项 pass/fail，不允许只写“已修复”。

### Task 19 — 移除匿名统计/共享数据

目标：把共享匿名统计从产品中整段移除，而不是隐藏开关。

范围：

- `SettingsView` 的 Privacy 区、`Share Anonymous Usage Statistics` 开关、`What Is Shared` 入口。
- `OnboardingView` 第 4 页的共享卡片；页面文案改为不含共享统计的隐私说明，或调整页数。
- `UsageStatisticsPrivacyView` 整个页面。
- `AppModel` 的 `sharesAnonymousUsageStatistics`、`setSharesAnonymousUsageStatistics`、`anonymousUsageStatisticsKey` 及所有 `usageAnalytics` 调用。
- `UsageAnalyticsService` 及 `UsageAnalyticsEvent` / `FailureDiagnosticSnapshot` 中仅服务于统计的部分；保留必要的诊断模型时不要误删连接检查使用的类型。
- `PrivacyInfo.xcprivacy` 删除 ProductInteraction / DeviceID 的 Analytics 声明；保留 UserDefaults 的 CA92.1。
- `Localizable.xcstrings` 删除对应 key；测试删除或改写。

验收证据：

- `rg -n "UsageAnalytics|sharesAnonymousUsageStatistics|AnonymousUsage|Telemetry|What Is Shared|Share Anonymous" RoamControl RoamControlTests` 只剩历史文档/迁移说明，不含运行代码。
- `PrivacyInfo.xcprivacy` 不再声明 Analytics 收集。
- 119+ tests 全绿；CI 三 job 全绿。
- 真机：Settings 无 Privacy/共享入口；Onboarding 无共享卡片；匿名统计页不可达；截图各一张。
- 不要求保留“关闭状态”的兼容逻辑；旧 UserDefaults key 可以留着不读，不必迁移。

### Task 16R — 语言与英文残留返工

目标：

- 选择语言时，只有真正改变生效语言才写入并提示重启；切回当前语言不弹窗。
- 简体中文下，重要功能介绍、设备设置、连接检查不再出现英文句子；匿名统计页若已被 Task 19 删除则不处理。
- 保留品牌/产品名：`ROAM CONTROL`、`LocalDevVPN`、`GCJ-02 → WGS-84`、`WGS-84 → GCJ-02`、罗盘 `N/E/S/W` 可以继续英文。

范围：

- `SettingsView.swift:42-46` 的语言变更判断。
- `AppLanguage` 增加“当前生效语言”的判断辅助；注意 App 重启前 bundle 语言可能未变，设计要能解释。
- `OnboardingView` 的 `title/message` 改为 `LocalizedStringKey` 或 `String(localized:)`。
- `PairingSetupView` 的 `requirementRow` / `instructionRow` 改为本地化 key，或让调用方传 `LocalizedStringKey`。
- `ConnectionHealthView` 的 `restorationStatus` 与 `"None"` 改为本地化；`LocalDeviceSessionCoordinator` 可保留英文内部状态，但显示层必须映射，不要把内部诊断字符串直接当 UI 文案。
- 更新 `Localizable.xcstrings`，确保 611+ keys 的 zh-Hans 非空；`check_localizations.py` 的覆盖范围说明要改成实际能力，别声称检查所有 Swift 引用。

验收证据：

- 单测：语言选择“相同不弹窗/不同弹窗”、system 移除 override、英文/中文写入。
- 本地化脚本：所有 key 非空，exit 0。
- CI 三 job 全绿。
- 真机：英文→中文→英文不重复弹窗；中文下 Onboarding 四页、设备设置、连接检查全中文；英文下这些页面全英文；截图至少 6 张。
- 报告：列出仍保留英文的项及理由。

### Task 20 — 更新/反馈仓库地址

目标：不再指向 `seanhowarthdev/Roam-Control`。

范围：

- 统一仓库常量，`SettingsView` 的 bug report / feature request 与 `ReleaseUpdateChecker` 共用。
- 目标默认 `FaHits/Roam-Control`；如果该 fork 没有 releases，更新检查应明确禁用/提示未配置，不能回落原版。
- 若用户决定移除更新检查，则删除相关 UI 与 service，而不是保留死代码。

验收证据：

- `rg -n "seanhowarthdev/Roam-Control" RoamControl` = 0。
- 单测：URL 常量/更新检查分支（有 release、404、无配置）覆盖。
- CI 全绿。
- 真机：点 Report a Bug / Request a Feature 打开正确仓库；更新检查显示正确结果；截图。

### Task 17 — 开放路线折返/往返次数

目标：非闭环路线不再只有“Once”，可设置折返/往返次数。

先确认语义（在生成 prompt 时问用户一次，不要猜）：

- “折返 1 次”是走到终点再原路返回（一个往返），还是走 N 个单程？
- 默认建议：`往返次数`，1 次 = 去 + 回；UI 文案写清楚。

范围：

- `RouteRunMode` 增加开放路线模式（如 `.outAndBack(repetitions: Int)`），或单独配置。
- `RouteRunSetupView` 对开放路线显示次数 Picker，不再只显示 `Text("Once")`。
- `RouteRunner` / `RouteSessionModel` 支持反向遍历、接缝、进度、圈数/往返计数。
- 恢复记录、运行卡、地图折线、暂停/继续、Stop 全部兼容。
- 闭环路线的 `.laps` / `.continuous` 不能回归。

验收证据：

- 单测：1/2/3 次往返的进度、接缝、完成、暂停恢复；开放路线不再只跑一次。
- CI 全绿。
- 真机：开放路线 1 次、3 次各跑一段；地图上能看到去程/回程；运行卡计数正确；截图。
- 报告：明确次数语义与边界。

### Task 18 — 路线编辑器卫星/混合底图

目标：路线选点时可切换 standard / satellite / hybrid。

范围：

- `RouteEditorView` 接入 `AppModel.mapDisplayStyle`，或提供编辑页内的样式 Picker。
- 保证卫星图下折线、锚点、点击落点、清除/保存都正常。
- 主页地图样式行为不变。

验收证据：

- 单测：如样式映射有纯逻辑，覆盖；否则以构建 + 真机为准。
- CI 全绿。
- 真机：三种样式各截一张；卫星图下点 4 个点、闭环保存、重开路线，几何不变。
- 报告：是否复用全局设置、是否允许编辑页临时覆盖。

### Task 14 — 最终全量回归

前置：Task 9R / 19 / 16R / 20 / 17 / 18 全部验收通过。

范围：

- 版本保持 0.10.0 / 62（除非用户要求新 build）。
- 自动化门禁：全部测试、Debug/Release、本地化、架构边界、无 `seanhowarthdev`、无 analytics 代码。
- 真机全量：Task 15 坐标/Stop、Task 10 历史、Task 12 图标、Task 13 恢复、Task 9R 删除/改名、Task 16R 语言、Task 19 设置清理、Task 20 链接、Task 17 折返、Task 18 卫星。
- 截图：每个失败项修复前后对照 + 最终状态；至少覆盖 9R、16R、19、20、17、18。
- 文档：更新 `ImplementationStatus.md` 顶部当前任务、状态、最近 CI、Task 14 记录；删除“not_run”陈述；Task 9/16/17/18/19/20 状态与证据一致。

验收证据：

- 最终 CI run 三个 job 全绿，Release/Debug artifact id 与大小。
- 119+ tests / 0。
- 逐项验收矩阵，无 `not_run`；未测项必须明说。
- 只有全部通过，才把 Task 14 标 `completed`；否则保持 `fail` 或 `implemented_unverified`。

## 5. 每条 prompt 的固定格式

生成 prompt 时，至少包含：

1. 当前分支、HEAD、版本、测试基线。
2. 本 Task 的目标、明确不在范围内的事。
3. 需要读/改的文件与关键行号。
4. 约束：不改坐标方向、不硬编码偏移、不提前删数据、不误删诊断类型、不把未验证写成完成。
5. 测试要求：新增/修改哪些测试，现有 119 tests 不能回归。
6. CI 要求：test / unsigned-ipa / unsigned-ipa-debug 三个 job，给出 run 与 artifact。
7. 真机步骤与截图清单。
8. 报告格式：提交哈希、测试数、CI、产物、逐项 pass/fail、未验证项。
9. 最后一句固定提醒：**输出要便于本会话直接验收；不要只写“已修复”。**

## 6. 下一会话的启动指令（可直接粘贴）

> 你接手 Roam Control 的大返工策划与验收。先读 `roam-src/Documentation/Handoffs/2026-10-31-rework-handoff.md`，再检查 `git status`、`git log -1`、版本号和最近 CI。不要直接改代码。按交接文档第 3 节顺序，一次只给一个 Task 的 prompt；当前先给 Task 9R。每条 prompt 都要求执行方输出提交哈希、测试数、CI run、产物 id/大小、真机步骤与截图、逐项状态矩阵。只有当前 Task 验收通过，才生成下一个；不通过就生成完善当前 Task 的 prompt。不要回退 `.gcj02ToWGS84`，不要硬编码坐标偏移，不要把没有真机证据的任务标成 completed。
