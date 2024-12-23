import 'dart:io';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:multicloud/storageproviders/storage_provider.dart';
import 'package:multicloud/toolkit/file_type.dart';
import 'package:multicloud/toolkit/file_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress_v2/video_compress_v2.dart';

const _thumbnailSuffix = 'thumbnail';
const int _thumbnailSize = 128;
const int _thumbnailQuality = 65;

late String thumbnailsDirectory;

Future<void> init() async {
  if (kDebugMode) {
    print('thumbnails.init()');
  }

  final supportDir = await getApplicationSupportDirectory();
  final thumbnailDir = Directory('${supportDir?.path}/.thumbnails');
  final exists = await thumbnailDir.exists();
  if (exists == false) {
    await thumbnailDir.create();
  }

  thumbnailsDirectory = thumbnailDir.path;
}

Future<int> getThumbnailsSize() async {
  return getDirectorySize(thumbnailsDirectory);
}

Future<void> clearThumbnails() async {
  await clearDirectory(thumbnailsDirectory);
}

String toThumbnail(String filename) {
  return '$filename.$_thumbnailSuffix';
}

String fromThumbnail(String filename) {
  if (isThumbnail(filename)) {
    return filename.replaceAll('.$_thumbnailSuffix', '');
  }

  return filename;
}

bool isThumbnail(String filename) {
  return filename.endsWith(_thumbnailSuffix);
}

String getThumbnailFile(Content content) {
  final fileId = content.id;
  return getThumbnailFileFromId(fileId);
}

String getThumbnailFileFromId(String fileId) {
  return '$thumbnailsDirectory/$fileId';
}

Future<File?> createThumbnail({
  required Content content,
  required String originalPath,
  bool rebuild = false,
}) async {
  final thumbnailFile = File(getThumbnailFile(content));
  if (await thumbnailFile.exists()) {
    if (rebuild) {
      await thumbnailFile.delete();
    } else {
      return thumbnailFile;
    }
  }

  try {
    if (content.fileType == FileType.PICTURE) {
      return await _createPictureThumbnail(
          content: content, originalPath: originalPath);
    } else if (content.fileType == FileType.VIDEO) {
      return await _createVideoThumbnail(
          content: content, originalPath: originalPath);
    }
  } catch (e) {
    if (kDebugMode) {
      print('createThumbnail => Failed : $e');
    }

    return null;
  }

  throw 'Unsupported thumbnail type ${content.fileType}';
}

Future<File> _createVideoThumbnail({
  required Content content,
  required String originalPath,
}) async {
  final thumbnailFile = File(getThumbnailFile(content));

  final thumbnail = await VideoCompressV2.getByteThumbnail(
    originalPath,
    quality: _thumbnailQuality,
    position: -1, // default(-1)
  );

  if (thumbnail == null) {
    throw '_createVideoThumbnail => [$originalPath] Failed thumbnail null';
  }

  await thumbnailFile.writeAsBytes(thumbnail);

  if (kDebugMode) {
    log('''_createVideoThumbnail => Creating thumbnail for [${content.name}].
            Size before : [${await thumbnailFile.length()}] bytes, After : [${thumbnail.length}].
            location: [${thumbnailFile.path}]
            ''');
  }

  return thumbnailFile;
}

Future<File> _createPictureThumbnail({
  required Content content,
  required String originalPath,
}) async {
  final thumbnailFile = File(getThumbnailFile(content));

  final thumbnail = await FlutterImageCompress.compressWithFile(
    originalPath,
    minHeight: _thumbnailSize,
    minWidth: _thumbnailSize,
    quality: _thumbnailQuality,
  );

  if (thumbnail == null) {
    throw '_createPictureThumbnail => [$originalPath] Failed thumbnail null';
  }

  await thumbnailFile.writeAsBytes(thumbnail);

  if (kDebugMode) {
    log('''_createPictureThumbnail => Creating thumbnail for [${content.name}].
            Size before : [${await thumbnailFile.length()}] bytes, After : [${thumbnail.length}].
            location: [${thumbnailFile.path}]
            ''');
  }

  return thumbnailFile;
}
