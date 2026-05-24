import 'dart:io';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'database_service.dart';

class DocumentVaultService {
  final _auth = LocalAuthentication();
  final _db = DatabaseService();
  final _uuid = const Uuid();

  bool _unlocked = false;
  bool get isUnlocked => _unlocked;

  // ── Biometric Auth ────────────────────────────────────────────────────────

  Future<bool> isBiometricAvailable() async {
    try {
      return await _auth.canCheckBiometrics ||
          await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      _unlocked = await _auth.authenticate(
        localizedReason: 'Unlock your document vault',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      return _unlocked;
    } on PlatformException {
      return false;
    }
  }

  void lock() => _unlocked = false;

  // ── Document CRUD ─────────────────────────────────────────────────────────

  Future<VaultDocument> addDocument({
    required String imagePath,
    required String title,
    required DocumentType type,
    String? notes,
    List<String> tags = const [],
  }) async {
    final dir = await _vaultDirectory();
    final ext = p.extension(imagePath);
    final id = _uuid.v4();
    final destPath = p.join(dir.path, '$id$ext');

    await File(imagePath).copy(destPath);

    final doc = VaultDocument(
      id: id,
      title: title,
      imagePath: destPath,
      type: type,
      addedAt: DateTime.now(),
      notes: notes,
      tags: tags,
    );

    await _db.insertDocument(doc);
    return doc;
  }

  Future<List<VaultDocument>> getAllDocuments() => _db.getAllDocuments();

  Future<List<VaultDocument>> search(String query) =>
      _db.searchDocuments(query);

  Future<void> deleteDocument(String id) async {
    final docs = await _db.getAllDocuments();
    final doc = docs.firstWhere((d) => d.id == id,
        orElse: () => throw Exception('Document not found'));
    final file = File(doc.imagePath);
    if (await file.exists()) await file.delete();
    await _db.deleteDocument(id);
  }

  // ── PDF Export ────────────────────────────────────────────────────────────

  Future<File> exportToPdf(List<VaultDocument> documents) async {
    final pdf = pw.Document();

    for (final doc in documents) {
      final imageFile = File(doc.imagePath);
      if (!await imageFile.exists()) continue;

      final imageBytes = await imageFile.readAsBytes();
      final pdfImage = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                doc.title,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Type: ${doc.type.name} | Added: ${_formatDate(doc.addedAt)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              if (doc.notes != null) ...[
                pw.SizedBox(height: 4),
                pw.Text(doc.notes!,
                    style: const pw.TextStyle(fontSize: 10)),
              ],
              pw.SizedBox(height: 12),
              pw.Expanded(
                child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
              ),
            ],
          ),
        ),
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final outFile = File(p.join(dir.path, 'vault_export.pdf'));
    await outFile.writeAsBytes(await pdf.save());
    return outFile;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<Directory> _vaultDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'vault'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
