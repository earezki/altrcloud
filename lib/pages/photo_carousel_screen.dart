import 'dart:io';

import 'package:flutter/material.dart';
import 'package:multicloud/pages/content_info.dart';
import 'package:multicloud/pages/easy_image_view.dart';
import 'package:multicloud/pages/edit_photo_screen.dart';
import 'package:multicloud/pages/state/models.dart';
import 'package:multicloud/pages/widgets/video_player.dart';
import 'package:multicloud/storageproviders/storage_provider.dart';
import 'package:multicloud/toolkit/file_type.dart';
import 'package:provider/provider.dart';

class PhotoCarouselScreen extends StatefulWidget {
  const PhotoCarouselScreen({super.key, required this.initialIndex});

  final int initialIndex;

  @override
  State<PhotoCarouselScreen> createState() => _PhotoCarouselScreenState();
}

class _PhotoCarouselScreenState extends State<PhotoCarouselScreen> {
  late PageController _pageController;
  bool _pagingEnabled = true;
  Content? _selected;

  @override
  void initState() {
    _pageController = PageController(initialPage: widget.initialIndex);
    //this is here the controller takes the index and scrolls to that Page

    _selected = context.read<ContentModel>().contents[widget.initialIndex];
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contentModel = context.read<ContentModel>();
    final contents = contentModel.contents;

    return Scaffold(
      appBar: _pagingEnabled
          ? AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              actions: [
                PopupMenuButton<String>(
                  onSelected: (_) => {},
                  itemBuilder: _popupMenu,
                ),
              ],
            )
          : null,
      body: PageView.builder(
        physics: _pagingEnabled
            ? const PageScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        itemCount: contents.length,
        controller: _pageController,
        pageSnapping: true,
        itemBuilder: (context, index) {
          return FutureBuilder<Content>(
            future: contentModel.loadContent(index),
            builder: (BuildContext context, AsyncSnapshot<Content> snapshot) {
              if (!snapshot.hasData) {
                // while data is loading:
                return const Center(
                  child: CircularProgressIndicator(),
                );
              } else if (snapshot.error != null) {
                return const Center(
                  child: Icon(Icons.error),
                );
              } else {
                // data loaded:
                final data = snapshot.data!;
                _selected = data;
                return _buildContentWidget(data);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildContentWidget(Content data) {
    if (data.fileType == FileType.PICTURE) {
      return EasyImageView(
        imageProvider: FileImage(File(data.path)),
        onScaleChanged: (scale) {
          var newPagingEnabled = scale <= 1.0;
          if (newPagingEnabled != _pagingEnabled) {
            setState(() {
              // Disable paging when image is zoomed-in
              _pagingEnabled = newPagingEnabled;
            });
          }
        },
      );
    } else if (data.fileType == FileType.VIDEO) {
      return VideoPlayerScreen(video: data);
    }

    throw 'Unsupported file type ${data.fileType}';
  }

  List<PopupMenuEntry<String>> _popupMenu(BuildContext context) {
    List<PopupMenuItem<String>> menus = [];

    if (_selected!.fileType == FileType.PICTURE) {
      menus.add(
        PopupMenuItem<String>(
          value: 'Edit',
          child: const ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit'),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) {
                  return EditPhotoScreen(
                    content: _selected!,
                  );
                },
              ),
            );
          },
        ),
      );
    }
    return [
      PopupMenuItem<String>(
        value: 'Info',
        child: const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Info'),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) {
                return ContentInfo(
                  content: _selected!,
                );
              },
            ),
          );
        },
      ),
      ...menus
    ];
  }
}
