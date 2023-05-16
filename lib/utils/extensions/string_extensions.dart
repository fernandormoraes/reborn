import 'package:reborn/enums/decode_mode.dart';

import 'consts.dart';

extension PathNormalizer on String {
  String get normalizePath {
    if (startsWith('/')) {
      return substring('/'.length).normalizePath;
    }
    if (endsWith('/')) {
      return substring(0, length - '/'.length).normalizePath;
    }
    return this;
  }
}

extension StringDecoder on String {
  String decodeUri(DecodeMode mode) {
    var codes = codeUnits;
    var changed = false;
    var pos = 0;
    while (pos < codes.length) {
      final char = codes[pos];
      if (char == Consts.percent) {
        if (pos + 2 >= length) break;
        final hex1 = _decodeHex(codes[pos + 1]);
        final hex2 = _decodeHex(codes[pos + 2]);
        final codeUnit = _getCodeUnit(hex1, hex2);
        if (_decode(codeUnit, mode)) {
          if (!changed) {
            // make a copy
            codes = codes.toList();
            changed = true;
          }
          codes[pos] = codeUnit!;
          codes.removeRange(pos + 1, pos + 3);
        }
      }
      pos++;
    }
    return changed ? String.fromCharCodes(codes) : this;
  }

  int _decodeHex(int codeUnit) {
    if (Consts.zero <= codeUnit && codeUnit <= Consts.nine) {
      return codeUnit - Consts.zero;
    }
    if (Consts.lowerA <= codeUnit && codeUnit <= Consts.lowerF) {
      return 10 + codeUnit - Consts.lowerA;
    } else if (Consts.upperA <= codeUnit && codeUnit <= Consts.upperF) {
      return 10 + codeUnit - Consts.upperA;
    } else {
      return -1;
    }
  }

  bool _decode(int? codeUnit, DecodeMode mode) {
    if (codeUnit == null) return false;
    switch (mode) {
      case DecodeMode.allExceptSlash:
        return codeUnit != Consts.slash;
      case DecodeMode.onlySlash:
        return codeUnit == Consts.slash;
      default:
        return codeUnit != Consts.slash;
    }
  }

  int? _getCodeUnit(int hex1, int hex2) {
    if (hex1 < 0 || hex1 >= 16) return null;
    if (hex2 < 0 || hex2 >= 16) return null;
    return 16 * hex1 + hex2;
  }
}
