import 'package:reborn/enums/decode_mode.dart';
import 'package:reborn/enums/methods.dart';
import 'package:reborn/utils/extensions/string_extensions.dart';

import 'http_route.dart';

class RouteMatcher {
  static Iterable<HttpRouteMatch> match(
      String input, List<HttpRoute> options, Method method) sync* {
    // decode URL path before matching except for "/"
    final inputPath = Uri.parse(input)
        .path
        .normalizePath
        .decodeUri(DecodeMode.allExceptSlash);

    for (final option in options) {
      // Check if http method matches
      if (!option.methods.contains(method)) {
        continue;
      }

      // Match against route RegExp and capture params if valid
      RegExpMatch? match;

      for (var matcher in option.listMatchers) {
        match = matcher.firstMatch(inputPath);
        if (match != null) break;
      }

      if (match != null) {
        final routeMatch = HttpRouteMatch.tryParse(option, match);
        if (routeMatch != null) {
          yield routeMatch;
        }
      }
    }
  }
}

/// Retains the matched route and parameter values extracted
/// from the Uri
///
class HttpRouteMatch {
  HttpRouteMatch._(this.route, this.params);

  static HttpRouteMatch? tryParse(HttpRoute route, RegExpMatch match) {
    try {
      final params = <String, dynamic>{};
      for (var param in route.params) {
        var value = match.namedGroup(param.name);
        if (value == null) {
          if (param.pattern != '*') {
            return null;
          }
          value = '';
        }
        params[param.name] = param.getValue(value);
      }
      return HttpRouteMatch._(route, params);
    } catch (e) {
      return null;
    }
  }

  final HttpRoute route;
  final Map<String, dynamic> params;
}
