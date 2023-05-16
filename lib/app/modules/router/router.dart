import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:reborn/app/modules/router/reborn_router.dart';

import 'package:reborn/enums/methods.dart';

import 'http_route.dart';

mixin Router {
  @visibleForOverriding
  RebornApp get app;

  /// A prefix for all routes path
  ///
  /// Examples: `api`, `rebornapi`
  String get pathPrefix;

  /// Creates a new route for incoming requests
  ///
  /// Given a [List] of paths
  ///
  /// A [Function] handler
  ///
  /// A [List] of supported [Method]'s
  HttpRoute request(List<String> paths,
          FutureOr Function(HttpRequest req, HttpResponse res) handler,
          {List<Method> supportedMethods = const [Method.get]}) =>
      _createRoute(supportedMethods, paths, handler);

  HttpRoute _createRoute(List<Method> methods, List<String> paths,
      FutureOr Function(HttpRequest req, HttpResponse res) handler) {
    final List<String> listPaths = [];

    for (var path in paths) {
      listPaths.add('${pathPrefix == '' ? '' : '$pathPrefix/'}$path');
    }

    final route =
        HttpRoute(routes: listPaths, handler: handler, methods: methods);
    app.routes.add(route);
    return route;
  }
}
