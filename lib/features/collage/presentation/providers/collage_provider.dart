import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/collage_template.dart';
import '../../domain/models/sticker_overlay.dart';
import '../../domain/models/text_overlay.dart';

// ── Panel mode ────────────────────────────────────────────────────────────

enum CollagePanelMode { layout, style, text, stickers }

// ── Collage State ─────────────────────────────────────────────────────────

class CollageState {
  final CollageTemplate template;
  final Map<int, String> slotPhotos;
  final double spacing;
  final double cornerRadius;
  final CollageBgStyle bgStyle;
  final List<TextOverlay> textOverlays;
  final List<StickerOverlay> stickerOverlays;
  final int? selectedTextIndex;
  final int? selectedStickerIndex;
  final CollagePanelMode panelMode;
  final bool isRendering;
  final File? renderedFile;

  const CollageState({
    required this.template,
    this.slotPhotos = const {},
    this.spacing = 8,
    this.cornerRadius = 12,
    required this.bgStyle,
    this.textOverlays = const [],
    this.stickerOverlays = const [],
    this.selectedTextIndex,
    this.selectedStickerIndex,
    this.panelMode = CollagePanelMode.layout,
    this.isRendering = false,
    this.renderedFile,
  });

  bool get allSlotsFilled => slotPhotos.length == template.photoCount;

  CollageState copyWith({
    CollageTemplate? template,
    Map<int, String>? slotPhotos,
    double? spacing,
    double? cornerRadius,
    CollageBgStyle? bgStyle,
    List<TextOverlay>? textOverlays,
    List<StickerOverlay>? stickerOverlays,
    int? Function()? selectedTextIndex,
    int? Function()? selectedStickerIndex,
    CollagePanelMode? panelMode,
    bool? isRendering,
    File? Function()? renderedFile,
  }) => CollageState(
    template: template ?? this.template,
    slotPhotos: slotPhotos ?? this.slotPhotos,
    spacing: spacing ?? this.spacing,
    cornerRadius: cornerRadius ?? this.cornerRadius,
    bgStyle: bgStyle ?? this.bgStyle,
    textOverlays: textOverlays ?? this.textOverlays,
    stickerOverlays: stickerOverlays ?? this.stickerOverlays,
    selectedTextIndex: selectedTextIndex != null ? selectedTextIndex() : this.selectedTextIndex,
    selectedStickerIndex: selectedStickerIndex != null ? selectedStickerIndex() : this.selectedStickerIndex,
    panelMode: panelMode ?? this.panelMode,
    isRendering: isRendering ?? this.isRendering,
    renderedFile: renderedFile != null ? renderedFile() : this.renderedFile,
  );
}

// ── Collage Notifier ──────────────────────────────────────────────────────

class CollageNotifier extends StateNotifier<CollageState> {
  CollageNotifier() : super(CollageState(
    template: CollageTemplates.all[0],
    bgStyle: CollageBgStyles.all[0],
  ));

  void selectTemplate(CollageTemplate t) {
    final cleaned = Map<int, String>.from(state.slotPhotos)
      ..removeWhere((k, _) => k >= t.photoCount);
    state = state.copyWith(
      template: t,
      slotPhotos: cleaned,
      renderedFile: () => null,
    );
  }

  void setPhotoForSlot(int index, String path) {
    state = state.copyWith(
      slotPhotos: {...state.slotPhotos, index: path},
      renderedFile: () => null,
    );
  }

  void swapSlots(int from, int to) {
    final photos = Map<int, String>.from(state.slotPhotos);
    final temp = photos[from];
    photos[from] = photos[to]!;
    if (temp != null) {
      photos[to] = temp;
    } else {
      photos.remove(to);
    }
    state = state.copyWith(slotPhotos: photos, renderedFile: () => null);
  }

  void setSpacing(double v) => state = state.copyWith(
      spacing: v, renderedFile: () => null);

  void setCornerRadius(double v) => state = state.copyWith(
      cornerRadius: v, renderedFile: () => null);

  void setBgStyle(CollageBgStyle bg) => state = state.copyWith(
      bgStyle: bg, renderedFile: () => null);

  void setPanelMode(CollagePanelMode mode) =>
      state = state.copyWith(panelMode: mode);

  // ── Text overlays ────────────────────────────────────────────────────

  void addText() {
    final overlays = [...state.textOverlays, TextOverlay(text: 'Tap to edit')];
    state = state.copyWith(
      textOverlays: overlays,
      selectedTextIndex: () => overlays.length - 1,
      selectedStickerIndex: () => null,
      panelMode: CollagePanelMode.text,
      renderedFile: () => null,
    );
  }

  void updateText(int index, TextOverlay overlay) {
    final overlays = [...state.textOverlays];
    overlays[index] = overlay;
    state = state.copyWith(textOverlays: overlays, renderedFile: () => null);
  }

  void selectText(int index) => state = state.copyWith(
    selectedTextIndex: () => index,
    selectedStickerIndex: () => null,
    panelMode: CollagePanelMode.text,
  );

  // ── Sticker overlays ─────────────────────────────────────────────────

  void addSticker(String emoji) {
    final overlays = [...state.stickerOverlays, StickerOverlay(emoji: emoji)];
    state = state.copyWith(
      stickerOverlays: overlays,
      selectedStickerIndex: () => overlays.length - 1,
      selectedTextIndex: () => null,
      renderedFile: () => null,
    );
  }

  void updateSticker(int index, StickerOverlay sticker) {
    final overlays = [...state.stickerOverlays];
    overlays[index] = sticker;
    state = state.copyWith(stickerOverlays: overlays, renderedFile: () => null);
  }

  void selectSticker(int index) => state = state.copyWith(
    selectedStickerIndex: () => index,
    selectedTextIndex: () => null,
    panelMode: CollagePanelMode.stickers,
  );

  // ── Delete selected ──────────────────────────────────────────────────

  void deleteSelected() {
    if (state.selectedTextIndex != null) {
      final overlays = [...state.textOverlays]
        ..removeAt(state.selectedTextIndex!);
      state = state.copyWith(
        textOverlays: overlays,
        selectedTextIndex: () => null,
        renderedFile: () => null,
      );
    } else if (state.selectedStickerIndex != null) {
      final overlays = [...state.stickerOverlays]
        ..removeAt(state.selectedStickerIndex!);
      state = state.copyWith(
        stickerOverlays: overlays,
        selectedStickerIndex: () => null,
        renderedFile: () => null,
      );
    }
  }

  void clearSelection() => state = state.copyWith(
    selectedTextIndex: () => null,
    selectedStickerIndex: () => null,
  );

  // ── Rendering ────────────────────────────────────────────────────────

  void setRendering(bool v) => state = state.copyWith(isRendering: v);

  void setRenderedFile(File? f) => state = state.copyWith(
      renderedFile: () => f, isRendering: false);

  void clearRender() => state = state.copyWith(renderedFile: () => null);
}

// ── Provider ──────────────────────────────────────────────────────────────

final collageProvider =
    StateNotifierProvider<CollageNotifier, CollageState>((ref) {
  return CollageNotifier();
});
