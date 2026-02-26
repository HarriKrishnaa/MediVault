import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ipfs_service.dart';
import '../services/encryption_service.dart';
import '../services/vault_password_service.dart';
import '../services/database_helper.dart';
import '../services/prescription_parser_service.dart';
import '../shared/services/prescription_ocr_service.dart';
import '../shared/services/notification_service.dart';
import '../shared/theme/app_colors.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({Key? key}) : super(key: key);

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final picker = ImagePicker();

  // File state
  File? _selectedFile;
  String? _fileName;
  String? _mimeType;

  bool isLoading = false;
  String vaultPassword = "";

  // OCR state
  bool _isScanning = false;
  ParsedPrescriptionData? _parsedData;

  // Vault Selection
  List<Map<String, dynamic>> _vaults = [];
  String? _selectedVaultId;
  bool _isLoadingVaults = false;

  @override
  void initState() {
    super.initState();
    _fetchVaults();
  }

  Future<void> _fetchVaults() async {
    setState(() => _isLoadingVaults = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final data = await Supabase.instance.client
            .from('family_vaults')
            .select()
            .eq('owner_id', userId);

        if (mounted) {
          setState(() {
            _vaults = List<Map<String, dynamic>>.from(data);
            _isLoadingVaults = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching vaults: $e');
      if (mounted) setState(() => _isLoadingVaults = false);
    }
  }

  Future<void> pickImage(ImageSource source) async {
    if (isLoading) return;
    try {
      final picked = await picker.pickImage(source: source);
      if (picked != null) {
        setState(() {
          _selectedFile = File(picked.path);
          _fileName = picked.name;
          _mimeType = 'image/jpeg'; // Assuming standard image picker
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> pickFile() async {
    if (isLoading) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _fileName = result.files.single.name;
          _mimeType = 'application/pdf';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
    }
  }

  Future<void> uploadEncrypted() async {
    if (_selectedFile == null || vaultPassword.isEmpty) return;
    print('🚀 Starting upload with vault: ${_selectedVaultId ?? "personal"}');

    setState(() => isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception("User not logged in");
      }
      final userId = user.id;
      final bytes = await _selectedFile!.readAsBytes();

      print('📦 File size: ${bytes.length} bytes');

      final encryptedData = await compute(
        _encryptInIsolate,
        _EncryptionRequest(bytes, vaultPassword),
      );
      final encryptedBytes = Uint8List.fromList(encryptedData);

      print('🔐 Encrypted size: ${encryptedBytes.length} bytes');

      final filename = '${_fileName}.enc';
      final cid = await IpfsService.uploadBytesToIPFS(encryptedBytes, filename);

      print('✅ IPFS Upload Success! CID: $cid');

      // Build minimal insert data first (only columns guaranteed to exist)
      final insertData = <String, dynamic>{
        'user_id': userId,
        'image_cid': cid,
        'image_url': 'https://ipfs.io/ipfs/$cid',
        'file_name': _fileName ?? 'unknown',
        'is_encrypted': true,
      };

      // Try adding optional columns
      if (_mimeType != null) {
        insertData['mime_type'] = _mimeType;
      }
      if (_selectedVaultId != null) {
        insertData['vault_id'] = _selectedVaultId;
      }

      print('📝 Supabase Insert Data: $insertData');

      try {
        await Supabase.instance.client.from('prescriptions').insert(insertData);
        print('✅ Supabase Insert SUCCESS');
      } catch (insertError) {
        print('⚠️ Full insert failed: $insertError');
        print('⚠️ Retrying without mime_type column...');

        // Fallback: drop only mime_type (the likely missing column).
        // vault_id is always preserved so the file lands in the correct vault.
        final fallbackData = <String, dynamic>{
          'user_id': userId,
          'image_cid': cid,
          'image_url': 'https://ipfs.io/ipfs/$cid',
          'file_name': _fileName ?? 'unknown',
          'is_encrypted': true,
        };
        if (_selectedVaultId != null) {
          fallbackData['vault_id'] = _selectedVaultId;
        }

        try {
          await Supabase.instance.client
              .from('prescriptions')
              .insert(fallbackData);
          print('✅ Fallback Supabase Insert SUCCESS (without mime_type)');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '⚠️ Uploaded but mime_type column may be missing. Run migration SQL.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          }
        } catch (fallbackError) {
          print('❌ Fallback insert ALSO failed: $fallbackError');
          throw fallbackError;
        }
      }

      // Capture vault name BEFORE resetting state
      final uploadedVaultName = _getVaultName(_selectedVaultId);

      if (mounted) {
        setState(() {
          isLoading = false;
          _selectedFile = null;
          _fileName = null;
          _mimeType = null;
          vaultPassword = "";
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Encrypted & Uploaded to $uploadedVaultName"),
            backgroundColor: AppColors.success,
          ),
        );
        // Go back so the user lands on the vault tab, which will refresh.
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ Error during upload: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String _getVaultName(String? id) {
    if (id == null) return "My Personal Vault";
    final vault = _vaults.firstWhere((v) => v['id'] == id, orElse: () => {});
    return vault.isNotEmpty ? (vault['vault_name'] ?? 'Vault') : 'Vault';
  }

  Future<void> askPassword() async {
    if (isLoading) return;

    final vaultId = _selectedVaultId;
    final hasExisting = await VaultPasswordService.hasPassword(vaultId);

    if (hasExisting) {
      // Vault already has a password → verify it
      _showVerifyPasswordDialog(vaultId);
    } else {
      // First time → set a new password
      _showSetPasswordDialog(vaultId);
    }
  }

  void _showSetPasswordDialog(String? vaultId) {
    String pw = '';
    String confirmPw = '';
    String? errorText;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Set Password for ${_getVaultName(vaultId)}"),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "This password will be used for all files in this vault. Remember it — you'll need it to view your files.",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  obscureText: true,
                  autofocus: true,
                  onChanged: (val) => pw = val,
                  decoration: const InputDecoration(
                    labelText: 'New password',
                    hintText: "Enter new password",
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  obscureText: true,
                  onChanged: (val) => confirmPw = val,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                    hintText: "Re-enter password",
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      errorText!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (pw.isEmpty || pw.length < 4) {
                  setDialogState(
                    () => errorText = 'Password must be at least 4 characters',
                  );
                  return;
                }
                if (pw != confirmPw) {
                  setDialogState(() => errorText = 'Passwords do not match');
                  return;
                }
                try {
                  await VaultPasswordService.setPassword(vaultId, pw);
                  vaultPassword = pw;
                  if (mounted) {
                    Navigator.pop(context);
                    uploadEncrypted();
                  }
                } on StateError {
                  setDialogState(
                    () => errorText =
                        '⚠️ This vault already has a password. Please use Unlock instead.',
                  );
                }
              },
              child: const Text("Set & Upload"),
            ),
          ],
        ),
      ),
    );
  }

  void _showVerifyPasswordDialog(String? vaultId) {
    String pw = '';
    String? errorText;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Unlock ${_getVaultName(vaultId)}"),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  obscureText: true,
                  autofocus: true,
                  onChanged: (val) => pw = val,
                  decoration: const InputDecoration(
                    hintText: "Enter vault password",
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      errorText!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (pw.isEmpty) {
                  setDialogState(() => errorText = 'Please enter the password');
                  return;
                }
                final isValid = await VaultPasswordService.verifyPassword(
                  vaultId,
                  pw,
                );
                if (isValid) {
                  vaultPassword = pw;
                  if (mounted) {
                    Navigator.pop(context);
                    uploadEncrypted();
                  }
                } else {
                  setDialogState(
                    () => errorText =
                        '❌ Wrong password. All files in this vault use the same password.',
                  );
                }
              },
              child: const Text("Encrypt & Upload"),
            ),
          ],
        ),
      ),
    );
  }

  // ── OCR Scan Flow ───────────────────────────────────────────────

  Future<void> _scanPrescription() async {
    if (_selectedFile == null || _isScanning) return;

    setState(() => _isScanning = true);

    try {
      // 1. Run OCR on the image.
      final rawText = await PrescriptionOcrService.extractTextFromImagePath(
        _selectedFile!.path,
      );

      if (rawText.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No text found in image. Try a clearer photo.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isScanning = false);
        return;
      }

      // 2. Parse the text into structured medicine data.
      final parsed = PrescriptionParserService.parse(rawText);

      setState(() {
        _parsedData = parsed;
        _isScanning = false;
      });

      if (parsed.medicines.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not find medication names. The prescription might need a clearer photo.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 3. Show review dialog.
      if (mounted) _showReviewDialog(parsed);
    } catch (e) {
      debugPrint('OCR scan error: $e');
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Shows a dialog letting the user review parsed medicines before saving
  /// them as reminders.
  void _showReviewDialog(ParsedPrescriptionData data) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.medication_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Flexible(
              child: Text('Scanned Medicines', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: data.medicines.isEmpty
              ? const Text('No medicines detected.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: data.medicines.length,
                  separatorBuilder: (_, __) => const Divider(height: 20),
                  itemBuilder: (_, i) {
                    final med = data.medicines[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          med.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Dose times (morning / night)
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                med.times
                                    .map((t) => _formatTimeOfDay(t))
                                    .join('  ·  '),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Duration
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${med.durationDays} days',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Meal timing badge
                        Row(
                          children: [
                            Icon(
                              med.mealTiming == 'before food'
                                  ? Icons.no_meals_rounded
                                  : med.mealTiming == 'after food'
                                  ? Icons.restaurant_rounded
                                  : Icons.access_time_filled_rounded,
                              size: 14,
                              color: med.mealTiming == 'before food'
                                  ? Colors.orange
                                  : med.mealTiming == 'after food'
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                med.mealTiming == 'before food'
                                    ? 'Before food'
                                    : med.mealTiming == 'after food'
                                    ? 'After food'
                                    : 'Any time',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: med.mealTiming == 'before food'
                                      ? Colors.orange
                                      : med.mealTiming == 'after food'
                                      ? Colors.green
                                      : Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _saveReminders(data);
            },
            icon: const Icon(Icons.alarm_add_rounded, size: 18),
            label: const Text('Save as Reminders'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Persists parsed medicines as medication reminders in SQLite and
  /// schedules local push notifications for each one.
  Future<void> _saveReminders(ParsedPrescriptionData data) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final reminders = <Map<String, dynamic>>[];
    final startDate = DateTime.now().toIso8601String();

    for (final med in data.medicines) {
      for (final time in med.times) {
        reminders.add({
          'user_id': userId,
          'medicine_name': med.name,
          'hour': time.hour,
          'minute': time.minute,
          'duration_days': med.durationDays,
          'start_date': startDate,
          'is_active': 1,
          'meal_timing': med.mealTiming,
        });
      }
    }

    await DatabaseHelper.instance.insertReminders(reminders);

    // Schedule push notifications for each saved reminder.
    // Re-query the active reminders to get their SQLite row IDs.
    final activeReminders = await DatabaseHelper.instance.getActiveReminders(
      userId,
    );
    await NotificationService.instance.cancelAllReminders();
    for (final r in activeReminders) {
      await NotificationService.instance.scheduleMedicationReminder(
        id: r['id'] as int,
        medicineName: r['medicine_name'] as String,
        hour: r['hour'] as int,
        minute: r['minute'] as int,
        durationDays: r['duration_days'] as int,
        mealTiming: (r['meal_timing'] as String?) ?? 'any time',
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Reminders saved with notifications!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  /// Compact preview of parsed data shown below the scan button.
  Widget _buildParsedPreview() {
    if (_parsedData == null || _parsedData!.medicines.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => _showReviewDialog(_parsedData!),
                child: const Text(
                  'Review →',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _parsedData!.medicines
                .map(
                  (m) => Chip(
                    label: Text(m.name, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final period = t.hour >= 12 ? 'PM' : 'AM';
    final h = t.hour == 0
        ? 12
        : t.hour > 12
        ? t.hour - 12
        : t.hour;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    bool isPdf = _mimeType == 'application/pdf';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Document"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Vault Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _isLoadingVaults
                  ? const Center(child: LinearProgressIndicator())
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedVaultId,
                        isExpanded: true,
                        hint: const Text(
                          "Select Vault (Default: My Personal Vault)",
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Row(
                              children: [
                                Icon(Icons.person, color: AppColors.primary),
                                SizedBox(width: 10),
                                Text("My Personal Vault"),
                              ],
                            ),
                          ),
                          ..._vaults.map((vault) {
                            return DropdownMenuItem<String?>(
                              value: vault['id'],
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.folder_shared,
                                    color: AppColors.secondary,
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      "${vault['vault_name']} (${vault['description'] ?? 'Member'})",
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedVaultId = val);
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 24),

            // Preview Area
            GestureDetector(
              onTap: () => pickImage(ImageSource.gallery), // Default tap action
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _selectedFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (isPdf)
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.picture_as_pdf,
                                      size: 64,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _fileName ?? 'Selected PDF',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (kIsWeb)
                              Image.network(
                                _selectedFile!.path,
                                fit: BoxFit.cover,
                              )
                            else
                              Image.file(_selectedFile!, fit: BoxFit.cover),

                            // Trash Icon
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: IconButton(
                                onPressed: isLoading
                                    ? null
                                    : () => setState(() {
                                        _selectedFile = null;
                                        _fileName = null;
                                        _mimeType = null;
                                      }),
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cloud_upload_rounded,
                              size: 48,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Select a document to upload",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 32),

            // Pick Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Gallery"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Camera"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : pickFile,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text("PDF"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (isLoading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            else if (_selectedFile != null) ...[
              // ── Scan Prescription (images only) ──
              if (_mimeType != 'application/pdf') ...[
                _isScanning
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Scanning prescription…',
                              style: TextStyle(color: AppColors.primary),
                            ),
                          ],
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: _scanPrescription,
                        icon: const Icon(Icons.document_scanner_rounded),
                        label: Text(
                          _parsedData != null
                              ? 'Re-scan Prescription'
                              : 'Scan Prescription',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                if (_parsedData != null) ...[
                  const SizedBox(height: 8),
                  _buildParsedPreview(),
                ],
                const SizedBox(height: 16),
              ],

              // ── Encrypt & Upload ──
              ElevatedButton.icon(
                onPressed: askPassword,
                icon: const Icon(Icons.lock),
                label: const Text("Encrypt & Upload Securely"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EncryptionRequest {
  final Uint8List bytes;
  final String password;
  _EncryptionRequest(this.bytes, this.password);
}

Future<List<int>> _encryptInIsolate(_EncryptionRequest request) async {
  return EncryptionService.encryptData(request.bytes, request.password);
}
