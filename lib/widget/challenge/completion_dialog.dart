import 'package:flutter/material.dart';
import 'package:dayverse_book/model/challenge_model.dart';

class ChallengeCompletionDialog extends StatelessWidget {
  final Challenge challenge;

  const ChallengeCompletionDialog({super.key, required this.challenge});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final emojiSize = screenWidth * 0.12;          // 화면에 비례한 이모지 크기
    final titleFontSize = screenWidth * 0.045;     // 약 16~20
    final bodyFontSize = screenWidth * 0.037;      // 약 13~15
    final buttonFontSize = screenWidth * 0.03;
    final padding = screenWidth * 0.05;

    return AlertDialog(
      backgroundColor: Colors.greenAccent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: EdgeInsets.symmetric(horizontal: padding, vertical: padding * 0.7),
      content: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("🏆", style: TextStyle(fontSize: emojiSize)),
            SizedBox(height: screenHeight * 0.015),
            Text(
              "'${challenge.title}'\n챌린지 달성 완료!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Kopub',
                fontWeight: FontWeight.bold,
                fontSize: titleFontSize,
                color: Colors.black,
              ),
            ),
            SizedBox(height: screenHeight * 0.01),
            Text(
              "멋진 도전을 완수하셨습니다 👏\n당신의 꾸준함에 박수를 보냅니다!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black87,
                fontFamily: 'Kopub',
                fontSize: bodyFontSize,
                height: 1.4,
              ),
            ),
            SizedBox(height: screenHeight * 0.025),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: TextStyle(
                    fontSize: buttonFontSize,
                    fontFamily: 'Kopub',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // ✅ 꼭 있어야 함
                },
                child: const Text("확인"),
              ),
            )
          ],
        ),
      ),
    );
  }
}