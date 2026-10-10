/// AI waste detection is DISABLED for now.
///
/// The TFLite (`tflite_flutter`) dependency and the bundled model were removed
/// so the app builds on every platform (including web). The public API is kept
/// so the rest of the app (repository, bloc, DI) compiles unchanged; every call
/// reports that detection is unavailable.
///
/// To re-enable: add `tflite_flutter` + `image` back to pubspec.yaml, restore
/// `assets/ai_models/mobilenetv3_float32.tflite` in the asset list, and
/// restore the previous implementation from git history.
class AiDetectionDatasource {
  Future<void> loadModel() async {
    throw UnsupportedError('AI detection is currently disabled.');
  }

  void dispose() {}

  Future<Map<String, dynamic>> detectWaste(String imagePath) async {
    throw UnsupportedError('AI detection is currently disabled.');
  }
}
