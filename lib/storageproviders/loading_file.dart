import 'package:multicloud/toolkit/file_utils.dart';


class LoadingFile {
  String filename;
  int size;

  int totalChunks;
  int uploadedChunks;

  String get extension => getExt(filename);

  LoadingFile({
    required this.filename,
    required this.size,
    required this.totalChunks,
    required this.uploadedChunks,
  });

}
