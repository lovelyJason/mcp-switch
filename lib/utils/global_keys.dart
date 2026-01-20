import 'package:flutter/material.dart';

/// 全局 ScaffoldKey，用于控制 MainWindow 的 endDrawer（终端抽屉）
final GlobalKey<ScaffoldState> globalScaffoldKey = GlobalKey<ScaffoldState>();

/// 全局 NavigatorKey，用于在 Overlay 中导航
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();
