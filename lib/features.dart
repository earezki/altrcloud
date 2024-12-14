import 'package:flutter/foundation.dart';
import 'package:multicloud/toolkit/file_type.dart';

const VERSION = '1.0.0';
List<Feature> features = [];

enum Feature {
  PHOTO_EDIT,
  EDIT_CHUNK_SIZE,
  AUTO_UPLOAD,

  // up-coming
  STORY_FLASHBACK,
  OBJECT_SEARCH
}

const List<FileType> supportedExtensions = [FileType.PICTURE, FileType.VIDEO];

void initFeatures() {
  if (kDebugMode) {
    features.addAll([
      Feature.EDIT_CHUNK_SIZE,
      Feature.AUTO_UPLOAD,
    ]);
  }
}
