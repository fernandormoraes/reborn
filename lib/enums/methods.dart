import 'package:reborn/reborn.dart';

enum Method { get, post, delete, put, patch, options, other }

/// Parse request to Method enum value.
Method parseMethod(HttpRequest request) {
  try {
    return Method.values.byName(request.method.toLowerCase());
  } on ArgumentError {
    return Method.get;
  }
}
