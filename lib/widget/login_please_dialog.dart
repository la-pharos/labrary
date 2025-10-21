import 'package:flutter/material.dart';

Future<void> showLoginRequiredDialog(BuildContext context) async {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;

  final fontSizeTitle = screenWidth * 0.05;     // 약 18~20
  final fontSizeBody = screenWidth * 0.04;      // 약 14~16
  final fontSizeButton = screenWidth * 0.04;
  final padding = screenWidth * 0.05;           // dialog padding

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
