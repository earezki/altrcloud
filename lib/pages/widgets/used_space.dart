import 'package:flutter/material.dart';
import 'package:multicloud/pages/widgets/widgets.dart';
import 'package:multicloud/storageproviders/data_source.dart';
import 'package:multicloud/toolkit/cache.dart';
import 'package:multicloud/toolkit/thumbnails.dart';

class UsedCloudSpace extends StatelessWidget {
  const UsedCloudSpace({super.key});

  @override
  Widget build(BuildContext context) {
    final ContentRepository repository = ContentRepository();

    return Card(
      child: FutureBuilder<int>(
        future: repository.totalSize(),
        builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
          return ListTile(
            title: const Text('Used cloud space'),
            leading: const Icon(Icons.cloud_outlined),
            trailing: _getUsedSize(snapshot),
          );
        },
      ),
    );
  }
}

class UsedCacheSpace extends StatelessWidget {
  const UsedCacheSpace({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: FutureBuilder<int>(
        future: getCacheSize(),
        builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
          return ListTile(
            title: const Text('Used cache space'),
            leading: const Icon(Icons.cached_outlined),
            trailing: _getUsedSize(snapshot),
          );
        },
      ),
    );
  }
}

class UsedThumbnailSpace extends StatelessWidget {
  const UsedThumbnailSpace({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: FutureBuilder<int>(
        future: getThumbnailsSize(),
        builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
          return ListTile(
            title: const Text('Used thumbnail space'),
            leading: const Icon(Icons.account_circle_outlined),
            trailing: _getUsedSize(snapshot),
          );
        },
      ),
    );
  }
}

class TotalPrimaryFiles extends StatelessWidget {
  const TotalPrimaryFiles({super.key});

  @override
  Widget build(BuildContext context) {
    final ContentRepository repository = ContentRepository();

    return Card(
      child: FutureBuilder<int>(
        future: repository.totalPrimary(),
        builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
          return ListTile(
            title: const Text('Total cloud files'),
            leading: const Icon(Icons.file_copy_outlined),
            trailing: !snapshot.hasData
                ? const CircularProgressIndicator()
                : Text('${snapshot.data!}'),
          );
        },
      ),
    );
  }
}

class TotalChunkFiles extends StatelessWidget {
  const TotalChunkFiles({super.key});

  @override
  Widget build(BuildContext context) {
    final ContentRepository repository = ContentRepository();

    return Card(
      child: FutureBuilder<int>(
        future: repository.totalContents(),
        builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
          return ListTile(
            title: const Text('Total chunks'),
            leading: const Icon(Icons.file_copy_outlined),
            trailing: !snapshot.hasData
                ? const CircularProgressIndicator()
                : Text('${snapshot.data!}'),
          );
        },
      ),
    );
  }
}

Widget _getUsedSize(AsyncSnapshot<int> snapshot) {
  if (snapshot.hasError) {
    return const Text('N/A');
  }
  if (!snapshot.hasData) {
    return const CircularProgressIndicator();
  }
  final int usedBytes = snapshot.data!;
  return getUsedSizeWidget(usedBytes);
}
