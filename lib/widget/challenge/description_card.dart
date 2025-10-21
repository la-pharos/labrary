import 'package:flutter/material.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/utils/challenge_check_utils.dart';

class DescriptionCard extends StatelessWidget {
  final String title;
  final String content;

  const DescriptionCard({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final titleFontSize = screenWidth * 0.037;   // 대략 15~17
    final contentFontSize = screenWidth * 0.032; // 대략 13~14
    final horizontalPadding = screenWidth * 0.04;
    final verticalMargin = screenWidth * 0.03;

    return Container(
      margin: EdgeInsets.only(top: verticalMargin),
      padding: EdgeInsets.all(horizontalPadding),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'kopub',
                  ),
                ),
                SizedBox(height: screenWidth * 0.015),
                Text(
                  content,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: contentFontSize,
                    fontFamily: 'kopub',
                    height: 1.4,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}