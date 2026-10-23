# Luma 原版交互记录

当前状态：原版应用尚未安装，以下均为待检查清单，不是已观察到的界面事实。

参考应用：Luma: Events & Invites；开发者 Luma Labs, Inc.；Android 包名 `com.luma.mobile`；iOS App Store ID `1546150895`。

2026-10-23 用户确认：用安卓模拟器查看原版，交互由用户操作；首期仍开发 iOS。

## 待检查流程

| 范围 | 需要记录的内容 | 当前证据 |
| --- | --- | --- |
| 首次进入 | 启动画面、欢迎内容、首次/再次打开区别 | 未检查 |
| 登录注册 | 登录方式、验证码、校验、取消和返回 | 未检查 |
| 用户资料 | 实际出现的姓名、头像、年龄等字段及必填规则 | 未检查，不能假定存在年龄页 |
| 权限 | 通知、相机、相册、定位的触发时机和拒绝状态 | 未检查 |
| 主导航 | 默认首页、所有标签、入口和菜单 | 未检查 |
| 活动发现 | 列表、搜索、分类、地点、日期筛选、空状态 | 仅有商店宣传截图，不足以验证流程 |
| 活动详情 | 内容结构、主办方、地点、参与者、分享与收藏 | 未检查 |
| 报名 | 免费/审核/候补、表单、成功、失败、取消 | 未检查 |
| 票券 | 二维码、入场状态、系统钱包、离线行为 | 未检查 |
| 创建活动 | 所有字段、默认值、图片、时间、可见性、预览 | 未检查 |
| 主办方管理 | 编辑、邀请、报名名单、核销、通知、取消 | 未检查 |
| 社群与日历 | 关注、订阅、事件入口、取消订阅 | 未检查 |
| 消息与设置 | 通知、聊天、个人资料、账号与退出 | 未检查 |

## 单条记录模板

- 原版版本号与系统：
- 页面名称和入口：
- 前置条件：
- 页面截图（本机路径，不提交账号资料）：
- 可操作控件：
- 用户操作与结果：
- 弹窗、键盘与校验：
- 返回/关闭后的状态：
- iOS 平台差异：
- 实现与测试状态：

## 已核实的环境限制

- Xcode iOS 模拟器不能直接安装 App Store 分发的 iPhone 应用。我们自己的 iOS 应用可在建立工程后编译为模拟器版本。
- 当前 Xcode 未发现连接的 iPhone 真机。
- 现有 Android AVD `Pixel_8_API_36_1` 使用 Google APIs 镜像，`PlayStore.enabled=no`。需要另建 Google Play AVD；保留原设备。

官方参考：

- [Apple：Simulator 中安装应用](https://developer.apple.com/library/archive/documentation/IDEs/Conceptual/iOS_Simulator_Guide/InteractingwiththeiOSSimulator/InteractingwiththeiOSSimulator.html)
- [Android：创建和管理虚拟设备](https://developer.android.com/studio/run/managing-avds)
- [Luma 的 Google Play 页面](https://play.google.com/store/apps/details?id=com.luma.mobile)
