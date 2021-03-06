import 'dart:collection';

import 'package:flutter/widgets.dart';

import '../../get.dart';

class RouterReportManager<T> {
  /// Holds a reference to `Get.reference` when the Instance was
  /// created to manage the memory.
  /// Route所持有的Instance对象
  static final Map<Route?, List<String>> _routesKey = {};

  /// Stores the onClose() references of instances created with `Get.create()`
  /// using the `Get.reference`.
  /// Experimental feature to keep the lifecycle and memory management with
  /// non-singleton instances.
  /// Route销毁时需要执行的方法（主要是controller中的onClose()方法）
  static final Map<Route?, HashSet<Function>> _routesByCreate = {};

  void printInstanceStack() {
    Get.log(_routesKey.toString());
  }

  static Route? _current;

  // ignore: use_setters_to_change_properties
  static void reportCurrentRoute(Route newRoute) {
    _current = newRoute;
  }

  /// Links a Class instance [S] (or [tag]) to the current route.
  /// Requires usage of `GetMaterialApp`.
  /// 将创建的对象绑定放入到当前Route所管理的类中
  static void reportDependencyLinkedToRoute(String depedencyKey) {
    // _current 是当前最顶层的Route
    if (_current == null) return;
    if (_routesKey.containsKey(_current)) {
      _routesKey[_current!]!.add(depedencyKey);
    } else {
      _routesKey[_current] = <String>[depedencyKey];
    }
  }

  static void clearRouteKeys() {
    _routesKey.clear();
    _routesByCreate.clear();
  }

  // 所有帮当到当前Route的GetLifeCycleBase进行记录，销毁时，执行onDelete方法
  static void appendRouteByCreate(GetLifeCycleBase i) {
    _routesByCreate[_current] ??= HashSet<Function>();
    // _routesByCreate[Get.reference]!.add(i.onDelete as Function);
    _routesByCreate[_current]!.add(i.onDelete);
  }

  static void reportRouteDispose(Route disposed) {
    if (Get.smartManagement != SmartManagement.onlyBuilder) {
      WidgetsBinding.instance!.addPostFrameCallback((_) {
        // 移除所有绑定到Route上的依赖
        _removeDependencyByRoute(disposed);
      });
    }
  }

  static void reportRouteWillDispose(Route disposed) {
    final keysToRemove = <String>[];

    _routesKey[disposed]?.forEach(keysToRemove.add);

    /// Removes `Get.create()` instances registered in `routeName`.
    if (_routesByCreate.containsKey(disposed)) {
      for (final onClose in _routesByCreate[disposed]!) {
        // assure the [DisposableInterface] instance holding a reference
        // to onClose() wasn't disposed.
        onClose();
      }
      _routesByCreate[disposed]!.clear();
      _routesByCreate.remove(disposed);
    }

    for (final element in keysToRemove) {
      GetInstance().markAsDirty(key: element);

      //_routesKey.remove(element);
    }

    keysToRemove.clear();
  }

  /// Clears from memory registered Instances associated with [routeName] when
  /// using `Get.smartManagement` as [SmartManagement.full] or
  /// [SmartManagement.keepFactory]
  /// Meant for internal usage of `GetPageRoute` and `GetDialogRoute`
  static void _removeDependencyByRoute(Route routeName) {
    final keysToRemove = <String>[];

    _routesKey[routeName]?.forEach(keysToRemove.add);

    /// Removes `Get.create()` instances registered in `routeName`.
    if (_routesByCreate.containsKey(routeName)) {
      for (final onClose in _routesByCreate[routeName]!) {
        // assure the [DisposableInterface] instance holding a reference
        // to onClose() wasn't disposed.
        // 重点方法1 调用onClose() 方法
        onClose();
      }
      _routesByCreate[routeName]!.clear();
      _routesByCreate.remove(routeName);
    }

    for (final element in keysToRemove) {
      // 重点方法2 调用delete方法，从内存中移除
      final value = GetInstance().delete(key: element);
      if (value) {
        _routesKey[routeName]?.remove(element);
      }
    }

    keysToRemove.clear();
  }
}
