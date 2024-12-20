import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:multicloud/geo/openstreetmap.dart';
import 'package:multicloud/pages/state/models.dart';
import 'package:multicloud/pages/widgets/widgets.dart';
import 'package:multicloud/storageproviders/storage_provider.dart';
import 'package:multicloud/toolkit/utils.dart';
import 'package:native_exif/native_exif.dart';
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
        subtitle: _getWidgetOfFuture(_getDimensions(), (dims) => Text(dims)),
        leading: const Icon(Icons.image_outlined),
      ),
    );

    tiles.add(
      ListTile(
        title: _getWidgetOfFuture(contentModel.getContentSize(content),
            (bytes) => getUsedSizeWidget(bytes)),
        leading: const Icon(Icons.sd_storage_outlined),
      ),
    );

    tiles.add(
      ListTile(
        title: const Text('Location'),
        subtitle: _getWidgetOfFuture(_getAddress(), (address) => Text(address)),
        leading: const Icon(Icons.location_on_outlined),
      ),
    );

    tiles.add(
      ListTile(
        title: const Text('Chunks'),
        subtitle: _getWidgetOfFuture(contentModel.getNumberOfChunks(content),
            (chunks) => Text('$chunks')),
        leading: const Icon(Icons.numbers_outlined),
      ),
    );

    return tiles;
  }

  Future<String> _getDimensions() async {
    final exif = await Exif.fromPath(content.path);
    final attributes = await exif.getAttributes();

    if (attributes == null) {
      return 'Unavailable';
    }

    final width = attributes['ImageWidth'] ?? 'NA';
    final height = attributes['ImageLength'] ?? 'NA';

    return '$width x $height';
  }

  Future<String> _getAddress() async {
    final exif = await Exif.fromPath(content.path);
    final latlong = await exif.getLatLong();

    // Model
    // ISOSpeedRatings => ISO[val]
    // ImageWidth x ImageLength
    if (kDebugMode) {
      print('${content.path} => ${await exif.getAttributes()}');
    }

    if (latlong == null) {
      return 'Unavailable';
    }

    final address =
        await OpenStreetMapGeocoding.reverseGeocoding(latlong.latitude, latlong.longitude);

    if (address == null) {
      return '(${latlong.latitude}, ${latlong.longitude})';
    }
    return address;
  }

  Widget _getWidgetOfFuture<T>(Future<T> future, Function(T) widget) {
    return FutureBuilder<T>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<T> snapshot) {
        if (snapshot.hasError) {
          return const Text('N/A');
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        final T data = snapshot.data!;
        return widget(data);
      },
    );
  }
}
