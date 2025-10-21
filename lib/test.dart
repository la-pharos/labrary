import 'package:flutter/material.dart';

class TestImageScreen extends StatelessWidget {
  const TestImageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('이미지 테스트')),
      body: Center(
        child: Image.asset(
          'assets/image/morning_calm.jpg', // ⬅️ 여기 직접 테스트할 이미지 넣기
          width: 200,
          height: 200,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}