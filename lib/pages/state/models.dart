import 'dart:collection';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:multicloud/storageproviders/data_source.dart';
import 'package:multicloud/storageproviders/storage_provider.dart';
import 'package:multicloud/toolkit/cache.dart' as cache;
import 'package:multicloud/toolkit/file_type.dart';
import 'package:multicloud/toolkit/thumbnails.dart';
import 'package:multicloud/toolkit/utils.dart';

class ContentModel extends ChangeNotifier {
  final ContentRepository _repository = ContentRepository();

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
    return await _repository.find(criteria: SearchCriteria(chunkSeq: -1));
  }

  Future<void> initState() async {
    if (kDebugMode) {
      print('ContentModel.initState running ...');
    }

    if (_isLoading) {
      return;
    }

    startLoading();

    final contents = await _contentsOfRepo();
    replace(contents);

    var remoteContent = await storageProviderModel.fetchContent();

    // TODO remove duplicates from remoteContent

    remoteContent.removeWhere((rc) {
      final alreadyExistsLocally =
          (contents.indexWhere((c) => c.id == rc.id) != -1);
      return alreadyExistsLocally;
    });

    if (remoteContent.isNotEmpty) {
      // save all first to have all the chunks available for videos.
      await _repository.saveAll(remoteContent);

      // create thumbnails.
      for (var rc in remoteContent) {
        if (rc.isNotPrimaryChunk) {
          continue;
        }

        rc = await _loadData(rc);

        // TODO: if thumbnail creation failed, usually the vid isn't well uploaded !
        try {
          await createThumbnail(
            content: rc,
            originalPath: rc.path,
          );

          await _repository.update(rc);
          add(rc);
        } catch (e) {
          if (kDebugMode) {
            print('ContentModel.initState => failed to create thumbnail for ${rc.name}, assuming bad upload and deleting from storage !');
          }
          _deleteChunks(rc);
        }
      }
    }

    finishLoading();
  }

  Future<void> search(String query) async {
    var contents = await _repository.find(
      criteria: SearchCriteria(
        name: query,
      ),
    );
    replace(contents);
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
      _contents.add(content);

      /*  _contents.sort(
        (a, b) =>
            b.createdAtMillisSinceEpoch.compareTo(a.createdAtMillisSinceEpoch),
      );*/
    }

    notifyListeners();
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
        .map((content) async => await _repository.save(content))
        .toList());

    addAll(nonNullableContents);
  }

  Future<void> save(Content content) async {
    await _repository.save(content);

    add(content);
  }

  Future<void> saveChunked(ChunkedContent chunkedContent) async {
    for (final content in chunkedContent.chunks) {
      await _repository.save(content);
    }

    add(chunkedContent.primaryChunk);
  }

  bool hasFilename(String filename) {
    var index = _contents.indexWhere((content) => content.name == filename);
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

  Future<List<Content>> _getChunks(Content content) async {
    return await _repository.find(
      criteria: SearchCriteria(chunkSeq: -1, chunkSeqId: content.chunkSeqId),
    );
  }

  Future<void> delete(List<int> indices) async {
    startLoading();

    final contentsToDelete = indices.map((index) => _contents[index]).toList();
    for (var content in contentsToDelete) {
      await _deleteChunks(content);
    }

    finishLoading();
  }

  Future<void> _deleteChunks(Content content) async {
    if (content.hasOtherChunks) {
      final chunks = await _getChunks(content);
      for (Content chunk in chunks) {
        await _deleteContent(chunk);
      }

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
      await _repository.deleteByName(content);

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
    return await _loadData(content);
  }

  Future<Uint8List> loadContentBytes(int index) async {
    var content = _contents[index];
    var data = await loadDataBytes(content);
    return data;
  }

  Content thumbnail(int index) {
    return _thumbnails[index];
  }

  String thumbnailFilepath(int index) {
    var content = _thumbnails[index];
    return getThumbnailFile(content);
  }

  Future<Uint8List> loadDataBytes(Content content) async {
    final loadedContent = await _loadData(content);
    final localFile = File(loadedContent.localPath!);
    return await localFile.readAsBytes();
  }

  Future<Content> _loadData(Content content) async {
    if (content.localPathAvailable) {
      final existingLocalFile = File(content.localPath!);
      if (await existingLocalFile.exists()) {
        return content;
      }
    }

    final cacheKey = content.id;
    final cacheFile = await cache.getCacheFile(cacheKey);
    final cacheExists = await cacheFile.exists();

    content.localPath = cacheFile.path;
    if (!cacheExists) {
      if (kDebugMode) {
        print(
            'ContentModel._loadData => cache miss for [${content.fileType}] - [${content.name}] - [$cacheKey]');
      }

      StorageProvider provider = _getProviderOfContent(content);

      if (content.fileType == FileType.PICTURE) {
        final result = await provider.loadData(content);
        await cacheFile.writeAsBytes(result.$2);
      } else if (content.fileType == FileType.VIDEO && content.isPrimaryChunk) {
        final allChunks = await _repository.find(
          criteria: SearchCriteria(
              chunkSeq: -1, // find all
              chunkSeqId: content.chunkSeqId),
        );

        final randomAccessFile = await cacheFile.open(mode: FileMode.append);

        if (kDebugMode) {
          print(
              'ContentModel._loadData => loading video [${content.name}], having ${allChunks.length} chunks');
        }
        try {
          allChunks.sort((lhs, rhs) => lhs.chunkSeq.compareTo(rhs.chunkSeq));

          /* TODO:
              each chunk should be stored in a temp file, then afterwards merge the chunks info the result file,
              the issue is that the chunks could be written but not completely which leaves the final file existing incomplete.
          */
          for (Content chunk in allChunks) {
            final result = await provider.loadData(chunk);
            await randomAccessFile.writeFrom(result.$2);
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
        } finally {
          await randomAccessFile.close();
        }

        if (kDebugMode) {
          print(
              'ContentModel._loadData => done loading video [${content.name}]');
        }
      }
    }

    return await _repository.update(content);
  }

  Future<void> clearCache() async {
    await cache.clearCache();
  }
}

class StorageProviderModel extends ChangeNotifier {
  final List<StorageProvider> _providers = [];
  final StorageProviderRepository _repository = StorageProviderRepository();

  UnmodifiableListView<StorageProvider> get providers =>
      UnmodifiableListView(_providers);

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
