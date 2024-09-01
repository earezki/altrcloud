import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

Future<File> getCacheFile(String key) async {
  final dir = await getCacheDirectory();
  return File('$dir/$key');
}

Future<String> getCacheDirectory() async {
  final dir = await getApplicationCacheDirectory();
  return dir.path;
}

Future<void> clearCache() async {
  final cacheDir = await getCacheDirectory();
  await for (var cacheFile
      in Directory(cacheDir).list(recursive: false, followLinks: false)) {
    if (cacheFile is! File) {
      continue;
    }

    await cacheFile.delete();

    if (kDebugMode) {
      print(
          'clearCache => cache file [${basename(cacheFile.path)}] deleted !');
    }
  }
}

Future<int> getCacheSize() async {
  final cacheDir = await getCacheDirectory();
  int size = 0;
  await for (var cacheFile
  in Directory(cacheDir).list(recursive: true, followLinks: false)) {
    if (cacheFile is! File) {
      continue;
    }

    size += await cacheFile.length();
  }

  return size;
}
