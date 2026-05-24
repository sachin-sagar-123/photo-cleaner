import 'dart:convert';
import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/photo_asset.dart';

// ── AI Provider enum ──────────────────────────────────────────────────────

enum AIProvider {
  gemini,
  grok;

  String get displayName => switch (this) {
    AIProvider.gemini => 'Google Gemini',
    AIProvider.grok => 'Grok (xAI)',
  };

  String get keyHint => switch (this) {
    AIProvider.gemini => 'AIza...',
    AIProvider.grok => 'xai-...',
  };

  String get keyUrl => switch (this) {
    AIProvider.gemini => 'ai.google.dev',
    AIProvider.grok => 'console.x.ai',
  };
}

// ── Persistence keys ──────────────────────────────────────────────────────

const _kProvider = 'ai_provider';
const _kGeminiKey = 'ai_gemini_key';
const _kGrokKey = 'ai_grok_key';

// ── Abstract AI backend ───────────────────────────────────────────────────

abstract class _AIBackend {
  Future<String> generateCaption(String imagePath);
  Future<PhotoCategory> categorizePhoto(String imagePath);
  Future<PhotoAIAnalysis> analyzePhoto(String imagePath);
  Future<String> chat(String message, {String? imagePath});
  void resetChat();
}

// ── Main AI Service ───────────────────────────────────────────────────────

class AIService {
  AIProvider _provider = AIProvider.gemini;
  String? _geminiKey;
  String? _grokKey;
  _AIBackend? _backend;
  bool _loaded = false;

  AIProvider get provider => _provider;
  bool get isConfigured => _activeKey != null && _activeKey!.isNotEmpty;
  String? get _activeKey => _provider == AIProvider.gemini ? _geminiKey : _grokKey;

  /// Load persisted provider and keys.
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final providerName = prefs.getString(_kProvider);
    if (providerName == 'grok') _provider = AIProvider.grok;
    _geminiKey = prefs.getString(_kGeminiKey);
    _grokKey = prefs.getString(_kGrokKey);
    _rebuildBackend();
    _loaded = true;
  }

  /// Switch AI provider.
  Future<void> setProvider(AIProvider p) async {
    _provider = p;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProvider, p.name);
    _rebuildBackend();
  }

  /// Set API key for a specific provider.
  Future<void> setApiKey(AIProvider provider, String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (provider == AIProvider.gemini) {
      _geminiKey = key;
      await prefs.setString(_kGeminiKey, key);
    } else {
      _grokKey = key;
      await prefs.setString(_kGrokKey, key);
    }
    _rebuildBackend();
  }

  /// Get stored key for a provider.
  String? getApiKey(AIProvider provider) {
    return provider == AIProvider.gemini ? _geminiKey : _grokKey;
  }

  void _rebuildBackend() {
    final key = _activeKey;
    if (key == null || key.isEmpty) {
      _backend = null;
      return;
    }
    _backend = switch (_provider) {
      AIProvider.gemini => _GeminiBackend(key),
      AIProvider.grok => _GrokBackend(key),
    };
  }

  _AIBackend get _requireBackend {
    if (_backend == null) {
      throw Exception(
        'AI not configured. Add your ${_provider.displayName} API key in Settings.');
    }
    return _backend!;
  }

  Future<String> generateCaption(String imagePath) =>
      _requireBackend.generateCaption(imagePath);

  Future<PhotoCategory> categorizePhoto(String imagePath) =>
      _requireBackend.categorizePhoto(imagePath);

  Future<PhotoAIAnalysis> analyzePhoto(String imagePath) =>
      _requireBackend.analyzePhoto(imagePath);

  /// Batch categorize photos. Returns map of imagePath -> PhotoCategory.
  /// Rate-limited: waits [delayMs] between each API call.
  Future<Map<String, PhotoCategory>> batchCategorize(
    List<String> imagePaths, {
    int delayMs = 200,
  }) async {
    final results = <String, PhotoCategory>{};
    for (final path in imagePaths) {
      try {
        results[path] = await categorizePhoto(path);
      } catch (_) {
        // Skip failures — will be retried on next batch
      }
      if (delayMs > 0) {
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    return results;
  }

  Future<List<PhotoAIAnalysis>> batchAnalyze(List<String> imagePaths) async {
    final results = <PhotoAIAnalysis>[];
    for (final path in imagePaths) {
      try {
        results.add(await analyzePhoto(path));
      } catch (e) {
        results.add(PhotoAIAnalysis(
          quality: 'unknown', shouldKeep: 'maybe',
          reason: 'Analysis failed: $e',
          category: PhotoCategory.other, caption: '',
        ));
      }
    }
    return results;
  }

  Future<String> chat(String message, {String? imagePath}) =>
      _requireBackend.chat(message, imagePath: imagePath);

  void resetChat() => _backend?.resetChat();
}

// ── Gemini Backend ────────────────────────────────────────────────────────

class _GeminiBackend implements _AIBackend {
  final GenerativeModel _model;
  ChatSession? _chatSession;

  _GeminiBackend(String apiKey)
      : _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);

  @override
  Future<String> generateCaption(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final response = await _model.generateContent([
      Content.multi([
        TextPart('Describe this photo in 1-2 sentences. Be concise and natural, '
            'like an Instagram caption. Do not use hashtags.'),
        DataPart('image/jpeg', bytes),
      ]),
    ]);
    return response.text ?? 'Could not generate caption.';
  }

  @override
  Future<PhotoCategory> categorizePhoto(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final response = await _model.generateContent([
      Content.multi([
        TextPart(_categorizationPrompt),
        DataPart('image/jpeg', bytes),
      ]),
    ]);
    final text = (response.text ?? 'other').trim().toLowerCase();
    return PhotoCategoryX.fromName(text);
  }

  @override
  Future<PhotoAIAnalysis> analyzePhoto(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final response = await _model.generateContent([
      Content.multi([
        TextPart(_analysisPrompt),
        DataPart('image/jpeg', bytes),
      ]),
    ]);
    return PhotoAIAnalysis.parse(response.text ?? '');
  }

  @override
  Future<String> chat(String message, {String? imagePath}) async {
    _chatSession ??= _model.startChat();
    final parts = <Part>[TextPart(message)];
    if (imagePath != null) {
      parts.add(DataPart('image/jpeg', await File(imagePath).readAsBytes()));
    }
    final response = await _chatSession!.sendMessage(Content.multi(parts));
    return response.text ?? 'No response.';
  }

  @override
  void resetChat() => _chatSession = null;
}

// ── Grok Backend (xAI OpenAI-compatible API) ──────────────────────────────

class _GrokBackend implements _AIBackend {
  final String _apiKey;
  final List<Map<String, dynamic>> _chatHistory = [];

  static const _baseUrl = 'https://api.x.ai/v1/chat/completions';
  static const _model = 'grok-vision-beta';

  _GrokBackend(this._apiKey);

  Future<String> _complete(List<Map<String, dynamic>> messages) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messages,
        'max_tokens': 1024,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Grok API error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List;
    if (choices.isEmpty) return 'No response.';
    return (choices[0]['message']['content'] as String?) ?? 'No response.';
  }

  List<Map<String, dynamic>> _buildImageMessage(
      String prompt, String imagePath) {
    final bytes = File(imagePath).readAsBytesSync();
    final b64 = base64Encode(bytes);
    return [
      {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': prompt},
          {
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,$b64'},
          },
        ],
      },
    ];
  }

  @override
  Future<String> generateCaption(String imagePath) async {
    return _complete(_buildImageMessage(
      'Describe this photo in 1-2 sentences. Be concise and natural, '
      'like an Instagram caption. Do not use hashtags.',
      imagePath,
    ));
  }

  @override
  Future<PhotoCategory> categorizePhoto(String imagePath) async {
    final text = await _complete(
        _buildImageMessage(_categorizationPrompt, imagePath));
    return PhotoCategoryX.fromName(text.trim());
  }

  @override
  Future<PhotoAIAnalysis> analyzePhoto(String imagePath) async {
    final text = await _complete(
        _buildImageMessage(_analysisPrompt, imagePath));
    return PhotoAIAnalysis.parse(text);
  }

  @override
  Future<String> chat(String message, {String? imagePath}) async {
    if (imagePath != null) {
      final bytes = File(imagePath).readAsBytesSync();
      final b64 = base64Encode(bytes);
      _chatHistory.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': message},
          {
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,$b64'},
          },
        ],
      });
    } else {
      _chatHistory.add({'role': 'user', 'content': message});
    }

    final response = await _complete(_chatHistory);
    _chatHistory.add({'role': 'assistant', 'content': response});
    return response;
  }

  @override
  void resetChat() => _chatHistory.clear();
}

// ── Shared prompts ────────────────────────────────────────────────────────

const _categorizationPrompt =
    'Classify this photo into exactly ONE of these categories: '
    'people, selfie, food, nature, animal, architecture, document, '
    'screenshot, meme, art, travel, sport, vehicle, night, other. '
    'Reply with ONLY the category name, nothing else.';

const _analysisPrompt =
    'Analyze this photo and respond in this exact format:\n'
    'QUALITY: [good/average/poor]\n'
    'KEEP: [yes/no/maybe]\n'
    'REASON: [one sentence why]\n'
    'CATEGORY: [people/selfie/food/nature/animal/architecture/document/'
    'screenshot/meme/art/travel/sport/vehicle/night/other]\n'
    'CAPTION: [1-2 sentence description]';

// ── Data models ───────────────────────────────────────────────────────────

class PhotoAIAnalysis {
  final String quality;
  final String shouldKeep;
  final String reason;
  final PhotoCategory category;
  final String caption;

  const PhotoAIAnalysis({
    required this.quality,
    required this.shouldKeep,
    required this.reason,
    required this.category,
    required this.caption,
  });

  factory PhotoAIAnalysis.parse(String text) {
    String extract(String key) {
      final regex = RegExp('$key:\\s*(.+)', caseSensitive: false);
      return regex.firstMatch(text)?.group(1)?.trim() ?? '';
    }

    final catText = extract('CATEGORY').toLowerCase();
    final category = PhotoCategoryX.fromName(catText);

    return PhotoAIAnalysis(
      quality: extract('QUALITY').toLowerCase(),
      shouldKeep: extract('KEEP').toLowerCase(),
      reason: extract('REASON'),
      category: category,
      caption: extract('CAPTION'),
    );
  }
}
