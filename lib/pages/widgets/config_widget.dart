import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:multicloud/pages/widgets/widgets.dart';
import 'package:multicloud/storageproviders/data_source.dart';
import 'package:multicloud/storageproviders/storage_provider.dart';
import 'package:multicloud/toolkit/utils.dart';

class UploadOnlyOnWifiConfig extends StatefulWidget {
  const UploadOnlyOnWifiConfig({super.key});

  @override
  State<UploadOnlyOnWifiConfig> createState() => _UploadOnlyOnWifiConfigState();
}

class _UploadOnlyOnWifiConfigState extends State<UploadOnlyOnWifiConfig> {
  final ConfigRepository _repository = ConfigRepository();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: FutureBuilder<Config>(
        future: _repository.find(),
        builder: (BuildContext context, AsyncSnapshot<Config> snapshot) {
          return ListTile(
            title: const Text('Upload only on wifi'),
            leading: const Icon(Icons.wifi_outlined),
            trailing: _buildSwitch(
              snapshot,
              (Config config) => config.uploadOnlyOnWifi,
              (bool value) async {
                final config = await _repository.find();
                config.uploadOnlyOnWifi = value;
                _repository.save(config);
                setState(() {
                  // redraw
                });
              },
            ),
          );
        },
      ),
    );
  }
}

class AutoUploadConfig extends StatefulWidget {
  const AutoUploadConfig({super.key});

  @override
  State<AutoUploadConfig> createState() => _AutoUploadConfigState();
}

class _AutoUploadConfigState extends State<AutoUploadConfig> {
  final ConfigRepository _repository = ConfigRepository();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: FutureBuilder<Config>(
        future: _repository.find(),
        builder: (BuildContext context, AsyncSnapshot<Config> snapshot) {
          return ListTile(
            title: const Text('Auto upload'),
            leading: const Icon(Icons.upload),
            trailing: _buildSwitch(
              snapshot,
              (Config config) => config.isAutoUploadEnabled,
              (bool value) async {
                final config = await _repository.find();
                config.autoUpload = value;
                _repository.save(config);
                setState(() {
                  // redraw
                });
              },
            ),
          );
        },
      ),
    );
  }
}

Widget _buildSwitch(
  AsyncSnapshot<Config> snapshot,
  Function(Config) propertyMapper,
  ValueChanged<bool> onChanged,
) {
  if (snapshot.hasError) {
    return const Text('N/A');
  }
  if (!snapshot.hasData) {
    return const CircularProgressIndicator();
  }

  return Switch(
    value: propertyMapper(snapshot.data!),
    activeColor: Colors.red,
    onChanged: onChanged,
  );
}

class ChunkSizeInMBConfig extends StatefulWidget {
  const ChunkSizeInMBConfig({super.key});

  @override
  State<ChunkSizeInMBConfig> createState() => _ChunkSizeInMBConfig();
}

class _ChunkSizeInMBConfig extends State<ChunkSizeInMBConfig> {
  final ConfigRepository _repository = ConfigRepository();
  final TextEditingController _textFieldController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      child: Card(
        child: FutureBuilder<Config>(
          future: _repository.find(),
          builder: (BuildContext context, AsyncSnapshot<Config> snapshot) {
            if (snapshot.hasData) {
              _textFieldController.text = '${snapshot.data!.chunkSizeInMB}';
            }
            return ListTile(
              title: const Text('Video chunk size'),
              leading: const Icon(Icons.video_file_outlined),
              subtitle: _getUsedSize(snapshot),
              trailing: const Icon(Icons.settings_outlined),
            );
          },
        ),
      ),
      onTap: () async {
        await displayTextInputDialog(context, _textFieldController,
            title: 'Video chunk size',
            error: 'Video chunk size should be an integer !',
            hint: '10',
            isValid: isInt,
            onUpdate: () async => await _updateChunkSizeInMB());
      },
    );
  }

  Future<void> _updateChunkSizeInMB() async {
    final config = await _repository.find();
    config.chunkSizeInMB = int.parse(_textFieldController.text);
    await _repository.save(config);
    setState(() {
      // redraw
    });
  }
}

Widget _getUsedSize(AsyncSnapshot<Config> snapshot) {
  if (snapshot.hasError) {
    return const Text('N/A');
  }
  if (!snapshot.hasData) {
    return const CircularProgressIndicator();
  }
  final chunkSize = snapshot.data!.chunkSizeInMB;
  return Text('$chunkSize MB');
}

class ClientCredentialsConfig extends StatefulWidget {
  const ClientCredentialsConfig({super.key});

  @override
  State<ClientCredentialsConfig> createState() => _ClientCredentialsConfig();
}

class _ClientCredentialsConfig extends State<ClientCredentialsConfig> {
  final ConfigRepository _repository = ConfigRepository();
  final TextEditingController _clientIdTextFieldController =
      TextEditingController();
  final TextEditingController _clientSecretTextFieldController =
      TextEditingController();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      child: const Card(
        child: ListTile(
          title: Text('Client credentials'),
          leading: Icon(Icons.account_circle_outlined),
          trailing: Icon(Icons.settings_outlined),
        ),
      ),
      onTap: () async {
        final config = await _repository.find();
        if (config.hasCredentials) {
          showConfirmationDialog(
            context,
            () async => await _showClientIdDialog(context),
            message:
                'Are you sure you want to override the client credentials ?',
          );
        } else {
          await _showClientIdDialog(context);
        }
      },
    );
  }

  Future<void> _showClientIdDialog(BuildContext context) async {
    await displayTextInputDialog(
      context,
      _clientIdTextFieldController,
      title: 'Client id',
      error: 'Client id must not be empty !',
      isValid: (txt) => txt.isNotEmpty,
      onUpdate: () {},
    );

    if (_clientIdTextFieldController.text.isNotEmpty) {
      await _showClientSecretDialog();
    }
  }

  Future<void> _showClientSecretDialog() async {
    await displayTextInputDialog(
      context,
      _clientSecretTextFieldController,
      title: 'Client secret',
      error: 'Client secret must not be empty !',
      isValid: (txt) => txt.isNotEmpty,
      onUpdate: () async => await _updateClientCredentials(),
    );
  }

  Future<void> _updateClientCredentials() async {
    final config = await _repository.find();
    if (_clientIdTextFieldController.text.isEmpty ||
        _clientSecretTextFieldController.text.isEmpty) {
      return;
    }

    config.clientId = _clientIdTextFieldController.text;
    config.clientSecret = _clientSecretTextFieldController.text;

    if (kDebugMode) {
      print('Client credentials updated: [${config.clientId} | ${config.clientSecret}]');
    }

    await _repository.save(config);
    setState(() {
      // redraw
    });
  }
}
