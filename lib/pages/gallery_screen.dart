import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:multicloud/pages/photo_carousel_screen.dart';
import 'package:multicloud/pages/state/models.dart';
import 'package:multicloud/pages/state/page_state.dart';
import 'package:multicloud/toolkit/file_type.dart';
import 'package:multicloud/pages/widgets/widgets.dart';
import 'package:provider/provider.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({
    super.key,
    required this.content,
    required this.galleryPage,
  });

  final ContentModel content;
  final GalleryPageModel galleryPage;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  static const _scrollbarActivationThreshold = 50;

  @override
  Widget build(BuildContext context) {
    final thumbnails = widget.content.thumbnails;
    if (thumbnails.isEmpty) {
      if (widget.content.isLoading) {
        return const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('No images found !')),
      );
    }

    final contentsByDate = widget.content.contentsByDate;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      bool newVisibleScrollbar =
          contentsByDate.length > _scrollbarActivationThreshold;

      final pageModel = context.read<GalleryPageModel>();
      if (pageModel.visibleScrollbar != newVisibleScrollbar) {
        pageModel.visibleScrollbar = newVisibleScrollbar;
      }
    });

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        childCount: contentsByDate.length,
        (context, index) {
          final date = contentsByDate.keys.elementAt(index);
          final imagesIndices = contentsByDate[date]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(date),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: imagesIndices.length,
                itemBuilder: (context, index) {
                  return _buildGridTile(imagesIndices[index]);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(DateTime date) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Text(
            DateFormat.yMMMEd().format(date),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Divider(
              thickness: 2, // You can customize the thickness of the line here
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildGridTile(int index) {
    final galleryPage = widget.galleryPage;
    if (galleryPage.isNotSelectionMode) {
      return GridTile(
        child: InkResponse(
          child: _buildThumbnail(index),
          onLongPress: () {
            galleryPage.changeSelection(enable: true, index: index);
          },
          onTap: () => {
            Navigator.push(
              context,
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) {
                  return PhotoCarouselScreen(
                    initialIndex: index,
                  );
                },
              ),
            )
          },
        ),
      );
    }
    return GridTile(
      header: GridTileBar(
        leading: Icon(
          galleryPage.isSelected(index)
              ? Icons.check_circle_outline
              : Icons.radio_button_unchecked,
          color: galleryPage.isSelected(index)
              ? Theme.of(context).colorScheme.secondary
              : Colors.grey,
        ),
      ),
      child: GestureDetector(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.inversePrimary.withAlpha(125),
              width: galleryPage.isSelected(index) ? 15.0 : 0.0,
            ),
          ),
          child: _buildThumbnail(index),
        ),
        onLongPress: () {
          setState(() {
            galleryPage.changeSelection(enable: false, index: -1);
          });
        },
        onTap: () {
          galleryPage.select(index);
        },
      ),
    );
  }

  Widget _buildThumbnail(int index) {
    final thumbnail = widget.content.thumbnail(index);

    return FutureBuilder<String>(
      future: widget.content.thumbnailFile(index),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: halfSizedCircularProgress(),
          );
        } else if (snapshot.error != null) {
          return const Center(
            child: Icon(Icons.error),
          );
        } else {
          return Container(
            decoration: BoxDecoration(
              //borderRadius: BorderRadius.circular(20),
              //border: Border.all(
              //  color: Theme.of(context).colorScheme.secondary,
              //  width: 1.0,
              //),

              image: DecorationImage(
                image: FileImage(
                  File(snapshot.data!),
                ),
                fit: BoxFit.fill,
              ),
            ),
            child: thumbnail.fileType == FileType.VIDEO
                ? const Icon(
                    Icons.play_circle_outline,
                    color: Colors.white,
                    size: 48,
                  )
                : null,
          );
        }
      },
    );
  }
}
