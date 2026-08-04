import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/app_theme.dart';
import 'core/config/app_config.dart';
import 'data/local/app_database.dart';
import 'data/remote/supabase_service.dart';
import 'data/sync/douyin_sync_service.dart';
import 'data/sync/sync_service.dart';
import 'state/auth_provider.dart';
import 'state/data_provider.dart';
import 'state/theme_provider.dart';
import 'ui/boot/boot_gate.dart';

/// 应用入口
///
/// 启动顺序：
///   1. 初始化 Flutter 绑定；
///   2. 桌面端切换到 sqflite FFI 实现（Windows/Linux 必做，否则 openDatabase 会崩）；
///   3. 初始化 Supabase（未配置则自动进入本地离线模式，不崩）；
///   4. 读取外观偏好；
///   5. 恢复登录态（本地模式 / 已登录云端账号）；
///   6. 装配全局状态并进入 BootGate 决定首屏。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 桌面端（Windows / Linux）必须切换到 FFI 实现，否则 openDatabase 会抛
  // “SQLite is not supported on this platform”，导致启动即闪退。
  AppDatabase.initPlatformFactory();

  // 捕获 Flutter 框架内的构建异常，写入崩溃日志（release 版也能留痕）
  FlutterError.onError = (FlutterErrorDetails details) {
    _writeCrashLog('FlutterError', details.exception, details.stack);
  };

  runZonedGuarded<void>(() async {
    await SupabaseService.instance.initialize();

    final ThemeProvider themeProvider = ThemeProvider();
    await themeProvider.load();

    final AuthProvider authProvider = AuthProvider();
    await authProvider.bootstrap();

    final DataProvider dataProvider = DataProvider();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<DataProvider>.value(value: dataProvider),
          // 两套同步引擎是进程内单例（.instance），此处以 .value 挂入 Provider 树，
          // 让 AppShell 的同步状态指示与设置页的开关能随状态变化即时重建。
          ChangeNotifierProvider<SyncService>.value(value: SyncService.instance),
          ChangeNotifierProvider<DouyinSyncService>.value(
            value: DouyinSyncService.instance,
          ),
        ],
        child: const AppRoot(),
      ),
    );
  }, (Object error, StackTrace stack) {
    // runApp 之前的初始化（Supabase / 本地数据库等）若抛异常，
    // 这里兜底显示一个可读的错误界面，而不是静默退出。
    _writeCrashLog('InitError', error, stack);
    runApp(_fatalScreen(error, stack));
  });
}

/// 启动期致命错误的可读界面（避免 release 版直接闪退无提示）
Widget _fatalScreen(Object error, StackTrace stack) {
  return MaterialApp(
    title: AppConfig.appName,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    home: Scaffold(
      appBar: AppBar(title: const Text('启动失败')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SelectableText(
          '应用启动失败，请将以下内容反馈给开发者：\n\n$error\n\n$stack',
        ),
      ),
    ),
  );
}

/// 把崩溃信息追加写入项目根目录的 crash_log.txt，便于排查
void _writeCrashLog(String tag, Object? error, StackTrace? stack) {
  try {
    const String path = r'C:\doudian\crash_log.txt';
    File(path).writeAsStringSync(
      '[$tag] ${DateTime.now()}\n$error\n$stack\n\n',
      mode: FileMode.append,
    );
  } catch (_) {
    // 写日志失败不影响主流程
  }
}

/// 根组件：负责主题与全局外观装配
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeProvider theme = context.watch<ThemeProvider>();
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      themeMode: theme.mode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeAnimationDuration: const Duration(milliseconds: 420),
      scrollBehavior: const AppScrollBehavior(),
      home: const BootGate(),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        // 限制最大字体缩放，避免大字号下界面被撑破
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
        child: child!,
      ),
    );
  }
}
