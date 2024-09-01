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
        await _displayTextInputDialog(context);
      },
    );
  }

  Future<void> _displayTextInputDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Video chunk size'),
          content: TextField(
            controller: _textFieldController,
            decoration: const InputDecoration(hintText: "10"),
          ),
          actions: <Widget>[
            TextButton.icon(
              label: const Text('CANCEL'),
              icon: const Icon(
                Icons.cancel_outlined,
                color: Colors.red,
              ),
              onPressed: () {
                _textFieldController.text = '';
                Navigator.pop(context);
              },
            ),
            TextButton.icon(
              label: const Text('OK'),
              icon: const Icon(
                Icons.check_box_outlined,
                color: Colors.green,
              ),
              onPressed: () async {
                if (isInt(_textFieldController.text)) {
                  await _updateChunkSizeInMB();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Video chunk size should be an integer !'),
                    ),
                  );
                }
                Navigator.pop(context);
              },
            ),
          ],
        );
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
