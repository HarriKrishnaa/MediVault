import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/enhanced_encryption_service.dart';

/// Example: How to view an encrypted prescription image
///
/// This widget demonstrates how to fetch and decrypt an encrypted
/// prescription from IPFS using the EncryptionService.
class EncryptedImageViewer extends StatefulWidget {
  final String cid;
  final String password;

  const EncryptedImageViewer({
    super.key,
    required this.cid,
    required this.password,
  });

  @override
  State<EncryptedImageViewer> createState() => _EncryptedImageViewerState();
}

class _EncryptedImageViewerState extends State<EncryptedImageViewer> {
  Uint8List? _imageData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final decryptedData =
          await EnhancedEncryptionService.fetchAndDecryptImage(
            widget.cid,
            widget.password,
          );

      setState(() {
        _imageData = decryptedData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to decrypt image: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadImage, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Image.memory(_imageData!, fit: BoxFit.cover);
  }
}

/// Simple usage example:
///
/// ```dart
/// // In your vault screen, when user taps encrypted prescription:
/// void _viewEncryptedPrescription(String cid) async {
///   final password = await _showPasswordDialog();
///   if (password != null) {
///     Navigator.push(
///       context,
///       MaterialPageRoute(
///         builder: (context) => Scaffold(
///           appBar: AppBar(title: const Text('Prescription')),
///           body: EncryptedImageViewer(
///             cid: cid,
///             password: password,
///           ),
///         ),
///       ),
///     );
///   }
/// }
/// ```
