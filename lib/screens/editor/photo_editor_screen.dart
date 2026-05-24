import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import '../../theme/app_theme.dart';

/// Full-featured photo editor powered by pro_image_editor.
///
/// Features: crop, rotate, filters (25+ Instagram-style presets), tune
/// (brightness/contrast/saturation/exposure/warmth/sharpness), paint/draw,
/// text overlay, emoji/stickers, blur.
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
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: AppTheme.background,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppTheme.cardColor,
            foregroundColor: AppTheme.textPrimary,
          ),
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.primary,
            secondary: AppTheme.secondary,
            surface: AppTheme.surface,
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
        paintEditor: const PaintEditorConfigs(
          canChangeLineWidth: true,
          canChangeOpacity: true,
          editorMinScale: 0.1,
          editorMaxScale: 5.0,
        ),
        textEditor: const TextEditorConfigs(
          customTextStyles: [
            TextStyle(fontWeight: FontWeight.bold),
            TextStyle(fontStyle: FontStyle.italic),
            TextStyle(
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ],
        ),
        cropRotateEditor: const CropRotateEditorConfigs(
          canChangeAspectRatio: true,
          aspectRatios: [
            AspectRatioItem(text: 'Free', value: -1),
            AspectRatioItem(text: 'Original', value: 0.0),
            AspectRatioItem(text: '1:1', value: 1),
            AspectRatioItem(text: '4:3', value: 4 / 3),
            AspectRatioItem(text: '3:4', value: 3 / 4),
            AspectRatioItem(text: '16:9', value: 16 / 9),
            AspectRatioItem(text: '9:16', value: 9 / 16),
          ],
        ),
        filterEditor: FilterEditorConfigs(
          filterList: [
            PresetFilters.none,
            PresetFilters.clarendon,
            PresetFilters.gingham,
            PresetFilters.moon,
            PresetFilters.lark,
            PresetFilters.reyes,
            PresetFilters.juno,
            PresetFilters.slumber,
            PresetFilters.crema,
            PresetFilters.ludwig,
            PresetFilters.aden,
            PresetFilters.perpetua,
            PresetFilters.amaro,
            PresetFilters.mayfair,
            PresetFilters.rise,
            PresetFilters.hudson,
            PresetFilters.valencia,
            PresetFilters.xProII,
            PresetFilters.sierra,
            PresetFilters.willow,
            PresetFilters.loFi,
            PresetFilters.inkwell,
            PresetFilters.nashville,
            PresetFilters.stinson,
            PresetFilters.vesper,
          ],
        ),
        blurEditor: const BlurEditorConfigs(
          maxBlur: 25.0,
        ),
        tuneEditor: TuneEditorConfigs(
          tuneAdjustmentOptions: [
            TuneAdjustmentItem(
              id: 'brightness',
              label: 'Brightness',
              icon: Icons.brightness_6,
              min: -0.5,
              max: 0.5,
              divisions: 200,
              labelMultiplier: 200,
              toMatrix: ColorFilterAddons.brightness,
            ),
            TuneAdjustmentItem(
              id: 'contrast',
              label: 'Contrast',
              icon: Icons.contrast,
              min: -0.5,
              max: 0.5,
              divisions: 200,
              labelMultiplier: 200,
              toMatrix: ColorFilterAddons.contrast,
            ),
            TuneAdjustmentItem(
              id: 'saturation',
              label: 'Saturation',
              icon: Icons.palette,
              min: -0.5,
              max: 0.5,
              divisions: 200,
              labelMultiplier: 200,
              toMatrix: ColorFilterAddons.saturation,
            ),
            TuneAdjustmentItem(
              id: 'exposure',
              label: 'Exposure',
              icon: Icons.exposure,
              min: -1,
              max: 1,
              divisions: 200,
              toMatrix: ColorFilterAddons.exposure,
            ),
            TuneAdjustmentItem(
              id: 'temperature',
              label: 'Warmth',
              icon: Icons.thermostat,
              min: -0.5,
              max: 0.5,
              divisions: 200,
              labelMultiplier: 200,
              toMatrix: ColorFilterAddons.temperature,
            ),
            TuneAdjustmentItem(
              id: 'sharpness',
              label: 'Sharpness',
              icon: Icons.deblur,
              min: 0,
              max: 1,
              divisions: 100,
              toMatrix: ColorFilterAddons.sharpness,
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
    final savedPath =
        p.join(editedDir.path, '${baseName}_edited_$timestamp.jpg');

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
}
