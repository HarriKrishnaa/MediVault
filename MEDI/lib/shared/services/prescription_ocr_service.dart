import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class PrescriptionOcrService {
  /// Extracts text from a prescription image at the given file [path].
  ///
  /// Uses Google ML Kit on-device text recognition (Latin script).
  static Future<String> extractTextFromImagePath(String path) async {
    final inputImage = InputImage.fromFile(File(path));
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognizedText = await recognizer.processImage(inputImage);
      return recognizedText.text;
    } finally {
      await recognizer.close();
    }
  }
}
