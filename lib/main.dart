import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';
import 'screens/main_shell.dart';
import 'services/background_scan_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Cap Flutter's image cache to 50MB and 200 images.
  // Default is 100MB / 1000 images which is excessive for a photo app
  // that scrolls through thousands of thumbnails.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 200;

  // Initialize WorkManager for background scanning
  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  runApp(const ProviderScope(child: PhotoCleanerApp()));
}

class PhotoCleanerApp extends StatelessWidget {
  const PhotoCleanerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhotoCleaner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const MainShell(),
    );
  }
}
