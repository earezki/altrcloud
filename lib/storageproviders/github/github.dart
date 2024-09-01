import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:multicloud/storageproviders/encryption.dart';
import 'package:multicloud/storageproviders/storage_provider.dart';
import 'package:retry/retry.dart';

import 'dart:developer';
import 'dart:math' as math;

import 'package:uuid/uuid.dart';

class Github extends StorageProvider {
  static const String _baseApi = 'https://api.github.com';
  static const String _managedRepoPrefix = 'altrcloud-data-';
  static const String _managedOrgPrefix = 'altrcloud';
  static const List<int> _successCodes = [200, 201, 204];
  static const _encodingNameDelimiter = '@';
  static const _readMe = 'README.md';
  static const _maxRepos = 5;

  final String _accessToken;
  final DateTime _accessTokenExpiryDate;
  late String? _orgName;

  late List<_Repository> _repositories = [];
  late _User _user;

  Encryption? _encryption;

  Encryption get _encrypt {
    if (_encryption == null) {
      if (kDebugMode) {
        print('Github => init encryption');
      }
      _encryption = Encryption(secret: _user.secret);
    }

    return _encryption as Encryption;
  }

  Github(
      {required super.id,
      required String accessToken,
      required DateTime accessTokenExpiryDate,
      String? orgName})
      : _orgName = orgName,
        _accessToken = accessToken,
        _accessTokenExpiryDate = accessTokenExpiryDate;

  static Future<Github> connect({
    required String accessToken,
    required DateTime accessTokenExpiryDate,
  }) async {
    var github = Github(
      id: const Uuid().v4(),
      accessToken: accessToken,
      accessTokenExpiryDate: accessTokenExpiryDate,
    );

    await github.initState();

    return github;
  }

  @override
  Github.fromMap(Map<String, Object?> map)
      : _orgName = map['orgName'] as String,
        _accessToken = map['accessToken'] as String,
        _accessTokenExpiryDate = DateTime.fromMillisecondsSinceEpoch(
            map['accessTokenExpiryDateMillisSinceEpoch'] as int),
        _repositories = (map['repositories'] as List<dynamic>)
            .map((json) => _Repository.fromJson(json))
            .toList(),
        _user = _User.fromJson(map['user'] as Map<String, Object?>),
        super(id: map['id'] as String);

  @override
  SupportedBackupType get supportedBackupType => SupportedBackupType.PICTURES;

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'sourceType': SourceType.GITHUB.name,
        'accessToken': _accessToken,
        'accessTokenExpiryDateMillisSinceEpoch':
            _accessTokenExpiryDate.millisecondsSinceEpoch,
        'orgName': _orgName,
        'repositories': _repositories.map((repo) => repo.toMap()).toList(),
        'user': _user.toMap(),
      };

  RetryOptions get _retryOpts => const RetryOptions(
        maxAttempts: 10,
        delayFactor: Duration(seconds: 5),
        randomizationFactor: 0.25,
      );

  @override
  Future<void> initState() async {
    _orgName ??= await _lookupCompatibleOrgNameOrFail();

    _repositories = await _getOrCreateRepositories();
    _user = await _getUser();
    _encryption = Encryption(secret: _user.secret);

    return;
  }

  Future<String> _lookupCompatibleOrgNameOrFail() async {
    var url = Uri.parse('$_baseApi/user/orgs');
    var response = await http.get(url, headers: _getHeaders());

    if (!_successCodes.contains(response.statusCode)) {
      throw Exception(
          'Failed to load organizations ${response.statusCode} : ${response.body}');
    }

    if (kDebugMode) {
      log('_lookupCompatibleOrgNameOrFail => ${response.statusCode} : ${response.body}');
    }

    var org = (jsonDecode(response.body) as List<dynamic>)
        .map((json) => json['login'])
        .where((orgName) => orgName.startsWith(_managedOrgPrefix))
        .firstOrNull;

    if (org == null) {
      throw Exception('No organization found starting with $_managedOrgPrefix');
    }

    return org;
  }

  Future<List<_Repository>> _getOrCreateRepositories() async {
    var repositories = await _getManagedRepositories();
    if (repositories.isNotEmpty) {
      return repositories;
    }

    repositories = [];
    for (var repoIdx = 0; repoIdx < _maxRepos; repoIdx++) {
      var newRepository = await _createNewRepository(repoIdx);
      repositories.add(newRepository);
    }

    return repositories;
  }

  Future<_Repository> _createNewRepository(int repoIdx) async {
    var url = Uri.parse('$_baseApi/orgs/$_orgName/repos');

    var response = await http.post(
      url,
      body: jsonEncode({
        'name': '$_managedRepoPrefix$repoIdx',
        'description': 'This repo is managed by altrcloud',
        'private': true,
        'auto_init': true
      }),
      headers: _getHeaders(),
    );

    final repository =
        _Repository.fromJson(jsonDecode(response.body) as Map<String, dynamic>);

    //Delete README.md
    final contents = await _getContent(repository);
    for (Content c in contents) {
      await _delete(repository._name, c);
    }

    if (kDebugMode) {
      print('Github._createNewRepository => ${repository._name} is created !');
    }

    return repository;
  }

  Future<List<_Repository>> _getManagedRepositories() async {
    var url = Uri.parse('$_baseApi/orgs/$_orgName/repos?type=private');
    var response = await http.get(url, headers: _getHeaders());

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to load repositories ${response.statusCode} : ${response.body}');
    }

    return (jsonDecode(response.body) as List<dynamic>)
        .map((json) => _Repository.fromJson(json))
        .where((repo) => repo._name.startsWith(_managedRepoPrefix))
        .toList();
  }

  _Repository _getAvailableRepository() {
    var random = math.Random();
    final repoIdx = random.nextInt(_repositories.length);
    return _repositories[repoIdx];
  }

  Map<String, String> _getHeaders() {
    return {
      'Accept': 'application/vnd.github+json',
      'Authorization': 'Bearer $_accessToken'
    };
  }

  static const int _encodedNameIdIdx = 0;
  static const int _encodedNameLastModifiedIdx = 1;
  static const int _encodedNameFilenameIdx = 2;
  static const int _encodedChunkSeqIdx = 3;
  static const int _encodedChunkSeqIdIdx = 4;

  String _encodeName({
    required String id,
    required String filename,
    required DateTime lastModified,
    int chunkSeq = 0,
    String? chunkSeqId,
  }) {
    if (id == _readMe) {
      return id;
    }
    final lastModifierEpochInMillis = lastModified.millisecondsSinceEpoch;

    return [id, lastModifierEpochInMillis, filename, chunkSeq, chunkSeqId]
        .join(_encodingNameDelimiter);
  }

  Map<String, Object?> _decodeName(String name) {
    if (!name.contains(_encodingNameDelimiter)) {
      return {
        'contentId': name,
        'lastModified': DateTime.now(),
        'filename': name,
        'chunkSeq': 0
      };
    }

    final nameParts = name.split(_encodingNameDelimiter);
    final id = nameParts[_encodedNameIdIdx];
    final lastModified = DateTime.fromMillisecondsSinceEpoch(
      int.parse(nameParts[_encodedNameLastModifiedIdx]),
    );

    final chunkSeq = int.parse(nameParts[_encodedChunkSeqIdx]);
    final chunkSeqId = nameParts[_encodedChunkSeqIdIdx] == 'null'
        ? null
        : nameParts[_encodedChunkSeqIdIdx];

    return {
      'contentId': id,
      'lastModified': lastModified,
      'filename': nameParts[_encodedNameFilenameIdx],
      'chunkSeq': chunkSeq,
      'chunkSeqId': chunkSeqId,
    };
  }

  @override
  Future<(BackupStatus, Content?)> backup({
    String? contentId,
    int chunkSeq = 0,
    String? chunkSeqId,
    required String filename,
    required Uint8List bytes,
    required DateTime lastModified,
  }) async {
    var repo = _getAvailableRepository();
    var encrypted = await _encrypt.encrypt(bytes);
    String contentInBase64 = base64Encode(encrypted);

    contentId ??= const Uuid().v4();

    final contentName = _encodeName(
      id: contentId,
      filename: filename,
      lastModified: lastModified,
      chunkSeq: chunkSeq,
      chunkSeqId: chunkSeqId,
    );
    final url = Uri.parse(
        '$_baseApi/repos/$_orgName/${repo._name}/contents/$contentName');

    if (kDebugMode) {
      print('Github start backup of file [$filename]/[$chunkSeq] to repo [${repo._name}]');
    }

    final response = await _retryOpts.retry(
      () async => await http.put(
        url,
        headers: _getHeaders(),
        body: jsonEncode(
          <String, String>{'message': filename, 'content': contentInBase64},
        ),
      ),
    );

/*    final response = await http.put(url,
        headers: _getHeaders(),
        body: jsonEncode(
            <String, String>{'message': filename, 'content': contentInBase64}));
*/
    if (_successCodes.contains(response.statusCode)) {
      if (kDebugMode) {
        log('Github success to backup file [$filename] to repo [${repo._name}]');
      }

      var contentJson =
          jsonDecode(response.body)['content'] as Map<String, Object?>;

      return (BackupStatus.OK, _jsonToContent(contentJson));
    } else {
      if (kDebugMode) {
        log('''Github failed to backup file [$filename] to repo [${repo._name}].
         status code: [${response.statusCode}]. body : [${response.body}]''');
      }
    }

    return (BackupStatus.FAILED, null);
  }

  @override
  Future<(Content, List<int>)> loadData(Content content) async {
    if (kDebugMode) {
      print('Github.loadData => ${content.name}|${content.chunkSeq}');
    }
    final url = Uri.parse(content.downloadUrl);
    final response = await http.get(url, headers: _getHeaders());

    if (kDebugMode) {
      print('Github.loadData => ${content.name}|${content.chunkSeq} result: ${response.statusCode}');
    }

    if (!_successCodes.contains(response.statusCode)) {
      throw Exception(
          'Failed to load data of ${content.name} => ${response.statusCode} : ${response.body}');
    }

    final contentInBase64 = ((jsonDecode(response.body)
        as Map<String, Object?>)['content']) as String;

    try {
      final decoded = base64Decode(contentInBase64.replaceAll('\n', ''));
      final data = await _encrypt.decrypt(decoded);
      return (content, data);
    } catch (e) {
      if (kDebugMode) {
        log('Github, fail to decrypt/base64Decode: $e');
      }
      rethrow;
    }
  }

  Future<_User> _getUser() async {
    var url = Uri.parse('$_baseApi/user');
    var response = await http.get(url, headers: _getHeaders());

    if (kDebugMode) {
      print('Loading Github User status code : ${response.statusCode}');
    }

    if (!_successCodes.contains(response.statusCode)) {
      throw ('Failed to load user ${response.statusCode} : ${response.body}');
    }

    var json = jsonDecode(response.body) as Map<String, Object?>;
    return _User.fromJson(json);
  }

  @override
  Future<List<Content>> getContent() async {
    List<Content> allContents = [];
    for (var repo in _repositories) {
      allContents.addAll(
        await _getContent(repo),
      );
    }

    return allContents;
  }

  Future<List<Content>> _getContent(_Repository repo) async {
    var url = Uri.parse('$_baseApi/repos/$_orgName/${repo._name}/contents');
    var response = await http.get(url, headers: _getHeaders());

    if (kDebugMode) {
      log('''Loading Github contents from ${repo._name}
           with status code : ${response.statusCode}''');
    }

    if (!_successCodes.contains(response.statusCode)) {
      if (kDebugMode) {
        log('''Failed to load contents 
            ${response.statusCode} : ${response.body}''');
      }

      return [];
    }

    return (jsonDecode(response.body) as List<dynamic>)
        .map((json) => _jsonToContent(json))
        .toList();
  }

  Content _jsonToContent(Map<String, Object?> json) {
    final name = json['name'] as String;
    final nameDecoded = _decodeName(name);
    final contentId = nameDecoded['contentId'] as String;
    final lastModified = nameDecoded['lastModified'] as DateTime;
    return Content(
      id: contentId,
      storageProviderId: id,
      name: nameDecoded['filename'] as String,
      sha: json['sha'] as String,
      downloadUrl: json['git_url'] as String,
      size: json['size'] as int,
      createdAtMillisSinceEpoch: lastModified.millisecondsSinceEpoch,
      chunkSeq: nameDecoded['chunkSeq'] as int,
      chunkSeqId: nameDecoded['chunkSeqId'] as String?,
    );
  }

  @override
  Future<void> delete(Content content) async {
    final urlParts = content.downloadUrl.split('/');
    final repo =
        urlParts.firstWhere((elm) => elm.startsWith(_managedRepoPrefix));

    await _delete(repo, content);
  }

  Future<void> _delete(String repo, Content content) async {
    final contentName = _encodeName(
      id: content.id,
      filename: content.name,
      lastModified: content.createdAt,
      chunkSeq: content.chunkSeq,
      chunkSeqId: content.chunkSeqId,
    );

    final url =
        Uri.parse('$_baseApi/repos/$_orgName/$repo/contents/$contentName');

    final response = await _retryOpts.retry(
      () async => await http.delete(
        url,
        headers: _getHeaders(),
        body: jsonEncode(<String, String>{
          'message': content.name,
          'branch': 'main',
          'sha': content.sha
        }),
      ),
    );

    if (!_successCodes.contains(response.statusCode)) {
      throw Exception(
          'Failed to delete ${content.name} => ${response.statusCode} : ${response.body}');
    }

    if (kDebugMode) {
      log('Deleted ${content.name} from Github => ${response.statusCode} : ${response.body}');
    }
  }
}

class _Repository {
  final int _id;
  final String _name;
  final String _url;

  _Repository({required int id, required String name, required String url})
      : _id = id,
        _name = name,
        _url = url;

  _Repository.fromJson(Map<String, Object?> json)
      : _id = json['id'] as int,
        _name = json['name'] as String,
        _url = json['url'] as String;

  Map<String, Object?> toMap() => {
        'id': _id,
        'name': _name,
        'url': _url,
      };
}

class _User {
  final int id;
  final String login;

  _User({required this.id, required this.login});

  _User.fromJson(Map<String, Object?> json)
      : id = json['id'] as int,
        login = json['login'] as String;

  Map<String, Object?> toMap() => {
        'id': id,
        'login': login,
      };

  get secret => '$id$login${login.hashCode}';
}
