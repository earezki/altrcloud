import 'dart:io';

import 'package:multicloud/storageproviders/storage_provider.dart';
import 'package:multicloud/toolkit/file_utils.dart';
import 'package:path_provider/path_provider.dart';

Future<File> getCacheFileOfContent(Content content) async {
  final cacheKey = content.id;
  return await getCacheFile(cacheKey);
}

Future<File> getCacheFile(String cacheKey) async {
  final dir = await getCacheDirectory();
  return File('$dir/$cacheKey');
}

Future<String> getCacheDirectory() async {
  final dir = await getApplicationCacheDirectory();
  return dir.path;
}

Future<void> clearCache() async {
  final cacheDir = await getCacheDirectory();
  await clearDirectory(cacheDir);
}

Future<int> getCacheSize() async {
  final cacheDir = await getCacheDirectory();
  return getDirectorySize(cacheDir);
}
