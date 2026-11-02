import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> showLoginRequiredDialog(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;

  // 1) 로그인 안 됨(익명/없음) → 기존 로그인 다이얼로그
  final isAnonymous = (user == null) || (user.isAnonymous);
  if (isAnonymous) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSizeTitle = screenWidth * 0.05;
    final fontSizeBody = screenWidth * 0.04;
    final fontSizeButton = screenWidth * 0.04;
    final padding = screenWidth * 0.05;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.all(padding),
        title: Text(
          "로그인이 필요합니다",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'kopub',
            fontSize: fontSizeTitle,
          ),
        ),
        content: Text(
          "이 기능을 사용하려면 로그인해주세요.",
          style: TextStyle(
            fontFamily: 'kopub',
            height: 1.4,
            color: Colors.white70,
            fontSize: fontSizeBody,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/login');
            },
            child: Text(
              "로그인",
              style: TextStyle(
                color: Colors.amberAccent,
                fontSize: fontSizeButton,
                fontFamily: 'kopub',
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "취소",
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: fontSizeButton,
                fontFamily: 'kopub',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2) 로그인은 했는데 이메일 인증이 안 됨 → 이메일 인증 다이얼로그
  await user.reload();
  final refreshed = FirebaseAuth.instance.currentUser;

  if (refreshed != null && !refreshed.emailVerified) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSizeTitle = screenWidth * 0.05;
    final fontSizeBody = screenWidth * 0.04;
    final fontSizeButton = screenWidth * 0.04;
    final padding = screenWidth * 0.05;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.all(padding),
        title: Text(
          "이메일 인증이 필요합니다",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'kopub',
            fontSize: fontSizeTitle,
          ),
        ),
        content: Text(
          "이 기능을 사용하려면 이메일 인증을 완료해주세요.\n메일함에서 인증 후 다시 시도해 주세요.",
          style: TextStyle(
            fontFamily: 'kopub',
            height: 1.4,
            color: Colors.white70,
            fontSize: fontSizeBody,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/verify_email');
            },
            child: Text(
              "인증하러 가기",
              style: TextStyle(
                color: Colors.amberAccent,
                fontSize: fontSizeButton,
                fontFamily: 'kopub',
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "취소",
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: fontSizeButton,
                fontFamily: 'kopub',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3) 인증 완료면 아무것도 안 띄움(=허용)
  return;
}