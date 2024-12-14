import 'dart:io';

import 'package:external_path/external_path.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:multicloud/toolkit/connectivity.dart' as connectivity;
import 'package:multicloud/toolkit/file_type.dart' as ft;
import 'package:uuid/uuid.dart';

abstract class StorageProvider {
  final String _id;

  String get id => _id;

  SupportedBackupType get supportedBackupType => throw UnimplementedError();

  StorageProvider({required String id}) : _id = id;

  Map<String, Object?> toMap();

  Future<void> initState();

  Future<(Content, List<int>)> loadData(Content content);

  Future<http.Response> upload({
    required String name,
    required String filename,
    required Uint8List bytes,
  });

  Future<(BackupStatus, Content?)> backup(
      {String? contentId,
      required int totalChunks,
      required int chunkSeq,
      String? chunkSeqId,
      required String filename,
      required Uint8List bytes,
      required DateTime lastModified});

  Future<void> delete(Content content);

  Future<List<Content>> getContent();
}

enum BackupStatus { OK, FAILED, RETRY_LATER, QUOTA_EXCEEDED, STORAGE_FULL }

enum SourceType {
  GITHUB,
  GOOGLE_DRIVE,
  ONE_DRIVE;

  static SourceType? of(String? type) {
    return SourceType.values.where((v) => v.name == type).first;
  }
}

enum SupportedBackupType { PICTURES, DOCUMENTS, AUDIO, VIDEO }

typedef LoadingCallback = void Function(Content content, int uploadedChunks);

class Content {
  static const thumbnail = 'thumbnail';
  static const delimiter = '|';
  static const thumbnailPrefix = 'thumbnail|';

  final String id;
  final String storageProviderId;

  final String name;
  final String sha;
  final String downloadUrl;
  final int size;
  final int createdAtMillisSinceEpoch;

  int chunkSeq;
  int totalChunks;
  String? chunkSeqId;

  String? localPath;

  //TODO
  //bool deleted;
  //int deletedAt;

  String get key => name;

  bool get hasOtherChunks => chunkSeqId != null;

  bool get isPrimaryChunk => chunkSeq == 0;

  bool get isNotPrimaryChunk => !isPrimaryChunk;

  Content({
    required this.id,
    required this.storageProviderId,
    required this.name,
    required this.sha,
    required this.downloadUrl,
    required this.size,
    required this.createdAtMillisSinceEpoch,
    this.totalChunks = 1,
    this.chunkSeq = 0,
    this.chunkSeqId,
    this.localPath,
  });

  bool get localPathAvailable => localPath?.isNotEmpty ?? false;

  String get path {
    return localPath!;
  }

  DateTime get createdAt =>
      DateTime.fromMillisecondsSinceEpoch(createdAtMillisSinceEpoch);

  ft.FileType get fileType {
    return ft.getFileType(name);
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'sha': sha,
        'size': size,
        'downloadUrl': downloadUrl,
        'storageProviderId': storageProviderId,
        'createdAtMillisSinceEpoch': createdAtMillisSinceEpoch,
        'totalChunks': totalChunks,
        'chunkSeq': chunkSeq,
        'chunkSeqId': chunkSeqId,
        'localPath': localPath,
      };

  Content.fromMap(Map<String, Object?> map)
      : id = map['id'] as String,
        name = map['name'] as String,
        sha = map['sha'] as String,
        size = map['size'] as int,
        downloadUrl = map['downloadUrl'] as String,
        storageProviderId = map['storageProviderId'] as String,
        createdAtMillisSinceEpoch = map['createdAtMillisSinceEpoch'] as int,
        totalChunks = map['totalChunks'] as int,
        chunkSeq = map['chunkSeq'] as int,
        chunkSeqId = map['chunkSeqId'] as String?,
        localPath = map['localPath'] as String?;

  bool get isThumbnail => name.startsWith(thumbnailPrefix);
  String get idFromThumbnail {
    if (!isThumbnail) {
      throw 'can only call for thumbnails';
    }

    return name.split(delimiter)[1];
  }
}

class ChunkedContent {
  final String id;
  final List<Content> chunks = [];

  ChunkedContent({required this.id});

  set localPath(String localPath) {
    for (Content chunk in chunks) {
      chunk.localPath = localPath;
    }
  }

  void addChunk(Content content) {
    if (kDebugMode &&
        (content.chunkSeq != nextSeq || content.chunkSeqId != id)) {
      throw 'Chunk have incorrect metadata !';
    }

    //content.chunkSeqId = id;
    chunks.add(content);
  }

  Future<void> rollback(StorageProvider provider) async {
    for (Content chunk in chunks) {
      await provider.delete(chunk);
    }
  }

  Content get primaryChunk => chunks[0];

  int get nextSeq {
    return chunks.length;
  }
}

class Config {
  static const _defaultChunkSize = 10;

  final String _id;
  bool _uploadOnlyOnWifi;
  bool _autoUpload;
  final List<String> _pictureDirectories;
  int chunkSizeInMB;

  String clientId;
  String clientSecret;

  Config({
    required String id,
    required bool uploadOnlyOnWifi,
    required bool autoUpload,
    required List<String> pictureDirectories,
    required this.chunkSizeInMB,
    required this.clientId,
    required this.clientSecret,
  })  : _id = id,
        _uploadOnlyOnWifi = uploadOnlyOnWifi,
        _autoUpload = autoUpload,
        _pictureDirectories = pictureDirectories;

  Config.defaultConfig()
      : _id = const Uuid().v4(),
        _uploadOnlyOnWifi = true,
        _autoUpload = false,
        _pictureDirectories = [],
        chunkSizeInMB = _defaultChunkSize,
        clientId = '',
        clientSecret = '';

  Map<String, Object?> toMap() => {
        'id': _id,
        'uploadOnlyOnWifi': _uploadOnlyOnWifi,
        'autoUpload': _autoUpload,
        'pictureDirectories': _pictureDirectories,
        'chunkSizeInMB': chunkSizeInMB,
        'clientId': clientId,
        'clientSecret': clientSecret,
      };

  Config.fromMap(Map<String, Object?> map)
      : _id = map['id'] as String,
        _uploadOnlyOnWifi = (map['uploadOnlyOnWifi'] ?? true) as bool,
        _autoUpload = (map['autoUpload'] ?? false) as bool,
        chunkSizeInMB = (map['chunkSizeInMB'] ?? _defaultChunkSize) as int,
        _pictureDirectories =
            (map['pictureDirectories'] as List<dynamic>).cast<String>(),
        clientId = (map['clientId'] ?? '') as String,
        clientSecret = (map['clientSecret'] ?? '') as String;

  String get id => _id;

  set uploadOnlyOnWifi(bool uploadOnlyOnWifi) =>
      _uploadOnlyOnWifi = uploadOnlyOnWifi;

  set autoUpload(bool autoUpload) => _autoUpload = autoUpload;

  bool get isAutoUploadEnabled => _autoUpload;

  bool get uploadOnlyOnWifi => _uploadOnlyOnWifi;

  bool get hasCredentials => clientId.isNotEmpty && clientSecret.isNotEmpty;

  Future<bool> isUploadEnabled() async {
    if (!_uploadOnlyOnWifi) {
      return true;
    }

    final bool isWifiEnabled = await connectivity.isWifiEnabled();
    return isWifiEnabled;
  }

  Future<List<String>> getDirectories() async {
    if (_pictureDirectories.isNotEmpty) {
      return _pictureDirectories;
    }

    final pictures = await ExternalPath.getExternalStoragePublicDirectory(
      ExternalPath.DIRECTORY_PICTURES,
    );

    final screenshots = await ExternalPath.getExternalStoragePublicDirectory(
      ExternalPath.DIRECTORY_SCREENSHOTS,
    );

    final dcim = await ExternalPath.getExternalStoragePublicDirectory(
      ExternalPath.DIRECTORY_DCIM,
    );

    final videos = await ExternalPath.getExternalStoragePublicDirectory(
      ExternalPath.DIRECTORY_MOVIES,
    );

    final List<String> directories = [];

    for (final dir in [pictures, screenshots, dcim, videos]) {
      if (await Directory(dir).exists()) {
        directories.add(dir);
      }
    }

    if (kDebugMode) {
      print('Config.getDirectories => $directories');
    }

    return directories;
  }
}
