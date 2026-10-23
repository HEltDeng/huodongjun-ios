# Luma 对标证据与范围

2026-10-23：用户决定停止安卓参考路线；若不能在 iOS 模拟器安装原版，则直接开发 iOS 对标版本。无需等待原版登录。

参考产品为 **Luma: Events & Invites**，开发者 Luma Labs, Inc.；Android 包名 `com.luma.mobile`，iOS App Store ID `1546150895`。

## 证据边界

已参考公开商店页面及截图，未逐页操作原版 iOS 或 Android 应用。不能将实现中的生日字段、身份表单、权限触发、导航结构或弹窗称为原版已核实行为。它们是当前校园版的实现选择，待有真实参考后继续校正。

| 范围 | 对标证据 | 本地实现 |
| --- | --- | --- |
| 首次启动/登录 | 完整原版流程未验证 | 欢迎、手动同意、本机浏览、资料设置；无真实登录 |
| 发现与详情 | 公开宣传截图，不足以验证全部交互 | 海报卡片、列表、搜索筛选、详情、收藏、分享 |
| 报名与票券 | 全部状态未逐页验证 | 免费活动确认、审核、候补、取消、二维码 |
| 创建与管理 | 原版完整字段未验证 | 校园活动编辑、人数、审核、群信息、名单、核销、取消 |
| 组织与个人 | 原版完整流程未验证 | 组织活动、关注、资料、收藏 |
| 群与综测 | 用户明确要求的校园特色 | 图片/链接、访问限制、本机计分与审核预览 |
| 钱包、付费、多设备消息 | 未核查 | 尚未实现 |

## 环境结论

- App Store 分发的 iPhone 版本不能直接作为 Xcode 模拟器应用安装。自有源码可以编译为模拟器版本，本项目已经实现并安装。
- Android 不是开发本应用的必要依赖。
- 此次新建的 `Luma_Reference_Play_API_36_1` 与专用 `system-images;android-36.1;google_apis_playstore;arm64-v8a` 已卸载。
- 原有 `Pixel_8_API_36_1` 及其系统镜像保留。

## 后续有参考资料时的记录方式

逐项保存原版版本、页面入口、首次/再次打开差异、实际字段、按钮、输入校验、权限拒绝、成功/失败/空状态、关闭与返回行为。将每项原版证据与本地页面对应，避免仅凭介绍页宣称全部一致。

官方参考：

- [Apple：Simulator 中安装应用](https://developer.apple.com/library/archive/documentation/IDEs/Conceptual/iOS_Simulator_Guide/InteractingwiththeiOSSimulator/InteractingwiththeiOSSimulator.html)
- [Android：创建和管理虚拟设备](https://developer.android.com/studio/run/managing-avds)
- [Luma Google Play 页面](https://play.google.com/store/apps/details?id=com.luma.mobile)
- [Luma App Store 页面](https://apps.apple.com/app/id1546150895)
