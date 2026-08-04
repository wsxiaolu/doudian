# 抖店订单管家（doudian_shop）

一套 Flutter 3.27 + Dart 3.6 写的**抖店商家订单管理系统**，一套代码同时跑在
**Windows 桌面端 / Android / iOS** 三端。主打「抖店订单自动同步、发货一键搞定」，
离线优先、可接云端多端同步。

> 抖店订单只走**官方开放平台 API** 拉取（签名 + 授权令牌），不爬页面、不爬接口。

---

## 功能一览

| 模块 | 说明 |
| --- | --- |
| 订单 | 抖店自动同步 + 手动录入线下单；支持按状态/关键字/日期筛选、排序；单笔与批量发货；发货回写抖店 |
| 订单明细 | 每个订单挂多个商品行（子订单），含售价/成本，用于毛利核算 |
| 商品 | 商品档案（名称/规格/商家编码/成本/售价/库存），下单时直接带出价格 |
| 客户 | 抖店买家自动归档（按 open_id / 手机号去重），支持备注与历史订单 |
| 售后 | 退款/退货/换货/补发统一管理，进度跟踪与退款金额统计 |
| 统计 | 销售额、待发货、售后未结、商品销量 Top 等，含近 6 个月走势 |
| 账号与云端 | Supabase 邮箱注册登录；未配置则自动进入本地模式，数据只存本机 |
| 设置 | 主题、云端配置、抖店接入、同步策略、Excel 数据导出 |
| 数据导出 | 一键把订单/商品/客户/售后导出为 Excel，方便对账盘点 |

---

## 技术架构

- **Flutter 3.27 / Dart 3.6**，三端一套代码。
- **状态管理**：Provider（`ThemeProvider` / `AuthProvider` / `DataProvider` / `SyncService` / `DouyinSyncService`）。
- **离线优先**：本地用 SQLite（`sqflite` + `sqflite_common_ffi`）全量缓存，列表的搜索/筛选/排序/统计全在内存算，断网照常用。
- **云端同步**：Supabase（`supabase_flutter`）做多端双向同步，冲突以「最后修改时间」为准；软删除随同步传播，避免删了又冒出来。
- **数据模型**：每个实体都有 `toDb()`（SQLite，含 `sync_state`）与 `toRemote()`（Supabase，不含 `sync_state`），两端字段严格对齐。
- **设计系统**：统一的 `AppColors` / 间距圆角 / `Fmt` / `AppButton` 等控件，清爽商务简约风，自动适配亮暗主题与桌面/移动布局。

---

## 环境要求

- Flutter **3.27.0**（Dart 3.6.0）
- Windows 10+ / Android 6.0+ / iOS 13+
- 本地模式无需任何后端；多端同步需要自备一个 Supabase 项目

```bash
flutter --version        # 确认 3.27.0
flutter pub get
```

---

## 本地运行

```bash
# 桌面（Windows）
flutter run -d windows

# Android（连上设备 / 模拟器）
flutter run -d android

# iOS（仅 macOS 上可跑）
flutter run -d ios
```

首次启动若未配置 Supabase，会自动进入**本地模式**，所有功能（除云端多端同步外）照常可用。

---

## Supabase 云端配置

1. 到 [supabase.com](https://supabase.com) 新建项目，进入 **SQL Editor**。
2. 打开本项目 `supabase/schema.sql`，全选 → **Run**，一次性建好 7 张表、索引、触发器与 RLS 策略。
3. 在 App 内「设置 → 云端账号」填入项目的 **URL** 与 **Anon Key**。
   （也可以在 `lib/core/config/app_config.dart` 的 `defaultSupabaseUrl` / `defaultSupabaseAnonKey` 里写死出厂默认值，用户开箱即用。）
4. 重启 App 生效，用邮箱注册/登录即可开启多端同步。

> 安全提示：Anon Key 是公开密钥，靠 RLS 策略隔离数据；**不要把 Service Role Key 打进客户端**。
> 抖店 App Key / Secret 等敏感凭据只存于云端 `shop_configs`（对应用户隔离），本地不落库。

---

## 抖店开放平台接入

1. 在抖店开放平台创建应用，拿到 **App Key / App Secret**，自用型应用还需 **店铺 ID**。
2. App 内「设置 → 抖店开放平台」填写并「保存并测试」。
3. 测试通过后会换取访问令牌（存于本地安全存储），之后按设定周期自动拉取新增与变更订单。
4. 订单同步走官方 API，使用 `app_secret` 做 HMAC-SHA256 签名，详见 `lib/data/remote/douyin_api_service.dart`。

---

## Excel 数据导出

设置页「数据导出 → 导出 Excel」会把当前账号的 **订单 / 订单明细 / 商品 / 客户 / 售后**
导出为多 sheet 的 `.xlsx`（列对齐 Supabase 字段，状态/来源等用中文）。
桌面与安卓会弹出目录选择保存；iOS 等不支持目录选择的平台会走系统分享面板决定保存位置。

---

## 三端构建 / 打包

详见 `docs/` 目录：

- [Windows 打包](docs/build_windows.md) —— `flutter build windows`，产出 `build/windows/x64/runner/Release/` 下的可分发 exe 与依赖。
- [Android 打包](docs/build_android.md) —— `flutter build apk --release`（或 App Bundle），产出可安装 APK。
- [iOS 打包](docs/build_ios.md) —— `flutter build ipa`，经 Xcode / Transporter 上架或分发。

---

## 目录结构（节选）

```
lib/
  core/            # 配置、主题、工具、通用控件
  data/
    models/        # 实体 + toDb()/toRemote()
    repositories/  # SQLite 仓储
    remote/        # Supabase、抖店 API 服务
    sync/          # 云端双向同步、抖店增量同步
    export/        # Excel 导出
  state/           # Provider 状态（Auth / Data）
  ui/              # 各业务页面与外壳
supabase/schema.sql   # 云端建表脚本
docs/                  # 三端构建文档
```

---

## License

内部使用。
