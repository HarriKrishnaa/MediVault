import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/encryption_service.dart';
import '../services/ipfs_service.dart';

/// Full-screen QR export view for a vault's documents.
/// Each document card shows its name, date, and a QR code.
/// Users can "Unlock" a document to upload a decrypted version to IPFS
/// for public sharability (e.g. Google Lens).
class VaultQrExportScreen extends StatefulWidget {
  final String vaultName;
  final List<dynamic> prescriptions;

  const VaultQrExportScreen({
    super.key,
    required this.vaultName,
    required this.prescriptions,
  });

  @override
  State<VaultQrExportScreen> createState() => _VaultQrExportScreenState();
}

class _VaultQrExportScreenState extends State<VaultQrExportScreen> {
  // Maps original (encrypted) CID -> ephemeral public (unencrypted) CID
  final Map<String, String> _publicCids = {};
  // Track loading state per item
  final Map<String, bool> _processing = {};

  String? _vaultPassword;

  // Builds the QR data. Uses public CID if available, else original CID.
  String _buildQrData(dynamic item) {
    final originalCid = item['image_cid']?.toString().trim() ?? '';
    final publicCid = _publicCids[originalCid];

    // Priority: Public Unencrypted > Original (Encrypted)
    final effectiveCid = publicCid ?? originalCid;

    if (effectiveCid.isNotEmpty) {
      return 'https://ipfs.io/ipfs/$effectiveCid';
    }

    // Fallback: embed a text summary
    final name = item['file_name'] ?? 'Document';
    final date = item['created_at']?.toString().split('T')[0] ?? '';
    final info = {
      'vault': widget.vaultName,
      'file': name,
      'date': date,
      'note': 'File not yet on IPFS',
    };
    return jsonEncode(info);
  }

  Future<void> _unlockForPublic(dynamic item) async {
    final cid = item['image_cid']?.toString().trim();
    if (cid == null || cid.isEmpty) return;

    // 1. Confirm with warning
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Make Public?'),
        content: const Text(
          'This will decrypt the file and upload a PUBLIC copy to IPFS.\n\n'
          'Anyone with the new QR code will be able to view the file WITHOUT a password.\n\n'
          'This action cannot be undone (IPFS is permanent).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Make Public'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _processing[cid] = true);

    try {
      // 2. Get password if needed
      if (_vaultPassword == null) {
        // We need the vault ID for verification. Since we don't have it passed explicitly,
        // we might fail if we need to verify against a specific vault.
        // However, item['vault_id'] might be useful if we had it.
        // For now, let's just ask for the password and try to decrypt.
        // If the user already unlocked the vault to get here, we might not have the password
        // passed to this screen. We should probably pass it or ask for it.
        // Let's ask for it.
        final pw = await _promptPassword();
        if (pw == null) {
          setState(() => _processing[cid] = false);
          return;
        }
        _vaultPassword = pw;
      }

      // 3. Decrypt
      final decryptedBytes = await EncryptionService.fetchAndDecryptImage(
        cid,
        _vaultPassword!,
      );

      // 4. Re-upload Unencrypted
      final fileName = item['file_name'] ?? 'document.jpg';
      final publicCid = await IpfsService.uploadBytesToIPFS(
        decryptedBytes,
        fileName,
      );

      // 5. Update state
      if (mounted) {
        setState(() {
          _publicCids[cid] = publicCid;
          _processing[cid] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ File is now public via the new QR code'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing[cid] = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String?> _promptPassword() async {
    String p = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vault Password'),
        content: TextField(
          obscureText: true,
          autofocus: true,
          onChanged: (v) => p = v,
          decoration: const InputDecoration(
            hintText: 'Enter password to decrypt',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, p),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = widget.prescriptions;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('${widget.vaultName} — QR Export'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A9E8F),
        elevation: 0,
        actions: [
          if (docs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share Links',
              onPressed: _onShare,
            ),
        ],
      ),
      body: docs.isEmpty
          ? _buildEmpty()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: docs.length,
              itemBuilder: (context, i) => _buildQrCard(docs[i], i),
            ),
    );
  }

  Widget _buildQrCard(dynamic item, int index) {
    final name = item['file_name'] ?? 'Document';
    final date = item['created_at']?.toString().split('T')[0] ?? '';
    final mimeType = item['mime_type']?.toString() ?? '';
    final isPdf =
        mimeType.contains('pdf') ||
        name.toString().toLowerCase().endsWith('.pdf');
    final isEncrypted = item['is_encrypted'] == true;
    final originalCid = item['image_cid']?.toString().trim() ?? '';

    final isPublic = _publicCids.containsKey(originalCid);
    final isBusy = _processing[originalCid] == true;
    final qrData = _buildQrData(item);

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isPdf ? Colors.red.shade50 : const Color(0xFFE0F7F4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPdf ? Icons.picture_as_pdf : Icons.image_outlined,
                    color: isPdf
                        ? Colors.red.shade400
                        : const Color(0xFF1A9E8F),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badges
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isPublic)
                      const _Badge(
                        label: 'PUBLIC',
                        color: Colors.red,
                        bg: Color(0xFFFFEBEE),
                      )
                    else if (isEncrypted)
                      _Badge(
                        label: 'Encrypted',
                        color: Colors.orange.shade700,
                        bg: Colors.orange.shade50,
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),

            // ── QR Code ─────────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isPublic
                            ? Colors.red.withValues(alpha: 0.3)
                            : const Color(0xFF1A9E8F).withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 220,
                          backgroundColor: Colors.white,
                          eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: isPublic
                                ? Colors.red
                                : const Color(0xFF1A9E8F),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF0D2137),
                          ),
                        ),
                        if (isBusy)
                          Container(
                            width: 220,
                            height: 220,
                            color: Colors.white.withValues(alpha: 0.8),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isPublic
                        ? '⚠️ UNENCRYPTED: Scan to view file directly'
                        : 'Scan to verify (Encrypted)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isPublic
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isPublic ? Colors.red : Colors.grey,
                    ),
                  ),

                  // ── Action Buttons ────────────────────────────────────
                  const SizedBox(height: 16),
                  if (!isPublic && isEncrypted && originalCid.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: isBusy ? null : () => _unlockForPublic(item),
                      icon: const Icon(Icons.lock_open, size: 18),
                      label: const Text('Unlock for Public Access'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),

                  if (isPublic || (!isEncrypted && originalCid.isNotEmpty)) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: qrData));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Public Link copied!'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Text(
                        'Copy Link',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1A9E8F),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2, size: 72, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No documents in this vault',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _onShare() {
    // Share all available links
    final lines = <String>[];
    lines.add('📋 ${widget.vaultName} — Document Links');
    lines.add('');
    for (int i = 0; i < widget.prescriptions.length; i++) {
      final item = widget.prescriptions[i];
      final name = item['file_name'] ?? 'Document ${i + 1}';
      final cid = item['image_cid']?.toString().trim() ?? '';

      // Use public CID if we have one
      final public = _publicCids[cid];
      final linkCid = public ?? cid;

      final url = linkCid.isNotEmpty
          ? 'https://ipfs.io/ipfs/$linkCid'
          : '(no IPFS link)';

      lines.add('${i + 1}. $name');
      lines.add('   $url');
      if (public != null) lines.add('   (Public Unencrypted)');
      lines.add('');
    }
    final text = lines.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All links copied to clipboard'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _Badge({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
