import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 原生 Splash 屏幕服务
///
/// 用于控制应用启动时显示的原生 Splash 屏幕。
/// Splash 显示在 Flutter 引擎初始化期间,防止黑屏。
///
/// 功能:
/// - 隐藏 Splash 屏幕
/// - 配置 Splash 过渡效果
/// - 配置是否显示进度条
///
/// 使用方式:
/// 在 Flutter 首帧渲染后(通常在 main.dart 或 App 初始化完成后)
/// 调用 `SplashService.hideSplash()` 隐藏 Splash。
class SplashService {
  SplashService._();

  /// Platform Channel 名称,与原生端保持一致
  static const String _channelName = 'com.mcpswitch.splash';

  /// Method Channel 实例
  static const MethodChannel _channel = MethodChannel(_channelName);

  /// Splash 过渡效果类型
  static SplashTransitionType _transitionType = SplashTransitionType.fadeOut;

  /// Splash 过渡动画持续时间(秒)
  static double _transitionDuration = 0.3;

  /// 是否显示进度条
  static bool _showProgressBar = true;

  /// 获取当前过渡效果类型
  static SplashTransitionType get transitionType => _transitionType;

  /// 设置过渡效果类型
  static set transitionType(SplashTransitionType value) {
    _transitionType = value;
    _syncConfiguration();
  }

  /// 获取当前过渡动画持续时间
  static double get transitionDuration => _transitionDuration;

  /// 设置过渡动画持续时间
  static set transitionDuration(double value) {
    _transitionDuration = value;
    _syncConfiguration();
  }

  /// 获取是否显示进度条
  static bool get showProgressBar => _showProgressBar;

  /// 设置是否显示进度条
  static set showProgressBar(bool value) {
    _showProgressBar = value;
    _syncConfiguration();
  }

  /// 隐藏 Splash 屏幕
  ///
  /// 在 Flutter 首帧渲染后调用此方法,触发 Splash 淡出动画。
  /// 动画完成后 Splash 视图将被销毁。
  static Future<void> hideSplash() async {
    try {
      await _channel.invokeMethod<void>('hideSplash');
      debugPrint('[SplashService] hideSplash() success');
    } on PlatformException catch (e) {
      // Splash 可能已经隐藏或不存在,忽略错误
      debugPrint('[SplashService] hideSplash PlatformException: ${e.code} - ${e.message}');
    } on MissingPluginException catch (e) {
      // Channel 未注册
      debugPrint('[SplashService] hideSplash MissingPluginException: $e');
    } catch (e, stack) {
      // 捕获其他异常
      debugPrint('[SplashService] hideSplash error: $e');
      debugPrint('[SplashService] stack: $stack');
    }
  }

  /// 显示 Splash 屏幕 (调试用)
  ///
  /// 重新创建并显示 Splash 屏幕,用于调试 Splash 样式。
  /// [duration] 显示时长(毫秒),默认 3000ms 后自动隐藏
  static Future<void> showSplash({int duration = 3000}) async {
    debugPrint('[SplashService] showSplash() called, duration: ${duration}ms');
    try {
      await _channel.invokeMethod<void>('showSplash', {'duration': duration});
      debugPrint('[SplashService] showSplash() success');
    } on PlatformException catch (e) {
      debugPrint('[SplashService] showSplash PlatformException: ${e.code} - ${e.message}');
    } on MissingPluginException catch (e) {
      debugPrint('[SplashService] showSplash MissingPluginException: $e');
    } catch (e, stack) {
      debugPrint('[SplashService] showSplash error: $e');
      debugPrint('[SplashService] stack: $stack');
    }
  }

  /// 配置 Splash 屏幕选项
  ///
  /// 此方法应在 Splash 显示期间调用(即隐藏之前),
  /// 用于调整过渡效果等参数。
  ///
  /// [transitionType] 过渡效果类型
  /// [transitionDuration] 过渡动画持续时间(秒)
  /// [showProgressBar] 是否显示进度条
  static Future<void> configure({
    SplashTransitionType? transitionType,
    double? transitionDuration,
    bool? showProgressBar,
  }) async {
    if (transitionType != null) _transitionType = transitionType;
    if (transitionDuration != null) _transitionDuration = transitionDuration;
    if (showProgressBar != null) _showProgressBar = showProgressBar;

    await _syncConfiguration();
  }

  /// 同步配置到原生端
  static Future<void> _syncConfiguration() async {
    try {
      await _channel.invokeMethod('configureSplash', {
        'transitionType': _transitionType == SplashTransitionType.crossDissolve
            ? 'crossDissolve'
            : 'fadeOut',
        'transitionDuration': _transitionDuration,
        'showProgressBar': _showProgressBar,
      });
    } on PlatformException catch (e) {
      // 配置失败时忽略,不影响正常功能
      // ignore: avoid_print
      print('SplashService.configure failed: ${e.message}');
    }
  }
}

/// Splash 过渡效果类型
enum SplashTransitionType {
  /// 简单淡出
  fadeOut,

  /// 与 Flutter 视图交叉溶解
  crossDissolve,
}
