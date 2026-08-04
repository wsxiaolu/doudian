import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../core/config/pref_keys.dart';
import '../data/local/profile_dao.dart';
import '../data/models/user_profile.dart';
import '../data/remote/supabase_service.dart';
import '../data/sync/douyin_sync_service.dart';
import '../data/sync/sync_service.dart';

/// 账号状态机
enum AuthStatus {
  /// 启动中，正在恢复登录态
  booting,

  /// 未登录
  signedOut,

  /// 已登录（云端账号）
  signedIn,

  /// 本地模式（未配置云端，或用户主动选择只用本机）
  localOnly,
}

/// ============================================================================
/// 账号状态
///
/// 三种运行形态：
///   ① 云端账号  —— 配置了 Supabase 并成功登录，多端同步
///   ② 本地模式  —— 没配置云端 / 用户选择「先本地用着」，数据只存本机
///   ③ 未登录    —— 配置了云端但尚未登录，停留在登录页
///
/// 「记住登录」：Supabase SDK 会把会话持久化并自动续期；
/// 用户若关闭该开关，退出应用时会主动登出。
///
/// 无论哪种形态，登录成功后都会同时挂载两套同步引擎：
///   · [SyncService]        —— 本地 ⇄ Supabase 多端双向同步
///   · [DouyinSyncService]  —— 抖店开放平台订单增量拉取
/// ============================================================================
class AuthProvider extends ChangeNotifier {
  AuthProvider();

  static const String localUserId = 'local-user';

  final ProfileDao _profileDao = const ProfileDao();

  AuthStatus _status = AuthStatus.booting;
  UserProfile? _profile;
  String? _errorText;
  bool _busy = false;
  bool _rememberLogin = true;
  String _lastEmail = '';
  StreamSubscription<sb.AuthState>? _authSub;

  // ---------------------------------------------------------------------------
  // 只读状态
  // ---------------------------------------------------------------------------
  AuthStatus get status => _status;

  UserProfile? get profile => _profile;

  String? get errorText => _errorText;

  bool get busy => _busy;

  bool get rememberLogin => _rememberLogin;

  String get lastEmail => _lastEmail;

  /// 是否已经可以进入主界面
  bool get isAuthenticated =>
      _status == AuthStatus.signedIn || _status == AuthStatus.localOnly;

  /// 当前生效的账号 ID：云端账号用 Supabase uid，本地模式用固定值
  String? get userId {
    if (_status == AuthStatus.localOnly) return localUserId;
    return SupabaseService.instance.currentUserId;
  }

  /// 云端是否可用（决定登录页与设置页的展示分支）
  bool get cloudConfigured => SupabaseService.instance.isConfigured;

  // ---------------------------------------------------------------------------
  // 启动引导
  // ---------------------------------------------------------------------------
  Future<void> bootstrap() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _rememberLogin = prefs.getBool(PrefKeys.rememberLogin) ?? true;
    _lastEmail = prefs.getString(PrefKeys.lastEmail) ?? '';
    final bool localMode = prefs.getBool(PrefKeys.localModeEnabled) ?? false;

    if (!SupabaseService.instance.isConfigured) {
      // 没配置云端 —— 直接进入本地模式，不打扰用户
      await _enterLocalMode(persist: false);
      return;
    }

    // 监听登录态变化（Token 过期、其他端登出等）
    _authSub ??= SupabaseService.instance.authStateChanges.listen(
      (sb.AuthState state) {
        final bool hasSession = state.session != null;
        if (!hasSession && _status == AuthStatus.signedIn) {
          _status = AuthStatus.signedOut;
          _profile = null;
          SyncService.instance.detach();
          DouyinSyncService.instance.detach();
          notifyListeners();
        }
      },
    );

    if (SupabaseService.instance.currentUser != null) {
      await _afterSignedIn();
      return;
    }

    if (localMode) {
      await _enterLocalMode(persist: false);
      return;
    }

    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 注册 / 登录 / 登出
  // ---------------------------------------------------------------------------

  /// 注册新账号。部分 Supabase 项目开启了邮箱验证，此时不会立即产生会话，
  /// 返回 false 并提示用户先去邮箱确认。
  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    return _guard(() async {
      final sb.AuthResponse res = await SupabaseService.instance.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      await _rememberEmail(email);
      if (res.session == null) {
        _errorText = '注册成功，请先到邮箱点击确认链接，然后返回登录';
        notifyListeners();
        return false;
      }
      await _afterSignedIn(fallbackName: displayName);
      return true;
    });
  }

  /// 邮箱密码登录
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    return _guard(() async {
      await SupabaseService.instance.signIn(email: email, password: password);
      await _rememberEmail(email);
      await _afterSignedIn();
      return true;
    });
  }

  /// 找回密码
  Future<bool> sendResetMail(String email) async {
    return _guard(() async {
      await SupabaseService.instance.resetPassword(email);
      _errorText = '重置邮件已发送，请到邮箱查收';
      notifyListeners();
      return true;
    });
  }

  /// 退出登录 / 切换账号
  Future<void> signOut() async {
    _busy = true;
    notifyListeners();
    try {
      await SupabaseService.instance.signOut();
    } catch (e) {
      debugPrint('[Auth] 登出异常（忽略）: $e');
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefKeys.localModeEnabled, false);

    SyncService.instance.detach();
    DouyinSyncService.instance.detach();
    _profile = null;
    _errorText = null;
    _busy = false;
    // 退出后回到登录/本地模式选择页，由用户决定下一步
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  /// 主动选择「先在本机使用」
  Future<void> useLocalMode() => _enterLocalMode(persist: true);

  Future<void> _enterLocalMode({required bool persist}) async {
    if (persist) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PrefKeys.localModeEnabled, true);
    }

    UserProfile? cached = await _profileDao.findById(localUserId);
    cached ??= UserProfile(
      id: localUserId,
      displayName: '本地用户',
      updatedAt: DateTime.now(),
      isLocalOnly: true,
    );
    await _profileDao.upsert(cached);

    _profile = cached;
    _status = AuthStatus.localOnly;
    _errorText = null;
    notifyListeners();

    // 本地模式同样挂载同步服务：
    // 抖店订单照样能自动拉取，以后配置了云端并登录也可无缝接续
    await SyncService.instance.attach(localUserId);
    await DouyinSyncService.instance.attach(localUserId);
  }

  // ---------------------------------------------------------------------------
  // 登录成功后的收尾：加载资料 + 启动同步
  // ---------------------------------------------------------------------------
  Future<void> _afterSignedIn({String? fallbackName}) async {
    final sb.User? user = SupabaseService.instance.currentUser;
    if (user == null) {
      _status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }

    // 先用本地缓存兜底，保证断网也能立刻展示昵称
    UserProfile profile = await _profileDao.findById(user.id) ??
        UserProfile(
          id: user.id,
          email: user.email,
          displayName:
              fallbackName ?? (user.userMetadata?['display_name'] as String?),
          updatedAt: DateTime.now(),
        );
    profile = profile.copyWith(email: user.email);

    try {
      final Map<String, dynamic>? remote =
          await SupabaseService.instance.fetchProfile(user.id);
      if (remote != null) {
        profile = UserProfile.fromRemote(remote, email: user.email);
      } else {
        // 云端还没有资料行（触发器未生效时），补写一条
        await SupabaseService.instance.upsertProfile(profile.toRemote());
      }
    } catch (e) {
      debugPrint('[Auth] 拉取云端资料失败，使用本地缓存: $e');
    }

    await _profileDao.upsert(profile);
    _profile = profile;
    _status = AuthStatus.signedIn;
    _errorText = null;
    notifyListeners();

    await SyncService.instance.attach(user.id);
    await DouyinSyncService.instance.attach(user.id);
  }

  // ---------------------------------------------------------------------------
  // 个人资料
  // ---------------------------------------------------------------------------
  Future<bool> updateProfile({
    required String displayName,
    String? shopName,
    String? phone,
  }) async {
    final UserProfile? current = _profile;
    if (current == null) return false;

    final UserProfile updated = current.copyWith(
      displayName: displayName.trim(),
      shopName: shopName?.trim(),
      phone: phone?.trim(),
      updatedAt: DateTime.now(),
    );
    await _profileDao.upsert(updated);
    _profile = updated;
    notifyListeners();

    // 云端账号顺带同步一份到 Supabase，失败不影响本地保存
    if (_status == AuthStatus.signedIn) {
      try {
        await SupabaseService.instance.upsertProfile(updated.toRemote());
      } catch (e) {
        debugPrint('[Auth] 资料同步云端失败: $e');
        return false;
      }
    }
    return true;
  }

  Future<void> setRememberLogin(bool value) async {
    _rememberLogin = value;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefKeys.rememberLogin, value);
  }

  void clearError() {
    if (_errorText == null) return;
    _errorText = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 通用异常包装：统一置忙、统一中文化错误
  // ---------------------------------------------------------------------------
  Future<bool> _guard(Future<bool> Function() action) async {
    _busy = true;
    _errorText = null;
    notifyListeners();
    try {
      return await action();
    } catch (e) {
      _errorText = SupabaseService.describeError(e);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _rememberEmail(String email) async {
    _lastEmail = email.trim();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefKeys.lastEmail, _lastEmail);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
