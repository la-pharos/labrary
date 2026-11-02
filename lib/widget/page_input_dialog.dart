/// ReadingRunningScreen에서 사용

import 'package:flutter/material.dart';

class PageInputDialog extends StatefulWidget {
  final int? initialPage;
  final int totalPages;
  final Function(int? page, bool isDone)? onConfirm;

  const PageInputDialog({
    super.key,
    this.initialPage,
    required this.totalPages,
    this.onConfirm,
  });

  @override
  State<PageInputDialog> createState() =>
      _PageInputDialogState();
}

class _PageInputDialogState
    extends State<PageInputDialog> {
  late TextEditingController _controller;

  String? _errorText;
  bool isFullyRead = false;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text:
      widget.initialPage?.toString() ??
          '',
    );

    isFullyRead =
        widget.initialPage != null &&
            widget.initialPage ==
                widget.totalPages;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validateAndSubmit() {
    final text =
    _controller.text.trim();

    final page =
    int.tryParse(text);

    if (text.isEmpty) {
      widget.onConfirm?.call(
        null,
        false,
      );

      Navigator.of(context).pop({
        'page': null,
        'done': false,
      });

      return;
    }

    if (page == null ||
        page < 1) {
      setState(() {
        _errorText =
        '1페이지 이상 입력해주세요.';
      });

      return;
    }

    if (page >
        widget.totalPages) {
      setState(() {
        _errorText =
        '총 ${widget.totalPages}페이지를 넘을 수 없어요.';
      });

      return;
    }

    final isDone =
        page == widget.totalPages;

    widget.onConfirm?.call(
      page,
      isDone,
    );

    Navigator.of(context).pop({
      'page': page,
      'done': isDone,
    });
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final screenWidth =
        MediaQuery.of(context)
            .size
            .width;

    final currentPage =
        int.tryParse(
          _controller.text.trim(),
        ) ??
            0;

    final validCurrentPage =
    currentPage.clamp(
      0,
      widget.totalPages,
    );

    final progress =
    widget.totalPages > 0
        ? (validCurrentPage /
        widget.totalPages)
        .clamp(
      0.0,
      1.0,
    )
        .toDouble()
        : 0.0;

    final percent =
    (progress * 100).round();

    return Dialog(
      backgroundColor:
      Colors.transparent,

      insetPadding:
      EdgeInsets.symmetric(
        horizontal:
        screenWidth * 0.06,
      ),

      child: Container(
        width: double.infinity,
        padding:
        EdgeInsets.all(
          screenWidth * 0.045,
        ),
        decoration:
        BoxDecoration(
          color:
          const Color(
            0xFF16483F,
          ),
          borderRadius:
          BorderRadius.circular(
            20,
          ),
          border:
          Border.all(
            color:
            Colors.white
                .withOpacity(
              0.08,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color:
              Colors.black
                  .withOpacity(
                0.30,
              ),
              blurRadius:
              24,
              offset:
              const Offset(
                0,
                10,
              ),
            ),
          ],
        ),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            // =================================================
            // HEADER
            // =================================================

            _buildDialogHeader(
              context,
              screenWidth,
            ),

            SizedBox(
              height:
              screenWidth * 0.035,
            ),

            // =================================================
            // LABEL
            // =================================================

            Text(
              '읽은 페이지',
              style: TextStyle(
                color:
                Colors.white
                    .withOpacity(
                  0.65,
                ),
                fontFamily:
                'kopub',
                fontSize:
                screenWidth *
                    0.029,
                fontWeight:
                FontWeight.w600,
              ),
            ),

            SizedBox(
              height:
              screenWidth * 0.015,
            ),

            // =================================================
            // INPUT
            // =================================================

            TextField(
              controller:
              _controller,

              keyboardType:
              TextInputType.number,

              textInputAction:
              TextInputAction.done,

              style:
              TextStyle(
                color:
                Colors.white,
                fontFamily:
                'kopub',
                fontSize:
                screenWidth *
                    0.04,
                fontWeight:
                FontWeight.w600,
              ),

              decoration:
              InputDecoration(
                hintText:
                '0',

                hintStyle:
                TextStyle(
                  color:
                  Colors.white24,
                  fontFamily:
                  'kopub',
                ),

                suffixText:
                '페이지',

                suffixStyle:
                TextStyle(
                  color:
                  Colors.white54,
                  fontFamily:
                  'kopub',
                  fontSize:
                  screenWidth *
                      0.029,
                ),

                filled:
                true,

                fillColor:
                Colors.white
                    .withOpacity(
                  0.04,
                ),

                contentPadding:
                EdgeInsets.symmetric(
                  horizontal:
                  screenWidth *
                      0.035,
                  vertical:
                  screenWidth *
                      0.035,
                ),

                errorText:
                _errorText,

                errorStyle:
                TextStyle(
                  color:
                  Colors.redAccent
                      .withOpacity(
                    0.85,
                  ),
                  fontFamily:
                  'kopub',
                  fontSize:
                  screenWidth *
                      0.025,
                ),

                enabledBorder:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius
                      .circular(
                    14,
                  ),
                  borderSide:
                  BorderSide(
                    color:
                    Colors.white
                        .withOpacity(
                      0.07,
                    ),
                  ),
                ),

                focusedBorder:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius
                      .circular(
                    14,
                  ),
                  borderSide:
                  BorderSide(
                    color:
                    Colors.amberAccent
                        .withOpacity(
                      0.50,
                    ),
                  ),
                ),

                errorBorder:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius
                      .circular(
                    14,
                  ),
                  borderSide:
                  BorderSide(
                    color:
                    Colors.redAccent
                        .withOpacity(
                      0.55,
                    ),
                  ),
                ),

                focusedErrorBorder:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius
                      .circular(
                    14,
                  ),
                  borderSide:
                  BorderSide(
                    color:
                    Colors.redAccent
                        .withOpacity(
                      0.75,
                    ),
                  ),
                ),

                border:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius
                      .circular(
                    14,
                  ),
                ),
              ),

              onChanged:
                  (text) {
                final page =
                int.tryParse(
                  text.trim(),
                );

                setState(() {
                  _errorText = null;

                  isFullyRead =
                      page ==
                          widget
                              .totalPages;
                });
              },

              onSubmitted:
                  (_) =>
                  _validateAndSubmit(),
            ),

            SizedBox(
              height:
              screenWidth * 0.025,
            ),

            // =================================================
            // PROGRESS INFO
            // =================================================

            Container(
              width: double.infinity,
              padding:
              EdgeInsets.all(
                screenWidth * 0.035,
              ),
              decoration:
              BoxDecoration(
                color:
                Colors.white
                    .withOpacity(
                  0.035,
                ),
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
                border:
                Border.all(
                  color:
                  Colors.white
                      .withOpacity(
                    0.06,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.totalPages > 0
                              ? '$validCurrentPage / ${widget.totalPages} 페이지'
                              : '페이지 정보 없음',
                          style:
                          TextStyle(
                            color:
                            Colors.white70,
                            fontFamily:
                            'kopub',
                            fontSize:
                            screenWidth *
                                0.028,
                          ),
                        ),
                      ),

                      if (widget.totalPages >
                          0)
                        Text(
                          '$percent%',
                          style:
                          TextStyle(
                            color:
                            Colors.amberAccent,
                            fontFamily:
                            'kopub',
                            fontSize:
                            screenWidth *
                                0.028,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                    ],
                  ),

                  if (widget.totalPages >
                      0) ...[
                    SizedBox(
                      height:
                      screenWidth *
                          0.018,
                    ),

                    ClipRRect(
                      borderRadius:
                      BorderRadius
                          .circular(
                        20,
                      ),
                      child:
                      LinearProgressIndicator(
                        value:
                        progress,
                        minHeight:
                        screenWidth *
                            0.014,
                        backgroundColor:
                        Colors.white
                            .withOpacity(
                          0.07,
                        ),
                        color:
                        Colors.amberAccent,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // =================================================
            // COMPLETE
            // =================================================

            if (isFullyRead) ...[
              SizedBox(
                height:
                screenWidth * 0.025,
              ),

              Container(
                width:
                double.infinity,
                padding:
                EdgeInsets.symmetric(
                  horizontal:
                  screenWidth *
                      0.03,
                  vertical:
                  screenWidth *
                      0.025,
                ),
                decoration:
                BoxDecoration(
                  color:
                  Colors.amberAccent
                      .withOpacity(
                    0.07,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                  border:
                  Border.all(
                    color:
                    Colors.amberAccent
                        .withOpacity(
                      0.18,
                    ),
                  ),
                ),
                child:
                Row(
                  children: [
                    Container(
                      width:
                      screenWidth *
                          0.07,
                      height:
                      screenWidth *
                          0.07,
                      decoration:
                      BoxDecoration(
                        color:
                        Colors.amberAccent
                            .withOpacity(
                          0.12,
                        ),
                        shape:
                        BoxShape.circle,
                      ),
                      child:
                      Icon(
                        Icons
                            .check_rounded,
                        color:
                        Colors.amberAccent,
                        size:
                        screenWidth *
                            0.04,
                      ),
                    ),

                    SizedBox(
                      width:
                      screenWidth *
                          0.02,
                    ),

                    Expanded(
                      child: Text(
                        '이 책을 모두 읽었어요.',
                        style:
                        TextStyle(
                          color:
                          Colors.amberAccent,
                          fontFamily:
                          'kopub',
                          fontSize:
                          screenWidth *
                              0.028,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(
              height:
              screenWidth * 0.035,
            ),

            // =================================================
            // CTA
            // =================================================

            SizedBox(
              width:
              double.infinity,
              child:
              ElevatedButton(
                onPressed:
                _validateAndSubmit,

                style:
                ElevatedButton
                    .styleFrom(
                  backgroundColor:
                  Colors.amberAccent,

                  foregroundColor:
                  const Color(
                    0xFF013328,
                  ),

                  elevation:
                  0,

                  padding:
                  EdgeInsets.symmetric(
                    vertical:
                    screenWidth *
                        0.038,
                  ),

                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius
                        .circular(
                      14,
                    ),
                  ),
                ),

                child:
                Row(
                  mainAxisAlignment:
                  MainAxisAlignment
                      .center,
                  children: [
                    Icon(
                      Icons
                          .check_rounded,
                      size:
                      screenWidth *
                          0.042,
                    ),

                    SizedBox(
                      width:
                      screenWidth *
                          0.012,
                    ),

                    Text(
                      '기록 완료',
                      style:
                      TextStyle(
                        fontFamily:
                        'kopub',
                        fontWeight:
                        FontWeight.bold,
                        fontSize:
                        screenWidth *
                            0.032,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildDialogHeader(
      BuildContext context,
      double screenWidth,
      ) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                '페이지 기록',
                style:
                TextStyle(
                  fontSize:
                  screenWidth *
                      0.043,
                  fontWeight:
                  FontWeight.bold,
                  fontFamily:
                  'kopub',
                  color:
                  Colors.white,
                ),
              ),

              SizedBox(
                height:
                screenWidth *
                    0.01,
              ),

              Text(
                '오늘 읽은 위치를 기록해주세요.',
                style:
                TextStyle(
                  color:
                  Colors.white
                      .withOpacity(
                    0.50,
                  ),
                  fontFamily:
                  'kopub',
                  fontSize:
                  screenWidth *
                      0.028,
                ),
              ),
            ],
          ),
        ),

        IconButton(
          onPressed:
              () {
            Navigator.of(context)
                .pop();
          },
          icon:
          Icon(
            Icons.close_rounded,
            color:
            Colors.white54,
            size:
            screenWidth *
                0.05,
          ),
        ),
      ],
    );
  }
}