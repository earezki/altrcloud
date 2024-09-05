import 'dart:io';

import 'package:flutter/material.dart';
import 'package:multicloud/pages/photo_carousel_screen.dart';
import 'package:multicloud/pages/state/models.dart';
import 'package:multicloud/pages/state/page_state.dart';
import 'package:multicloud/toolkit/file_type.dart';
import 'package:multicloud/toolkit/utils.dart';
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

  Row _buildSectionTitle(DateTime date) {
    return Row(
      children: [
        // Line (Divider)
        const Expanded(
          child: Divider(
            //color: Colors.black,
            thickness: 2, // You can customize the thickness of the line here
          ),
        ),

        // Spacing between line and text
        const SizedBox(width: 10),

        // Text to the far right
        Text(formatDateOnly(date)),
      ],
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
          child: Hero(
            tag: 'photo-$index',
            child: _buildThumbnail(index),
          ),
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

    final thumbnailFilePath = widget.content.thumbnailFilepath(index);

    return Container(
      decoration: BoxDecoration(
          image: DecorationImage(
        image: FileImage(
          File(thumbnailFilePath),
        ),
        fit: BoxFit.fill,
      )),
      child: thumbnail.fileType == FileType.VIDEO
          ? const Icon(
              Icons.play_circle_outline,
              color: Colors.white,
              size: 48,
            )
          : null,
    );
  }
}
