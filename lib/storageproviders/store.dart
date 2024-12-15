import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:multicloud/pages/state/config.dart';
import 'package:multicloud/pages/state/models.dart';
import 'package:multicloud/storageproviders/data_source.dart';
import 'package:multicloud/storageproviders/loading_file.dart';
import 'package:multicloud/storageproviders/storage_provider.dart';
import 'package:multicloud/toolkit/file_type.dart';
import 'package:multicloud/toolkit/file_utils.dart';
import 'package:multicloud/toolkit/thumbnails.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class Store extends ChangeNotifier {
  ContentModel? _contentModel;
  StorageProviderModel? _storageProviderModel;

  ConfigModel? _configModel;

  bool _isUploadInProgress = false;
  LoadingFile? _loadingFile;

  final ContentRepository _contentRepository = ContentRepository();

  LoadingFile? get loadingFile {
    if (!_isUploadInProgress) {
      return null;
    }

    return _loadingFile;
  }

  ContentModel get contentModel {
    if (_contentModel == null) {
      throw 'Should init ContentModel before backup';
    }
    return _contentModel!;
  }

  StorageProviderModel get storageProviderModel {
    if (_storageProviderModel == null) {
      throw 'Should init StorageProviderModel before backup';
    }
    return _storageProviderModel!;
  }

  ConfigModel get configModel {
    if (_configModel == null) {
      throw 'Should init ConfigModel before backup';
    }
    return _configModel!;
  }

  Store updateConfig(ConfigModel configModel) {
    _configModel = configModel;

    return this;
  }

  Store updateContent(ContentModel contentModel) {
    _contentModel = contentModel;

    return this;
  }

  Store updateStorageProvider(
    StorageProviderModel storageProviderModel,
  ) {
    _storageProviderModel = storageProviderModel;
    return this;
  }

  Future<void> initState() async {
    if (kDebugMode) {
      print('Store.initState in progress ...');
    }

    if (_contentModel != null &&
        _configModel != null &&
        _storageProviderModel != null) {
      if (await _configModel!.isAutoSyncEnabled) {
        if (kDebugMode) {
          print('Store.initState => auto sync !');
        }

        await sync();
      }

      if (await _configModel!.isAutoUploadEnabled) {
        if (kDebugMode) {
          print('Store.initState => auto upload !');
        }

        await backup();
      }
    }
  }

  void _setLoadingFileUploadedChunks(int uploadedChunks) {
    _setLoadingFile(
      filename: _loadingFile!.filename,
      size: _loadingFile!.size,
      totalChunks: _loadingFile!.totalChunks,
      uploadedChunks: uploadedChunks,
    );
  }

  void _setLoadingFile({
    required String filename,
    required int size,
    required int totalChunks,
    required int uploadedChunks,
  }) {
    _loadingFile = LoadingFile(
      filename: filename,
      size: size,
      totalChunks: totalChunks,
      uploadedChunks: uploadedChunks,
    );

    notifyListeners();
  }

  void _reinit() {
    _loadingFile = null;
    _isUploadInProgress = false;

    notifyListeners();
  }

  Future<void> backup() async {
    if (_isUploadInProgress || _contentModel!.isLoading) {
      return;
    }

    final isUploadEnabled = await configModel.isUploadEnabled;

    if (isUploadEnabled == false) {
      return;
    }

    var pictureDirectories = await configModel.directories;

    if (kDebugMode) {
      print('Store.backup => picture folders: $pictureDirectories');
    }

    var providers = {
      for (var provider in storageProviderModel.providers)
        provider.supportedBackupType: provider
    };

    contentModel.startLoading();

    _isUploadInProgress = true;

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
    } finally {
      _reinit();
      contentModel.finishLoading();
    }
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
    final chunkSizeInMB = await configModel.chunkSizeInMB;
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

  Future<void> sync() async {
    if (contentModel.isLoading) {
      if (kDebugMode) {
        print('sync skipped content is loading ...');
      }
      return;
    }

    _reinit();
    contentModel.startLoading();
    _isUploadInProgress = true;

    try {
      final remoteContents = await _getRemoteContent();

      // download/sync missing thumbnails first.
      await _syncThumbnails(remoteContents);

      // upload pending thumbnails so they are available to other devices.
      await _uploadPendingThumbnails(remoteContents);
    } finally {
      _reinit();
      contentModel.finishLoading();
    }
  }

  Future<void> _syncThumbnails(List<Content> remoteContents) async {
    if (kDebugMode) {
      print('_syncThumbnails in progress ...');
    }

    final existingContents = await _contentRepository.find(
      criteria: SearchCriteria(
        chunkSeq: null,
      ),
    );

    //filter and keep only thumbnails that will be stored to the thumbnails folder.
    //content will be loaded when the user clicks on it.
    final List<Content> remoteThumbnails = [];

    // count the thumbnails
    var totalSize = 0;
    for (final rc in remoteContents) {
      if (!rc.isThumbnail) {
        continue;
      }

      // is the main content available locally ?
      final mainContentExists = existingContents.indexWhere(
              (ec) => ec.isPrimaryChunk && ec.id == rc.idFromThumbnail) !=
          -1;

      final contentId = rc.idFromThumbnail;
      final thumbnailFile = File(getThumbnailFileFromId(contentId));
      if (mainContentExists && await thumbnailFile.exists()) {
        continue;
      }

      totalSize += rc.size;
      remoteThumbnails.add(rc);
    }

    for (var i = 0; i < remoteThumbnails.length; i++) {
      _setLoadingFile(
        filename: "sync",
        size: totalSize,
        totalChunks: remoteThumbnails.length,
        uploadedChunks: i,
      );

      await _syncThumbnail(
        remoteContents: remoteContents,
        localContents: existingContents,
        rc: remoteThumbnails[i],
      );
    }
  }

  Future<void> _syncThumbnail({
    required List<Content> remoteContents,
    required List<Content> localContents,
    required Content rc,
  }) async {
    try {
      // skip already loaded thumbnails
      final contentId = rc.idFromThumbnail;
      final thumbnailFile = File(getThumbnailFileFromId(contentId));

      if (!await thumbnailFile.exists()) {
        final provider = contentModel.getProviderOfContent(rc);

        final result = await provider.loadData(rc);
        await thumbnailFile.writeAsBytes(result.$2);
      }

      // store the associated content so it can be shown.
      final contentIdx = remoteContents
          .indexWhere((c) => c.isPrimaryChunk && c.id == contentId);

      if (contentIdx != -1) {
        final primaryContent = remoteContents[contentIdx];

        final allChunks =
            contentModel.getChunksOf(remoteContents, primaryContent);
        await _contentRepository.saveAll(allChunks);
        contentModel.add(primaryContent);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Sync failed $e');
      }
    }
  }

  Future<List<Content>> _getRemoteContent() async {
    var remoteContent = await storageProviderModel.fetchContent();
    remoteContent.sort(
      (a, b) {
        final comp =
            b.createdAtMillisSinceEpoch.compareTo(a.createdAtMillisSinceEpoch);
        if (comp != 0) {
          return comp;
        }
        return a.chunkSeq.compareTo(b.chunkSeq);
      },
    );
    return remoteContent;
  }

  Future<List<Content>> _getMissingRemoteContent() async {
    var remoteContent = await _getRemoteContent();

    // remove duplicated content by filename and chunkSeq.
    // remoteContent.unique((rc) => '${rc.name}-${rc.chunkSeq}');

    final allContents = await _contentRepository.find(
      criteria: SearchCriteria(
        chunkSeq: null,
      ),
    );

    // TODO: retain those with null path even if it's existing locally
    remoteContent.removeWhere((rc) {
      final alreadyExistsLocally =
          (allContents.indexWhere((c) => c.id == rc.id) != -1);
      return alreadyExistsLocally;
    });

    remoteContent.sort(
      (a, b) {
        final comp =
            b.createdAtMillisSinceEpoch.compareTo(a.createdAtMillisSinceEpoch);
        if (comp != 0) {
          return comp;
        }
        return a.chunkSeq.compareTo(b.chunkSeq);
      },
    );

    return remoteContent;
  }

  // when uploading a content, there might be an interruption before uploading the thumbnail.
  // this method will sync and upload missing thumbnails to remote storage provider.
  Future<void> _uploadPendingThumbnails(List<Content> remoteContents) async {
    if (kDebugMode) {
      print('_uploadPendingThumbnails in progress ...');
    }
    final List<Content> toUpload = [];
    var totalSize = 0;

    // filter & count for progress loader.
    for (final rc in remoteContents) {
      if (!rc.isThumbnail && rc.isPrimaryChunk) {
        final thumbnailNotUploaded = remoteContents.indexWhere(
              (r) => r.isThumbnail && r.idFromThumbnail == rc.id,
            ) ==
            -1;

        if (thumbnailNotUploaded) {
          final filePath = getThumbnailFile(rc);
          final file = File(filePath);
          if (await file.exists()) {
            toUpload.add(rc);
            totalSize += (await file.length());
          }
        }
      }
    }

    if (kDebugMode) {
      print('_uploadPendingThumbnails: pending = ${toUpload.length}');
    }

    // actual upload
    for (var i = 0; i < toUpload.length; i++) {
      final content = toUpload[i];

      final provider = contentModel.getProviderOfContent(content);

      _setLoadingFile(
        filename: 'thumbnails',
        size: totalSize,
        totalChunks: toUpload.length,
        uploadedChunks: i,
      );

      await _uploadThumbnail(
        provider: provider,
        file: File(getThumbnailFile(content)),
      );
    }
  }
}
