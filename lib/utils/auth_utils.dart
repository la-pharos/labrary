import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:dayverse_book/widget/login_please_dialog.dart';

Future<bool> checkLoginAndProceed(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;

  // ✅ null 또는 익명 로그인 유저는 로그인 안 된 것으로 간주
  if (user == null || user.isAnonymous) {
    await showLoginRequiredDialog(context);
    return false;
  }

  return true;
}