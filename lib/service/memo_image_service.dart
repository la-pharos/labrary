import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class MemoImageService {
  static final FirebaseStorage _storage =
      FirebaseStorage.instance;

  static const Uuid _uuid = Uuid();

  static Future<String> uploadMemoImage({
    required String bookId,
    required String imagePath,
  }) async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError(
        '로그인된 사용자가 없습니다.',
      );
    }

    final normalizedBookId =
    bookId.trim();

    final normalizedImagePath =
    imagePath.trim();

    if (normalizedBookId.isEmpty) {
      throw ArgumentError(
        '책 ID가 비어 있습니다.',
      );
    }

    if (normalizedImagePath.isEmpty) {
      throw ArgumentError(
        '이미지 경로가 비어 있습니다.',
      );
    }

    final imageFile =
    File(normalizedImagePath);

    if (!await imageFile.exists()) {
      throw StateError(
        '업로드할 이미지 파일을 찾을 수 없습니다.',
      );
    }

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_'
        '${_uuid.v4()}.jpg';

    final reference =
    _storage.ref().child(
      'users/'
          '${user.uid}/'
          'memo_images/'
          '$normalizedBookId/'
          '$fileName',
    );

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        'userId': user.uid,
        'bookId': normalizedBookId,
      },
    );

    final uploadTask =
    await reference.putFile(
      imageFile,
      metadata,
    );

    return uploadTask.ref.getDownloadURL();
  }

  static Future<void> deleteMemoImage(
      String imageUrl,
      ) async {
    final normalizedUrl =
    imageUrl.trim();

    if (normalizedUrl.isEmpty) {
      return;
    }

    try {
      final reference =
      _storage.refFromURL(
        normalizedUrl,
      );

      await reference.delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        return;
      }

      rethrow;
    }
  }
}