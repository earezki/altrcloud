import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:multicloud/pages/state/models.dart';

class GalleryPageModel extends ChangeNotifier {
  final List<int> _selectedIndexList = [];
  bool _selectionMode = false;
  ContentModel? _contentModel;
  String _searchQuery = '';

  bool _visibleScrollbar = false;

  UnmodifiableListView<int> get selectedIndexList =>
      UnmodifiableListView(_selectedIndexList);

  bool get isSelectionMode => _selectionMode;

  bool get isNotSelectionMode => !_selectionMode;

  bool get isSearchMode => _searchQuery.isNotEmpty;

  bool get visibleScrollbar => _visibleScrollbar;

  set visibleScrollbar(bool newVal) {
    _visibleScrollbar = newVal;
    notifyListeners();
  }

  GalleryPageModel updateContent(ContentModel contentModel) {
    _contentModel = contentModel;
    return this;
  }

  void changeSelection({required bool enable, required int index}) {
    _selectionMode = enable;
    _selectedIndexList.add(index);
    if (index == -1) {
      _selectedIndexList.clear();
    }

    notifyListeners();
  }

  bool isSelected(int index) {
    return _selectionMode && _selectedIndexList.contains(index);
  }

  bool isAllSelected() {
    final thumbnails = _contentModel?.thumbnails ?? [];
    return thumbnails.length == _selectedIndexList.length;
  }

  void selectAll() {
    _selectedIndexList.clear();

    final thumbnails = _contentModel?.thumbnails ?? [];
    for (var idx = 0; idx < thumbnails.length; idx++) {
      _selectedIndexList.add(idx);
    }

    notifyListeners();
  }

  void select(int index) {
    if (isSelected(index)) {
      _selectedIndexList.remove(index);
    } else {
      _selectedIndexList.add(index);
    }

    if (_selectedIndexList.isEmpty) {
      _selectionMode = false;
    }

    notifyListeners();
  }

  void deleteSelected() async {
    if (_selectedIndexList.isNotEmpty) {
      await _contentModel!.delete(_selectedIndexList);

      changeSelection(enable: false, index: -1);
      notifyListeners();
    }
  }

  void shareSelected() async {
    if (_selectedIndexList.isNotEmpty) {
      await _contentModel!.share(_selectedIndexList);

      changeSelection(enable: false, index: -1);
    }
  }

  Future<void> search(String query) async {
    _searchQuery = query;
    await _contentModel?.search(query);
  }
}
