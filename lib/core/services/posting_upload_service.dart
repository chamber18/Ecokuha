import 'package:flutter/foundation.dart';

/// Status of a background posting upload.
enum PostingUploadStatus { idle, uploading, success, failed }

/// Singleton service that tracks background posting uploads so any screen
/// (particularly TrackScreen) can show live progress without blocking the UI.
class PostingUploadService extends ChangeNotifier {
  PostingUploadStatus _status = PostingUploadStatus.idle;
  String _message = '';
  String? _errorMessage;

  PostingUploadStatus get status => _status;
  String get message => _message;
  String? get errorMessage => _errorMessage;

  /// True when a card should be shown to the user.
  bool get isActive => _status != PostingUploadStatus.idle;

  /// Run [task] in the background, updating status as it progresses.
  /// [task] receives a callback it can call to update the progress message.
  Future<void> run(
    Future<void> Function(void Function(String message) updateMessage) task,
  ) async {
    _status = PostingUploadStatus.uploading;
    _message = 'Uploading images…';
    _errorMessage = null;
    notifyListeners();

    try {
      await task((msg) {
        _message = msg;
        notifyListeners();
      });
      _status = PostingUploadStatus.success;
      _message = 'Post created successfully!';
      notifyListeners();
      // Auto-dismiss after 5 s
      Future.delayed(const Duration(seconds: 5), dismiss);
    } catch (e) {
      _status = PostingUploadStatus.failed;
      _message = 'Upload failed';
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Dismiss the card. No-op while uploading.
  void dismiss() {
    if (_status == PostingUploadStatus.uploading) return;
    _status = PostingUploadStatus.idle;
    _message = '';
    _errorMessage = null;
    notifyListeners();
  }
}
