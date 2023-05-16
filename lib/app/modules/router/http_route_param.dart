import 'package:reborn/enums/decode_mode.dart';
import 'package:reborn/utils/extensions/string_extensions.dart';

class HttpRouteParam {
  HttpRouteParam(this.name, this.pattern, this.type);

  final String name;
  final String pattern;
  final HttpRouteParamType? type;

  dynamic getValue(String value) {
    // path has been decoded already except for '/'
    value = value.decodeUri(DecodeMode.onlySlash);
    return type?.parse(value) ?? value;
  }

  static final paramTypes = <HttpRouteParamType>[];

  static HttpRouteParam? tryParse(String segment) {
    /// route param is of the form ":name" or ":name:pattern"
    /// the ":pattern" part can be a regular expression
    /// or a param type name
    if (!segment.startsWith(':')) return null;
    var pattern = '';
    var name = segment.substring(1);
    HttpRouteParamType? type;
    final idx = name.indexOf(':');
    if (idx > 0) {
      pattern = name.substring(idx + 1);
      name = name.substring(0, idx);
      final typeName = pattern.toLowerCase();
      type = paramTypes
          .cast<HttpRouteParamType?>()
          .firstWhere((t) => t!.name == typeName, orElse: () => null);
      if (type != null) {
        // the pattern matches a param type name
        pattern = type.pattern;
      }
    } else {
      // anything but a slash
      pattern = r'[^/]+?';
    }
    return HttpRouteParam(name, pattern, type);
  }
}

sealed class HttpRouteParamType {
  String get name;
  String get pattern;

  dynamic parse(String value);
}
