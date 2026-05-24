import 'package:flutter/material.dart';
import 'dashboard/dashboard_screen.dart';
import 'cleanup/cleanup_screen.dart';
import 'duplicates/duplicates_screen.dart';
import 'collage/collage_screen.dart';
import 'settings/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  /// Build only the active screen. Previous screens are disposed,
  /// freeing their widget trees, image caches, and provider subscriptions.
  /// IndexedStack kept all 5 screens alive (~30-50MB wasted).
  Widget _buildScreen(int index) {
    return switch (index) {
      0 => const DashboardScreen(),
      1 => const CleanupScreen(),
      2 => const DuplicatesScreen(),
      3 => const CollageScreen(),
      4 => const SettingsScreen(),
      _ => const DashboardScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildScreen(_currentIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) =>
            setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.cleaning_services_outlined),
            selectedIcon: Icon(Icons.cleaning_services),
            label: 'Cleanup',
          ),
          NavigationDestination(
            icon: Icon(Icons.copy_outlined),
            selectedIcon: Icon(Icons.copy),
            label: 'Duplicates',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Collage',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
