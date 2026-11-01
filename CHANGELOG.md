# Changelog

All notable public changes to Roam Control are recorded here.

## [Unreleased]

Roam Control 0.9.2 Preview - Build 58. Public validation preview; Beta 6 / Build 57 remains the recommended release until validation.

### Fixed

- Build 58: derive pairing and location continued-processing task prefixes only from the runtime bundle identifier; require the exact runtime-rooted permitted wildcard and stop before registration when it is missing. Remove cross-bundle fallback and development-team plist variants. Preserve Build 57 telemetry and the existing immediate-failure scheduling strategy.

- Build 55: validate each generated location continued-processing identifier against the app's runtime permitted-identifier list before registration; reject obsolete or cancelled location-task launch callbacks and submission completions.
- Build 55: expose only fixed location-task configuration and registration states in copied diagnostics. These checks narrow configuration and lifecycle failures but do not establish that iOS `schedulerRegistration` failures are fixed.

- Build 53: guard submission before scheduling and cancel obsolete completions; keep pairing busy during secure storage and guard its completion; report terminal failure once per attempt, including teardown after cancellation.

- Build 53: retain fixed scheduler rejection reasons in pairing/session telemetry and copied diagnostics; reject late pairing launch callbacks and clean up cancelled pre-worker requests.
- Build 53: bound the native stop-simulation response wait, propagate clear errors through cancellation, and distinguish stop acknowledgement from unverified real-location reacquisition. Rebuilt both native slices.
- Build 53: retain local session failure stage/disposition, correct premature real-location-restored wording, and add cautious other-VPN comparison guidance without detection or sensitive network telemetry.

- Separated recoverable scheduler/tunnel interruptions into Connection.RecoveryNeeded, reserving Failure.Observed for terminal operation failures. Added a fixed disposition field so corrected data can be filtered separately from historical observations. Included in Build 52; earlier IPAs are unchanged.

- Added one bounded automatic discovery retry after enabling LocalDevVPN before showing manual connection help; foreground wait and cancellation are bounded. Owner-device automatic recovery verified on Build 53; affected-user verification remains open.

- Prevented cancelled discovery and connection-check timers from failing a replacement attempt.
- Fixed a pairing-session lifetime race when cancelling near native completion.
- Ignored obsolete or cancelled background-task submission failures.
- Suppressed repeated identical failure notifications during worker teardown to avoid duplicate failure counts.

### Improved

- Added the consent-gated first-party self-hosted telemetry destination. Configured beta builds continue sending the same fixed event to TelemetryDeck in parallel; no location, pairing material, free-form error text or diagnostics are added.
- Updated the in-app and repository privacy disclosures for both telemetry destinations, HTTPS connection metadata, the self-hosted live database's daily 90-day retention, backup/access-log limitations and consent withdrawal behaviour.

- Connection Health now verifies TCP reachability of the matched pairing service, and explains that secure session verification happens during session startup.
- Added fixed failure-stage and operation categories to optional telemetry, including recoverable native startup failures and background-task submission failures.
- Added connection-help, manual retry and successful-after-retry events to show recoverable connection friction.
- Updated the anonymous-statistics disclosure and user guide. No locations, searches, pairing records, credentials, PINs, device names or raw error text are transmitted.
- Removed macOS metadata files from test IPA packaging after an installation signature-verification failure; metadata was a suspected contributor, not a confirmed root cause.

### Validation and remaining work

- Build 54 was a private diagnostic build focused only on location-task registration validation and copied diagnostics. It was not committed, its exact source was not retained in Git, and external validation was limited. Build 55 reconstructs and carries forward that narrow intent; Build 54 must not be cited as proof of a scheduler fix.
- A targeted Build 29 versus current audit found no material change to the generated location-task identifier pattern, permitted wildcard configuration, registration API call or immediate-run strategy. Later builds added recovery paths and asynchronous lifecycle guards. The missing location callback identity guard was a plausible stale-callback risk after a retry, but it does not explain `register(...) == false` by itself.
- Build 56 consent gating was verified on the final SideStore-installed release candidate against the live self-hosted backend. After sharing was explicitly disabled, a force-close and relaunch produced no new self-hosted event. After sharing was enabled, participation and activation events were accepted by the backend. This verifies the Build 56 self-hosted consent gate; separate TelemetryDeck request verification remains open.

- Build 56 source invariants and release checks passed on the owner's Mac. The final unsigned Release IPA passed ZIP and identity checks, was installed through SideStore, and passed owner-device fixed-location, Stop & Restore and self-hosted telemetry consent-gating validation.
- Owner-device Build 53 testing passed repeated pairing cancellation and subsequent pairing, Wi-Fi automatic recovery, 5G startup/guidance, and quick stop/restore on both networks. Recoverable scheduler classification matched the active session diagnostics.
- First pairing attempt timed out; suspected manual-step delay is unconfirmed. Immediate retry succeeded.
- The Build 52 restoration delay was not reproduced. Affected-user pairing/session reports and other-VPN interference remain open; no universal fix is claimed.
- Walking-session foreground/background continuity and Stop & Restore also passed owner-device smoke testing on Build 53.

## [0.10.0] - 待发布（真机验收进行中）

尚未在 GitHub 发布 release，也没有可下载的构建。以下条目描述代码层面的行为；需要真机判定的表现统一登记在 `Documentation/Handoffs/2026-10-31-rework-handoff.md` 第 7 节，尚未标记为已验证。

### Added

- 手绘闭环路线：点击加点的编辑器、每条路线的跑步配置、路线库持久化到 `Application Support/RoamControl/routes.json`，支持重命名与删除。
- 开放路线可按趟数折返：偶数趟停在起点，奇数趟停在终点，运行卡显示 `1/3`、`2/3` 形式的趟数指标而不是 `Laps`。
- 拟人跑步模拟：速度波动、步频与平滑 GPS 抖动；抖动只影响上报坐标，不移动已保存的路线进度。
- 运行卡片与主页整合；中断的运行可从恢复卡继续，恢复卡显示路线名、圈数与圈内进度。
- 地图样式（standard / satellite / hybrid）在主地图与路线编辑器之间共用一套映射，编辑器跟随当前样式并可原地切换。
- 简体中文与语言切换：`AppLanguage` 由生效语言推导是否需要重启提示，本地化目录覆盖 615 个 key。

### Changed

- 反馈、Issue 与更新检查地址统一由 `AppRepository` 派生并指向 `FaHits/Roam-Control`；未发布 release 时显示「该仓库尚未发布版本。」，不再显示上游版本号。
- 注入到设备会话的坐标在唯一注入边界做 GCJ-02 → WGS-84 转换。
- 移除可选匿名统计全链路：设置分区、Onboarding 共享卡、上报客户端、自托管与 TelemetryDeck 目的地，以及 `PrivacyInfo.xcprivacy` 中的采集条目。
- 路线库删除改为确认后才移除数据，确认框打开期间行不再塌陷。

### Fixed

- 第三方输入法（如微信输入法）在未提交候选文字时 Rename 按钮不可用。
- 空名称或纯空白名称不再静默保存，改为提示「路线名称不能为空。」
- 路线编辑器的地图样式浮层补 `import SwiftUI`，修复样式控件不渲染。

## [0.9.1] - 2026-09-10

First beta polish release, corresponding to app version 0.9.1 Build 47.

### Improved

- Made location restoration clearer: confirmation, visible restoration progress and a clean return to the ready state.
- Improved interrupted-session recovery and removed unnecessary resume controls after a successful stop and restore.
- Kept active location sessions reliable in the background while allowing the Dynamic Island presentation to stay compact.
- Restored richer, faster place-search results, including useful address detail.
- Added drag-to-reorder for favourites while keeping history in chronological order.
- Made the selected map location reliably recenter when returning to it.

### Added

- Added **Copy Diagnostics** under Settings → Connection Health. The copied report deliberately excludes locations, searches, pairing records, PINs, device names and error text.
- Added Settings links for GitHub bug reports and feature requests, plus structured GitHub issue forms.
- Added a manual **Check for Updates** control in Settings that checks only the public GitHub release.
- Added privacy-preserving telemetry for handled pairing, preparation, restoration, start and LocalDevVPN failures.

## [0.9.0-beta.1] - 2026-09-04

First public beta, corresponding to app version 0.9.0 Build 29.

### Added

- Fixed reported locations selected by search, coordinates or map pin.
- Live MapKit search, favourites, history and renamed saved places.
- Walking-route preview, pace control, pause/resume, reverse and redirect.
- Native on-device pairing with secure Keychain storage.
- Guided LocalDevVPN flows for Wi-Fi and mobile data.
- Interrupted-session recovery and explicit real-location restoration.
- Light, dark and automatic appearance; map styles; Dynamic Type, VoiceOver and Reduce Motion support.
- Optional, off-by-default anonymous usage statistics with an in-app disclosure and Apple privacy manifest.

### Privacy and release hardening

- Removed per-launch analytics session identifiers.
- Preserved existing consent choices while defaulting new installations to sharing off.
- Prevented failed location updates from being counted as successful.
- Moved the release analytics destination and Apple development-team identifier out of tracked project settings.

[Unreleased]: https://github.com/seanhowarthdev/Roam-Control/compare/v0.9.1...HEAD
[0.9.1]: https://github.com/seanhowarthdev/Roam-Control/compare/v0.9.0-beta.1...v0.9.1
[0.9.0-beta.1]: https://github.com/seanhowarthdev/Roam-Control/releases/tag/v0.9.0-beta.1
