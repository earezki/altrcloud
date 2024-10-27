import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:multicloud/storageproviders/data_source.dart';
import 'package:multicloud/storageproviders/storage_provider.dart';
import 'package:multicloud/toolkit/cache.dart' as cache;
import 'package:multicloud/toolkit/file_type.dart';
import 'package:multicloud/toolkit/file_utils.dart' as fileutils;
import 'package:multicloud/toolkit/list_utils.dart';
import 'package:multicloud/toolkit/thumbnails.dart';
import 'package:multicloud/toolkit/utils.dart';
import 'package:share_plus/share_plus.dart';

class ContentModel extends ChangeNotifier {
  final ContentRepository _contentRepository = ContentRepository();
  final ConfigRepository _configRepository = ConfigRepository();

  final List<Content> _contents = [];
  Map<DateTime, List<int>> _contentsByDate = {};

  bool _isLoading = false;
  StorageProviderModel? _storageProviderModel;

  UnmodifiableListView<Content> get contents => UnmodifiableListView(_contents);

  UnmodifiableListView<Content> get thumbnails => contents;

  UnmodifiableMapView<DateTime, List<int>> get contentsByDate =>
      UnmodifiableMapView(_contentsByDate);

  List<Content> get _thumbnails => _contents;

  bool get isLoading => _isLoading;

  StorageProviderModel get storageProviderModel {
    if (_storageProviderModel == null) {
      throw 'StorageProviderModel needs to be available and initialized before initializing ContentModel';
    }

    return _storageProviderModel as StorageProviderModel;
  }

  @override
  void notifyListeners() {
    _updateContentsByDate();

    super.notifyListeners();
  }

  void _updateContentsByDate() {
    Map<DateTime, List<int>> groupedItems = {};

    for (int idx = 0; idx < _contents.length; idx++) {
      final item = _contents[idx];
      final createdAt = item.createdAt;
      DateTime dateOnly = getDateOnly(createdAt);

      if (!groupedItems.containsKey(dateOnly)) {
        groupedItems[dateOnly] = [];
      }
      groupedItems[dateOnly]!.add(idx);
    }

    _contentsByDate = groupedItems;
  }

  ContentModel updateStorageProvider(
      StorageProviderModel storageProviderModel) {
    _storageProviderModel = storageProviderModel;

    initState().then((aVoid) => notifyListeners());

    return this;
  }

  Future<List<Content>> _contentsOfRepo() async {
    return await _contentRepository.find(
      criteria: SearchCriteria(
        chunkSeq: -1,
        sortBy: 'createdAtMillisSinceEpoch',
      ),
    );
  }

  Future<void> initState() async {
    if (kDebugMode) {
      print('ContentModel.initState running ...');
    }

    if (_isLoading) {
      return;
    }

    try {
      await _reload();
      //await sync();
    } finally {
      finishLoading();
    }
  }

  Future<void> _reload() async {
    if (isLoading) {
      return;
    }

    startLoading();

    final contents = await _contentsOfRepo();
    // show some temporary contents waiting for the ne
    replace(contents);

    await contents.removeWhereAsync((c) async {
      final notSupportedExt =
          ![FileType.PICTURE, FileType.VIDEO].contains(c.fileType);
      return (!c.isPrimaryChunk) ||
          (notSupportedExt) ||
          (c.hasOtherChunks && (hasPendingChunks(contents, c.name)));
    });

    replace(contents);

    finishLoading();
  }

  List<Content> _getDuplicates(List<Content> list) {
    Set<String> unique = {};
    List<Content> duplicates = [];
    for (final content in list) {
      final id = '${content.name}|${content.chunkSeq}';
      if (unique.contains(id)) {
        duplicates.add(content);
      } else {
        unique.add(id);
      }
    }

    return duplicates;
  }

  /**
      TODO add documentation.
      deletes duplicated files with the same name and same chunck sequence from local and remote storage.
   */
  Future<void> resolveConflicts() async {
    if (isLoading) {
      return;
    }

    startLoading();
    try {
      final remoteContents = await storageProviderModel.fetchContent();
      Map<String, List<Content>> contentsByFilename = {};
      // group by 'name | chunkSeq'
      for (final content in _getDuplicates(remoteContents)) {
        remoteContents
            .where(
                (c) => c.name == content.name && c.chunkSeq == content.chunkSeq)
            .forEach(
          (c) {
            String key = '${c.name}|${c.chunkSeq}';
            if (!contentsByFilename.containsKey(key)) {
              contentsByFilename[key] = [];
            }
            contentsByFilename[key]!.add(c);
          },
        );
      }

      // Sort by the number of already uploaded chunks.
      for (final entry in contentsByFilename.entries) {
        entry.value.sort(
          (lhs, rhs) {
            final lhsChunksLength = getChunksOf(remoteContents, lhs).length;
            final rhsChunksLength = getChunksOf(remoteContents, rhs).length;

            return rhsChunksLength.compareTo(lhsChunksLength);
          },
        );
      }

      // delete
      Set<String?> deletedChunkSeqId = {};
      for (final entry in contentsByFilename.entries) {
        final toDelete = entry.value
            .skip(1) // keep the first element, and delete the rest.
            .whereNot((c) => deletedChunkSeqId.contains(c.chunkSeqId))
            .map((c) {
          deletedChunkSeqId.add(c.chunkSeqId);
          return c;
        }).toList(growable: false);

        if (_hasSameSequenceId(entry.value)) {
          for (final c in toDelete) {
            await _deleteContent(c);
          }
        } else {
          for (final c in toDelete) {
            await _deleteAllChunks(getChunksOf(remoteContents, c));
          }
        }

        // TODO: delete local duplicates from db.

        if (kDebugMode) {
          for (final c in toDelete) {
            print(
                "resolveConflicts => deleted (${_hasSameSequenceId(entry.value) ? 'one' : 'all'}): ${c.chunkSeqId}|${c.name}|${c.chunkSeq}|${c.totalChunks}|${getChunksOf(remoteContents, c).length}|${c.downloadUrl}");
          }
        }
      }
    } finally {
      finishLoading();
    }
  }

  bool _hasSameSequenceId(List<Content> contents) {
    if (contents.isEmpty) {
      return false;
    }

    final firstSequenceId = contents[0].chunkSeqId;
    for (final c in contents) {
      if (c.chunkSeqId != firstSequenceId) {
        return false;
      }
    }

    return true;
  }

  bool hasPendingChunks(List<Content> allContents, String filename) {
    final uploadedChunks =
        allContents.where((c) => c.name == filename).toList(growable: false);

    if (uploadedChunks.isNotEmpty) {
      return uploadedChunks.length != uploadedChunks.first.totalChunks;
    }

    return false;
  }

  Future<bool> hasPendingChunksForUpload(String filename) async {
    final uploadedChunks = await _contentRepository.find(
      criteria: SearchCriteria(
        name: filename,
        chunkSeq: null,
      ),
    );

    if (uploadedChunks.isNotEmpty) {
      return uploadedChunks.length != uploadedChunks.first.totalChunks;
    }

    return false;
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      await _reload();
    } else {
      final newContents = await _contentRepository.find(
        criteria: SearchCriteria(
            name: query.trim(),
            exactName: false,
            sortBy: 'createdAtMillisSinceEpoch'),
      );

      replace(newContents);
    }
  }

  void startLoading() {
    _isLoading = true;

    notifyListeners();
  }

  void finishLoading() {
    _isLoading = false;

    notifyListeners();
  }

  void replace(List<Content> contents) {
    _contents.clear();
    addAll(contents);
  }

  void addAll(List<Content> contents) {
    _contents.addAll(
      contents.where((c) => c.isPrimaryChunk).toList(),
    );

    notifyListeners();
  }

  void add(Content content) {
    if (content.isPrimaryChunk) {
      _contents.removeWhere((c) => c.id == content.id);
      _contents.add(content);

      _contents.sort(
        (a, b) =>
            b.createdAtMillisSinceEpoch.compareTo(a.createdAtMillisSinceEpoch),
      );
      notifyListeners();
    }
  }

  void _delete(Content content) {
    _contents.removeWhere((c) => content.id == c.id);

    notifyListeners();
  }

  void _deleteAll(List<Content> contents) {
    _contents.removeWhere((c) {
      return contents.indexWhere((ec) => ec.id == c.id) != -1;
    });
    _isLoading = false;

    notifyListeners();
  }

  Future<void> saveAll(List<Content?> contents) async {
    startLoading();

    var nonNullableContents =
        contents.where((content) => content != null).cast<Content>().toList();

    await Future.wait(nonNullableContents
        .map((content) async => await _contentRepository.save(content))
        .toList());

    addAll(nonNullableContents);
  }

  Future<void> save(Content content) async {
    await _contentRepository.save(content);

    add(content);
  }

  Future<void> saveChunked(ChunkedContent chunkedContent) async {
    for (final content in chunkedContent.chunks) {
      await _contentRepository.save(content);
    }

    add(chunkedContent.primaryChunk);
  }

  bool hasFilename(String filename) {
    final index = _contents.indexWhere((content) => content.name == filename);
    return index != -1;
  }

  Future<int> getContentSize(Content content) async {
    if (content.hasOtherChunks) {
      final chunks = await _getChunks(content);

      return chunks.map((c) => c.size).sum;
    }

    return content.size;
  }

  Future<int> getNumberOfChunks(Content content) async {
    if (content.hasOtherChunks) {
      final chunks = await _getChunks(content);

      return chunks.length;
    }

    return 1;
  }

  List<Content> getChunksOf(List<Content> contents, Content content) {
    final chunkSeqId = content.chunkSeqId;
    if (chunkSeqId == null) {
      return [content];
    }

    return contents
        .where((rc) => rc.chunkSeqId == chunkSeqId)
        .toList(growable: false);
  }

  Future<List<Content>> _getChunks(Content content) async {
    return await _contentRepository.find(
      criteria: SearchCriteria(chunkSeq: -1, chunkSeqId: content.chunkSeqId),
    );
  }

  Future<void> delete(
    List<int> indices, {
    bool deleteFromRemote = false,
  }) async {
    if (isLoading) {
      return;
    }

    startLoading();

    final contentsToDelete = indices.map((index) => _contents[index]).toList();

    for (var content in contentsToDelete) {
      try {
        /**
         * TODO, not delete but add a flag to say it's in the trash !
         */
        if (kDebugMode) {
          print('Deleting from device ...');
        }

        if (content.localPathAvailable) {
          await fileutils.recycle(content.path);
        }

        if (deleteFromRemote) {
          await _deleteChunks(content);
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to delete file: $e');
        }
      }
    }

    finishLoading();
  }

  Future<void> share(List<int> indices) async {
    if (isLoading) {
      return;
    }

    final filesToShare = indices
        .map((index) => _contents[index].localPath)
        .where((p) => p != null)
        .map((p) => XFile(p!))
        .toList();
    await Share.shareXFiles(filesToShare);
  }

  Future<void> _deleteAllChunks(List<Content> chunks) async {
    for (Content chunk in chunks) {
      await _deleteContent(chunk);
    }
  }

  Future<void> _deleteChunks(Content content) async {
    if (content.hasOtherChunks) {
      final chunks = await _getChunks(content);
      await _deleteAllChunks(chunks);

      if (kDebugMode) {
        print(
            'ContentModel.delete => deleted ${content.name} having ${chunks.length} chunks');
      }
    } else {
      await _deleteContent(content);

      if (kDebugMode) {
        print('ContentModel.delete => deleted ${content.name}');
      }
    }
  }

  Future<void> _deleteContent(Content content) async {
    StorageProvider provider = _getProviderOfContent(content);
    try {
      await provider.delete(content);
      await _contentRepository.deleteById(content);

      if (kDebugMode) {
        print(
            'ContentModel._deleteContent => Successfully deleted ${content.name}');
      }

      _delete(content);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to delete content $e');
      }
    }
  }

  StorageProvider _getProviderOfContent(Content content) {
    // TODO when reconnecting, Github instance gets a new id, hence the one in content is useless,
    // TODO FIX: when connecting a new Github, reuse the existing id.
    // final provider = storageProviderModel.providers
    //     .firstWhere((provider) => provider.id == content.storageProviderId);

    // QUICK FIX: we only have one provider anyways.
    final provider = storageProviderModel.providers[0];
    return provider;
  }

  Future<Content> loadContent(int index) async {
    var content = _contents[index];
    return await loadData(content);
  }

  Future<Uint8List> loadContentBytes(int index) async {
    var content = _contents[index];
    var data = await loadDataBytes(content);
    return data;
  }

  Content thumbnail(int index) {
    return _thumbnails[index];
  }

  Future<String> thumbnailFile(int index) async {
    var content = _thumbnails[index];
    final thumbnail = getThumbnailFile(content);

    if (await File(thumbnail).exists()) {
      return thumbnail;
    }

    if (!content.localPathAvailable) {
      content = await loadData(content);
    }

    await createThumbnail(
      content: content,
      originalPath: content.path,
    );

    return thumbnail;
  }

  Future<Uint8List> loadDataBytes(Content content) async {
    final loadedContent = await loadData(content);
    final localFile = File(loadedContent.localPath!);
    return await localFile.readAsBytes();
  }

  Future<Content> loadData(
    Content content, {
    List<Content>? chunksContents,
    LoadingCallback? loadingCallback,
  }) async {
    if (content.localPathAvailable) {
      if (await File(content.localPath!).exists()) {
        return content;
      }
    }

    final config = await _configRepository.find();
    final localFile = await fileutils.getFileByName(
      content.name,
      await config.getDirectories(),
    );

    if (localFile != null && (await localFile.exists())) {
      content.localPath = localFile.path;
      return await _contentRepository.save(content);
    }

    final cacheFile = await cache.getCacheFile(content.name);

    content.localPath = cacheFile.path;

    // TODO : more than if the file exists, check it's size if it's the same as in content.size
    final allChunks = chunksContents == null
        ? await _getChunks(content)
        : getChunksOf(chunksContents, content);

    final cacheExists = await cacheFile.exists();

    //TODO check the size of the cache against the total size of the chunks.
    if (!(cacheExists)) {
      if (kDebugMode) {
        print(
            'ContentModel._loadData => cache miss for [${content.fileType}] - [${content.name}]');
      }

      StorageProvider provider = _getProviderOfContent(content);

      if (content.fileType == FileType.PICTURE) {
        if (loadingCallback != null) {
          loadingCallback(content, 0);
        }

        final result = await provider.loadData(content);
        await cacheFile.writeAsBytes(result.$2);
      } else if (content.fileType == FileType.VIDEO && content.isPrimaryChunk) {
        allChunks.sort((lhs, rhs) => lhs.chunkSeq.compareTo(rhs.chunkSeq));

        if (kDebugMode) {
          print(
              'ContentModel._loadData => loading video [${content.name}], having ${allChunks.length} chunks');
        }
        try {
          /* TODO:
              each chunk should be stored in a temp file, then afterwards merge the chunks info the result file,
              the issue is that the chunks could be written but not completely which leaves the final file existing incomplete.
          */
          // for (Content chunk in allChunks) {
          //   final result = await provider.loadData(chunk);
          //  await randomAccessFile.writeFrom(result.$2);
          //}

          // make sure all chunks are loaded to cache files.
          for (int i = 0; i < allChunks.length; i++) {
            final chunk = allChunks[i];

            if (loadingCallback != null) {
              loadingCallback(chunk, i);
            }

            final chunkFile = await cache.getCacheFileOfContent(chunk);
            if (kDebugMode) {
              print(
                  '_loadData => loading ${chunk.name}|[${chunk.chunkSeq}/${chunk.totalChunks}]');
            }

            if (!(await chunkFile.exists())) {
              final result = await provider.loadData(chunk);
              chunkFile.writeAsBytes(result.$2);
            }
          }

          final randomAccessFile = await cacheFile.open(mode: FileMode.append);
          try {
            for (Content chunk in allChunks) {
              final chunkFile = await cache.getCacheFileOfContent(chunk);
              await randomAccessFile.writeFrom(await chunkFile.readAsBytes());
            }

            for (Content chunk in allChunks) {
              final chunkFile = await cache.getCacheFileOfContent(chunk);
              await chunkFile.delete();
            }
          } finally {
            await randomAccessFile.close();
          }

          /*
        // This is a parallel approach, the downside is that the whole file will be held in memory before It can be stored to the filesystem
         List<Future<(Content, List<int>)>> loadingChunks = [];
          for (Content chunk in allChunks) {
            loadingChunks.add(provider.loadData(chunk));
          }

          final loadedChunks = await Future.wait(loadingChunks);
          loadedChunks.sort((lhs, rhs) => lhs.$1.chunkSeq.compareTo(rhs.$1.chunkSeq));
          for (final chunk in loadedChunks) {
            await randomAccessFile.writeFrom(chunk.$2);
          }
          */
        } finally {}

        if (kDebugMode) {
          print(
              'ContentModel._loadData => done loading video [${content.name}]');
        }
      }
    }

    return await _contentRepository.save(content);
  }

  Future<void> clearCache() async {
    await cache.clearCache();
  }

  Future<void> clearThumbnails() async {
    await clearThumbnails();
  }
}

class StorageProviderModel extends ChangeNotifier {
  final List<StorageProvider> _providers = [];
  final StorageProviderRepository _repository = StorageProviderRepository();

  UnmodifiableListView<StorageProvider> get providers =>
      UnmodifiableListView(_providers);

  bool get hasNoProviders => _providers.isEmpty;

  Future<void> initState() async {
    var providers = await _repository.findAll();
    replace(providers);
  }

  void replace(List<StorageProvider> providers) {
    _providers.clear();
    _providers.addAll(providers);

    notifyListeners();
  }

  void add(StorageProvider provider) {
    _providers.add(provider);

    notifyListeners();
  }

  String _toString(Object o) {
    return '$o';
  }

  Future<void> saveProvider(StorageProvider provider) async {
    isSameProvider(p) =>
        _toString(p.runtimeType) == _toString(provider.runtimeType);

    _providers.where(isSameProvider).forEach(
      (p) async {
        if (kDebugMode) {
          print(
              'StorageProviderModel.saveProvider => Replacing existing provider connection !');
        }
        await _repository.delete(p);
      },
    );

    _providers.removeWhere(isSameProvider);

    if (kDebugMode) {
      print(
          'StorageProviderModel.saveProvider => Saving new StorageProvider connection !');
    }
    await _repository.save(provider);

    var newProvidersList = await _repository.findAll();
    replace(newProvidersList);
  }

  Future<List<Content>> fetchContent() async {
    final list = await Future.wait(
      _providers.map((provider) => provider.getContent()).toList(),
    );

    return list.expand((elm) => elm).toList();
  }
}
