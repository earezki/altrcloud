import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
//import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:multicloud/pages/state/models.dart';
import 'package:multicloud/storageproviders/storage_provider.dart';
import 'package:provider/provider.dart';

class EditPhotoScreen extends StatelessWidget {
  final Content content;

  const EditPhotoScreen({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        child: Center(
            child: FutureBuilder<Uint8List>(
              future: context.read<ContentModel>().loadDataBytes(content),
              builder:
                  (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
                if (!snapshot.hasData) {
                  // while data is loading:
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                } else if (snapshot.hasError) {
                  return const Center(
                    child: Icon(Icons.error),
                  );
                } else {
                  // data loaded:
                  final data = snapshot.data!;
                  return _buildImage(data);
                }
              },
            ),
        ),
        onTap: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildImage(Uint8List data) {
    return Text('Disabled !');
    //return ImageEditor(
    //  image: data, // <-- Uint8List of image
    //);
  }
}
