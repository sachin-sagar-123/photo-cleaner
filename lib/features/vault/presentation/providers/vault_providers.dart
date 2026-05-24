import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/cache_providers.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../models/vault_document.dart';
import '../../../../services/services.dart';
import '../../data/vault_dao.dart';
import '../../data/vault_repository.dart';

// ── Legacy service (used by VaultScreen directly) ─────────────────────────

final vaultServiceProvider = Provider((_) => DocumentVaultService());

final vaultUnlockedProvider = StateProvider<bool>((_) => false);

// ── Repository layer (for new code / migration) ───────────────────────────

final vaultDaoProvider = Provider((ref) =>
    VaultDao(ref.read(appDatabaseProvider)));

final vaultRepositoryProvider = Provider((ref) =>
    VaultRepository(
      ref.read(vaultDaoProvider),
      ref.read(memoryCacheProvider),
    ));

final vaultDocumentsProvider = FutureProvider<List<VaultDocument>>((ref) async {
  final vault = ref.read(vaultServiceProvider);
  return vault.getAllDocuments();
});
