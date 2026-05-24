import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import '../../theme/app_theme.dart';

/// Full-featured photo editor powered by pro_image_editor.
///
/// Features: crop, rotate, filters, tune (brightness/contrast/saturation),
/// paint/draw, text overlay, emoji/stickers, blur.
///
/// Returns the saved file path on pop, or null if cancelled.
class PhotoEditorScreen extends StatelessWidget {
  final String imagePath;
  final String? fileName;

  const PhotoEditorScreen({
    super.key,
    required this.imagePath,
    this.fileName,
  });

  /// Open the editor and return the saved file path (or null if cancelled).
  static Future<String?> open(
    BuildContext context, {
    required String imagePath,
    String? fileName,
  }) async {
    return Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoEditorScreen(
          imagePath: imagePath,
          fileName: fileName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProImageEditor.file(
      File(imagePath),
      callbacks: ProImageEditorCallbacks(
        onImageEditingComplete: (Uint8List bytes) async {
          // Save edited image to app's documents directory
          final savedPath = await _saveEditedImage(bytes);
          if (context.mounted) {
            Navigator.pop(context, savedPath);
          }
        },
        onCloseEditor: () {
          Navigator.pop(context, null);
        },
      ),
      configs: ProImageEditorConfigs(
        designMode: ImageEditorDesignMode.material,
        imageEditorTheme: ImageEditorTheme(
          background: AppTheme.background,
          appBarBackgroundColor: AppTheme.cardColor,
          appBarForegroundColor: AppTheme.textPrimary,
          bottomBarBackgroundColor: AppTheme.cardColor,
          uiOverlayStyle: const SystemUiOverlayStyle(
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
        i18n: const I18n(
          cancel: 'Cancel',
          done: 'Save',
          paintEditor: I18nPaintEditor(
            bottomNavigationBarText: 'Draw',
          ),
          textEditor: I18nTextEditor(
            bottomNavigationBarText: 'Text',
          ),
          cropRotateEditor: I18nCropRotateEditor(
            bottomNavigationBarText: 'Crop',
          ),
          filterEditor: I18nFilterEditor(
            bottomNavigationBarText: 'Filters',
          ),
          emojiEditor: I18nEmojiEditor(
            bottomNavigationBarText: 'Emoji',
          ),
          blurEditor: I18nBlurEditor(
            bottomNavigationBarText: 'Blur',
          ),
          tuneEditor: I18nTuneEditor(
            bottomNavigationBarText: 'Tune',
          ),
        ),
        paintEditorConfigs: const PaintEditorConfigs(
          hasColorPicker: true,
          hasLineWidthPicker: true,
          editorMinScale: 0.1,
          editorMaxScale: 5.0,
        ),
        textEditorConfigs: const TextEditorConfigs(
          whatsAppCustomTextStyles: [
            TextStyle(fontWeight: FontWeight.bold),
            TextStyle(fontStyle: FontStyle.italic),
            TextStyle(
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ],
        ),
        cropRotateEditorConfigs: const CropRotateEditorConfigs(
          canChangeAspectRatio: true,
          initAspectRatio: CropAspectRatios.custom,
          aspectRatios: [
            AspectRatioItem(text: 'Free', value: CropAspectRatios.custom),
            AspectRatioItem(text: 'Original', value: CropAspectRatios.original),
            AspectRatioItem(text: '1:1', value: 1),
            AspectRatioItem(text: '4:3', value: 4 / 3),
            AspectRatioItem(text: '3:4', value: 3 / 4),
            AspectRatioItem(text: '16:9', value: 16 / 9),
            AspectRatioItem(text: '9:16', value: 9 / 16),
          ],
        ),
        filterEditorConfigs: FilterEditorConfigs(
          filterList: _buildFilterList(),
        ),
        blurEditorConfigs: const BlurEditorConfigs(
          maxBlur: 25.0,
        ),
        tuneEditorConfigs: const TuneEditorConfigs(
          tuneAdjustmentList: [
            TuneAdjustmentItem(
              id: 'brightness',
              label: 'Brightness',
              icon: Icons.brightness_6,
              min: -100,
              max: 100,
            ),
            TuneAdjustmentItem(
              id: 'contrast',
              label: 'Contrast',
              icon: Icons.contrast,
              min: -100,
              max: 100,
            ),
            TuneAdjustmentItem(
              id: 'saturation',
              label: 'Saturation',
              icon: Icons.palette,
              min: -100,
              max: 100,
            ),
            TuneAdjustmentItem(
              id: 'exposure',
              label: 'Exposure',
              icon: Icons.exposure,
              min: -100,
              max: 100,
            ),
            TuneAdjustmentItem(
              id: 'warmth',
              label: 'Warmth',
              icon: Icons.thermostat,
              min: -100,
              max: 100,
            ),
            TuneAdjustmentItem(
              id: 'sharpness',
              label: 'Sharpness',
              icon: Icons.deblur,
              min: 0,
              max: 100,
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _saveEditedImage(Uint8List bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final editedDir = Directory(p.join(dir.path, 'edited'));
    if (!await editedDir.exists()) {
      await editedDir.create(recursive: true);
    }

    final baseName = fileName ?? p.basenameWithoutExtension(imagePath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final savedPath = p.join(editedDir.path, '${baseName}_edited_$timestamp.jpg');

    await File(savedPath).writeAsBytes(bytes);

    // Also save to DCIM so it appears in gallery
    try {
      final dcimDir = Directory('/storage/emulated/0/DCIM/PhotoCleaner Edited');
      if (!await dcimDir.exists()) {
        await dcimDir.create(recursive: true);
      }
      final galleryPath =
          p.join(dcimDir.path, '${baseName}_edited_$timestamp.jpg');
      await File(galleryPath).writeAsBytes(bytes);
    } catch (_) {
      // Gallery save failed — app-local copy still exists
    }

    return savedPath;
  }

  /// Build the filter list with Instagram-style presets.
  static List<FilterModel> _buildFilterList() {
    return [
      // No filter
      FilterModel(
        name: 'Original',
        filters: [],
      ),
      // Clarendon — boosts contrast and saturation, cool shadows
      FilterModel(
        name: 'Clarendon',
        filters: [
          ColorFilterAddons.brightness(0.1),
          ColorFilterAddons.contrast(0.15),
          ColorFilterAddons.saturation(0.2),
        ],
      ),
      // Gingham — soft, vintage, slightly desaturated
      FilterModel(
        name: 'Gingham',
        filters: [
          ColorFilterAddons.brightness(0.05),
          ColorFilterAddons.contrast(-0.05),
          ColorFilterAddons.saturation(-0.15),
          ColorFilterAddons.hue(0.02),
        ],
      ),
      // Moon — B&W with slight blue tint
      FilterModel(
        name: 'Moon',
        filters: [
          ColorFilterAddons.saturation(-1.0),
          ColorFilterAddons.brightness(0.1),
          ColorFilterAddons.contrast(0.1),
        ],
      ),
      // Lark — bright, warm, desaturated blues
      FilterModel(
        name: 'Lark',
        filters: [
          ColorFilterAddons.brightness(0.12),
          ColorFilterAddons.contrast(0.05),
          ColorFilterAddons.saturation(-0.1),
        ],
      ),
      // Reyes — vintage, dusty, low contrast
      FilterModel(
        name: 'Reyes',
        filters: [
          ColorFilterAddons.brightness(0.15),
          ColorFilterAddons.contrast(-0.1),
          ColorFilterAddons.saturation(-0.2),
        ],
      ),
      // Juno — warm tones, boosted reds/yellows
      FilterModel(
        name: 'Juno',
        filters: [
          ColorFilterAddons.contrast(0.1),
          ColorFilterAddons.saturation(0.25),
          ColorFilterAddons.brightness(0.05),
        ],
      ),
      // Slumber — desaturated, warm, dreamy
      FilterModel(
        name: 'Slumber',
        filters: [
          ColorFilterAddons.brightness(0.08),
          ColorFilterAddons.saturation(-0.25),
          ColorFilterAddons.contrast(-0.05),
        ],
      ),
      // Crema — creamy, warm, slightly desaturated
      FilterModel(
        name: 'Crema',
        filters: [
          ColorFilterAddons.brightness(0.1),
          ColorFilterAddons.saturation(-0.1),
          ColorFilterAddons.contrast(-0.05),
        ],
      ),
      // Ludwig — warm, slight vignette feel
      FilterModel(
        name: 'Ludwig',
        filters: [
          ColorFilterAddons.contrast(0.12),
          ColorFilterAddons.saturation(0.05),
          ColorFilterAddons.brightness(0.03),
        ],
      ),
      // Aden — soft, pastel, warm
      FilterModel(
        name: 'Aden',
        filters: [
          ColorFilterAddons.brightness(0.12),
          ColorFilterAddons.contrast(-0.08),
          ColorFilterAddons.saturation(-0.15),
          ColorFilterAddons.hue(0.03),
        ],
      ),
      // Perpetua — soft green tint, bright
      FilterModel(
        name: 'Perpetua',
        filters: [
          ColorFilterAddons.brightness(0.1),
          ColorFilterAddons.saturation(0.1),
          ColorFilterAddons.hue(-0.05),
        ],
      ),
      // Amaro — bright, warm, vintage
      FilterModel(
        name: 'Amaro',
        filters: [
          ColorFilterAddons.brightness(0.15),
          ColorFilterAddons.contrast(0.1),
          ColorFilterAddons.saturation(0.1),
        ],
      ),
      // Mayfair — warm pink tint, soft
      FilterModel(
        name: 'Mayfair',
        filters: [
          ColorFilterAddons.brightness(0.08),
          ColorFilterAddons.contrast(0.05),
          ColorFilterAddons.saturation(0.1),
          ColorFilterAddons.hue(0.02),
        ],
      ),
      // Rise — warm, golden, soft
      FilterModel(
        name: 'Rise',
        filters: [
          ColorFilterAddons.brightness(0.12),
          ColorFilterAddons.contrast(0.05),
          ColorFilterAddons.saturation(0.08),
        ],
      ),
      // Hudson — cool, icy, high contrast
      FilterModel(
        name: 'Hudson',
        filters: [
          ColorFilterAddons.brightness(0.1),
          ColorFilterAddons.contrast(0.15),
          ColorFilterAddons.saturation(-0.1),
          ColorFilterAddons.hue(-0.03),
        ],
      ),
      // Valencia — warm, faded, vintage
      FilterModel(
        name: 'Valencia',
        filters: [
          ColorFilterAddons.brightness(0.08),
          ColorFilterAddons.contrast(-0.05),
          ColorFilterAddons.saturation(0.1),
          ColorFilterAddons.hue(0.03),
        ],
      ),
      // X-Pro II — high contrast, warm vignette
      FilterModel(
        name: 'X-Pro II',
        filters: [
          ColorFilterAddons.contrast(0.2),
          ColorFilterAddons.saturation(0.15),
          ColorFilterAddons.brightness(-0.05),
        ],
      ),
      // Sierra — soft, slightly desaturated
      FilterModel(
        name: 'Sierra',
        filters: [
          ColorFilterAddons.brightness(0.1),
          ColorFilterAddons.contrast(-0.05),
          ColorFilterAddons.saturation(-0.1),
        ],
      ),
      // Willow — soft B&W with warm tint
      FilterModel(
        name: 'Willow',
        filters: [
          ColorFilterAddons.saturation(-0.8),
          ColorFilterAddons.brightness(0.1),
          ColorFilterAddons.contrast(-0.05),
        ],
      ),
      // Lo-Fi — high saturation, high contrast, bold
      FilterModel(
        name: 'Lo-Fi',
        filters: [
          ColorFilterAddons.contrast(0.2),
          ColorFilterAddons.saturation(0.3),
          ColorFilterAddons.brightness(-0.05),
        ],
      ),
      // Inkwell — pure B&W, high contrast
      FilterModel(
        name: 'Inkwell',
        filters: [
          ColorFilterAddons.saturation(-1.0),
          ColorFilterAddons.contrast(0.15),
        ],
      ),
      // Nashville — warm, pink/purple tint, vintage
      FilterModel(
        name: 'Nashville',
        filters: [
          ColorFilterAddons.brightness(0.12),
          ColorFilterAddons.contrast(0.05),
          ColorFilterAddons.saturation(0.15),
          ColorFilterAddons.hue(0.04),
        ],
      ),
      // Stinson — soft, slightly warm
      FilterModel(
        name: 'Stinson',
        filters: [
          ColorFilterAddons.brightness(0.1),
          ColorFilterAddons.contrast(-0.03),
          ColorFilterAddons.saturation(-0.05),
        ],
      ),
      // Vesper — golden hour, warm
      FilterModel(
        name: 'Vesper',
        filters: [
          ColorFilterAddons.brightness(0.08),
          ColorFilterAddons.contrast(0.08),
          ColorFilterAddons.saturation(0.12),
          ColorFilterAddons.hue(0.04),
        ],
      ),
    ];
  }
}
