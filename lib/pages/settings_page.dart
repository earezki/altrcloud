import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:multicloud/features.dart';
import 'package:multicloud/pages/github_signin.dart';
import 'package:multicloud/pages/widgets/config_widget.dart';
import 'package:multicloud/pages/widgets/used_space.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    List<Widget> widgets = [];

    widgets.addAll([
      const ClientCredentialsConfig(),
      const GithubSignIn(),
      const UploadOnlyOnWifiConfig(),
      const TotalLocalFiles(),
      const TotalPrimaryFiles(),
      const TotalChunkFiles(),
      const TotalLocalFilesSize(),
      const UsedCloudSpace(),
      const AutoUploadConfig(),
      const AutoSyncConfig()
    ]);

    if (features.contains(Feature.EDIT_CHUNK_SIZE)) {
      widgets.add(const ChunkSizeInMBConfig());
    }
    if (kDebugMode) {
      widgets.addAll([
        const UsedCacheSpace(),
        const UsedThumbnailSpace(),
        const UsedDatabaseSpace(),
        const HeapUsage(),
      ]);
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: widgets[index],
          );
        },
        childCount: widgets.length,
      ),
    );
  }
}
