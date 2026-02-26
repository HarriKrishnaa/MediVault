import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class IpfsService {
  static const pinataApiKey = "f9dbe5a8feadf90e92f4";
  static const pinataSecret =
      "df39f5c33eba5261b8244d660ebe372fcc3caf30089b668b5a629eec8aa043c1";

  static const _pinataGateway = 'https://gateway.pinata.cloud/ipfs';

  static Future<String> uploadToIPFS(File file) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.pinata.cloud/pinning/pinFileToIPFS'),
    );

    request.headers['pinata_api_key'] = pinataApiKey;
    request.headers['pinata_secret_api_key'] = pinataSecret;

    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    final res = await http.Response.fromStream(response);

    if (res.statusCode == 200) {
      final cid = jsonDecode(res.body)['IpfsHash'];
      return cid;
    } else {
      throw Exception('Failed to upload to IPFS: ${res.body}');
    }
  }

  static Future<String> uploadBytesToIPFS(
    Uint8List fileBytes,
    String filename,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.pinata.cloud/pinning/pinFileToIPFS'),
    );

    request.headers['pinata_api_key'] = pinataApiKey;
    request.headers['pinata_secret_api_key'] = pinataSecret;

    request.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: filename),
    );

    final response = await request.send();
    final res = await http.Response.fromStream(response);

    if (res.statusCode == 200) {
      return jsonDecode(res.body)['IpfsHash'];
    } else {
      throw Exception('Failed to upload to IPFS: ${res.body}');
    }
  }

  static Future<Uint8List> downloadFromIPFS(String cid) async {
    // Check disk cache first
    final cached = await _readFromDiskCache(cid);
    if (cached != null) {
      print('⚡ IPFS cache hit for $cid');
      return cached;
    }

    print('⬇️ Downloading from Pinata gateway: $cid');
    final stopwatch = Stopwatch()..start();

    // Try Pinata gateway first (fast, authenticated)
    try {
      final response = await http
          .get(
            Uri.parse('$_pinataGateway/$cid'),
            headers: {'x-pinata-gateway-token': pinataApiKey},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        stopwatch.stop();
        print(
          '✅ Downloaded in ${stopwatch.elapsedMilliseconds}ms (${response.bodyBytes.length} bytes)',
        );
        await _writeToDiskCache(cid, response.bodyBytes);
        return response.bodyBytes;
      }
    } catch (e) {
      print('⚠️ Pinata gateway failed: $e, trying fallback...');
    }

    // Fallback: public gateway
    final response = await http
        .get(Uri.parse('https://ipfs.io/ipfs/$cid'))
        .timeout(const Duration(minutes: 3));

    if (response.statusCode == 200) {
      stopwatch.stop();
      print('✅ Downloaded (fallback) in ${stopwatch.elapsedMilliseconds}ms');
      await _writeToDiskCache(cid, response.bodyBytes);
      return response.bodyBytes;
    } else {
      throw Exception('Failed to download from IPFS: ${response.statusCode}');
    }
  }

  /// Disk cache helpers
  static Future<Directory> _getCacheDir() async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/ipfs_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  static Future<Uint8List?> _readFromDiskCache(String cid) async {
    try {
      final dir = await _getCacheDir();
      final file = File('${dir.path}/$cid');
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _writeToDiskCache(String cid, Uint8List data) async {
    try {
      final dir = await _getCacheDir();
      final file = File('${dir.path}/$cid');
      await file.writeAsBytes(data);
    } catch (_) {}
  }
}
