import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:multicloud/pages/gallery_screen.dart';
import 'package:multicloud/pages/settings_page.dart';
import 'package:multicloud/pages/state/config.dart';
import 'package:multicloud/pages/state/models.dart';
import 'package:multicloud/pages/state/page_state.dart';
import 'package:multicloud/pages/widgets/gallery_search_delegate.dart';
import 'package:multicloud/pages/widgets/widgets.dart';
import 'package:multicloud/storageproviders/data_source.dart';
import 'package:multicloud/storageproviders/store.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../toolkit/thumbnails.dart' as thumbnails;

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _titles = ['Gallery', 'Documents', 'Settings'];
  static const _galleryIndex = 0;
  static const _documentsIndex = 1;
  static const _settingsIndex = 2;

  int _selectedTabIndex = _galleryIndex;

  final _scrollController = ScrollController();

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _asyncInit();
    });

    if (kDebugMode) {
      WakelockPlus.enable();
    }

    super.initState();
  }

  _asyncInit() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
      Permission.manageExternalStorage,
      Permission.audio,
      Permission.videos,
      Permission.photos,
      Permission.locationWhenInUse,
    ].request();

    if (kDebugMode) {
      statuses.forEach((permission, status) =>
          print('permission $permission have: $status'));
    }

    await thumbnails.init();
    if (context.mounted) {
      await context.read<StorageProviderModel>().initState();
      await context.read<Store>().initState();

      _onTabSelected(context.read<StorageProviderModel>().hasNoProviders
          ? _settingsIndex
          : _galleryIndex);
    }
  }

  void _onTabSelected(int index) {
    if (_selectedTabIndex != index) {
      if (index == _settingsIndex) {
        context.read<GalleryPageModel>().visibleScrollbar = false;
      }
      setState(() {
        _selectedTabIndex = index;
      });
    }
  }

  void _backupDir() async {
    final store = context.read<Store>();
    try {
      await store.backup();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload failed !'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.read<ConfigModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final isUploadEnabled = await config.isUploadEnabled;
      if (!isUploadEnabled && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload is not enabled, try to connect to wifi!'),
          ),
        );
      }
    });

    return Scaffold(
      body: Consumer2<GalleryPageModel, Store>(
        builder: (context, galleryPage, store, child) {
          return Scrollbar(
            controller: _scrollController,
            interactive: true,
            radius: const Radius.circular(30),
            trackVisibility: true,
            thickness: galleryPage.visibleScrollbar ? 30 : 0,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: <Widget>[
                SliverAppBar(
                  leading: _buildLeadingAppBar(galleryPage),
                  pinned:
                      store.loadingFile != null || galleryPage.isSelectionMode,
                  snap: true,
                  floating: true,
                  actions: _appBarActions(galleryPage),
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.all(16),
                    title: _buildAppBarTitle(galleryPage),
                    background: Container(
                      color: Theme.of(context).colorScheme.inversePrimary,
                    ),
                  ),
                ),
                _uploadingInfo(),
                _selectedPage(),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Consumer<StorageProviderModel>(
          builder: (context, storageProvider, child) {
        return _buildNavigationBar(context, storageProvider);
      }),
      floatingActionButton: Consumer2<ContentModel, GalleryPageModel>(
          builder: (context, contentModel, galleryPageModel, child) {
        return _buildFloatingActionButton(contentModel, galleryPageModel);
      }),
    );
  }

  Widget _buildNavigationBar(
      BuildContext context, StorageProviderModel storageProvider) {
    if (storageProvider.hasNoProviders) {
      return const SizedBox.shrink();
    }

    return NavigationBar(
      onDestinationSelected: _onTabSelected,
      indicatorColor: Theme.of(context).colorScheme.inversePrimary,
      selectedIndex: _selectedTabIndex,
      destinations: const <NavigationDestination>[
        NavigationDestination(
          icon: Icon(Icons.photo),
          label: 'Gallery',
        ),
        NavigationDestination(
          icon: Icon(Icons.file_copy),
          label: 'Documents',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }

  Widget? _buildLeadingAppBar(GalleryPageModel gallery) {
    if (gallery.isSelectionMode) {
      return IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          gallery.changeSelection(enable: false, index: -1);
        },
      );
    }

    return null;
  }

  Widget _buildAppBarTitle(GalleryPageModel gallery) {
    if (gallery.isSelectionMode) {
      return Row(
        children: [
          const SizedBox(width: 30),
          Text('${gallery.selectionCount}'),
        ],
      );
    }

    final title = _titles[_selectedTabIndex];

    return Text(title);
  }

  Widget _buildFloatingActionButton(
      ContentModel contentModel, GalleryPageModel galleryPage) {
    if (_selectedTabIndex == _settingsIndex) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton(
      onPressed: () {
        if (contentModel.isLoading) {
          return;
        }

        if (galleryPage.isSelectionMode) {
          showConfirmationDialog(
            context,
            () => galleryPage.deleteSelected(
              deleteFromRemote: true,
            ),
            message:
                'We do not delete the file in the device storage, only from the remote storage',
          );
        } else if (galleryPage.isSearchMode) {
          galleryPage.search('');
        } else {
          _backupDir();
        }
      },
      tooltip: galleryPage.isSelectionMode
          ? 'Delete'
          : (galleryPage.isSearchMode ? 'Reset' : 'Backup'),
      child: (contentModel.isLoading
          ? scaledCircularProgress(0.7)
          : galleryPage.isSelectionMode
              ? const Icon(Icons.delete_outline)
              : (galleryPage.isSearchMode
                  ? const Icon(Icons.cancel_outlined)
                  : const Icon(Icons.backup))),
    );
  }

  List<Widget> _appBarActions(GalleryPageModel gallery) {
    List<Widget> actions = [];

    if (gallery.isSelectionMode) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.share_outlined),
          onPressed: () {
            gallery.shareSelected();
          },
        ),
      );
      actions.add(
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () {
            showConfirmationDialog(
              context,
              () => gallery.deleteSelected(
                deleteFromRemote: true,
              ),
              message:
                  'We do not delete the file in the device storage, only from the remote storage',
            );
          },
        ),
      );
    }

    return [
      ...actions,
      PopupMenuButton<String>(
        onSelected: (_) => {},
        itemBuilder: _popupMenu,
      ),
    ];
  }

  List<PopupMenuEntry<String>> _popupMenu(BuildContext context) {
    final gallery = context.read<GalleryPageModel>();
    final contents = context.read<ContentModel>();
    final store = context.read<Store>();

    List<PopupMenuEntry<String>> popupMenus = [];
    if (gallery.isSelectionMode) {
      popupMenus.add(PopupMenuItem<String>(
        value: 'Clear selection',
        child: const ListTile(
          leading: Icon(Icons.clear),
          title: Text('Clear selection'),
        ),
        onTap: () {
          gallery.changeSelection(enable: false, index: -1);
        },
      ));
      popupMenus.add(PopupMenuItem<String>(
        value: 'Select all',
        child: ListTile(
          leading: Icon(
            gallery.isAllSelected()
                ? Icons.tab_unselected_outlined
                : Icons.select_all_outlined,
          ),
          title: Text(
            gallery.isAllSelected() ? 'Unselect all' : 'Select all',
          ),
        ),
        onTap: () {
          gallery.isAllSelected()
              ? gallery.changeSelection(enable: false, index: -1)
              : gallery.selectAll();
        },
      ));
      if (!contents.isLoading) {
        popupMenus.add(PopupMenuItem<String>(
          value: 'Delete',
          child: const ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Colors.red,
            ),
            title: Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
          onTap: () {
            showConfirmationDialog(
              context,
              () => gallery.deleteSelected(
                deleteFromRemote: true,
              ),
              message:
                  'We do not delete the file in the device storage, only from the remote storage',
            );
          },
        ));
        popupMenus.add(PopupMenuItem<String>(
          value: 'Share',
          child: const ListTile(
            leading: Icon(Icons.share_outlined),
            title: Text('Share'),
          ),
          onTap: () {
            gallery.shareSelected();
          },
        ));
      }
      popupMenus.add(const PopupMenuDivider());
    } else {
      popupMenus.add(PopupMenuItem<String>(
        value: 'Sync',
        child: const ListTile(
          leading: Icon(Icons.sync),
          title: Text('Sync'),
        ),
        onTap: () {
          store.sync();
        },
      ));
      popupMenus.add(PopupMenuItem<String>(
        value: 'Resolve conflict',
        child: const ListTile(
          leading: Icon(Icons.auto_fix_normal_outlined),
          title: Text('Resolve conflict'),
        ),
        onTap: () {
          showConfirmationDialog(context,
              () => contents.resolveConflicts().then((_) => _backupDir()));
        },
      ));
      popupMenus.add(const PopupMenuDivider());
    }

    List<PopupMenuEntry<String>> debugActions = [];
    if (kDebugMode) {
      debugActions.add(const PopupMenuDivider());
      debugActions.add(PopupMenuItem<String>(
        value: 'Clear cache',
        child: const ListTile(
          leading: Icon(Icons.delete_outline),
          title: Text('Clear cache'),
        ),
        onTap: () {
          context.read<ContentModel>().clearCache();
        },
      ));

      debugActions.add(
        PopupMenuItem<String>(
          value: 'Clear thumbnails',
          child: const ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Clear thumbnails'),
          ),
          onTap: () {
            context.read<ContentModel>().clearThumbnails();
          },
        ),
      );

      debugActions.add(
        PopupMenuItem<String>(
          value: 'Clear contents from DB',
          child: const ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Clear contents from DB'),
          ),
          onTap: () {
            ContentRepository().deleteAll()
              .then((_) => context.read<ContentModel>().initState());
          },
        ),
      );

      debugActions.add(const PopupMenuDivider());
    }

    return [
      ...popupMenus,
      PopupMenuItem<String>(
        value: 'Search',
        child: const ListTile(
          leading: Icon(Icons.search),
          title: Text('Search'),
        ),
        onTap: () {
          setState(() {
            showSearch(
              context: context,
              delegate: GallerySearchDelegate(
                contentModel: context.read<ContentModel>(),
              ),
            );
          });
        },
      ),
      PopupMenuItem<String>(
        value: 'Settings',
        child: const ListTile(
          leading: Icon(Icons.settings_outlined),
          title: Text('Settings'),
        ),
        onTap: () {
          _onTabSelected(_settingsIndex);
        },
      ),
      ...debugActions
    ];
  }

  Widget _selectedPage() {
    return [
      Consumer2<ContentModel, GalleryPageModel>(
        builder: (context, contentModel, galleryPageModel, child) {
          return GalleryPage(
            content: contentModel,
            galleryPage: galleryPageModel,
          );
        },
      ),
      // Documents page.
      const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('Coming soon !')),
      ),
      const SettingsPage(),
    ][_selectedTabIndex];
  }

  Widget _uploadingInfo() {
    return Consumer<Store>(
      builder: (context, store, child) {
        final loadingFile = store.loadingFile;
        if (loadingFile == null || _selectedTabIndex == _settingsIndex) {
          return SliverToBoxAdapter(
            child: Container(),
          );
        }

        final leadingFilename = loadingFile.filename
            .substring(0, min(10, loadingFile.filename.length));

        return SliverPersistentHeader(
          pinned: true,
          floating: false,
          delegate: _SliverAppBarDelegate(
            minHeight: 90.0,
            maxHeight: 90.0,
            child: Card(
              child: ListTile(
                leading: scaledCircularProgress(0.7),
                title: Text(
                    '$leadingFilename..${loadingFile.extension}|${getUsedSizeString(loadingFile.size)}'),
                subtitle: LinearProgressIndicator(
                  value: loadingFile.uploadedChunks / loadingFile.totalChunks,
                ),
                trailing: Text(
                    '${loadingFile.uploadedChunks}/${loadingFile.totalChunks}'),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
