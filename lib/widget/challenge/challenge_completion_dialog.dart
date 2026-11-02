import 'package:flutter/material.dart';

import 'package:dayverse_book/model/challenge_model.dart';

class ChallengeCompletionDialog
    extends StatelessWidget {
  final Challenge challenge;

  const ChallengeCompletionDialog({
    super.key,
    required this.challenge,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.065,
        ),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF16483F),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              screenWidth * 0.055,
              screenWidth * 0.06,
              screenWidth * 0.055,
              screenWidth * 0.045,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.amberAccent.withOpacity(0.10),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            /// 트로피
            Container(
              width:
              screenWidth * 0.19,
              height:
              screenWidth * 0.19,
              decoration:
              BoxDecoration(
                color: Colors
                    .amberAccent
                    .withOpacity(0.12),
                shape:
                BoxShape.circle,
                border:
                Border.all(
                  color: Colors
                      .amberAccent
                      .withOpacity(0.3),
                ),
              ),
              child: Icon(
                Icons
                    .emoji_events_rounded,
                color:
                Colors.amberAccent,
                size:
                screenWidth * 0.095,
              ),
            ),

            SizedBox(
              height:
              screenWidth * 0.03,
            ),

            /// COMPLETED
            Text(
              'COMPLETED',
              style: TextStyle(
                color:
                Colors.amberAccent,
                fontFamily:
                'kopub',
                fontSize:
                screenWidth * 0.026,
                fontWeight:
                FontWeight.bold,
                letterSpacing: 2,
              ),
            ),

            SizedBox(
              height:
              screenWidth * 0.03,
            ),

            /// 챌린지 제목
            Text(
              challenge.title,
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color:
                Colors.white,
                fontFamily:
                'kopub',
                fontSize:
                screenWidth * 0.045,
                fontWeight:
                FontWeight.bold,
                height: 1.4,
              ),
            ),

            SizedBox(
              height:
              screenWidth * 0.012,
            ),

            Text(
              '챌린지 달성 완료',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color: Colors.white
                    .withOpacity(0.65),
                fontFamily:
                'kopub',
                fontSize:
                screenWidth * 0.031,
                fontWeight:
                FontWeight.w600,
              ),
            ),

            SizedBox(
              height:
              screenWidth * 0.035,
            ),

            /// 메시지
            Text(
              '멋진 도전을 끝까지 완주했어요.\n'
                  '이번 성취도 당신의 기록으로 남았어요.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color: Colors.white
                    .withOpacity(0.55),
                fontFamily:
                'kopub',
                fontSize:
                screenWidth * 0.03,
                height: 1.6,
              ),
            ),

            SizedBox(
              height:
              screenWidth * 0.05,
            ),

            /// 확인
            SizedBox(
              width:
              double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context)
                      .pop();
                },
                style:
                ElevatedButton
                    .styleFrom(
                  backgroundColor:
                  Colors.amberAccent,
                  foregroundColor:
                  const Color(
                    0xFF013328,
                  ),
                  elevation: 0,
                  padding:
                  EdgeInsets.symmetric(
                    vertical:
                    screenWidth *
                        0.038,
                  ),
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                  ),
                ),
                child: Text(
                  '확인',
                  style: TextStyle(
                    color:
                    const Color(
                      0xFF013328,
                    ),
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth * 0.034,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    )
    );
  }
}