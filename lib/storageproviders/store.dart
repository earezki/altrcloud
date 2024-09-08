import 'dart:io';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:multicloud/pages/state/config.dart';
import 'package:multicloud/pages/state/models.dart';
import 'package:multicloud/storageproviders/data_source.dart';
import 'package:multicloud/storageproviders/loading_file.dart';
import 'package:multicloud/storageproviders/storage_provider.dart';
import 'package:multicloud/toolkit/file_type.dart';
import 'package:multicloud/toolkit/file_utils.dart';
import 'package:multicloud/toolkit/list_utils.dart';
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

    initState().then((aVoid) => notifyListeners());

    return this;
  }

  Store updateStorageProvider(
    StorageProviderModel storageProviderModel,
  ) {
    _storageProviderModel = storageProviderModel;
    return this;
  }

  Future<void> initState() async {
    if (_contentModel != null &&
        _configModel != null &&
        _storageProviderModel != null) {
      final autoUpload = await _configModel!.isAutoUploadEnabled;
      if (autoUpload) {
        if (kDebugMode) {
          print('Store.updateConfig => auto upload !');
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

    var pictureDirectories = await configModel.pictureDirectories;

    if (kDebugMode) {
      print('Store.backup => picture folders: $pictureDirectories');
    }

    var providers = {
      for (var provider in storageProviderModel.providers)
        provider.supportedBackupType: provider
    };

    contentModel.startLoading();

    _isUploadInProgress = true;
    try {
      for (String pictureDir in pictureDirectories) {
        // we only have one provider (Github) currently.
        final provider = providers[SupportedBackupType.PICTURES]!;

        await _upload(
          pictureDir,
          provider,
        );
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

          await createThumbnail(
            content: originalContent,
            originalPath: fileToUpload.path,
          );

          contentModel.save(originalContent);
        }
      } else if (fileType == FileType.VIDEO) {
        final videoContent = await _uploadVideo(
          provider: provider,
          video: file,
          lastModified: lastModified,
        );

        videoContent.localPath = fileToUpload.path;

        await createThumbnail(
          content: videoContent.primaryChunk,
          originalPath: fileToUpload.path,
          rebuild: true,
        );

        contentModel.saveChunked(videoContent);
      }

      // redraw after creating the thumbnails.
      contentModel.notifyListeners();

      if (kDebugMode) {
        print('Store => Done backup of [${fileToUpload.path}]');
      }
    }
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
      return;
    }

    _reinit();
    contentModel.startLoading();
    _isUploadInProgress = true;

    try {
      final remoteContent = await _getRemoteContent();

      if (remoteContent.isNotEmpty) {
        // save all first to have all the chunks available for videos.
        //  await _contentRepository.saveAll(remoteContent);

        // create thumbnails.
        for (var rc in remoteContent) {
          if (rc.isNotPrimaryChunk) {
            continue;
          }

          if (rc.hasOtherChunks &&
              await contentModel.hasPendingChunksForUpload(rc.name)) {
            // if not all chunks have been updated then we skip it and wait for the next synchronization.
            continue;
          }

          //  final localFile = await getFileByName(rc.name, directories);
          //  rc.localPath = localFile?.path;

          List<Content> allChunks = contentModel.getChunksOf(remoteContent, rc);
          final totalSize = sum(allChunks.map((c) => c.size));
          rc = await contentModel.loadData(
            rc,
            chunksContents: remoteContent,
            loadingCallback: (content, uploadedChunks) => _setLoadingFile(
              filename: content.name,
              size: totalSize,
              totalChunks: content.totalChunks,
              uploadedChunks: uploadedChunks,
            ),
          );

          await _contentRepository
              .saveAll(allChunks);

          try {
            await createThumbnail(
              content: rc,
              originalPath: rc.path,
            );

            await _contentRepository.update(rc);
            contentModel.add(rc);
          } catch (e) {
            if (kDebugMode) {
              print(
                  'ContentModel.initState => failed to create thumbnail for ${rc.name}, assuming bad upload and deleting from storage !');
            }
            // TODO: if thumbnail creation failed, usually the vid isn't well uploaded !
            // _deleteChunks(rc);
          }
        }
      }
    } finally {
      _reinit();
      contentModel.finishLoading();
    }
  }

  Future<List<Content>> _getRemoteContent() async {
    var remoteContent = await storageProviderModel.fetchContent();

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
}
