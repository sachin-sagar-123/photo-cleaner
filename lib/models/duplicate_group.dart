import 'photo_asset.dart';

class DuplicateGroup {
  final String groupId;
  final List<PhotoAsset> assets;
  final double similarity; // 0.0 – 1.0

  const DuplicateGroup({
    required this.groupId,
    required this.assets,
    required this.similarity,
  });

  /// The asset to keep — largest file or most recent.
  PhotoAsset get bestAsset => assets.reduce(
        (a, b) => a.sizeBytes >= b.sizeBytes ? a : b,
      );

  List<PhotoAsset> get duplicates =>
      assets.where((a) => a.id != bestAsset.id).toList();

  int get wastedBytes =>
      duplicates.fold(0, (sum, a) => sum + a.sizeBytes);

  double get wastedMB => wastedBytes / (1024 * 1024);
}
