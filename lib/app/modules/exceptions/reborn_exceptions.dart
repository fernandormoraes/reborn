import 'package:reborn/reborn.dart';

/// Error thrown when a type handler cannot be found for a returned item
///
class NoTypeHandlerError extends Error {
  final dynamic object;
  final HttpRequest request;

  NoTypeHandlerError(this.object, this.request);

  @override
  String toString() =>
      'No type handler found for ${object.runtimeType} / ${object.toString()} \nRoute: ${request.uri}\nIf the app is running in production mode, the type name may be minified. Run it in debug mode to resolve';
}

/// Error used by middleware, utils or type handler to elevate
/// a NotFound response.
class NotFoundError extends Error {}

/// Throw these exceptions to bubble up an error from sub functions and have them
/// handled automatically for the client
class RebornException implements Exception {
  /// The response to send to the client
  ///
  Object? response;

  /// The statusCode to send to the client
  ///
  int statusCode;

  RebornException(this.statusCode, this.response);
}

class BodyParserException implements RebornException {
  @override
  Object? response;

  @override
  int statusCode;

  final Object exception;
  final StackTrace stacktrace;

  BodyParserException(
      {this.statusCode = 400,
      this.response = 'Bad Request',
      required this.exception,
      required this.stacktrace});
}
