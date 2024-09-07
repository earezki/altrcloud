import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';

Future<File?> getFileByName(
    String requiredFilename, List<String> directories) async {
  for (final directory in directories) {
    await for (final file
        in Directory(directory).list(recursive: true, followLinks: false)) {
      if (file is! File) {
        continue;
      }

      final filename = basename(file.path);

      if (filename == requiredFilename) {
        return file;
      }
    }
  }

  return null;
}

int getTotalChunks(int chunkSizeInBytes, int fileLength) {
  return (fileLength / chunkSizeInBytes).ceil();
}

String getExt(String filename) {
  return extension(filename);
}

Future<int> getDirectoriesSize(Future<List<String>> directories) async {
  int size = 0;
  for (final directory in (await directories)) {
    size += (await getDirectorySize(directory));
  }
  return size;
}

Future<int> getDirectorySize(String directory) async {
  int size = 0;
  await for (final f
      in Directory(directory).list(recursive: true, followLinks: false)) {
    if (f is! File) {
      continue;
    }

    final filename = basename(f.path);
    if (!isTrash(filename)) {
      size += await f.length();
    }
  }

  return size;
}

Future<void> clearDirectory(String directory) async {
  await for (var f
      in Directory(directory).list(recursive: false, followLinks: false)) {
    if (f is! File) {
      continue;
    }

    await f.delete();

    if (kDebugMode) {
      print('clearDirectory => file [${f.path}] deleted !');
    }
  }
}

Future<int> getTotalFiles(Future<List<String>> directories) async {
  int totalFiles = 0;
  for (final directory in (await directories)) {
    await for (final f
        in Directory(directory).list(recursive: true, followLinks: false)) {
      if (f is! File) {
        continue;
      }

      final filename = basename(f.path);
      if (!isTrash(filename)) {
        totalFiles++;
      }
    }
  }

  return totalFiles;
}

bool isTrash(String filename) {
  return filename.startsWith('.trashed');
}
