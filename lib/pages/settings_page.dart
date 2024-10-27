import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:multicloud/pages/github_signin.dart';
import 'package:multicloud/pages/widgets/config_widget.dart';
import 'package:multicloud/pages/widgets/used_space.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const widgets = <Widget>[
      ClientCredentialsConfig(),
      GithubSignIn(),
      UploadOnlyOnWifiConfig(),
      AutoUploadConfig(),
      ChunkSizeInMBConfig(),
      TotalLocalFiles(),
      TotalPrimaryFiles(),
      TotalChunkFiles(),
      TotalLocalFilesSize(),
      UsedCloudSpace(),
      UsedCacheSpace(),
      UsedThumbnailSpace(),
      UsedDatabaseSpace(),
      HeapUsage(),
    ];

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
