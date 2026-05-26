import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoScan = ref.watch(autoScanProvider);
    final backgroundScan = ref.watch(backgroundScanEnabledProvider);
    final scanFrequency = ref.watch(scanFrequencyDaysProvider);
    final compressionMode = ref.watch(defaultCompressionModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Scanning'),
          _ToggleTile(
            icon: Icons.autorenew,
            iconColor: Colors.green,
            title: 'Auto Scan on Open',
            subtitle: 'Scan new photos when app opens',
            value: autoScan,
            onChanged: (v) async {
              ref.read(autoScanProvider.notifier).state = v;
              await ref.read(scanPreferencesProvider).setAutoScan(v);
            },
          ),
          _ToggleTile(
            icon: Icons.schedule,
            iconColor: Colors.blue,
            title: 'Weekly Background Scan',
            subtitle: 'Auto-scan even when app is closed',
            value: backgroundScan,
            onChanged: (v) async {
              ref.read(backgroundScanEnabledProvider.notifier).state = v;
              final bgService = ref.read(backgroundScanProvider);
              if (v) {
                await bgService.registerPeriodicScan(frequencyDays: scanFrequency);
              } else {
                await bgService.cancelPeriodicScan();
              }
            },
          ),
          if (backgroundScan)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('Frequency:',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(width: 12),
                  ...[3, 7, 14].map((days) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${days}d'),
                      selected: scanFrequency == days,
                      onSelected: (_) async {
                        ref.read(scanFrequencyDaysProvider.notifier).state = days;
                        final bgService = ref.read(backgroundScanProvider);
                        await bgService.registerPeriodicScan(frequencyDays: days);
                      },
                      selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: scanFrequency == days
                            ? AppTheme.primary : AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  )),
                ],
              ),
            ),

          const _SectionHeader('Compression'),
          ...CompressionMode.values.map(
            (mode) => RadioListTile<CompressionMode>(
              value: mode,
              groupValue: compressionMode,
              onChanged: (v) => ref
                  .read(defaultCompressionModeProvider.notifier).state = v!,
              title: Text(_modeTitle(mode),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text(_modeSubtitle(mode),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              activeColor: AppTheme.primary,
            ),
          ),

          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline, color: AppTheme.textSecondary),
            title: Text('Version', style: TextStyle(color: AppTheme.textPrimary)),
            trailing: Text('2.0.0', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: AppTheme.error),
            title: const Text('Clear All Data', style: TextStyle(color: AppTheme.error)),
            onTap: () => _confirmClearData(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearData(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Clear All Data',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'This will remove all scanned data. Original photos are not deleted.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear', style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );

    if (confirm == true) {
      final db = ref.read(databaseServiceProvider);
      await db.clearAll();
      ref.invalidate(storageStatsProvider);
      ref.invalidate(duplicatesProvider);
      ref.invalidate(blurryPhotosProvider);
      ref.invalidate(importantPhotosProvider);
      ref.invalidate(importantCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data cleared'),
              backgroundColor: AppTheme.secondary),
        );
      }
    }
  }

  String _modeTitle(CompressionMode m) => switch (m) {
    CompressionMode.lossless => 'Lossless',
    CompressionMode.smart => 'Smart (Recommended)',
    CompressionMode.aggressive => 'Aggressive',
  };

  String _modeSubtitle(CompressionMode m) => switch (m) {
    CompressionMode.lossless => 'No quality loss, strips metadata only',
    CompressionMode.smart => '82% JPEG quality, ~40-60% size reduction',
    CompressionMode.aggressive => '60% quality + resize to 1920px, up to 90% reduction',
  };
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(title.toUpperCase(),
        style: const TextStyle(color: AppTheme.primary, fontSize: 11,
            fontWeight: FontWeight.w700, letterSpacing: 1.2)),
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
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      trailing: Switch(value: value, onChanged: onChanged, activeColor: AppTheme.primary),
    );
  }
}
