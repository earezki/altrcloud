import 'package:flutter/material.dart';
import 'package:multicloud/pages/state/models.dart';
import 'package:multicloud/pages/state/page_state.dart';
import 'package:multicloud/storageproviders/storage_provider.dart';
import 'package:provider/provider.dart';

class GallerySearchDelegate extends SearchDelegate<String> {
  late final ContentModel _contentModel;
  late final List<Content> _data;

  GallerySearchDelegate({required ContentModel contentModel}) {
    _contentModel = contentModel;
    _data = contentModel.contents;
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          if (query.isEmpty) {
            close(context, '');
          }
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: AnimatedIcon(
        icon: AnimatedIcons.menu_arrow,
        progress: transitionAnimation,
      ),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results =
        _data.where((element) => element.name.contains(query)).toList();

    if (query.isEmpty) {
      return ListTile(
        title: const Text('Empty search query!'),
        onTap: () {
          close(context, '');
        },
      );
    }

    final gallery = context.read<GalleryPageModel>();
    gallery.search(query).then((_) => close(context, query));

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(results[index].name),
          onTap: () {
            close(context, results[index].name);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = query.isEmpty
        ? _data
        : _data.where((element) => element.name.contains(query)).toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(suggestions[index].name),
          onTap: () {
            query = suggestions[index].name;
            showResults(context);
          },
        );
      },
    );
  }
}
