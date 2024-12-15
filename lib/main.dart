import 'package:flutter/material.dart';
import 'package:multicloud/features.dart';
import 'package:multicloud/pages/home_page.dart';
import 'package:multicloud/pages/state/config.dart';
import 'package:multicloud/pages/state/models.dart';
import 'package:multicloud/pages/state/page_state.dart';
import 'package:multicloud/storageproviders/store.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CarouselModel(),
        ),
        ChangeNotifierProvider(
          create: (_) => ConfigModel(),
        ),
        ChangeNotifierProvider(
          create: (_) => StorageProviderModel(),
        ),
        ChangeNotifierProxyProvider<StorageProviderModel, ContentModel>(
          create: (_) => ContentModel(),
          update: (context, provider, prevContent) =>
              prevContent!..updateStorageProvider(provider),
        ),
        ChangeNotifierProxyProvider3<StorageProviderModel, ContentModel, ConfigModel, Store>(
          create: (context) => Store(),
          update: (_, provider, content, config, store) => store!
            ..updateContent(content)
            ..updateStorageProvider(provider)
            ..updateConfig(config),
        ),
        ChangeNotifierProxyProvider<ContentModel, GalleryPageModel>(
          create: (_) => GalleryPageModel(),
          update: (context, content, prevGalleryPage) =>
              prevGalleryPage!..updateContent(content),
        ),
      ],
      child: const MultiCloudManagerApp(),
    ),
  );
}

class MultiCloudManagerApp extends StatelessWidget {
  const MultiCloudManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    initFeatures();

    return MaterialApp(
      title: 'GitPhoto',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ).copyWith(surface: Colors.grey[850]!),
      ),
      home: const HomePage(title: 'Home Page'),
    );
  }
}
