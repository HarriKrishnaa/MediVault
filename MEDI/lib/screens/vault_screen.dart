import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:open_filex/open_filex.dart';
import '../services/encryption_service.dart';
import '../services/ipfs_service.dart';
import '../services/vault_password_service.dart';
import '../services/vault_biometric_service.dart';
import '../services/biometric_service.dart';
import '../shared/theme/app_colors.dart';
import 'vault_qr_export_screen.dart';

class VaultScreen extends StatefulWidget {
  final String? vaultId;
  final String? vaultName;

  const VaultScreen({super.key, this.vaultId, this.vaultName});

  @override
  State<VaultScreen> createState() => VaultScreenState();
}

class VaultScreenState extends State<VaultScreen> {
  List<dynamic> _prescriptions = [];
  bool _isLoading = true;
  String? _vaultPassword;
  bool _isVaultUnlocked = false;

  // Family vault name lookup: vaultId -> vaultName
  Map<String, String> _vaultNames = {};

  // In-memory cache for decrypted images (avoids re-download + re-decrypt)
  final Map<String, Uint8List> _decryptedCache = {};

  @override
  void initState() {
    super.initState();
    _fetchPrescriptions();
  }

  /// Called by HomeScreen whenever the user switches to the Vault tab,
  /// so the list is always up-to-date after an upload.
  void refresh() => _fetchPrescriptions();

  Future<void> _fetchPrescriptions() async {
    if (!mounted) return;
    try {
      if (_prescriptions.isEmpty) setState(() => _isLoading = true);

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      final userId = user.id;

      // When opened as a specific family vault → filter by vault_id
      // When opened as personal vault (vaultId == null) → show ALL user docs
      // so it works even if vault_id column is missing or docs have no vault_id
      List<dynamic> response;
      if (widget.vaultId != null) {
        response = await Supabase.instance.client
            .from('prescriptions')
            .select()
            .eq('user_id', userId)
            .eq('vault_id', widget.vaultId!)
            .order('created_at', ascending: false);
      } else {
        // Personal vault = ALL docs (master view)
        response = await Supabase.instance.client
            .from('prescriptions')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        // Also fetch vault names so we can badge docs belonging to a family vault
        try {
          final vaultData = await Supabase.instance.client
              .from('family_vaults')
              .select('id, vault_name')
              .eq('owner_id', userId);
          final names = <String, String>{};
          for (final v in vaultData as List) {
            names[v['id'].toString()] = v['vault_name'] ?? 'Family';
          }
          if (mounted) setState(() => _vaultNames = names);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _prescriptions = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showVaultPasswordDialog() async {
    final vaultId = widget.vaultId;
    final bioService = VaultBiometricService.instance;

    final hasPassword = await VaultPasswordService.hasPassword(vaultId);
    if (!hasPassword) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No vault password set yet. Upload a file first to set the password.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    // ── Try biometric unlock first ──────────────────────────────────────
    final canUseBio = await bioService.canUnlockWithBiometrics(vaultId);
    if (canUseBio) {
      final bioPassword = await bioService.unlockWithBiometrics(vaultId);
      if (bioPassword != null && mounted) {
        setState(() {
          _vaultPassword = bioPassword;
          _isVaultUnlocked = true;
        });
        return; // unlocked — no dialog needed
      }
      // Biometric failed/cancelled — fall through to manual dialog
    }

    if (!mounted) return;

    // ── Manual password dialog ──────────────────────────────────────────
    final controller = TextEditingController(text: _vaultPassword ?? '');
    String? errorText;
    // Show biometric button ONLY when password is already saved (fully set up)
    // canUseBio = biometrics enabled AND vault password saved
    final deviceSupportsBio = await BiometricService.instance
        .canCheckBiometrics();

    if (!mounted) return;

    final bioSetupHint =
        deviceSupportsBio && !canUseBio; // supported but not configured

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          title: Row(
            children: [
              Icon(Icons.lock_open_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Unlock Vault'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter the vault password to view your files.'),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    errorText: errorText,
                  ),
                  autofocus: true,
                  onSubmitted: (_) async {
                    final val = controller.text;
                    if (val.isEmpty) return;
                    final isValid = await VaultPasswordService.verifyPassword(
                      vaultId,
                      val,
                    );
                    if (isValid) {
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, val);
                      }
                    } else {
                      setDialogState(() => errorText = 'Wrong password');
                    }
                  },
                ),
                // ── Biometric shortcut (only when fully set up) ───────────
                if (canUseBio) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final bioPassword = await bioService.unlockWithBiometrics(
                        vaultId,
                      );
                      if (bioPassword != null) {
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, bioPassword);
                        }
                      } else {
                        if (dialogContext.mounted) {
                          setDialogState(
                            () => errorText =
                                'Biometric not recognised. Try again or enter password.',
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Use Biometrics'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ],
                // ── Hint: biometrics available but not yet configured ─────
                if (bioSetupHint) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(dialogContext);
                            Navigator.pushNamed(context, '/security-settings');
                          },
                          child: const Text(
                            'Enable biometric unlock in Security & Privacy settings.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final val = controller.text;
                if (val.isEmpty) return;
                final isValid = await VaultPasswordService.verifyPassword(
                  vaultId,
                  val,
                );
                if (isValid) {
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, val);
                  }
                } else {
                  setDialogState(() => errorText = 'Wrong password');
                }
              },
              child: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );

    if (password != null && password.isNotEmpty && mounted) {
      setState(() {
        _vaultPassword = password;
        _isVaultUnlocked = true;
      });
      // ── Offer to save password for future biometric unlocks ──────────
      await _offerSaveForBiometrics(vaultId, password);
    }
  }

  /// Prompts the user to save the vault password for biometric access,
  /// but only if biometrics are supported AND the password isn't already saved.
  Future<void> _offerSaveForBiometrics(String? vaultId, String password) async {
    final bioService = VaultBiometricService.instance;
    final alreadySaved = await bioService.hasSavedPassword(vaultId);
    if (alreadySaved || !mounted) return;

    // Check device supports biometrics
    final canCheck = await BiometricService.instance.canCheckBiometrics();
    if (!canCheck || !mounted) return;

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.fingerprint, color: Colors.green),
            SizedBox(width: 8),
            Text('Enable Biometrics?'),
          ],
        ),
        content: const Text(
          'Would you like to use fingerprint / face ID to unlock this vault next time?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (save == true && mounted) {
      // Confirm biometric before saving
      final authenticated = await BiometricService.instance.authenticate(
        reason: 'Confirm biometric to enable vault unlock',
      );
      if (authenticated) {
        await bioService.saveVaultPassword(vaultId, password);
        await BiometricService.instance.setBiometricEnabled(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric unlock enabled for this vault ✓'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<Uint8List> _decryptImage(String cid) async {
    // Check in-memory cache first
    if (_decryptedCache.containsKey(cid)) {
      return _decryptedCache[cid]!;
    }

    // Download (uses disk cache internally)
    final encryptedBytes = await IpfsService.downloadFromIPFS(cid);

    // Decrypt in background isolate to avoid blocking UI
    final decrypted = await compute(
      _decryptInIsolate,
      _DecryptRequest(encryptedBytes, _vaultPassword!),
    );
    final result = Uint8List.fromList(decrypted);

    // Cache the decrypted result
    _decryptedCache[cid] = result;
    return result;
  }

  Future<void> _openFile(dynamic item) async {
    // Always prompt for passcode when opening a file
    setState(() => _isVaultUnlocked = false);
    await _showVaultPasswordDialog();
    if (!_isVaultUnlocked || _vaultPassword == null) return;

    final cid = item['image_cid'];
    final fileName = item['file_name'] ?? 'document';
    final isEncrypted = item['is_encrypted'] == true;

    if (cid == null) return;

    setState(() => _isLoading = true);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      String filePath;
      if (isEncrypted) {
        final file = await EncryptionService.decryptAndSaveFile(
          cid,
          fileName,
          _vaultPassword!,
        );
        filePath = file.path;
      } else {
        // Should not happen in current flow, but handle if needed
        throw Exception('File is not encrypted?');
      }

      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('${result.message}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteItem(dynamic item) async {
    final itemId = item['id'];
    final fileName = item['file_name'] ?? 'Document';
    if (itemId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text(
          'Are you sure you want to delete "$fileName"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client
          .from('prescriptions')
          .delete()
          .eq('id', itemId);

      // Remove from local cache
      final cid = item['image_cid'];
      if (cid != null) _decryptedCache.remove(cid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document deleted successfully')),
        );
        _fetchPrescriptions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _openQrExport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VaultQrExportScreen(
          vaultName: widget.vaultName ?? 'My Vault',
          prescriptions: _prescriptions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.vaultName ?? 'My Vault';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.vaultId != null
          ? AppBar(
              title: Text(title),
              actions: [
                if (_prescriptions.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.qr_code_2),
                    tooltip: 'Export as QR',
                    onPressed: _openQrExport,
                  ),
              ],
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            if (widget.vaultId == null) _buildVaultHeader(context),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchPrescriptions,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _prescriptions.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(24),
                        itemCount: _prescriptions.length,
                        separatorBuilder: (c, i) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          return _buildPrescriptionCard(_prescriptions[index]);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVaultHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Vault',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                ),
                Text(
                  '${_prescriptions.length} Documents',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (_prescriptions.isNotEmpty)
                IconButton.filledTonal(
                  onPressed: _openQrExport,
                  icon: const Icon(Icons.qr_code_2),
                  tooltip: 'Export as QR',
                ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                onPressed: () => Navigator.pushNamed(context, '/family-vault'),
                icon: const Icon(Icons.group),
                tooltip: 'Family Vaults',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            widget.vaultId == null ? 'Your vault is empty' : 'No documents',
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionCard(dynamic item) {
    final fileName = item['file_name'] ?? 'Document';
    final cid = item['image_cid'] ?? '';
    final isEncrypted = item['is_encrypted'] == true;
    final date = item['created_at']?.toString().split('T')[0] ?? '';
    final mimeType = item['mime_type'] ?? '';
    final isPdf =
        mimeType.contains('pdf') ||
        fileName.toString().toLowerCase().endsWith('.pdf');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _openFile(item),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            SizedBox(
              height: 150,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: isEncrypted
                    ? (!_isVaultUnlocked || _vaultPassword == null)
                          ? Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(
                                  Icons.lock,
                                  color: Colors.grey,
                                  size: 40,
                                ),
                              ),
                            )
                          : isPdf
                          ? Container(
                              color: Colors.red.shade50,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.picture_as_pdf,
                                      size: 50,
                                      color: Colors.red.shade400,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'PDF Document',
                                      style: TextStyle(
                                        color: Colors.red.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : FutureBuilder<Uint8List>(
                              future: _decryptImage(cid),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                  );
                                }
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                            )
                    // Not encrypted fallback (rare/legacy)
                    : isPdf
                    ? const Center(child: Icon(Icons.picture_as_pdf, size: 50))
                    : Image.network(item['image_url'] ?? '', fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    isPdf ? Icons.picture_as_pdf : Icons.image,
                    color: isPdf ? Colors.red : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Show date
                        Text(
                          date,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        // Show family badge when in master view
                        if (widget.vaultId == null &&
                            item['vault_id'] != null) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Family: ${_vaultNames[item['vault_id'].toString()] ?? 'Member'}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isEncrypted)
                    const Icon(Icons.lock, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => _deleteItem(item),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    tooltip: 'Delete',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecryptRequest {
  final Uint8List bytes;
  final String password;
  _DecryptRequest(this.bytes, this.password);
}

Future<List<int>> _decryptInIsolate(_DecryptRequest request) async {
  return EncryptionService.decryptBytes(request.bytes, request.password);
}
