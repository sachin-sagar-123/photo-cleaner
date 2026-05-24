import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/vault_document.dart';
import '../../../../services/services.dart';

final vaultServiceProvider = Provider((_) => DocumentVaultService());

final vaultUnlockedProvider = StateProvider<bool>((_) => false);

final vaultDocumentsProvider = FutureProvider<List<VaultDocument>>((ref) async {
  final vault = ref.read(vaultServiceProvider);
  return vault.getAllDocuments();
});
