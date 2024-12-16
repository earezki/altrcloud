/*import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:multicloud/storageproviders/data_source.dart';
import 'package:multicloud/storageproviders/storage_provider.dart';
import 'package:multicloud/toolkit/file_type.dart';
import 'package:multicloud/toolkit/file_utils.dart';
import 'package:multicloud/toolkit/thumbnails.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

// https://pub.dev/packages/flutter_isolate
class UploadTask {
  final _contentRepository = ContentRepository();
  final _configRepository = ConfigRepository();

  Future<void> exec() async {
    // we only have one provider (Github) currently.
    final provider = providers[SupportedBackupType.PICTURES]!;

    try {
      for (String pictureDir in pictureDirectories) {
        try {
          await _upload(
            pictureDir,
            provider,
          );
        } catch (e) {
          if (kDebugMode) {
            print('Store.backup => backup failed [$pictureDir]: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Store.backup => backup failed: $e');
      }

      rethrow;
    } finally {}
  }

  Future<void> _upload(String directory, StorageProvider provider) async {
    await for (final fileToUpload
        in Directory(directory).list(recursive: true, followLinks: false)) {
      if (fileToUpload is! File) {
        continue;
      }

      try {
        final originalFilename = basename(fileToUpload.path);
        if (isTrash(originalFilename) ||
            (contentModel.hasFilename(originalFilename) &&
                !(await contentModel
                    .hasPendingChunksForUpload(originalFilename)))) {
          continue;
        }

        final file = File(fileToUpload.path);
        final lastModified = await file.lastModified();

        final fileType = getFileType(fileToUpload.path);
        if (fileType == FileType.PICTURE) {
          final originalBytes = await file.readAsBytes();

          final originalContent = await _backupFile(
            provider: provider,
            filename: originalFilename,
            fileBytes: originalBytes,
            lastModified: lastModified,
          );

          if (originalContent != null) {
            originalContent.localPath = fileToUpload.path;

            _setLoadingFile(
              filename: originalFilename,
              size: await file.length(),
              totalChunks: 1,
              uploadedChunks: 0,
            );

            final thumbnailFile = await createThumbnail(
              content: originalContent,
              originalPath: fileToUpload.path,
            );

            await _uploadThumbnail(provider: provider, file: thumbnailFile);

            contentModel.save(originalContent);
          }
        } else if (fileType == FileType.VIDEO) {
          final videoContent = await _uploadVideo(
            provider: provider,
            video: file,
            lastModified: lastModified,
          );

          videoContent.localPath = fileToUpload.path;

          final thumbnailFile = await createThumbnail(
            content: videoContent.primaryChunk,
            originalPath: fileToUpload.path,
            rebuild: true,
          );

          await _uploadThumbnail(provider: provider, file: thumbnailFile);

          contentModel.saveChunked(videoContent);
        }

        // redraw after creating the thumbnails.
        contentModel.notifyListeners();

        if (kDebugMode) {
          print('Store => Done backup of [${fileToUpload.path}]');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Upload failed: $e');
        }
      }
    }
  }

  Future<void> _uploadThumbnail({
    required StorageProvider provider,
    File? file,
  }) async {
    if (file == null) {
      return;
    }

    final name = '${Content.thumbnailPrefix}${basename(file.path)}';
    await provider.upload(
      name: name,
      filename: name,
      bytes: await file.readAsBytes(),
    );
  }

  Future<ChunkedContent> _uploadVideo(
      {required StorageProvider provider,
      required File video,
      required DateTime lastModified}) async {
    // read in chunks of X MB for non photos

    final chunkSizeInMB = (await _configRepository.find()).chunkSizeInMB;
    final chunkSizeInBytes = chunkSizeInMB * 1024 * 1024;

    final randomAccessFile = await video.open();

    final filename = basename(video.path);

    try {
      final length = await randomAccessFile.length();
      int offset = 0;

      final totalChunks = getTotalChunks(chunkSizeInBytes, length);

      _setLoadingFile(
        filename: filename,
        size: length,
        totalChunks: totalChunks,
        uploadedChunks: 0,
      );

      if (kDebugMode) {
        print(
            'Store._uploadVideo => Start backup of [${video.path}], size: [$length] in chunks of $chunkSizeInMB MB, '
            'total chunks is $totalChunks');
      }

      ChunkedContent chunks =
          ChunkedContent(id: await _getChunkSeqId(filename));

      while (offset < length) {
        final remainingBytes = length - offset;
        final currentChunkSize = remainingBytes < chunkSizeInBytes
            ? remainingBytes
            : chunkSizeInBytes;

        final chunk = await randomAccessFile.read(currentChunkSize);

        final contentChunk = await _backupFile(
          provider: provider,
          filename: filename,
          fileBytes: chunk,
          lastModified: lastModified,
          chunkSeq: chunks.nextSeq,
          chunkSeqId: chunks.id,
          totalChunks: totalChunks,
        );

        if (contentChunk == null) {
          // maybe not rollback every thing ? keep the uploaded chunks and retry later the next chunks !
          //   chunks.rollback(provider);
          throw 'Failed to upload ${video.path}';
        }
        chunks.addChunk(contentChunk);
        _contentRepository.save(contentChunk);

        _setLoadingFileUploadedChunks(chunks.chunks.length);

        offset += currentChunkSize;
      }

      if (kDebugMode) {
        print(
          'Store._uploadVideo => Finished backup of [${video.path}], number of chunks of ${chunks.nextSeq}',
        );
      }

      return chunks;
    } finally {
      await randomAccessFile.close();
    }
  }

  Future<String> _getChunkSeqId(String filename) async {
    final existingChunks = await _contentRepository.find(
      criteria: SearchCriteria(name: filename, chunkSeq: null),
    );

    if (existingChunks.isNotEmpty && existingChunks.first.chunkSeqId != null) {
      if (kDebugMode) {
        print(
            'Store._getChunkSeqId => existing chunk found : ${existingChunks.first.chunkSeqId}');
      }
      return existingChunks.first.chunkSeqId!;
    }

    return const Uuid().v4();
  }

  Future<Content?> _backupFile({
    required StorageProvider provider,
    required String filename,
    required Uint8List fileBytes,
    required DateTime lastModified,
    int totalChunks = 1,
    int chunkSeq = 0,
    String? chunkSeqId,
  }) async {
    final uploadedChunk = await _contentRepository.maybeOne(
      SearchCriteria(
        name: filename,
        chunkSeq: chunkSeq,
      ),
    );

    final chunkAlreadyUploaded = uploadedChunk != null;
    if (chunkAlreadyUploaded) {
      if (kDebugMode) {
        print('Store._backupFile => $filename | $chunkSeq already exists !');
      }
      return uploadedChunk;
    }

    final result = await provider.backup(
      filename: filename,
      bytes: fileBytes,
      lastModified: lastModified,
      chunkSeq: chunkSeq,
      totalChunks: totalChunks,
      chunkSeqId: chunkSeqId,
    );

    if (result.$1 == BackupStatus.OK && result.$2 != null) {
      return result.$2;
    }
    return null;
  }
}
*/