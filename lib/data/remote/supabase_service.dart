import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/config/pref_keys.dart';

/// ============================================================================
/// Supabase 云端服务封装
///
/// 设计要点：
///   1. URL / Key 支持「编译期默认值」和「运行时在设置页填写」两种来源，
///      运行时填写的优先，修改后需要重启 App 生效（Supabase SDK 只能初始化一次）；
///   2. 未配置时 [isConfigured] 为 false，整个 App 自动进入纯本地离线模式，
///      不会因为缺少后端而崩溃；
///   3. 所有网络调用都不把「原始异常」抛给界面，而是统一转成中文可读信息。
/// ============================================================================
class SupabaseService {
  SupabaseService._internal();

  static final SupabaseService instance = SupabaseService._internal();

  bool _initialized = false;
  String _url = '';
  String _anonKey = '';

  /// 是否已成功初始化云端连接
  bool get isConfigured => _initialized;

  String get url => _url;

  /// 密钥脱敏展示，设置页只回显头尾
  String get anonKeyMasked {
    if (_anonKey.length < 12) return _anonKey.isEmpty ? '（未填写）' : '******';
    return '${_anonKey.substring(0, 6)}······'
        '${_anonKey.substring(_anonKey.length - 4)}';
  }

  SupabaseClient get client => Supabase.instance.client;

  /// 当前登录用户（未登录或未配置返回 null）
  User? get currentUser => _initialized ? client.auth.currentUser : null;

  String? get currentUserId => currentUser?.id;

  // ---------------------------------------------------------------------------
  // 初始化：在 main() 里 runApp 之前调用
  // ---------------------------------------------------------------------------
  Future<void> initialize() async {
    if (_initialized) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // 运行时配置优先于编译期默认值
    _url = (prefs.getString(PrefKeys.supabaseUrl) ?? '').trim();
    _anonKey = (prefs.getString(PrefKeys.supabaseAnonKey) ?? '').trim();
    if (_url.isEmpty) _url = AppConfig.defaultSupabaseUrl.trim();
    if (_anonKey.isEmpty) _anonKey = AppConfig.defaultSupabaseAnonKey.trim();

    if (_url.isEmpty || _anonKey.isEmpty) {
      debugPrint('[Supabase] 未配置 URL / Key，进入本地离线模式');
      return;
    }

    try {
      // SDK 默认会把会话持久化到本地并自动续期，正是「记住登录状态」所需要的行为
      await Supabase.initialize(
        url: _url,
        // publishableKey 兼容新版 sb_publishable_ 格式密钥（anonKey 已废弃）
        publishableKey: _anonKey,
        debug: false,
      );
      _initialized = true;
      debugPrint('[Supabase] 初始化成功: $_url');
    } catch (e) {
      _initialized = false;
      debugPrint('[Supabase] 初始化失败，回退到本地模式: $e');
    }
  }

  /// 保存新的云端配置（下次启动生效）
  static Future<void> saveConfig({
    required String url,
    required String anonKey,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefKeys.supabaseUrl, url.trim());
    await prefs.setString(PrefKeys.supabaseAnonKey, anonKey.trim());
  }

  /// 读取已保存的云端配置（用于设置页回显）
  static Future<(String url, String anonKey)> loadConfig() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String u =
        (prefs.getString(PrefKeys.supabaseUrl) ?? AppConfig.defaultSupabaseUrl)
            .trim();
    final String k = (prefs.getString(PrefKeys.supabaseAnonKey) ??
            AppConfig.defaultSupabaseAnonKey)
        .trim();
    return (u, k);
  }

  // ===========================================================================
  // 账号体系
  // ===========================================================================

  /// 注册
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _ensureReady();
    return client.auth.signUp(
      email: email.trim(),
      password: password,
      data: <String, dynamic>{
        if (displayName != null && displayName.trim().isNotEmpty)
          'display_name': displayName.trim(),
      },
    );
  }

  /// 密码登录
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    _ensureReady();
    return client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// 退出登录
  Future<void> signOut() async {
    if (!_initialized) return;
    await client.auth.signOut();
  }

  /// 发送重置密码邮件
  Future<void> resetPassword(String email) async {
    _ensureReady();
    await client.auth.resetPasswordForEmail(email.trim());
  }

  /// 监听登录态变化（多端踢出、Token 失效等）
  Stream<AuthState> get authStateChanges => _initialized
      ? client.auth.onAuthStateChange
      : const Stream<AuthState>.empty();

  // ===========================================================================
  // 用户资料
  // ===========================================================================
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    _ensureReady();
    final List<Map<String, dynamic>> rows =
        await client.from('user_profiles').select().eq('id', userId).limit(1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> upsertProfile(Map<String, dynamic> payload) async {
    _ensureReady();
    await client.from('user_profiles').upsert(payload);
  }

  // ===========================================================================
  // 抖店应用配置（跟着账号走，换台电脑登录同一账号即可继续同步）
  // ===========================================================================
  Future<Map<String, dynamic>?> fetchShopConfig(String userId) async {
    _ensureReady();
    final List<Map<String, dynamic>> rows = await client
        .from('shop_configs')
        .select()
        .eq('user_id', userId)
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> upsertShopConfig(Map<String, dynamic> row) async {
    _ensureReady();
    await client.from('shop_configs').upsert(row);
  }

  // ===========================================================================
  // 通用数据同步接口
  // ===========================================================================

  /// 拉取自 [since] 之后有变动的记录（含被软删除的，保证删除也能同步）
  Future<List<Map<String, dynamic>>> fetchUpdatedSince({
    required String table,
    required String userId,
    required DateTime since,
    int limit = 2000,
  }) async {
    _ensureReady();
    final List<Map<String, dynamic>> rows = await client
        .from(table)
        .select()
        .eq('user_id', userId)
        .gt('updated_at', since.toUtc().toIso8601String())
        .order('updated_at', ascending: true)
        .limit(limit);
    return rows;
  }

  /// 批量上推（存在则更新，不存在则插入）
  Future<void> pushRows({
    required String table,
    required List<Map<String, dynamic>> rows,
  }) async {
    _ensureReady();
    if (rows.isEmpty) return;
    // 分批提交，避免单次请求体过大被网关拒绝
    const int chunkSize = 200;
    for (int i = 0; i < rows.length; i += chunkSize) {
      final int end =
          (i + chunkSize) > rows.length ? rows.length : (i + chunkSize);
      await client.from(table).upsert(rows.sublist(i, end));
    }
  }

  /// 轻量连通性探测：用于设置页「测试连接」
  Future<bool> ping() async {
    if (!_initialized) return false;
    try {
      await client.from('user_profiles').select('id').limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _ensureReady() {
    if (!_initialized) {
      throw const CloudNotConfiguredException();
    }
  }

  // ===========================================================================
  // 异常信息中文化
  // ===========================================================================
  static String describeError(Object error) {
    if (error is CloudNotConfiguredException) {
      return '尚未配置云端账号，请先到「设置 → 云端账号配置」填写 Supabase 地址与密钥';
    }
    if (error is AuthException) {
      final String msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials')) return '邮箱或密码不正确';
      if (msg.contains('user already registered')) return '该邮箱已注册，请直接登录';
      if (msg.contains('email not confirmed')) {
        return '邮箱尚未验证，请到邮箱点击确认链接后再登录';
      }
      if (msg.contains('password should be at least')) {
        return '密码强度不足，请至少 6 位';
      }
      if (msg.contains('rate limit') || msg.contains('too many')) {
        return '操作过于频繁，请稍后再试';
      }
      return '账号服务返回错误：${error.message}';
    }
    if (error is PostgrestException) {
      if (error.code == '42P01') {
        return '云端数据表不存在，请先在 Supabase 执行 supabase/schema.sql 建表脚本';
      }
      if ('${error.message}'.contains('row-level security')) {
        return '数据权限校验未通过，请确认已执行建表脚本中的 RLS 策略';
      }
      return '云端数据错误：${error.message}';
    }
    final String text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('Connection')) {
      return '网络连接失败，已切换为离线模式，数据会在联网后自动同步';
    }
    if (text.contains('TimeoutException')) {
      return '网络请求超时，请稍后重试';
    }
    return '操作失败：$text';
  }
}

/// 未配置云端时抛出的专用异常
class CloudNotConfiguredException implements Exception {
  const CloudNotConfiguredException();

  @override
  String toString() => 'CloudNotConfiguredException';
}
