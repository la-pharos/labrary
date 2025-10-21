import 'package:flutter/material.dart';

class RewardScreen extends StatelessWidget {
  const RewardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF013328),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("리워드"),
      ),
      body: const Center(
        child: Text(
          "여기는 리워드 화면입니다!",
          style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'kopub'),
        ),
      ),
    );
  }
}