import 'dart:math' as math;

import 'package:flutter/material.dart';

class BookSpineWidget extends StatelessWidget {
  final String title;
  final String author;
  final String? spineUrl;
  final String? coverUrl;

  final double width;
  final double height;

  const BookSpineWidget({
    super.key,
    required this.title,
    required this.author,
    required this.spineUrl,
    required this.coverUrl,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final url = spineUrl?.trim() ?? '';

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          width * 0.12,
        ),
        child: url.startsWith('http')
            ? Image.network(
          url,
          width: width,
          height: height,
          fit: BoxFit.fill,

          loadingBuilder: (
              context,
              child,
              loadingProgress,
              ) {
            if (loadingProgress == null) {
              return child;
            }

            return Container(
              width: width,
              height: height,
              color: Colors.grey.withOpacity(0.08),
            );
          },

          errorBuilder: (
              context,
              error,
              stackTrace,
              ) {
            debugPrint(
              '[SPINE IMAGE ERROR] '
                  '$title / $url / $error',
            );

            return _buildFallback();
          },
        )
            : _buildFallback(),
      ),
    );
  }

  Widget _buildFallback() {
    final backgroundColor =
    _fallbackColor();

    final textColor =
    backgroundColor.computeLuminance() > 0.48
        ? const Color(0xFF24201D)
        : const Color(0xFFF8F5EE);

    final secondaryTextColor =
    textColor.withOpacity(0.72);

    final accentColor =
    textColor.withOpacity(0.24);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _lighten(
              backgroundColor,
              0.06,
            ),
            backgroundColor,
            _darken(
              backgroundColor,
              0.05,
            ),
          ],
          stops: const [
            0,
            0.55,
            1,
          ],
        ),
      ),
      child: Stack(
        children: [
          // =================================================
          // 왼쪽 미세 음영
          // =================================================

          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: math.max(
                1,
                width * 0.08,
              ),
              color: Colors.black.withOpacity(
                0.045,
              ),
            ),
          ),

          // =================================================
          // 오른쪽 미세 하이라이트
          // =================================================

          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: math.max(
                1,
                width * 0.045,
              ),
              color: Colors.white.withOpacity(
                0.045,
              ),
            ),
          ),

          // =================================================
          // 상단 장식선
          // =================================================

          Positioned(
            top: height * 0.045,
            left: width * 0.2,
            right: width * 0.2,
            child: Container(
              height: math.max(
                1,
                width * 0.035,
              ),
              color: accentColor,
            ),
          ),

          // =================================================
          // 하단 장식선
          // =================================================

          Positioned(
            bottom: height * 0.045,
            left: width * 0.2,
            right: width * 0.2,
            child: Container(
              height: math.max(
                1,
                width * 0.035,
              ),
              color: accentColor,
            ),
          ),

          // =================================================
          // 중앙 텍스트
          // =================================================

          Center(
            child: RotatedBox(
              quarterTurns: 1,
              child: SizedBox(
                width: height * 0.72,
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment:
                      Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: textColor,
                          fontFamily: 'kopub',
                          fontWeight:
                          FontWeight.w700,
                          fontSize: math.max(
                            8,
                            width * 0.34,
                          ),
                          letterSpacing: -0.2,
                          height: 1,
                        ),
                      ),
                    ),

                    if (author
                        .trim()
                        .isNotEmpty) ...[
                      SizedBox(
                        height: math.max(
                          2,
                          width * 0.08,
                        ),
                      ),

                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment:
                        Alignment.centerLeft,
                        child: Text(
                          author,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color:
                            secondaryTextColor,
                            fontFamily: 'kopub',
                            fontWeight:
                            FontWeight.w400,
                            fontSize: math.max(
                              6,
                              width * 0.21,
                            ),
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // =================================================
          // 작은 출판사 느낌 포인트
          // =================================================

          Positioned(
            bottom: height * 0.022,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: math.max(
                  2,
                  width * 0.14,
                ),
                height: math.max(
                  2,
                  width * 0.14,
                ),
                decoration: BoxDecoration(
                  color: textColor.withOpacity(
                    0.5,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _fallbackColor() {
    const colors = [
      Color(0xFF596275), // dusty navy
      Color(0xFF6D597A), // muted purple
      Color(0xFF8D5A4A), // terracotta
      Color(0xFFB56576), // dusty rose
      Color(0xFF5F7161), // sage green
      Color(0xFF7A6F5D), // taupe
      Color(0xFF4F6D7A), // blue gray
      Color(0xFF7F5539), // cocoa
      Color(0xFF6A7B4F), // olive
      Color(0xFF9C6644), // caramel
      Color(0xFF5C677D), // slate blue
      Color(0xFF8A5A44), // muted rust
      Color(0xFF577590), // desaturated blue
      Color(0xFF7D6B91), // lavender gray
      Color(0xFF52796F), // eucalyptus

      // 조금 더 트렌디한 포인트
      Color(0xFF8A817C), // warm gray
      Color(0xFFA98467), // clay
      Color(0xFF6B705C), // moss
      Color(0xFF7B6D8D), // muted lilac
      Color(0xFF4A6670), // deep dusty teal
    ];

    final hash =
    title.codeUnits.fold<int>(
      0,
          (sum, value) =>
      sum + value,
    );

    return colors[
    hash % colors.length];
  }

  Color _lighten(
      Color color,
      double amount,
      ) {
    return Color.lerp(
      color,
      Colors.white,
      amount,
    ) ??
        color;
  }

  Color _darken(
      Color color,
      double amount,
      ) {
    return Color.lerp(
      color,
      Colors.black,
      amount,
    ) ??
        color;
  }
}