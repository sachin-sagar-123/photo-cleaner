import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final _searchController = TextEditingController();
  List<VaultDocument>? _searchResults;
  bool _exporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = ref.watch(vaultUnlockedProvider);

    if (!unlocked) {
      return _LockScreen(onUnlock: () => _authenticate(ref));
    }

    final docsAsync = ref.watch(vaultDocumentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline),
            onPressed: () =>
                ref.read(vaultUnlockedProvider.notifier).state =
                    false,
            tooltip: 'Lock vault',
          ),
          IconButton(
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary))
                : const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exporting ? null : () => _exportPdf(ref),
            tooltip: 'Export to PDF',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search documents...',
                hintStyle: const TextStyle(
                    color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.search,
                    color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (q) => _search(q, ref),
            ),
          ),
          Expanded(
            child: docsAsync.when(
              data: (docs) {
                final display = _searchResults ?? docs;
                if (display.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_open_outlined,
                            color: AppTheme.textSecondary,
                            size: 48),
                        SizedBox(height: 12),
                        Text('No documents yet',
                            style: TextStyle(
                                color: AppTheme.textSecondary)),
                        SizedBox(height: 4),
                        Text('Tap + to add a document',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12),
                  itemCount: display.length,
                  itemBuilder: (_, i) => _DocumentTile(
                    doc: display[i],
                    onDelete: () => _deleteDoc(display[i].id, ref),
                  ),
                );
              },
              loading: () => const Center(
                  child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(
                          color: AppTheme.error))),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDocumentSheet(ref),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _authenticate(WidgetRef ref) async {
    final vault = ref.read(vaultServiceProvider);
    final ok = await vault.authenticate();
    if (ok) {
      ref.read(vaultUnlockedProvider.notifier).state = true;
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication failed'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _search(String query, WidgetRef ref) async {
    if (query.isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    final vault = ref.read(vaultServiceProvider);
    final results = await vault.search(query);
    setState(() => _searchResults = results);
  }

  Future<void> _deleteDoc(String id, WidgetRef ref) async {
    final vault = ref.read(vaultServiceProvider);
    await vault.deleteDocument(id);
    ref.invalidate(vaultDocumentsProvider);
  }

  Future<void> _exportPdf(WidgetRef ref) async {
    setState(() => _exporting = true);
    try {
      final vault = ref.read(vaultServiceProvider);
      final docs = await vault.getAllDocuments();
      final file = await vault.exportToPdf(docs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to ${file.path}'),
            backgroundColor: AppTheme.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      setState(() => _exporting = false);
    }
  }

  Future<void> _showAddDocumentSheet(WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddDocumentSheet(
        onAdd: (title, type, notes) async {
          // In production, use image_picker here
          // For now, show a placeholder
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Image picker integration required')),
            );
          }
        },
      ),
    );
  }
}

class _LockScreen extends StatelessWidget {
  final VoidCallback onUnlock;

  const _LockScreen({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline,
                  color: AppTheme.primary, size: 48),
            ),
            const SizedBox(height: 24),
            const Text('Document Vault',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Authenticate to access your documents',
                style: TextStyle(
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onUnlock,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Unlock Vault'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final VaultDocument doc;
  final VoidCallback onDelete;

  const _DocumentTile(
      {required this.doc, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(doc.imagePath),
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 56,
              height: 56,
              color: AppTheme.surface,
              child: Icon(
                _docTypeIcon(doc.type),
                color: AppTheme.primary,
              ),
            ),
          ),
        ),
        title: Text(doc.title,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500)),
        subtitle: Text(
          '${doc.type.name} · ${_formatDate(doc.addedAt)}',
          style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline,
              color: AppTheme.error, size: 20),
          onPressed: onDelete,
        ),
      ),
    );
  }

  IconData _docTypeIcon(DocumentType type) => switch (type) {
        DocumentType.idCard => Icons.badge_outlined,
        DocumentType.passport => Icons.book_outlined,
        DocumentType.license => Icons.drive_eta_outlined,
        DocumentType.insurance => Icons.health_and_safety_outlined,
        DocumentType.receipt => Icons.receipt_outlined,
        DocumentType.other => Icons.description_outlined,
      };

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
}

class _AddDocumentSheet extends StatefulWidget {
  final Future<void> Function(
      String title, DocumentType type, String? notes) onAdd;

  const _AddDocumentSheet({required this.onAdd});

  @override
  State<_AddDocumentSheet> createState() =>
      _AddDocumentSheetState();
}

class _AddDocumentSheetState
    extends State<_AddDocumentSheet> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  DocumentType _type = DocumentType.other;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Document',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            style:
                const TextStyle(color: AppTheme.textPrimary),
            decoration: _inputDecoration('Title'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<DocumentType>(
            value: _type,
            dropdownColor: AppTheme.cardColor,
            style:
                const TextStyle(color: AppTheme.textPrimary),
            decoration: _inputDecoration('Document Type'),
            items: DocumentType.values
                .map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.name,
                        style: const TextStyle(
                            color: AppTheme.textPrimary))))
                .toList(),
            onChanged: (v) =>
                setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            style:
                const TextStyle(color: AppTheme.textPrimary),
            decoration: _inputDecoration('Notes (optional)'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onAdd(
                  _titleController.text,
                  _type,
                  _notesController.text.isEmpty
                      ? null
                      : _notesController.text,
                );
              },
              child: const Text('Add Document'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppTheme.textSecondary),
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );
}
