import 'package:path/path.dart' as p;

enum FileType { PICTURE, AUDIO, VIDEO, OTHER }

FileType getFileType(String path) {
  String ext = p.extension(path);

  if (['.png', '.jpg', '.jpeg'].contains(ext)) {
    return FileType.PICTURE;
  }

  if (['.mp4'].contains(ext)) {
    return FileType.VIDEO;
  }

  return FileType.OTHER;
}
