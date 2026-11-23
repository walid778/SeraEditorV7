import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class NationalIdMlKitService {
  NationalIdMlKitService._();

  static final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  static Future<String> readNationalIdFromFile(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText =
          await _recognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (_) {
      return '';
    }
  }

  static Future<void> dispose() async {
    await _recognizer.close();
  }
}