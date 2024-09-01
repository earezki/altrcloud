import 'package:flutter/foundation.dart';
import 'package:multicloud/storageproviders/data_source.dart';

class ConfigModel extends ChangeNotifier {
  final ConfigRepository _configRepository = ConfigRepository();

  Future<bool> get isUploadEnabled async {
    final config = await _configRepository.find();
    return await config.isUploadEnabled();
  }

  Future<bool> get isAutoUploadEnabled async {
    final config = await _configRepository.find();
    final autoUpload = config.isAutoUploadEnabled;
    var uploadEnabled = await config.isUploadEnabled();
    return uploadEnabled && autoUpload;
  }

  Future<List<String>> get pictureDirectories async {
    final config = await _configRepository.find();
    return await config.getPictureDirectories();
  }

  Future<void> uploadOnlyOnWifi(bool uploadOnlyOnWifi) async {
    final config = await _configRepository.find();

    config.uploadOnlyOnWifi = uploadOnlyOnWifi;
    notifyListeners();
  }

  Future<int> get chunkSizeInMB async {
    final config = await _configRepository.find();
    return config.chunkSizeInMB;
  }
}
