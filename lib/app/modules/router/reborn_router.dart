import 'dart:io';

import 'package:logger/logger.dart';
import 'package:reborn/app/modules/handler/binary_type_handler.dart';
import 'package:reborn/app/modules/handler/file_type_handler.dart';
import 'package:reborn/app/modules/handler/json_type_handler.dart';
import 'package:reborn/app/modules/handler/serializable_type_handler.dart';
import 'package:reborn/app/modules/handler/string_type_handler.dart';
import 'package:reborn/app/modules/handler/type_handler.dart';
import 'package:reborn/app/modules/handler/websocket_type_handler.dart';
import 'package:reborn/app/modules/queue/queue.dart';
import 'package:reborn/app/modules/router/route_matcher.dart';
import 'package:reborn/app/modules/router/router.dart';
import 'package:reborn/enums/methods.dart';

import '../exceptions/reborn_exceptions.dart';
import 'http_route.dart';

class RebornApp with Router {
  @override
  RebornApp get app => this;

  /// Logger used to log error, warning and info messages
  ///
  /// Uses by default Log level `error`
  Logger logger = Logger(level: Level.error);

  /// Optional path prefix to apply to all routes and route groups
  ///
  @override
  final String pathPrefix;

  /// List of routes
  ///
  /// Generally you don't want to manipulate this array directly, instead add
  /// routes by calling the [get,post,put,delete] methods.
  final List<HttpRoute> routes = <HttpRoute>[];

  /// HttpServer instance from the dart:io library
  ///
  /// If there is anything the app can't do, you can do it through here.
  HttpServer? server;

  /// Incoming request queue
  ///
  /// Set the number of simultaneous connections being processed at any one time
  /// in the [simultaneousProcessing] param in the constructor
  Queue requestQueue;

  final _onDoneListeners = <void Function(HttpRequest req, HttpResponse res)>[];

  /// An array of [TypeHandler] that Reborn walks through in order to determine
  /// if it can handle a value returned from a route.
  ///
  List<TypeHandler> typeHandlers = <TypeHandler>[
    stringTypeHandler,
    uint8listTypeHandler,
    listIntTypeHandler,
    binaryStreamTypeHandler,
    jsonListTypeHandler,
    jsonMapTypeHandler,
    jsonNumberTypeHandler,
    jsonBooleanTypeHandler,
    fileTypeHandler,
    websocketTypeHandler,
    serializableTypeHandler
  ];

  RebornApp({
    this.pathPrefix = '',
    int simultaneousProcessing = 50,
  }) : requestQueue = Queue(parallel: simultaneousProcessing);

  Future<HttpServer> listen({
    int port = 3000,
    dynamic bindIp = '0.0.0.0',
    bool shared = true,
    int backlog = 0,
  }) async {
    final server = await HttpServer.bind(
      bindIp,
      port,
      backlog: backlog,
      shared: shared,
    );

    server.idleTimeout = Duration(seconds: 1);

    server.listen((HttpRequest request) {
      requestQueue.add(() => _incomingRequest(request));
    });

    logger.i('Listening on port $port');

    return this.server = server;
  }

  /// Function to prevent linting errors.
  ///
  void _unawaited(Future<void> then) {}

  /// Responds request with a NotFound response
  ///
  Future _respondNotFound(HttpRequest request, bool isDone) async {
    request.response.statusCode = 404;
    request.response.write('404 not found');
    await request.response.close();
  }

  /// Handle a response by response type
  ///
  /// This is the logic that will handle the response based on what you return.
  ///
  Future<void> _handleResponse(dynamic result, HttpRequest request) async {
    if (result != null) {
      var handled = false;
      for (var handler in typeHandlers) {
        if (handler.shouldHandle(result)) {
          logger.d('Apply TypeHandler for result type: ${result.runtimeType}');

          dynamic handlerResult =
              await handler.handler(request, request.response, result);
          if (handlerResult != false) {
            handled = true;
            break;
          }
        }
      }
      if (!handled) {
        throw NoTypeHandlerError(result, request);
      }
    }
  }

  /// Handles and routes an incoming request
  ///
  Future<void> _incomingRequest(HttpRequest request) async {
    /// Variable to track the close of the response
    var isDone = false;

    logger.i('${request.method} - ${request.uri.toString()}');

    // We track if the response has been resolved in order to exit out early
    // the list of routes (ie the middleware returned)
    _unawaited(request.response.done.then((dynamic _) {
      isDone = true;
      for (var listener in _onDoneListeners) {
        listener(request, request.response);
      }
      logger.d('Response sent to client');
    }));

    // Work out all the routes we need to process
    final effectiveMatches = RouteMatcher.match(
        request.uri.toString(), routes, parseMethod(request));

    try {
      // If there are no effective routes, that means we need to throw a 404
      // or see if there are any static routes to fall back to, otherwise
      // continue and process the routes
      if (effectiveMatches.isEmpty) {
        logger.d('No matching routes in server');
        await _respondNotFound(request, isDone);
      } else {
        /// Tracks if one route is using a wildcard
        var nonWildcardRouteMatch = false;

        // Loop through the routes in the order they are in the routes list
        for (var match in effectiveMatches) {
          if (isDone) {
            break;
          }
          logger.d('Match routes: ${match.route.routes}');

          /// Loop through any middleware
          for (var middleware in match.route.middlewares) {
            // If the request has already completed, exit early.
            if (isDone) {
              break;
            }

            logger.d('Middleware found and executed with associated route');

            await _handleResponse(
                await middleware(request, request.response), request);
          }

          /// If the request has already completed, exit early, otherwise process
          /// the primary route callback
          if (isDone) {
            break;
          }

          logger.d('Execute route callback function');

          /// Nested try catch because if you set the header twice it wasn't
          /// catching an error. This fixes it and its in tests, so if you can
          /// remove it and all the tests pass, cool beans.
          ///try {
          await _handleResponse(
              await match.route.handler(request, request.response), request);

          ///} catch (e, s) {
          ///  logger.e(e);
          ///  logger.e(s);
          ///}
        }

        /// If you got here and isDone is still false, you forgot to close
        /// the response, or you didn't return anything. Either way its an error,
        /// but instead of letting the whole server hang as most frameworks do,
        /// lets at least close the connection out
        ///
        if (!isDone) {
          if (request.response.contentLength == -1) {
            if (nonWildcardRouteMatch == false) {
              await _respondNotFound(request, isDone);
            }
          }
          await request.response.close();
        }
      }
    } on RebornException catch (e) {
      // The user threw a handle HTTP Exception
      logger.e(e);
      try {
        request.response.statusCode = e.statusCode;
        await _handleResponse(e.response, request);
      } on StateError catch (e, _) {
        // It can hit this block if you try to write a header when one is already been raised
        logger.e(e);
      } catch (e, _) {
        // Catch all other errors, this block may be able to be removed in the future
        logger.e(e);
      }
    } on NotFoundError catch (_) {
      await _respondNotFound(request, isDone);
    } catch (e, _) {
      // Its all broken, bail (but don't crash)

      //Otherwise fall back to a generic 500 error
      logger.e(e);
      try {
        request.response.statusCode = 500;
        request.response.write(e);
        await request.response.close();
      } catch (e, _) {
        logger.e(e);
        await request.response.close();
      }
    }
  }
}
