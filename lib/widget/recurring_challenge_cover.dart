
import 'package:flutter/material.dart';
import 'package:dayverse_book/model/challenge_model.dart';

class RecurringChallengeCover extends StatelessWidget {
  final Challenge challenge;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const RecurringChallengeCover({
    super.key,
    required this.challenge,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(14),
    ),
  });

  static bool supports(Challenge challenge) {
    return challenge.imageUrl == 'recurring://weekly' ||
        challenge.imageUrl == 'recurring://monthly';
  }

  @override
  Widget build(BuildContext context) {
    // =====================================================
    // CHALLENGE DATA
    // =====================================================

    final weekly =
        challenge.imageUrl == 'recurring://weekly';

    final start =
        challenge.startDate ?? DateTime.now();

    // 주간 챌린지는 목요일이 속한 월을 기준으로 표시
    final displayDate = weekly
        ? start.add(const Duration(days: 3))
        : start;

    final target = weekly
        ? (challenge.requiredMinutes ?? 0)
        : (challenge.totalBooks ?? 0);

    const monthNames = [
      'JAN', 'FEB', 'MAR', 'APR',
      'MAY', 'JUN', 'JUL', 'AUG',
      'SEP', 'OCT', 'NOV', 'DEC',
    ];

    final month =
    monthNames[displayDate.month - 1];

    final year = displayDate.year;

    // =====================================================
    // COLORS
    // =====================================================

    final backgroundColor = weekly
        ? const Color(0xFFD9E7D9)
        : const Color(0xFFE6E0EF);

    final foregroundColor = weekly
        ? const Color(0xFF173B2B)
        : const Color(0xFF49385F);

    // =====================================================
    // COVER
    // =====================================================

    return LayoutBuilder(
      builder: (context, constraints) {
        final actualWidth =
        constraints.hasBoundedWidth
            ? constraints.maxWidth
            : (width ?? 300.0);

        final actualHeight =
        constraints.hasBoundedHeight
            ? constraints.maxHeight
            : (height ?? actualWidth);

        final size = actualWidth < actualHeight
            ? actualWidth
            : actualHeight;

        final compact = size < 150;

        final padding = compact
            ? size * 0.09
            : size * 0.075;

        return ClipRRect(
          borderRadius: borderRadius,
          child: Container(
            width: width ?? double.infinity,
            height: height,
            color: backgroundColor,
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  // =========================================
                  // 1. DATE - 상단 크게
                  // =========================================

                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          month,
                          style: TextStyle(
                            color: foregroundColor,
                            fontSize: compact
                                ? size * 0.10
                                : size * 0.10,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            letterSpacing: 0.2,
                          ),
                        ),

                        SizedBox(
                          height: size * 0.015,
                        ),

                        Text(
                          '$year · ${weekly ? 'WEEKLY' : 'MONTHLY'}',
                          maxLines: 1,
                          style: TextStyle(
                            color: foregroundColor
                                .withOpacity(0.65),
                            fontSize: compact
                                ? size * 0.035
                                : size * 0.035,
                            fontWeight: FontWeight.w600,
                            letterSpacing: compact ? 0 : 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // =========================================
                  // 2. GOAL - 중앙 배치
                  // =========================================

                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$target',
                              style: TextStyle(
                                color: foregroundColor,
                                fontSize: compact
                                    ? size * 0.34
                                    : size * 0.33,
                                fontWeight:
                                FontWeight.w800,
                                height: 1.0,
                              ),
                            ),

                            SizedBox(
                              height: size * 0.025,
                            ),

                            Text(
                              weekly
                                  ? 'MINUTES'
                                  : 'BOOKS',
                              style: TextStyle(
                                color: foregroundColor,
                                fontSize: compact
                                    ? size * 0.078
                                    : size * 0.065,
                                fontWeight:
                                FontWeight.w700,
                                letterSpacing:
                                compact ? 0.2 : 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
