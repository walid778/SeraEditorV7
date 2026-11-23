
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class ModelDownloadService {
  ModelDownloadService._();

  static const modelUrl =
      'https://huggingface.co/litert-community/'
      'gemma-4-E2B-it-litert-lm/resolve/main/'
      'gemma-4-E2B-it.litertlm';

  static const modelName = 'gemma-4-E2B-it.litertlm';

  static CancelToken? _cancelToken;

  static Future<String> getModelPath() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/$modelName';
  }

  static const int minModelSize = 2500000000;

static Future<bool> isDownloaded() async {
  final path = await getModelPath();
  final file = File(path);

  if (!await file.exists()) return false;

  final size = await file.length();

  return size >= minModelSize;
}

  static Future<String> download({
    required void Function(int received, int total) onProgress,
  }) async {
    final modelPath = await getModelPath();
    final modelFile = File(modelPath);

    if (await isDownloaded()) {
      return modelPath;
    }

    final tempFile = File('$modelPath.part');

    await tempFile.parent.create(recursive: true);

    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    _cancelToken = CancelToken();

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 30),
        followRedirects: true,
      ),
    );

    try {
      await dio.download(
        modelUrl,
        tempFile.path,
        cancelToken: _cancelToken,
        deleteOnError: false,
        onReceiveProgress: onProgress,
      );

      final size = await tempFile.length();

      if (size < 2000000000) {
        throw Exception('Downloaded model is incomplete.');
      }

      if (await modelFile.exists()) {
        await modelFile.delete();
      }

      await tempFile.rename(modelPath);

      return modelPath;
    } catch (_) {
      rethrow;
    } finally {
      _cancelToken = null;
      dio.close();
    }
  }

  static void cancelDownload() {
    _cancelToken?.cancel('Download cancelled');
  }
}
