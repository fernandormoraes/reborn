import 'dart:io';

import 'package:reborn/app/modules/exceptions/reborn_exceptions.dart';
import 'package:reborn/utils/extensions/response_extensions.dart';

import 'type_handler.dart';

TypeHandler get fileTypeHandler =>
    TypeHandler<File>((HttpRequest req, HttpResponse res, File file) async {
      if (file.existsSync()) {
        res.setContentTypeFromFile(file);
        await res.addStream(file.openRead());
        return res.close();
      } else {
        throw NotFoundError();
      }
    });
