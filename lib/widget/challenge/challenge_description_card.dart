import 'package:flutter/material.dart';

import 'package:dayverse_book/widget/card_box.dart';

class DescriptionCard
    extends StatelessWidget {
  final String title;
  final String content;

  const DescriptionCard({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    return CardBox(
      margin: EdgeInsets.only(
        bottom:
        screenWidth * 0.025,
      ),
      padding: EdgeInsets.all(
        screenWidth * 0.04,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width:
                screenWidth * 0.085,
                height:
                screenWidth * 0.085,
                decoration:
                BoxDecoration(
                  color: Colors
                      .amberAccent
                      .withOpacity(
                    0.08,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),
                child: Icon(
                  _getIconForTitle(
                    title,
                  ),
                  color: Colors
                      .amberAccent
                      .withOpacity(
                    0.85,
                  ),
                  size:
                  screenWidth *
                      0.043,
                ),
              ),

              SizedBox(
                width:
                screenWidth *
                    0.025,
              ),

              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color:
                    Colors.white,
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth *
                        0.034,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(
            height:
            screenWidth * 0.035,
          ),

          Text(
            content,
            style: TextStyle(
              color: Colors.white
                  .withOpacity(0.68),
              fontFamily:
              'kopub',
              fontSize:
              screenWidth * 0.031,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForTitle(
      String title,
      ) {
    switch (title) {
      case '챌린지 소개':
        return Icons
            .menu_book_outlined;

      case '챌린지 목표':
        return Icons
            .flag_outlined;

      case '이런 분께 추천':
        return Icons
            .person_outline_rounded;

      case '진행 방법':
        return Icons
            .route_outlined;

      default:
        return Icons
            .notes_rounded;
    }
  }
}