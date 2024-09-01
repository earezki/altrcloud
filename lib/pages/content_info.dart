import 'package:flutter/material.dart';
import 'package:multicloud/pages/state/models.dart';
import 'package:multicloud/pages/widgets/widgets.dart';
import 'package:multicloud/storageproviders/storage_provider.dart';
import 'package:multicloud/toolkit/utils.dart';
import 'package:provider/provider.dart';

class ContentInfo extends StatelessWidget {
  final Content content;

  const ContentInfo({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Info'),
      ),
      body: Card(
        child: Column(
          children: _infoTiles(context.read<ContentModel>(), content),
        ),
      ),
    );
  }

  List<Widget> _infoTiles(ContentModel contentModel, Content content) {
    List<Widget> tiles = [];

    tiles.add(
      const ListTile(
        title: Text(
          'DETAILS :',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: Icon(Icons.info_outline),
      ),
    );

    if (content.localPathAvailable) {
      tiles.add(
        ListTile(
          title: Text(content.localPath!),
          leading: const Icon(Icons.folder_open),
        ),
      );
    }

    tiles.add(
      ListTile(
        title: Text(formatDateOnly(content.createdAt)),
        leading: const Icon(Icons.calendar_today_outlined),
      ),
    );

    tiles.add(
      ListTile(
        title: Text(content.name),
        leading: const Icon(Icons.image_outlined),
      ),
    );

    tiles.add(
      ListTile(
        title: _getUsedSize(contentModel.getContentSize(content), (bytes) => getUsedSizeWidget(bytes)),
        leading: const Icon(Icons.sd_storage_outlined),
      ),
    );

    tiles.add(
      ListTile(
        title: const Text('Chunks'),
        subtitle: _getUsedSize(contentModel.getNumberOfChunks(content), (chunks) => Text('$chunks')),
        leading: const Icon(Icons.numbers_outlined),
      ),
    );

    return tiles;
  }

  Widget _getUsedSize(Future<int> size, Function(int) widget) {
    return FutureBuilder<int>(
      future: size,
      builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
        if (snapshot.hasError) {
          return const Text('N/A');
        }
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }
        final int data = snapshot.data!;
        return widget(data);
      },
    );
  }

}
