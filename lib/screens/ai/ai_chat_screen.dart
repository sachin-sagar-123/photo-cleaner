import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

class _ChatMessage {
  final String text;
  final bool isUser;
  final String? imagePath;
  final DateTime time;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.imagePath,
  }) : time = DateTime.now();
}

class AIChatScreen extends ConsumerStatefulWidget {
  final String? initialImagePath;

  const AIChatScreen({super.key, this.initialImagePath});

  @override
  ConsumerState<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends ConsumerState<AIChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _attachedImage;

  @override
  void initState() {
    super.initState();
    _addSystemGreeting();
    if (widget.initialImagePath != null) {
      _attachedImage = widget.initialImagePath;
      // Auto-analyze the initial image
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage('Analyze this photo. Tell me about it — what it shows, '
            'its quality, and whether I should keep or delete it.');
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addSystemGreeting() {
    _messages.add(_ChatMessage(
      text: 'Hi! I\'m your AI photo assistant powered by Gemini. '
          'I can help you:\n\n'
          '📸 Analyze and describe your photos\n'
          '🏷️ Categorize photos automatically\n'
          '🗑️ Suggest which photos to keep or delete\n'
          '💬 Answer questions about your photos\n\n'
          'Attach a photo or ask me anything!',
      isUser: false,
    ));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty && _attachedImage == null) return;

    final gemini = ref.read(geminiServiceProvider);
    if (!gemini.isConfigured) {
      _showApiKeyDialog();
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(
        text: text.trim(),
        isUser: true,
        imagePath: _attachedImage,
      ));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    final imagePath = _attachedImage;
    _attachedImage = null;

    try {
      final response = await gemini.chat(
        text.trim(),
        imagePath: imagePath,
      );
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(text: response, isUser: false));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            text: 'Error: ${e.toString().replaceAll(RegExp(r'Exception: '), '')}',
            isUser: false,
          ));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _pickImage() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) return;

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
      ),
    );
    if (albums.isEmpty) return;

    final assets = await albums.first.getAssetListRange(start: 0, end: 100);
    if (!mounted || assets.isEmpty) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _QuickPhotoPicker(assets: assets),
    );

    if (selected != null && mounted) {
      setState(() => _attachedImage = selected);
    }
  }

  void _showApiKeyDialog() {
    final keyController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Gemini API Key',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your Google Gemini API key.\n'
              'Get one free at ai.google.dev',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'AIza...',
                hintStyle: TextStyle(color: AppTheme.textSecondary),
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
            onPressed: () {
              final key = keyController.text.trim();
              if (key.isNotEmpty) {
                ref.read(geminiServiceProvider).configure(key);
                // Persist the key
                ref.read(geminiApiKeyProvider.notifier).state = key;
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    keyController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New conversation',
            onPressed: () {
              ref.read(geminiServiceProvider).resetChat();
              setState(() {
                _messages.clear();
                _addSystemGreeting();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.key),
            tooltip: 'API Key',
            onPressed: _showApiKeyDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i == _messages.length) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[i]);
              },
            ),
          ),

          // Attached image preview
          if (_attachedImage != null)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_attachedImage!),
                      width: 50, height: 50, fit: BoxFit.cover,
                      cacheWidth: 100,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Photo attached',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _attachedImage = null),
                  ),
                ],
              ),
            ),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.cardColor)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_outlined, color: AppTheme.textSecondary),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Ask about your photos...',
                      hintStyle: const TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.cardColor,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.send, color: AppTheme.primary),
                  onPressed: () => _sendMessage(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: msg.isUser ? AppTheme.primary : AppTheme.cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.imagePath != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(msg.imagePath!),
                    height: 150, fit: BoxFit.cover,
                    cacheWidth: 300,
                  ),
                ),
              ),
            Text(
              msg.text,
              style: TextStyle(
                color: msg.isUser ? Colors.white : AppTheme.textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            _buildDot(1),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + index * 200),
      builder: (ctx, value, child) {
        return Container(
          width: 8, height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.textSecondary.withOpacity(0.3 + value * 0.5),
          ),
        );
      },
    );
  }
}

// ── Quick photo picker ────────────────────────────────────────────────────

class _QuickPhotoPicker extends StatelessWidget {
  final List<AssetEntity> assets;
  const _QuickPhotoPicker({required this.assets});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Select Photo', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, crossAxisSpacing: 2, mainAxisSpacing: 2),
              itemCount: assets.length,
              itemBuilder: (ctx, i) => _QuickPickerTile(
                asset: assets[i],
                onTap: (path) => Navigator.pop(context, path),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPickerTile extends StatefulWidget {
  final AssetEntity asset;
  final ValueChanged<String> onTap;
  const _QuickPickerTile({required this.asset, required this.onTap});

  @override
  State<_QuickPickerTile> createState() => _QuickPickerTileState();
}

class _QuickPickerTileState extends State<_QuickPickerTile> {
  File? _file;

  @override
  void initState() {
    super.initState();
    widget.asset.file.then((f) {
      if (mounted && f != null) setState(() => _file = f);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { if (_file != null) widget.onTap(_file!.path); },
      child: _file != null
          ? Image.file(_file!, fit: BoxFit.cover, cacheWidth: 200, cacheHeight: 200)
          : Container(color: AppTheme.cardColor,
              child: const Center(child: SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5)))),
    );
  }
}
