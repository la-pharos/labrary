import 'package:flutter/material.dart';

enum ShareCardStyle {
  paper,
  forest,
  midnight,
  rose,
}

class ShareCardStyleData {
  final ShareCardStyle style;
  final String label;

  final Color backgroundColor;
  final Color accentColor;

  const ShareCardStyleData({
    required this.style,
    required this.label,
    required this.backgroundColor,
    required this.accentColor,
  });
}

const List<ShareCardStyleData> shareCardStyles = [
  ShareCardStyleData(
    style: ShareCardStyle.paper,
    label: 'Paper',
    backgroundColor: Color(0xFFF3EBDD),
    accentColor: Color(0xFF7B3F3F),
  ),

  ShareCardStyleData(
    style: ShareCardStyle.forest,
    label: 'Forest',
    backgroundColor: Color(0xFF173C33),
    accentColor: Color(0xFFE1C176),
  ),

  ShareCardStyleData(
    style: ShareCardStyle.midnight,
    label: 'Midnight',
    backgroundColor: Color(0xFF171B25),
    accentColor: Color(0xFFAFC5E8),
  ),

  ShareCardStyleData(
    style: ShareCardStyle.rose,
    label: 'Rose',
    backgroundColor: Color(0xFFE7D4CF),
    accentColor: Color(0xFF81545A),
  ),
];

class ShareCardTheme {
  final Color backgroundColor;

  final Color primaryTextColor;
  final Color secondaryTextColor;

  final Color accentColor;

  final Color surfaceColor;
  final Color surfaceStrongColor;

  final Color dividerColor;
  final Color borderColor;

  final Color fallbackCoverColor;

  final Color progressBackgroundColor;
  final Color ratingColor;

  final Color shadowColor;

  const ShareCardTheme({
    required this.backgroundColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.accentColor,
    required this.surfaceColor,
    required this.surfaceStrongColor,
    required this.dividerColor,
    required this.borderColor,
    required this.fallbackCoverColor,
    required this.progressBackgroundColor,
    required this.ratingColor,
    required this.shadowColor,
  });

  factory ShareCardTheme.fromStyle(
      ShareCardStyle style,
      ) {
    switch (style) {
    // =================================================
    // PAPER
    // 따뜻한 종이 + 버건디 포인트
    // =================================================
      case ShareCardStyle.paper:
        return const ShareCardTheme(
          backgroundColor:
          Color(0xFFF3EBDD),

          primaryTextColor:
          Color(0xFF28231E),

          secondaryTextColor:
          Color(0xFF7A7168),

          accentColor:
          Color(0xFF7B3F3F),

          surfaceColor:
          Color(0xFFE9DFCF),

          surfaceStrongColor:
          Color(0xFFDED1BF),

          dividerColor:
          Color(0xFFCFC3B2),

          borderColor:
          Color(0xFFD8CCBB),

          fallbackCoverColor:
          Color(0xFFE1D5C4),

          progressBackgroundColor:
          Color(0xFFD6CABB),

          ratingColor:
          Color(0xFFB98B36),

          shadowColor:
          Color(0x22000000),
        );

    // =================================================
    // FOREST
    // Labrary 시그니처
    // =================================================
      case ShareCardStyle.forest:
        return const ShareCardTheme(
          backgroundColor:
          Color(0xFF173C33),

          primaryTextColor:
          Color(0xFFF5EFE4),

          secondaryTextColor:
          Color(0xFFB7C4BE),

          accentColor:
          Color(0xFFE1C176),

          surfaceColor:
          Color(0xFF214B40),

          surfaceStrongColor:
          Color(0xFF29574A),

          dividerColor:
          Color(0xFF41675D),

          borderColor:
          Color(0xFF315A4F),

          fallbackCoverColor:
          Color(0xFF294F45),

          progressBackgroundColor:
          Color(0xFF355D52),

          ratingColor:
          Color(0xFFE1C176),

          shadowColor:
          Color(0x66000000),
        );

    // =================================================
    // MIDNIGHT
    // 거의 블랙에 가까운 네이비
    // =================================================
      case ShareCardStyle.midnight:
        return const ShareCardTheme(
          backgroundColor:
          Color(0xFF171B25),

          primaryTextColor:
          Color(0xFFF2F3F6),

          secondaryTextColor:
          Color(0xFF9EA6B5),

          accentColor:
          Color(0xFFAFC5E8),

          surfaceColor:
          Color(0xFF202631),

          surfaceStrongColor:
          Color(0xFF292F3C),

          dividerColor:
          Color(0xFF353D4A),

          borderColor:
          Color(0xFF303746),

          fallbackCoverColor:
          Color(0xFF262D38),

          progressBackgroundColor:
          Color(0xFF323A48),

          ratingColor:
          Color(0xFFD8B96B),

          shadowColor:
          Color(0x88000000),
        );

    // =================================================
    // ROSE
    // muted rose / editorial
    // =================================================
      case ShareCardStyle.rose:
        return const ShareCardTheme(
          backgroundColor:
          Color(0xFFE7D4CF),

          primaryTextColor:
          Color(0xFF3D3032),

          secondaryTextColor:
          Color(0xFF826E72),

          accentColor:
          Color(0xFF81545A),

          surfaceColor:
          Color(0xFFDDC6C1),

          surfaceStrongColor:
          Color(0xFFD3B8B3),

          dividerColor:
          Color(0xFFC8ACA7),

          borderColor:
          Color(0xFFD0B7B2),

          fallbackCoverColor:
          Color(0xFFD7C0BB),

          progressBackgroundColor:
          Color(0xFFCDB4AF),

          ratingColor:
          Color(0xFFA97D39),

          shadowColor:
          Color(0x26000000),
        );
    }
  }

  // =================================================
  // 기존 코드와의 호환용
  // =================================================

  Color get contentBackgroundColor =>
      surfaceColor;
}

class ShareCardStyleOption
    extends StatelessWidget {
  final String label;

  final Color backgroundColor;
  final Color accentColor;

  final bool isSelected;

  final VoidCallback onTap;

  const ShareCardStyleOption({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration:
        const Duration(milliseconds: 180),
        padding:
        const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(
            isSelected ? 0.10 : 0.035,
          ),
          borderRadius:
          BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? Colors.amberAccent
                : Colors.white
                .withOpacity(0.08),
            width:
            isSelected ? 1.4 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius:
                  BorderRadius.circular(9),
                ),
                child: Stack(
                  children: [
                    // =================================================
                    // 상단 작은 editorial label
                    // =================================================

                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        width: 20,
                        height: 3,
                        decoration:
                        BoxDecoration(
                          color:
                          accentColor,
                          borderRadius:
                          BorderRadius
                              .circular(20),
                        ),
                      ),
                    ),

                    // =================================================
                    // 큰 타이포를 상징하는 라인
                    // =================================================

                    Positioned(
                      left: 10,
                      right: 16,
                      top: 30,
                      child: Container(
                        height: 6,
                        decoration:
                        BoxDecoration(
                          color: accentColor
                              .withOpacity(
                            0.92,
                          ),
                          borderRadius:
                          BorderRadius
                              .circular(10),
                        ),
                      ),
                    ),

                    Positioned(
                      left: 10,
                      right: 30,
                      top: 42,
                      child: Container(
                        height: 6,
                        decoration:
                        BoxDecoration(
                          color: accentColor
                              .withOpacity(
                            0.58,
                          ),
                          borderRadius:
                          BorderRadius
                              .circular(10),
                        ),
                      ),
                    ),

                    // =================================================
                    // 하단 editorial 요소
                    // =================================================

                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 12,
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 30,
                            decoration:
                            BoxDecoration(
                              color:
                              accentColor
                                  .withOpacity(
                                0.18,
                              ),
                              borderRadius:
                              BorderRadius
                                  .circular(
                                3,
                              ),
                            ),
                          ),

                          const SizedBox(
                            width: 7,
                          ),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                              children: [
                                Container(
                                  height: 3,
                                  decoration:
                                  BoxDecoration(
                                    color:
                                    accentColor
                                        .withOpacity(
                                      0.7,
                                    ),
                                    borderRadius:
                                    BorderRadius
                                        .circular(
                                      10,
                                    ),
                                  ),
                                ),

                                const SizedBox(
                                  height: 5,
                                ),

                                FractionallySizedBox(
                                  widthFactor:
                                  0.62,
                                  child:
                                  Container(
                                    height: 3,
                                    decoration:
                                    BoxDecoration(
                                      color:
                                      accentColor
                                          .withOpacity(
                                        0.32,
                                      ),
                                      borderRadius:
                                      BorderRadius
                                          .circular(
                                        10,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.amberAccent
                    : Colors.white70,
                fontFamily: 'kopub',
                fontSize: 12,
                fontWeight: isSelected
                    ? FontWeight.bold
                    : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
