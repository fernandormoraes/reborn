import 'dart:async';
import 'dart:io';

import 'package:reborn/enums/methods.dart';
import 'package:reborn/utils/extensions/string_extensions.dart';

import 'http_route_param.dart';

class HttpRoute {
  final List<Method> methods;
  final List<String> routes;
  final FutureOr Function(HttpRequest request, HttpResponse response) handler;

  // The RegExp used to match the input URI
  late final List<RegExp> listMatchers = [];

  final Map<String, HttpRouteParam> _params = <String, HttpRouteParam>{};

  Iterable<HttpRouteParam> get params => _params.values;

  HttpRoute(
      {required this.routes, required this.handler, required this.methods}) {
    // Split route path into segments

    /// Because in dart 2.18 uri parsing is more permissive, using a \ in regex
    /// is being counted as a /, so we need to add an r and join them together
    /// VERY happy for a more elegant solution here than some random escape
    /// sequence.
    const escapeChar = '@@@^';
    List<String> escapedPaths = [];
    List<List<String>> listSegments = [];

    for (String route in routes) {
      escapedPaths.add(route.replaceAll('\\', escapeChar));
      listSegments.add([route.normalizePath]);
    }

    for (int counter = 0; counter < escapedPaths.length; counter++) {
      List<String>? pathSegments =
          Uri.tryParse('/${escapedPaths[counter]}')?.pathSegments;

      if (pathSegments != null) {
        listSegments[counter] = pathSegments;
      }
    }

    for (List<String> segment in listSegments) {
      segment = segment.map((e) => e.replaceAll(escapeChar, '\\')).toList();
    }

    for (List<String> segments in listSegments) {
      String pattern = '^';

      for (var segment in segments) {
        if (segment == '*' &&
            segment != segments.first &&
            segment == segments.last) {
          // Generously match path if last segment is wildcard (*)
          // Example: 'some/path/*' => should match 'some/path', 'some/path/', 'some/path/with/children'
          //                           but not 'some/pathological'
          pattern += r'(?:/.*|)';
          break;
        } else if (segment != segments.first) {
          // Add path separators
          pattern += '/';
        }

        // parse parameter if any
        final param = HttpRouteParam.tryParse(segment);
        if (param != null) {
          if (_params.containsKey(param.name)) {
            throw Exception(param.name);
          }
          _params[param.name] = param;
          // ignore: prefer_interpolation_to_compose_strings
          segment = r'(?<' + param.name + r'>' + param.pattern + ')';
        } else {
          // escape period character
          segment = segment.replaceAll('.', r'\.');
          // wildcard ('*') to anything
          segment = segment.replaceAll('*', '.*?');
        }

        pattern += segment;
      }

      pattern += r'$';

      listMatchers.add(RegExp(pattern, caseSensitive: false));
    }
  }
}
