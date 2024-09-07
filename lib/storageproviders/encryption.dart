import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

class Encryption {
  final String _secret;
  final _algorithm = AesCbc.with128bits(
    macAlgorithm: Hmac.sha256(),
  );

  SecretKey get _secretKey =>
      SecretKey(_fillBytes(utf8.encode(_secret), _algorithm.secretKeyLength));

  Encryption({required String secret}) : _secret = secret;

  Future<List<int>> encrypt(List<int> data) async {
    if (kDebugMode) {
      print('Encryption.encrypt => Started encryption ...');
    }
    final secretBox = await _algorithm.encrypt(data, secretKey: _secretKey);

    if (kDebugMode) {
      print('Encryption.encrypt => Finished encryption ...');
    }
    return secretBox.concatenation();
  }

  Future<List<int>> decrypt(List<int> bytes) async {
    if (kDebugMode) {
      print('Encryption.decrypt => Started decryption ...');
    }

    var secretBox = SecretBox.fromConcatenation(
      bytes,
      nonceLength: _algorithm.nonceLength,
      macLength: _algorithm.macAlgorithm.macLength,
    );

    final result = await _algorithm.decrypt(
      secretBox,
      secretKey: _secretKey,
    );

    if (kDebugMode) {
      print('Encryption.decrypt => Finished decryption ...');
    }
    // TODO create a 'Uint8List' from the 'List<int>'
    // Uint8List.fromList(result);
    return result;
  }

  List<int> _fillBytes(List<int> bytes, int length) {
    if (bytes.length >= length) {
      return bytes.sublist(0, length);
    }

    List<int> result = [...bytes];
    while (result.length != length) {
      int missingBytesCount = min(bytes.length, length - result.length);
      List<int> missingBytes = bytes.sublist(0, missingBytesCount);
      result.addAll(missingBytes);
    }

    return result;
  }

}
