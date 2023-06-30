import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:reborn/app/modules/router/reborn_router.dart';
import 'package:reborn/enums/methods.dart';
import 'package:reborn/utils/extensions/request_extensions.dart';

void main() async {
  final app = RebornApp(pathPrefix: 'api/v1');

  app.injector.add<ExternalDependency>(Dependency.new);

  app.injector.commit();

  app.request(['test', 'abelha'], (req, res) => 'Teste',
      supportedMethods: [Method.get, Method.post]);

  app.request(['testpost'], (req, res) async {
    final body = await req.body;

    return jsonEncode(Test(1, 'test', body != null).toJson());
  }, supportedMethods: [Method.post]);

  app.request(
      ['sum'], (req, res) => app.injector.get<ExternalDependency>().sum(2, 2));

  app.logger = Logger(level: Level.debug);

  await app.listen(port: 7071, bindIp: '127.0.0.1');
}

abstract class ExternalDependency {
  int sum(int a, int b);
}

class Dependency implements ExternalDependency {
  @override
  int sum(int a, int b) {
    return a + b;
  }
}

class Test {
  final int id;
  final String description;
  final bool test;

  Test(this.id, this.description, this.test);

  Map<String, dynamic> toJson() {
    return {'id': id, 'description': description, 'test': test};
  }
}
