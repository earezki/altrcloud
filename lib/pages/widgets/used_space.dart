import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:multicloud/pages/state/config.dart';
import 'package:multicloud/pages/widgets/widgets.dart';
import 'package:multicloud/storageproviders/data_source.dart';
import 'package:multicloud/toolkit/cache.dart';
import 'package:multicloud/toolkit/file_utils.dart';
import 'package:multicloud/toolkit/thumbnails.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:developer' as developer;

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

class UsedDatabaseSpace extends StatelessWidget {
  const UsedDatabaseSpace({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: FutureBuilder<int>(
        future: getDatabaseSize(),
        builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
          return ListTile(
            title: const Text('Used database space'),
            leading: const FaIcon(FontAwesomeIcons.floppyDisk),
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

class TotalLocalFiles extends StatelessWidget {
  const TotalLocalFiles({super.key});

  @override
  Widget build(BuildContext context) {
    final ContentRepository repository = ContentRepository();

    return Card(
      child: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          repository.totalPrimary(),
          getTotalFiles(context.read<ConfigModel>().pictureDirectories),
        ]),
        builder: (BuildContext context, AsyncSnapshot<List<dynamic>> snapshot) {
          return ListTile(
            title: const Text('Uploaded/Total files'),
            subtitle: _getProgressIndicator(snapshot),
            trailing: _getUsed(snapshot),
          );
        },
      ),
    );
  }

  Widget _getUsed(AsyncSnapshot<List<dynamic>> snapshot) {
    if (snapshot.hasError) {
      return const Text('N/A');
    }
    if (!snapshot.hasData) {
      return halfSizedCircularProgress();
    }

    final used = snapshot.data![0];
    final total = snapshot.data![1];

    return Text('${used.toInt()} / ${total.toInt()}');
  }

  Widget _getProgressIndicator(AsyncSnapshot<List<dynamic>> snapshot) {
    if (snapshot.hasError) {
      return const SizedBox.shrink();
    }
    if (!snapshot.hasData) {
      return const SizedBox.shrink();
    }

    final used = snapshot.data![0];
    final total = snapshot.data![1];
    return LinearProgressIndicator(
      value: used / total,
    );
  }
}

class TotalLocalFilesSize extends StatelessWidget {
  const TotalLocalFilesSize({super.key});

  @override
  Widget build(BuildContext context) {
    final ContentRepository repository = ContentRepository();

    return Card(
      child: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          repository.totalSize(),
          getDirectoriesSize(context.read<ConfigModel>().pictureDirectories),
        ]),
        builder: (BuildContext context, AsyncSnapshot<List<dynamic>> snapshot) {
          return ListTile(
            title: const Text('Uploaded/Total size'),
            subtitle: _getProgressIndicator(snapshot),
            trailing: _getUsed(snapshot),
          );
        },
      ),
    );
  }

  Widget _getUsed(AsyncSnapshot<List<dynamic>> snapshot) {
    if (snapshot.hasError) {
      return const Text('N/A');
    }
    if (!snapshot.hasData) {
      return halfSizedCircularProgress();
    }

    final used = snapshot.data![0];
    final total = snapshot.data![1];

    return Text('${getUsedSizeString(used)} / ${getUsedSizeString(total)}');
  }

  Widget _getProgressIndicator(AsyncSnapshot<List<dynamic>> snapshot) {
    if (snapshot.hasError) {
      return const SizedBox.shrink();
    }
    if (!snapshot.hasData) {
      return const SizedBox.shrink();
    }

    final used = snapshot.data![0];
    final total = snapshot.data![1];
    return LinearProgressIndicator(
      value: used / total,
    );
  }
}


class HeapUsage extends StatelessWidget {
  const HeapUsage({super.key});

  @override
  Widget build(BuildContext context) {
    return  Card(
      child: ListTile(
        title: const Text('Heap usage'),
        subtitle: LinearProgressIndicator(
          value: ProcessInfo.currentRss / ProcessInfo.maxRss,
        ),
        trailing: Text('${getUsedSizeString(ProcessInfo.currentRss)} / ${getUsedSizeString(ProcessInfo.maxRss)}'),
      ),
    );
  }

}