# 手绘闭环路线与拟人跑步模拟设计

> 状态：提案，等待确认
> 源码基线：`E:\Ai_Agent\RUN\roam-src`（0.9.2 Build 61 源码）
> 日期：2026-10-30

## 1. 意图

这套系统首先要解决的不是“从 A 到 B 的导航”，而是：

> 在操场上手动画出闭合跑道，把路线保存下来；以后从路线库重新选择它，让模拟位置以接近真人的跑步特征持续绕圈。

因此，路线本身必须是可保存、可选择、可恢复的一等数据。Apple 路线规划和 GPX 导入都只是未来向同一条路线模型提供数据的来源，不是首版主链路。

## 2. 目标

### 2.1 首版必须完成

- 在地图上点击加点，形成一条可见的手绘路线。
- 支持撤销最后一个点、清空、闭合路线、命名和保存。
- 闭合路线至少 3 个有效点，开放路线至少 2 个有效点。
- 保存后的路线出现在“我的路线”中；App 退出、重启后仍能重新选择。
- 可从已保存路线直接开始模拟。
- 闭合路线默认支持无限循环；跨过首尾接缝时连续、稳定，不出现停顿或跳点。
- 可配置目标速度、步频、GPS 抖动和速度波动。
- 位置推进表示真实的沿路运动；GPS 抖动只影响上报坐标，不污染路线进度。
- 暂停保持当前点，继续从原进度运行，停止后恢复真实位置。
- App 被中断后，至少能通过路线库重新选择原路线；理想情况下可恢复到上次进度。
- 现有固定位置功能保持可用。

### 2.2 后续完成

- GPX 导入并进入同一个路线库和回放器。
- Apple Maps 路线规划并进入同一个路线库和回放器。
- 路线反向运行。
- 路线编辑增强：拖动顶点、插入点、裁剪、合并。
- GPX 记录与导出。
- 跑步疲劳、起跑加速、偶发停顿等更细的拟人模型。
- 实时活动、快捷指令、摇杆和卡片样式。它们与路线核心解耦，当前不作为验收条件。

## 3. 非目标与反目标

- 不把系统做成逐向导航。
- 不要求首版从 Apple Maps 为操场生成路线；操场通常没有可用的导航路线。
- 不为 GPX 和 Apple 路线各自复制一套运动状态机。
- 不把固定位置强行表示为零长度路线。
- 不在首版同时实现记录、编辑、导出和多种运动模式。
- 不用随机瞬移制造“GPS 抖动”；上报点必须有连续性和可解释的边界。
- 不让 UI 直接推进路线或直接操作设备会话；UI 只读状态和发出命令。

## 4. 当前代码事实

- `HomeView.swift:9-10` 直接持有 `WalkingRoutePlanner` 和 `WalkingSimulationController`。
- `WalkingRoutePlanner.swift:16-37` 固定请求 `.walking`，关闭备选路线。
- `WalkingSimulationController.swift:76-99` 将 `MKRoute` 直接转成 `MKMapPoint`，没有路线值对象。
- `WalkingSimulationController.swift:231-277` 在同一个类里完成计时、插值、UI 状态和设备更新。
- `AppModel.swift:335-350` 只把起点、终点和速度传给设备会话。
- `SessionRecoveryRecord.swift:3-44` 不保存路线几何、圈数或已走进度。
- `HomeView.swift:66-75` 的普通地图点击用于选点；路线编辑必须切换到互斥的输入模式。
- `LocalDeviceSessionCoordinator.swift:217-237` 的 `updateLocation` 是干净的设备输出边界。

这些事实说明：当前 walking 逻辑适合作为行为参考，不适合直接承载手绘路线、持久化和拟人化循环。

## 5. 方案比较

### 方案 A：最小适配

保留 `WalkingSimulationController`，增加一个把点数组伪装成 `MKRoute` 的适配器，再给控制器加 GPX 条件分支。

- 优点：短期改动少。
- 缺点：路线几何、循环、恢复和 UI 状态继续耦合；GPX 会成为第二套特殊逻辑。
- 结论：不采用。

### 方案 B：领域核心优先（采用）

先建立纯 Swift 的路线几何、运行器和拟人运动模型，再加入 MapKit/GPX 适配器和 SwiftUI 界面。

- 优点：所有来源共用一条回放管线；闭环接缝、循环、暂停、抖动和恢复可独立测试。
- 缺点：需要先重构现有 walking 代码，首版不是最快出效果。
- 结论：采用。它符合“先做完整路线系统，再归并来源”的目标。

### 方案 C：完整路线平台

在方案 B 上同时做编辑、记录、导出、多模式和导航。

- 优点：功能最全。
- 缺点：首版范围过大，且会把编辑器和导出格式提前固化。
- 结论：不作为首版。

## 6. 架构

### 6.1 分层

```text
SwiftUI Views
    ↓ commands / snapshots
RouteSessionModel（@MainActor，UI 适配）
    ↓
RouteRunner（纯 Swift 状态机）
    ├── RouteGeometry / RouteSampler
    ├── HumanizedMotionModel
    └── RunProfile
    ↓ LocationFix
LocalDeviceSessionCoordinator（设备输出端口）

RouteStore（路线库持久化）
RouteEditorModel（编辑状态）
```

规则：

- `RouteRunner` 不导入 SwiftUI、MapKit 或 `AppModel`。
- `RouteGeometry` 不依赖 `MKRoute`、`MKMapPoint`。
- MapKit 和 GPX 只负责转换成 `RouteDefinition`。
- UI 不自己计算下一坐标。
- 设备会话失败必须反馈给运行器，并进入明确的失败状态。

### 6.2 核心数据

建议的最小模型：

```swift
struct GeoCoordinate: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double
}

enum RouteSource: String, Codable, Sendable {
    case drawn
    case gpx
    case appleMaps
}

struct RouteDefinition: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var points: [GeoCoordinate]
    var isClosed: Bool
    var source: RouteSource
    let createdAt: Date
    var updatedAt: Date
}

struct RouteGeometry {
    let points: [GeoCoordinate]
    let isClosed: Bool
    let segmentLengths: [Double]
    let totalLength: Double
}
```

`RouteDefinition` 是用户保存的路线；`RouteGeometry` 是从中派生的可计算几何。不要在每个 UI 状态里复制点数组。

### 6.3 几何与闭环接缝

`RouteGeometry` 负责：

- 删除连续重复点，默认阈值 0.5 米。
- 计算每段长度和总长度。
- 按距离返回插值坐标。
- 闭环时额外计算“最后一点到第一点”的闭合段。
- 闭环总长度包含闭合段。
- `distance == totalLength` 时，下一采样点必须是起点，并只增加一圈一次。
- 使用取模处理超出总长的距离，处理浮点边界时使用容差。

闭环示意：

```text
P0 → P1 → P2 → ... → Pn → P0
                              ↑
                         接缝只在这里处理
```

运行器和 UI 不能各自再写一遍首尾接缝逻辑。

### 6.4 运动模型

建议首版参数：

```swift
struct RunProfile: Codable, Equatable, Sendable {
    var targetSpeedMetersPerSecond: Double
    var targetCadenceStepsPerMinute: Double
    var speedVariationFraction: Double
    var cadenceVariationFraction: Double
    var gpsJitterRadiusMeters: Double
    var noiseSeed: UInt64
}
```

约束与语义：

- 目标速度决定地面推进速度。
- 步频是独立的步态指标，界面显示 `spm`；步幅由速度和步频推导，保证数据物理上自洽。
- 速度和步频的变化使用平滑、低频、可复现的噪声，不做每个 tick 的独立随机跳变。
- GPS 抖动用于上报坐标，目标是在路线附近产生小幅偏移；路线进度始终使用未抖动的地面坐标。
- 抖动幅度应被限制，默认建议 1 至 3 米，允许用户设为 0。
- 同样的种子和输入产生同样的输出，便于回归测试和问题复现。
- 首版只做持续跑步；起跑加速、疲劳、红绿灯式停顿后续再加。

运行器的最小状态：

```text
idle → preparing → running ⇄ paused
                         ├→ arrived（开放路线或有限圈数）
                         └→ stopping → idle
                 └→ failed
```

`RouteRunner` 的纯推进接口应是 `advance(by:)`，计时器只负责调用它；这样单元测试可以不依赖真实时间。

### 6.5 路线库与恢复

路线库：

- 保存到 `Application Support/RoamControl/routes.json`，使用原子写入。
- 首版路线数量不大，一个 JSON 文件足够；不引入数据库。
- 路线有稳定 UUID；重命名和编辑不改变 ID。
- 启动时加载；文件损坏时保留错误状态，不静默覆盖用户数据。
- 删除当前正在运行的路线必须被拒绝或先停止运行。

运行恢复：

- 运行开始时保存路线快照、路线 ID、当前圈数、圈内距离、RunProfile 和时间戳。
- 快照独立于路线库；即使用户之后修改或删除路线，恢复记录仍能判断原路线几何。
- 每 5 秒左右持久化一次进度，停止/到达时清理。
- 恢复时从原路线和原进度继续，不能重新请求一条 Apple 路线来代替。

### 6.6 路线编辑与界面

首版交互采用“点击加点”，而不是自由手绘笔刷：

- 进入路线编辑模式后，普通选点行为暂停。
- 单击地图增加一个顶点。
- 地图显示折线和顶点。
- 工具栏提供撤销、清空、闭合、保存和取消。
- 闭合后显示首尾连接线。
- 保存前校验点数、总长度和重复点。
- 已保存路线可重新打开查看、重命名和删除；拖动顶点等编辑增强后续再做。

界面拆分：

- `RouteLibraryView`：我的路线列表，显示名称、距离、闭环状态和最近使用时间。
- `RouteEditorView`：地图加点与保存。
- `RouteRunCard`：圈数、当前速度、步频、进度、暂停/继续/停止。
- `RunProfileView`：目标速度、步频、抖动和波动参数。
- `HomeView`：只负责页面组合和入口，不再直接管理路线状态。

### 6.7 与现有设备会话的边界

`RouteSessionModel` 负责：

1. 取得当前路线和 RunProfile。
2. 启动 `LocalDeviceSessionCoordinator`。
3. 等待设备进入 `.active`。
4. 按固定间隔推进 `RouteRunner`。
5. 将 `LocationFix` 提交给 `updateLocation`。
6. 将设备失败、用户暂停和停止命令同步回运行器。
7. 持久化恢复快照。

`RouteRunner` 只产出坐标和运行指标，不直接调用设备。

## 7. 长期路线图

### M0：基线稳定

- 在 Xcode 中确认 Release 构建。
- 添加 `RoamControlTests` 测试目标。
- 保留现有 fixed location 行为。
- 记录当前 walking 流程作为回归对照。

验收：源码基线可构建，测试目标可运行，未改变现有功能。

### M1：路线几何核心

- 实现 `GeoCoordinate`、`RouteDefinition`、`RouteGeometry`。
- 实现距离、插值、闭环接缝和输入校验。
- 为开放路线与闭环路线建立单元测试。

验收：纯单元测试覆盖边界点、重复点、接缝和 1,000 次绕圈。

### M2：路线库持久化

- 实现 `RouteStore` 和路线列表模型。
- 实现保存、加载、重命名、删除和损坏文件处理。
- 验证 App 重启后仍能加载路线。

验收：保存一个闭环路线，退出并重启，列表仍能选择和显示。

### M3：手绘路线编辑器

- 地图点击加点、撤销、清空、闭合、保存。
- 与普通选点模式互斥。
- 加入最小点数、总长度和重复点提示。

验收：画出操场形闭环，命名保存，重新打开并看到相同几何。

### M4：纯 Swift 路线运行器

- 实现 `RouteRunner`、`advance(by:)`、暂停和到达。
- 实现无限闭环和有限圈数。
- 实现速度、步频和 GPS 抖动模型。
- 先用模拟设备输出验证，不接真实会话。

验收：10 圈连续运行，接缝无停顿；暂停期间坐标不变；步频和速度可复现。

### M5：接入设备会话

- 用 `RouteSessionModel` 连接运行器和 `LocalDeviceSessionCoordinator`。
- 处理启动、设备失败、暂停、停止和真实位置恢复。
- 替换 `HomeView` 中的 walking 专用状态。

验收：已保存的闭环路线可以开始、暂停、继续、停止；停止后恢复真实位置。

### M6：恢复与长期运行验证

- 保存路线快照、圈数和圈内距离。
- 中断 App 后恢复或重新选择路线。
- 进行长时间循环和设备后台测试。
- 更新回归清单。

验收：强制退出后至少能重新选择路线；若启用恢复，能从正确圈数和进度继续。

### M7：后续来源适配

- GPX 导入：使用 Foundation `XMLParser`，转换成 `RouteDefinition`。
- Apple 路线：把 `MKRoute.polyline` 转换成 `RouteDefinition`。
- 两者只实现适配器，不改 `RouteRunner` 和路线库格式。
- GPX 记录/导出和路线编辑增强另行设计。

验收：同一闭环运行器能直接运行手绘、GPX 和 Apple 路线。

## 8. 验收标准

### 路线保存

- 画出的闭环路线可命名保存。
- App 关闭再打开后，路线仍在“我的路线”中。
- 选择旧路线后能再次开始，不需要重新画。
- 重命名和删除不会破坏其他路线。

### 循环

- 闭合路线可无限循环。
- 每圈完成时圈数只增加一次。
- 跨接缝的相邻上报点连续，没有回到起点造成的远距离跳跃。
- 连续 30 分钟或 100 圈后，总里程和圈数没有累计漂移。

### 拟人跑步

- 可设置目标速度或配速，并显示当前速度。
- 可设置步频，显示值在目标值附近平滑波动。
- GPS 抖动有上限，不会产生瞬移。
- 关闭抖动后输出严格沿路线。
- 暂停时坐标保持不动，继续后从暂停点前进。

### 集成

- 设备会话失败会让路线进入明确的失败状态，不继续假跑。
- 停止运行后恢复真实位置。
- 旧的固定位置流程不回归。
- 无障碍字号下路线卡片和编辑器工具栏仍可操作。

## 9. 测试重点

### 纯单元测试

- 开放路线两端插值。
- 闭环路线的闭合段和首尾接缝。
- 刚好等于总长度、超过总长度、浮点容差。
- 重复点、少于最小点数、零长度路线。
- 1000 圈后的圈数和距离精度。
- RunProfile 编解码和参数边界。
- GPS 抖动不超过上限，且相邻点变化连续。
- 暂停/继续不推进距离。
- 恢复快照编解码。

### 模拟器测试

- 绘制、保存、重启加载。
- 路线列表选择、重命名、删除。
- 路线编辑与普通地图选点互斥。
- 大字号和 VoiceOver 基本操作。

### 真机测试

- 配对和 LocalDevVPN 启动。
- 开始、暂停、继续、停止与恢复真实位置。
- 后台运行 10 分钟以上。
- 30 分钟闭环运行的稳定性和耗电观察。
- App 强制退出后的路线库和运行恢复。

## 10. 风险与处理

| 风险 | 处理 |
|------|------|
| 闭环接缝重复计算 | 只在 `RouteGeometry` 计算闭合段，运行器只消费总长度 |
| GPS 抖动污染路线进度 | 进度使用地面坐标，抖动只作用于上报坐标 |
| 1 秒循环在后台被系统挂起 | 先验证现有保活；运行恢复保存时间戳和进度，后续再做后台补偿策略 |
| 路线编辑与普通点击冲突 | 用明确的编辑模式互斥输入，不叠加手势 |
| 路线文件损坏 | 加载失败保留错误和原文件，不静默清空 |
| 路线被编辑后无法恢复运行 | 恢复记录保存路线快照，不依赖当前库中版本 |
| 首版抽象过度 | 只抽出路线几何、运行器、存储和设备边界，不提前做编辑器插件系统 |
| 当前许可证限制 | 当前源码为 PolyForm Noncommercial；若要商业分发，先单独处理授权，不能把技术方案当成授权 |

## 11. 已定的设计选择

- 首版用手绘闭环路线作为主场景。
- 首版采用点击加点，不做自由手绘笔刷。
- 闭环路线默认无限循环；开放路线按单程到达。
- 固定位置继续走现有流程，不并入路线模型。
- 先建立路线核心和路线库，再实现设备接入。
- Apple 路线和 GPX 放到 M7，仅保留适配器边界。
- 不使用第三方路线或 GPS 噪声依赖；标准库、CoreLocation、MapKit 足够。

## 12. 需要评审时确认的点

本文已经把“记录”解释为“我的路线”持久化库，并把“拟人化”收窄为速度波动、步频、平滑 GPS 抖动和可复现随机种子。若“记录”还要求保存每次运行的轨迹历史，或“拟人化”首版就必须包含起跑加速、疲劳和随机停顿，需要在进入实现计划前扩大范围。
