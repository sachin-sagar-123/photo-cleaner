import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';

/// Gemini AI service for photo analysis, captions, and chat.
class GeminiService {
  GenerativeModel? _model;
  ChatSession? _chatSession;
  String? _apiKey;

  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  /// Initialize with API key.
  void configure(String apiKey) {
    _apiKey = apiKey;
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );
    _chatSession = null;
  }

  GenerativeModel get _requireModel {
    if (_model == null) throw Exception('Gemini not configured. Add API key in Settings.');
    return _model!;
  }

  /// Generate a caption/description for a photo.
  Future<String> generateCaption(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final content = Content.multi([
      TextPart('Describe this photo in 1-2 sentences. Be concise and natural, '
          'like an Instagram caption. Do not use hashtags.'),
      DataPart('image/jpeg', bytes),
    ]);

    final response = await _requireModel.generateContent([content]);
    return response.text ?? 'Could not generate caption.';
  }

  /// Categorize a photo into predefined categories.
  Future<PhotoAICategory> categorizePhoto(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final content = Content.multi([
      TextPart(
        'Classify this photo into exactly ONE of these categories: '
        'people, selfie, food, nature, animal, architecture, document, '
        'screenshot, meme, art, travel, sport, vehicle, night, other. '
        'Reply with ONLY the category name, nothing else.',
      ),
      DataPart('image/jpeg', bytes),
    ]);

    final response = await _requireModel.generateContent([content]);
    final text = (response.text ?? 'other').trim().toLowerCase();

    return PhotoAICategory.values.firstWhere(
      (c) => c.name == text,
      orElse: () => PhotoAICategory.other,
    );
  }

  /// Analyze photo quality and suggest keep/delete.
  Future<PhotoAIAnalysis> analyzePhoto(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final content = Content.multi([
      TextPart(
        'Analyze this photo and respond in this exact format:\n'
        'QUALITY: [good/average/poor]\n'
        'KEEP: [yes/no/maybe]\n'
        'REASON: [one sentence why]\n'
        'CATEGORY: [people/selfie/food/nature/animal/architecture/document/'
        'screenshot/meme/art/travel/sport/vehicle/night/other]\n'
        'CAPTION: [1-2 sentence description]',
      ),
      DataPart('image/jpeg', bytes),
    ]);

    final response = await _requireModel.generateContent([content]);
    return PhotoAIAnalysis.parse(response.text ?? '');
  }

  /// Batch analyze multiple photos — returns analysis for each.
  Future<List<PhotoAIAnalysis>> batchAnalyze(List<String> imagePaths) async {
    final results = <PhotoAIAnalysis>[];
    for (final path in imagePaths) {
      try {
        results.add(await analyzePhoto(path));
      } catch (e) {
        results.add(PhotoAIAnalysis(
          quality: 'unknown',
          shouldKeep: 'maybe',
          reason: 'Analysis failed: $e',
          category: PhotoAICategory.other,
          caption: '',
        ));
      }
    }
    return results;
  }

  /// Start or continue a chat session about photos.
  Future<String> chat(String message, {String? imagePath}) async {
    _chatSession ??= _requireModel.startChat();

    final parts = <Part>[TextPart(message)];
    if (imagePath != null) {
      final bytes = await File(imagePath).readAsBytes();
      parts.add(DataPart('image/jpeg', bytes));
    }

    final response = await _chatSession!.sendMessage(Content.multi(parts));
    return response.text ?? 'No response.';
  }

  /// Reset chat session.
  void resetChat() {
    _chatSession = null;
  }
}

// ── Data models ───────────────────────────────────────────────────────────

enum PhotoAICategory {
  people, selfie, food, nature, animal, architecture,
  document, screenshot, meme, art, travel, sport,
  vehicle, night, other;

  String get displayName => switch (this) {
    PhotoAICategory.people => 'People',
    PhotoAICategory.selfie => 'Selfie',
    PhotoAICategory.food => 'Food',
    PhotoAICategory.nature => 'Nature',
    PhotoAICategory.animal => 'Animal',
    PhotoAICategory.architecture => 'Architecture',
    PhotoAICategory.document => 'Document',
    PhotoAICategory.screenshot => 'Screenshot',
    PhotoAICategory.meme => 'Meme',
    PhotoAICategory.art => 'Art',
    PhotoAICategory.travel => 'Travel',
    PhotoAICategory.sport => 'Sport',
    PhotoAICategory.vehicle => 'Vehicle',
    PhotoAICategory.night => 'Night',
    PhotoAICategory.other => 'Other',
  };

  String get emoji => switch (this) {
    PhotoAICategory.people => '👥',
    PhotoAICategory.selfie => '🤳',
    PhotoAICategory.food => '🍕',
    PhotoAICategory.nature => '🌿',
    PhotoAICategory.animal => '🐾',
    PhotoAICategory.architecture => '🏛️',
    PhotoAICategory.document => '📄',
    PhotoAICategory.screenshot => '📱',
    PhotoAICategory.meme => '😂',
    PhotoAICategory.art => '🎨',
    PhotoAICategory.travel => '✈️',
    PhotoAICategory.sport => '⚽',
    PhotoAICategory.vehicle => '🚗',
    PhotoAICategory.night => '🌙',
    PhotoAICategory.other => '📷',
  };
}

class PhotoAIAnalysis {
  final String quality;
  final String shouldKeep;
  final String reason;
  final PhotoAICategory category;
  final String caption;

  const PhotoAIAnalysis({
    required this.quality,
    required this.shouldKeep,
    required this.reason,
    required this.category,
    required this.caption,
  });

  /// Parse structured response from Gemini.
  factory PhotoAIAnalysis.parse(String text) {
    String extract(String key) {
      final regex = RegExp('$key:\\s*(.+)', caseSensitive: false);
      final match = regex.firstMatch(text);
      return match?.group(1)?.trim() ?? '';
    }

    final catText = extract('CATEGORY').toLowerCase();
    final category = PhotoAICategory.values.firstWhere(
      (c) => c.name == catText,
      orElse: () => PhotoAICategory.other,
    );

    return PhotoAIAnalysis(
      quality: extract('QUALITY').toLowerCase(),
      shouldKeep: extract('KEEP').toLowerCase(),
      reason: extract('REASON'),
      category: category,
      caption: extract('CAPTION'),
    );
  }
}
