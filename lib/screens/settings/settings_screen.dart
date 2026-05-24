import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../services/ai_service.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biometricEnabled = ref.watch(biometricEnabledProvider);
    final autoScan = ref.watch(autoScanProvider);
    final backgroundScan = ref.watch(backgroundScanEnabledProvider);
    final scanFrequency = ref.watch(scanFrequencyDaysProvider);
    final compressionMode =
        ref.watch(defaultCompressionModeProvider);
    final driveSignedIn = ref.watch(driveSignedInProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Security'),
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
                await bgService.registerPeriodicScan(
                    frequencyDays: scanFrequency);
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
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(width: 12),
                  ...[3, 7, 14].map((days) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${days}d'),
                          selected: scanFrequency == days,
                          onSelected: (_) async {
                            ref.read(scanFrequencyDaysProvider.notifier)
                                .state = days;
                            final bgService =
                                ref.read(backgroundScanProvider);
                            await bgService.registerPeriodicScan(
                                frequencyDays: days);
                          },
                          selectedColor:
                              AppTheme.primary.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: scanFrequency == days
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
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

          const _SectionHeader('Google Drive'),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
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

          const _SectionHeader('AI Assistant'),
          // Provider selector
          ListTile(
            leading: const Icon(Icons.smart_toy_outlined, color: AppTheme.secondary),
            title: const Text('AI Provider',
                style: TextStyle(color: AppTheme.textPrimary)),
            subtitle: Text(
              ref.watch(aiServiceProvider).provider.displayName,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right,
                color: AppTheme.textSecondary),
            onTap: () => _showProviderPicker(context, ref),
          ),
          // API key
          ListTile(
            leading: const Icon(Icons.key, color: AppTheme.secondary),
            title: const Text('API Key',
                style: TextStyle(color: AppTheme.textPrimary)),
            subtitle: Text(
              ref.watch(aiServiceProvider).isConfigured
                  ? 'Configured'
                  : 'Not set — tap to add',
              style: TextStyle(
                color: ref.watch(aiServiceProvider).isConfigured
                    ? AppTheme.secondary
                    : AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            trailing: const Icon(Icons.chevron_right,
                color: AppTheme.textSecondary),
            onTap: () => _showAIKeyDialog(context, ref),
          ),

          const _SectionHeader('About'),
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

  void _showProviderPicker(BuildContext context, WidgetRef ref) {
    final ai = ref.read(aiServiceProvider);
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Select AI Provider',
            style: TextStyle(color: AppTheme.textPrimary)),
        children: AIProvider.values.map((p) => RadioListTile<AIProvider>(
          value: p,
          groupValue: ai.provider,
          title: Text(p.displayName,
              style: const TextStyle(color: AppTheme.textPrimary)),
          subtitle: Text('Get key at ${p.keyUrl}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          activeColor: AppTheme.primary,
          onChanged: (v) async {
            if (v != null) {
              await ai.setProvider(v);
            }
            if (ctx.mounted) Navigator.pop(ctx);
          },
        )).toList(),
      ),
    );
  }

  void _showAIKeyDialog(BuildContext context, WidgetRef ref) {
    final ai = ref.read(aiServiceProvider);
    final provider = ai.provider;
    final controller = TextEditingController(
      text: ai.getApiKey(provider) ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text('${provider.displayName} API Key',
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Get a key at ${provider.keyUrl}\n'
              'Used for photo captions, categorization, and AI chat.',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: provider.keyHint,
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final key = controller.text.trim();
              if (key.isNotEmpty) {
                await ai.setApiKey(provider, key);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
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
      ref.invalidate(storageStatsProvider);
      ref.invalidate(duplicatesProvider);
      ref.invalidate(vaultDocumentsProvider);
      ref.invalidate(unreviewedCountProvider);
      ref.invalidate(junkPhotosProvider);
      ref.invalidate(blurryPhotosProvider);
      ref.invalidate(backedUpCleanupProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data cleared'),
            backgroundColor: AppTheme.secondary,
          ),
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
          color: iconColor.withValues(alpha: 0.1),
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
