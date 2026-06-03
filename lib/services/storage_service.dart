import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// The result of uploading a receipt image: where it lives and how to fetch it.
class ReceiptRef {
  /// Storage object path, e.g. `users/{uid}/receipts/1700000000.jpg`.
  /// Persisted so the object can later be deleted.
  final String path;

  /// Public-via-rules download URL, persisted for display.
  final String url;

  const ReceiptRef({required this.path, required this.url});
}

/// Uploads and deletes receipt images in Firebase Storage, scoped per user.
///
/// Layout: `users/{uid}/receipts/{timestamp}.{ext}`.
class StorageService {
  StorageService(this.uid, {FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final String uid;
  final FirebaseStorage _storage;

  Future<ReceiptRef> uploadReceipt(
    Uint8List bytes, {
    required String contentType,
  }) async {
    final ext = _extensionFor(contentType);
    final path =
        'users/$uid/receipts/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();
    return ReceiptRef(path: path, url: url);
  }

  /// Best-effort delete; a missing object is not treated as an error.
  Future<void> deleteReceipt(String path) async {
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }

  String _extensionFor(String contentType) {
    switch (contentType) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/heic':
        return 'heic';
      case 'image/jpeg':
      default:
        return 'jpg';
    }
  }
}
