import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biometricEnabled = ref.watch(biometricEnabledProvider);
    final autoScan = ref.watch(autoScanProvider);
    final compressionMode =
        ref.watch(defaultCompressionModeProvider);
    final driveSignedIn = ref.watch(driveSignedInProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SectionHeader('Security'),
          _ToggleTile(
            icon: Icons.fingerprint,
            iconColor: AppTheme.primary,
            title: 'Biometric Lock',
            subtitle: 'Require biometrics to open vault',
            value: biometricEnabled,
            onChanged: (v) =>
                ref.read(biometricEnabledProvider.notifier).state =
                    v,
          ),

          _SectionHeader('Scanning'),
          _ToggleTile(
            icon: Icons.autorenew,
            iconColor: Colors.green,
            title: 'Auto Scan',
            subtitle: 'Scan photos automatically on open',
            value: autoScan,
            onChanged: (v) =>
                ref.read(autoScanProvider.notifier).state = v,
          ),

          _SectionHeader('Compression'),
          ...CompressionMode.values.map(
            (mode) => RadioListTile<CompressionMode>(
              value: mode,
              groupValue: compressionMode,
              onChanged: (v) => ref
                  .read(defaultCompressionModeProvider.notifier)
                  .state = v!,
              title: Text(_modeTitle(mode),
                  style: const TextStyle(
                      color: AppTheme.textPrimary)),
              subtitle: Text(_modeSubtitle(mode),
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12)),
              activeColor: AppTheme.primary,
            ),
          ),

          _SectionHeader('Google Drive'),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cloud_outlined,
                  color: Colors.blue, size: 20),
            ),
            title: Text(
              driveSignedIn
                  ? 'Connected to Google Drive'
                  : 'Connect Google Drive',
              style: const TextStyle(
                  color: AppTheme.textPrimary),
            ),
            subtitle: Text(
              driveSignedIn
                  ? 'Tap to disconnect'
                  : 'Identify backed-up photos',
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12),
            ),
            trailing: driveSignedIn
                ? const Icon(Icons.check_circle,
                    color: AppTheme.secondary, size: 20)
                : const Icon(Icons.arrow_forward_ios,
                    size: 14,
                    color: AppTheme.textSecondary),
            onTap: () => _toggleDrive(ref, driveSignedIn),
          ),

          _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline,
                color: AppTheme.textSecondary),
            title: Text('Version',
                style:
                    TextStyle(color: AppTheme.textPrimary)),
            trailing: Text('1.0.0',
                style: TextStyle(
                    color: AppTheme.textSecondary)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined,
                color: AppTheme.error),
            title: const Text('Clear All Data',
                style: TextStyle(color: AppTheme.error)),
            onTap: () => _confirmClearData(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleDrive(
      WidgetRef ref, bool currentlySignedIn) async {
    final drive = ref.read(driveSyncServiceProvider);
    if (currentlySignedIn) {
      await drive.signOut();
      ref.read(driveSignedInProvider.notifier).state = false;
    } else {
      final ok = await drive.signIn();
      ref.read(driveSignedInProvider.notifier).state = ok;
    }
  }

  Future<void> _confirmClearData(
      BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Clear All Data',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'This will remove all scanned data and vault documents. Original photos are not deleted.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear',
                  style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );

    if (confirm == true) {
      final db = ref.read(databaseServiceProvider);
      await db.clearAll();
      ref.invalidate(photosProvider);
      ref.invalidate(storageStatsProvider);
      ref.invalidate(duplicatesProvider);
      ref.invalidate(vaultDocumentsProvider);
    }
  }

  String _modeTitle(CompressionMode m) => switch (m) {
        CompressionMode.lossless => 'Lossless',
        CompressionMode.smart => 'Smart (Recommended)',
        CompressionMode.aggressive => 'Aggressive',
      };

  String _modeSubtitle(CompressionMode m) => switch (m) {
        CompressionMode.lossless =>
          'No quality loss, strips metadata only',
        CompressionMode.smart =>
          '82% JPEG quality, ~40–60% size reduction',
        CompressionMode.aggressive =>
          '60% quality + resize to 1920px, up to 90% reduction',
      };
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          style:
              const TextStyle(color: AppTheme.textPrimary)),
      subtitle: Text(subtitle,
          style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 12)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primary,
      ),
    );
  }
}
