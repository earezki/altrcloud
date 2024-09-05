import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:multicloud/storageproviders/github/Github.dart';
import 'package:multicloud/storageproviders/storage_provider.dart';
import 'package:multicloud/toolkit/file_utils.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:unique_identifier/unique_identifier.dart';

enum _Tables { STORAGE_PROVIDER, CONTENT, CONFIG, UPLOAD_STATUS }

Future<int> getDatabaseSize() async {
  return getDirectorySize(await getDatabasesPath());
}

class DataSource {
  static final DataSource instance = DataSource._();

  static Database? _database;

  DataSource._();

  Future<Database> get database async {
    // TODO fix this, the database is created twice because of the await, maybe make a synchronous call instead of async
    if (_database == null) {
      _database = await _create();
    }

    return _database!;
  }

  static Future<Database> _create() async {
    String? identifier = await UniqueIdentifier.serial;

    if (kDebugMode) {
      print('DataSource: identifier $identifier');
    }

    final databasePath =
        join(await getDatabasesPath(), 'altrcloud_database_32.db');
    if (kDebugMode) {
      print('''
      Creating database connection in path: $databasePath
      ''');
    }

    Database database = await openDatabase(databasePath, version: 1,
        onCreate: (db, version) async {
      await db.execute('''
                CREATE TABLE ${_Tables.STORAGE_PROVIDER.name}(
                  id TEXT PRIMARY KEY,
                  metadata TEXT
                );''');
      await db.execute('''
                CREATE TABLE ${_Tables.CONTENT.name}(
                  id TEXT PRIMARY KEY,
                  name TEXT,
                  sha TEXT,
                  downloadUrl TEXT,
                  size INTEGER,
                  storageProviderId TEXT,
                  createdAtMillisSinceEpoch INTEGER,
                  localPath TEXT,
                  thumbnailPath TEXT,
                  totalChunks INTEGER,
                  chunkSeq INTEGER,
                  chunkSeqId TEXT
                );
                ''');

      await db.execute('''
                CREATE TABLE ${_Tables.CONFIG.name}(
                  id TEXT PRIMARY KEY,
                  metadata TEXT
                );''');

      await db.execute('''
                CREATE TABLE ${_Tables.UPLOAD_STATUS.name}(
                  filename TEXT,
                  chunkSeq INTEGER,
                  chunkSeqId TEXT,
                  chunksCount INTEGER
                );''');

      await db.execute(
          'CREATE INDEX content_name_index ON ${_Tables.CONTENT.name} (name)');
      await db.execute(
          'CREATE INDEX content_chunk_seq_index ON ${_Tables.CONTENT.name} (chunkSeq)');
      await db.execute(
          'CREATE INDEX content_chunk_seq_id_index ON ${_Tables.CONTENT.name} (chunkSeqId)');
      await db.execute(
          'CREATE INDEX content_create_at_index ON ${_Tables.CONTENT.name} (createdAtMillisSinceEpoch)');
      await db.execute(
          'CREATE INDEX content_storage_provider_id_index ON ${_Tables.CONTENT.name} (storageProviderId)');
      await db.execute(
          'CREATE INDEX upload_status_filename_index ON ${_Tables.UPLOAD_STATUS.name} (filename)');
      await db.execute(
          'CREATE INDEX upload_status_chunk_seq_index ON ${_Tables.UPLOAD_STATUS.name} (chunkSeq)');
    });

    return database;
  }
}

class StorageProviderRepository {
  Future<void> delete(StorageProvider provider) async {
    Database database = await DataSource.instance.database;

    await database.rawDelete(
        "DELETE FROM ${_Tables.STORAGE_PROVIDER.name} WHERE id = '${provider.id}'");
  }

  Future<void> save(StorageProvider provider) async {
    Database database = await DataSource.instance.database;

    await database.insert(
      _Tables.STORAGE_PROVIDER.name,
      {'id': provider.id, 'metadata': jsonEncode(provider.toMap())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<StorageProvider>> findAll() async {
    Database database = await DataSource.instance.database;

    final List<Map<String, Object?>> providersMap = await database
        .rawQuery('SELECT * FROM ${_Tables.STORAGE_PROVIDER.name}');

    return [
      for (final {'metadata': metadata as String} in providersMap)
        await _create(metadata),
    ];
  }

  Future<StorageProvider> _create(String metadataJson) async {
    var metadata = jsonDecode(metadataJson);
    SourceType? sourceType = SourceType.of(metadata['sourceType'] as String);

    if (sourceType == SourceType.GITHUB) {
      final github = Github.fromMap(metadata);
      //  await github.initState();
      return github;
    }
    throw Exception('Unsupported $sourceType , $metadata');
  }
}

class ContentRepository {
  Future<void> saveAll(List<Content> contents) async {
    for (Content c in contents) {
      await save(c);
    }
  }

  Future<void> save(Content content) async {
    Database database = await DataSource.instance.database;

    await database.insert(
      _Tables.CONTENT.name,
      content.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Content> findOne(SearchCriteria criteria) async {
    final result = await find(criteria: criteria);
    if (result.isEmpty) {
      throw 'ContentRepository.findOne => no content found';
    }
    if (result.length != 1) {
      throw 'ContentRepository.findOne => more than one content found';
    }

    return result[0];
  }

  Future<Content?> maybeOne(SearchCriteria criteria) async {
    final result = await find(criteria: criteria);
    if (result.isEmpty) {
      return null;
    }
    if (result.length != 1) {
      throw 'ContentRepository.maybeOne => more than one content found';
    }

    return result[0];
  }

  Future<int> totalSize() async {
    Database database = await DataSource.instance.database;

    const alias = 'totalSize';
    final sqlQuery = 'SELECT SUM(size) as $alias FROM ${_Tables.CONTENT.name}';

    final List<Map<String, Object?>> sum = await database.rawQuery(
      sqlQuery,
    );

    return sum[0][alias] as int;
  }

  Future<int> totalContents() async {
    Database database = await DataSource.instance.database;

    const alias = 'totalContents';
    final sqlQuery = 'SELECT COUNT(*) as $alias FROM ${_Tables.CONTENT.name}';

    final List<Map<String, Object?>> sum = await database.rawQuery(
      sqlQuery,
    );

    return sum[0][alias] as int;
  }

  Future<int> totalPrimary() async {
    Database database = await DataSource.instance.database;

    const alias = 'totalPrimary';
    final sqlQuery =
        'SELECT COUNT(*) as $alias FROM ${_Tables.CONTENT.name} WHERE chunkSeq = 0';

    final List<Map<String, Object?>> sum = await database.rawQuery(
      sqlQuery,
    );

    return sum[0][alias] as int;
  }

  Future<List<Content>> find({SearchCriteria? criteria}) async {
    Database database = await DataSource.instance.database;

    final sqlQuery =
        'SELECT * FROM ${_Tables.CONTENT.name} ${_buildSearchSql(criteria)}';
    if (kDebugMode) {
      print('ContentRepository.find => search query : $sqlQuery');
    }
    final List<Map<String, Object?>> contentsMap = await database.rawQuery(
      sqlQuery,
    );

    return contentsMap.map((map) => Content.fromMap(map)).toList();
  }

  String? _buildSearchSql(SearchCriteria? criteria) {
    if (criteria == null) {
      return '';
    }
    return criteria.sql();
  }

  Future<void> deleteByName(Content content) async {
    Database database = await DataSource.instance.database;

    await database.rawDelete(
        "DELETE FROM ${_Tables.CONTENT.name} WHERE name = '${content.name}'");
  }

  Future<Content> update(Content content) async {
    Database database = await DataSource.instance.database;

    await database.update(
      _Tables.CONTENT.name,
      content.toMap(),
      where: 'id = "${content.id}"',
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return await findOne(SearchCriteria(id: content.id, chunkSeq: -1));
  }
}

class SearchCriteria {
  String? id;
  String? name;
  bool exactName;
  String? sortBy;
  String? sortDirection;
  int? chunkSeq;
  String? chunkSeqId;

  SearchCriteria(
      {this.id,
      this.name,
      this.sortBy,
      this.sortDirection,
      this.chunkSeq = 0,
      this.exactName = true,
      this.chunkSeqId});

  String sql() {
    List<String> wheres = [];
    if (chunkSeq != null && chunkSeq! >= 0) {
      wheres.add('chunkSeq = $chunkSeq');
    }

    if (id != null && id?.isNotEmpty == true) {
      wheres.add('id = "$id"');
    }
    if (name != null && name?.isNotEmpty == true) {
      wheres.add('name ${exactName ? '= "$name"' : 'like "%$name%"'}');
    }
    if (chunkSeqId != null && chunkSeqId?.isNotEmpty == true) {
      wheres.add('chunkSeqId = "$chunkSeqId"');
    }

    String sql = '';
    if (wheres.isNotEmpty) {
      sql += ' WHERE ';
      sql += wheres.join(' AND ');
    }

    sql +=
        ' ORDER BY ${sortBy ?? 'createdAtMillisSinceEpoch'} ${sortDirection ?? 'DESC'}';

    return sql;
  }
}

class ConfigRepository {
  Future<void> save(Config config) async {
    Database database = await DataSource.instance.database;

    database.transaction((tx) async {
      // delete existing configuration to only maintain one configuration at all times.
      // for now, this is the easiest solution instead of find existing then upsert.
      await tx.rawDelete('DELETE FROM ${_Tables.CONFIG.name}');

      await tx.insert(
        _Tables.CONFIG.name,
        {'id': config.id, 'metadata': jsonEncode(config.toMap())},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (kDebugMode) {
        print('ConfigRepository.save => config updated !');
      }
    });
  }

  Future<Config> find() async {
    Database database = await DataSource.instance.database;

    final List<Map<String, Object?>> configMap =
        await database.rawQuery('SELECT * FROM ${_Tables.CONFIG.name}');

    if (configMap.isEmpty) {
      if (kDebugMode) {
        print('ConfigRepository.find => creating default config');
      }
      Config newConfig = Config.defaultConfig();
      await save(newConfig);
      return find();
    }

    if (configMap.length != 1) {
      throw 'Invalid configuration, should contains only one entry ! $configMap';
    }

    final {'metadata': json as String} = configMap[0];

    return Config.fromMap(jsonDecode(json));
  }
}

class UploadStatusRepository {
  Future<void> save(UploadStatus uploadStatus) async {
    Database database = await DataSource.instance.database;

    await database.insert(
      _Tables.UPLOAD_STATUS.name,
      uploadStatus.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<UploadStatus>> find({
    required String filename,
    int? chunkSeq,
  }) async {
    Database database = await DataSource.instance.database;

    List<String> whereOps = [];
    whereOps.add('filename = "$filename"');
    if (chunkSeq != null) {
      whereOps.add('chunkSeq = $chunkSeq');
    }

    final sql =
        'SELECT * FROM ${_Tables.UPLOAD_STATUS.name} WHERE ${whereOps.join(' AND ')}';

    final List<Map<String, Object?>> uploadStatuses =
        await database.rawQuery(sql);

    if (kDebugMode) {
      print(
          'UploadStatusRepository.find => $sql | total result : [${uploadStatuses.length}]');
    }

    return uploadStatuses.map((map) => UploadStatus.fromMap(map)).toList();
  }
}
