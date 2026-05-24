import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../screens/ai/ai_chat_screen.dart';
import '../../screens/browser/photo_browser_screen.dart';
import '../../screens/category/category_photos_screen.dart';
import '../../screens/cleanup/cleanup_screen.dart';
import '../../screens/collage/collage_screen.dart';
import '../../screens/drive/drive_screen.dart';
import '../../screens/duplicates/duplicates_screen.dart';
import '../../screens/editor/photo_editor_screen.dart';
import '../../screens/important/important_photos_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/vault/vault_screen.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen_v2.dart';

// ── Route names ───────────────────────────────────────────────────────────

abstract class AppRoutes {
  static const dashboard = '/';
  static const cleanup = '/cleanup';
  static const duplicates = '/duplicates';
  static const collage = '/collage';
  static const settings = '/settings';
  static const browser = '/browser';
  static const editor = '/editor';
  static const aiChat = '/ai-chat';
  static const important = '/important';
  static const vault = '/vault';
  static const drive = '/drive';
  static const category = '/category';
}

// ── Shell for bottom nav ──────────────────────────────────────────────────

class _MainShell extends StatefulWidget {
  final Widget child;
  const _MainShell({required this.child});

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _index = 0;

  static const _tabs = [
    AppRoutes.dashboard,
    AppRoutes.cleanup,
    AppRoutes.duplicates,
    AppRoutes.collage,
    AppRoutes.settings,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.primary.withOpacity(0.2),
        onDestinationSelected: (i) {
          setState(() => _index = i);
          context.go(_tabs[i]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppTheme.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.cleaning_services_outlined),
            selectedIcon: Icon(Icons.cleaning_services, color: AppTheme.primary),
            label: 'Cleanup',
          ),
          NavigationDestination(
            icon: Icon(Icons.copy_outlined),
            selectedIcon: Icon(Icons.copy, color: AppTheme.primary),
            label: 'Duplicates',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view, color: AppTheme.primary),
            label: 'Collage',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: AppTheme.primary),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ── Router ────────────────────────────────────────────────────────────────

final _shellKey = GlobalKey<NavigatorState>();
final _rootKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: AppRoutes.dashboard,
    routes: [
      // ── Shell routes (with bottom nav) ──────────────────────────────
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (_, state, child) => _MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            pageBuilder: (_, state) => const NoTransitionPage(
              child: DashboardScreenV2(),
            ),
          ),
          GoRoute(
            path: AppRoutes.cleanup,
            pageBuilder: (_, state) => const NoTransitionPage(
              child: CleanupScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.duplicates,
            pageBuilder: (_, state) => const NoTransitionPage(
              child: DuplicatesScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.collage,
            pageBuilder: (_, state) => const NoTransitionPage(
              child: CollageScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (_, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),

      // ── Full-screen routes (no bottom nav) ──────────────────────────
      GoRoute(
        path: AppRoutes.browser,
        builder: (_, state) => const PhotoBrowserScreen(),
      ),
      GoRoute(
        path: AppRoutes.editor,
        builder: (_, state) {
          final path = state.uri.queryParameters['path'] ?? '';
          final name = state.uri.queryParameters['name'];
          return PhotoEditorScreen(imagePath: path, fileName: name);
        },
      ),
      GoRoute(
        path: AppRoutes.aiChat,
        builder: (_, state) {
          final photo = state.uri.queryParameters['photo'];
          return AIChatScreen(initialImagePath: photo);
        },
      ),
      GoRoute(
        path: AppRoutes.important,
        builder: (_, state) => const ImportantPhotosScreen(),
      ),
      GoRoute(
        path: AppRoutes.vault,
        builder: (_, state) => const VaultScreen(),
      ),
      GoRoute(
        path: AppRoutes.drive,
        builder: (_, state) => const DriveScreen(),
      ),
      GoRoute(
        path: AppRoutes.category,
        builder: (_, state) {
          final catIndex = int.tryParse(
              state.uri.queryParameters['id'] ?? '') ?? 5;
          final label = state.uri.queryParameters['label'] ?? 'Photos';
          final colorValue = int.tryParse(
              state.uri.queryParameters['color'] ?? '') ?? 0xFF6C63FF;
          final iconCode = int.tryParse(
              state.uri.queryParameters['icon'] ?? '') ?? 0xe3f4;
          return CategoryPhotosScreen(
            category: PhotoCategory.values[catIndex],
            label: label,
            color: Color(colorValue),
            icon: IconData(iconCode, fontFamily: 'MaterialIcons'),
          );
        },
      ),
    ],
  );
});
