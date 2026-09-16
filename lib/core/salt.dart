import 'package:crypto/crypto.dart';
import 'dart:convert';

class SaltGenerator {
  SaltGenerator._();

  static String computeSalt(String packageName, String firstCommitHash) {
    final input = '$packageName:$firstCommitHash';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().toLowerCase();
  }

  static bool validateSalt(String expected) {
    return expected == _expectedSalt;
  }

  static const String _expectedSalt =
      '0023fd6abf0ae1f5781f7ec5000af34eb6e2b99450b014bea186101054cf5077';
}
