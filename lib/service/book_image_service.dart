import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class BookImageService {
  static Future<String> uploadSelfRegisteredBookCover({
    required File imageFile,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw StateError('로그인 정보를 찾을 수 없습니다.');
    }

    if (!await imageFile.exists()) {
      throw StateError('선택한 이미지 파일을 찾을 수 없습니다.');
    }

    final extension = _getFileExtension(imageFile.path);
    final fileName = '${const Uuid().v4()}.$extension';

    final reference = FirebaseStorage.instance
        .ref()
        .child('users')
        .child(uid)
        .child('book_covers')
        .child(fileName);

    final metadata = SettableMetadata(
      contentType: _getContentType(extension),
      customMetadata: {
        'ownerUid': uid,
        'type': 'selfRegisteredBookCover',
      },
    );

    final uploadTask = await reference.putFile(
      imageFile,
      metadata,
    );

    return uploadTask.ref.getDownloadURL();
  }

  static Future<void> deleteBookCover(String imageUrl) async {
    if (imageUrl.trim().isEmpty) {
      return;
    }

    try {
      final reference =
      FirebaseStorage.instance.refFromURL(imageUrl);

      await reference.delete();
    } on FirebaseException catch (e) {
      // 이미 삭제된 파일은 무시
      if (e.code != 'object-not-found') {
        rethrow;
      }
    }
  }

  static String _getFileExtension(String path) {
    final cleanPath = path.split('?').first;
    final lastDot = cleanPath.lastIndexOf('.');

    if (lastDot == -1) {
      return 'jpg';
    }

    final extension = cleanPath
        .substring(lastDot + 1)
        .toLowerCase();

    switch (extension) {
      case 'png':
      case 'webp':
      case 'jpeg':
      case 'jpg':
        return extension;
      default:
        return 'jpg';
    }
  }

  static String _getContentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }
}