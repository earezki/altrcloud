import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';

const trashFilePredix = '.trashed';

Future<File?> getFileByName(
    String requiredFilename, List<String> directories) async {
  final futures = directories
      .map((dir) => _getFileByNameFromDir(requiredFilename, dir))
      .toList(growable: false);

  final files = await Future.wait(futures);

  return files.where((f) => f != null).firstOrNull;
}

Future<File?> _getFileByNameFromDir(
    String requiredFilename, String directory) async {
  if (kDebugMode) {
    print(
        '_getFileByNameFromDir => searching for [$requiredFilename] in [$directory]');
  }
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
  return filename.startsWith(trashFilePredix);
}

const platform = MethodChannel('file_manager');

Future<void> recycle(String path) async {
  final file = File(path);
  final exists = await file.exists();

  if (exists) {
    if (kDebugMode) {
      print('recycle => recycling [$path] ...');
    }

    if (kDebugMode) {
      print("Recycling is disabled !");
    }

    /*try {
      await platform.invokeMethod('moveToTrash', {'filePath': path});
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print("Failed to recycle file: ${e.message}");
      }
    }*/

    /*final filename = basename(path);
    final dir = dirname(path);

    if (isTrash(filename)) {
      await file.delete();
    } else {
      await file.rename('$dir/$trashFilePredix-$filename');
    }*/
  }
}
