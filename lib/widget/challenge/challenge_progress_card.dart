import 'package:flutter/material.dart';

import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/utils/challenge_progress_utils.dart';
import 'package:dayverse_book/utils/challenge_check_utils.dart';
import 'package:dayverse_book/widget/card_box.dart';

class ProgressCard extends StatelessWidget {
  final Challenge challenge;
  final List<BookModel> savedBooks;
  final Map<String, dynamic> record;

  final List<BookModel>?
  targetBooksOverride;

  const ProgressCard({
    super.key,
    required this.challenge,
    required this.savedBooks,
    required this.record,
    this.targetBooksOverride,
  });

  String? _keyForBook(
      BookModel book,
      ) {
    if (book.id.isNotEmpty) {
      return book.id;
    }

    final isbn =
        book.isbn;

    if (isbn != null &&
        isbn.isNotEmpty) {
      return isbn;
    }

    return null;
  }

  List<BookModel> get _targetBooks {
    if (targetBooksOverride != null &&
        targetBooksOverride!.isNotEmpty) {
      return targetBooksOverride!;
    }

    final participated =
    challenge.attempts.isNotEmpty
        ? challenge
        .attempts
        .last
        .participatedBooks ??
        const <BookModel>[]
        : const <BookModel>[];

    if (participated.isNotEmpty) {
      return participated;
    }

    return challenge.requiredBooks ??
        const <BookModel>[];
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    final checkType =
    getChallengeCheckActionType(
      challenge,
    );

    final dynamic source =
    checkType ==
        ChallengeCheckActionType
            .libraryAuto
        ? savedBooks
        : record;

    final status =
    _buildStatus(
      challenge,
    );

    final unit =
    _getUnit(
      challenge,
      checkType,
    );

    var targetCount =
    ChallengeProgressUtils
        .getTargetCount(
      challenge,
      source,
      targetBooksOverride:
      _targetBooks,
    );

    var completed =
    ChallengeProgressUtils
        .getCompletedCount(
      challenge,
      source,
      targetBooksOverride:
      _targetBooks,
    );

    var progress =
    ChallengeProgressUtils
        .getProgress(
      challenge,
      source,
      targetBooksOverride:
      _targetBooks,
    );

    var percentage =
    (progress * 100)
        .toInt()
        .clamp(
      0,
      100,
    );

    if (challenge.method ==
        ChallengeMethod
            .specificBooks &&
        checkType ==
            ChallengeCheckActionType
                .pageAuto) {
      final pageProgress =
      _pageSumProgressFromTargets(
        source,
      );

      final totalPages =
      pageProgress['target']!;

      final readPages =
      pageProgress['completed']!;

      if (totalPages > 0) {
        targetCount =
            totalPages;

        completed =
            readPages;

        progress =
            (readPages / totalPages)
                .clamp(
              0.0,
              1.0,
            );

        percentage =
            (progress * 100)
                .toInt()
                .clamp(
              0,
              100,
            );
      }
    }

    return _buildProgressCard(
      screenWidth:
      screenWidth,
      status:
      status,
      progress:
      progress,
      completed:
      completed,
      targetCount:
      targetCount,
      percentage:
      percentage,
      unit:
      unit,
    );
  }

  // =========================================================
  // UI
  // =========================================================

  Widget _buildProgressCard({
    required double screenWidth,
    required _ChallengeStatus status,
    required double progress,
    required int completed,
    required int targetCount,
    required int percentage,
    required String unit,
  }) {
    return CardBox(
      margin: EdgeInsets.zero,
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
                screenWidth * 0.09,
                height:
                screenWidth * 0.09,
                decoration:
                BoxDecoration(
                  color: Colors.amberAccent
                      .withOpacity(0.10),
                  borderRadius:
                  BorderRadius.circular(
                    11,
                  ),
                ),
                child: Icon(
                  status.icon,
                  color:
                  Colors.amberAccent,
                  size:
                  screenWidth * 0.045,
                ),
              ),

              SizedBox(
                width:
                screenWidth * 0.025,
              ),

              Expanded(
                child: Text(
                  status.text,
                  style: TextStyle(
                    color:
                    Colors.white,
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth * 0.033,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(
            height:
            screenWidth * 0.04,
          ),

          Row(
            crossAxisAlignment:
            CrossAxisAlignment.end,
            children: [
              Text(
                '진행률',
                style: TextStyle(
                  color:
                  Colors.white54,
                  fontFamily:
                  'kopub',
                  fontSize:
                  screenWidth * 0.029,
                ),
              ),

              const Spacer(),

              Text(
                '$percentage%',
                style: TextStyle(
                  color:
                  Colors.amberAccent,
                  fontFamily:
                  'kopub',
                  fontSize:
                  screenWidth * 0.052,
                  fontWeight:
                  FontWeight.bold,
                  height: 1,
                ),
              ),
            ],
          ),

          SizedBox(
            height:
            screenWidth * 0.02,
          ),

          ClipRRect(
            borderRadius:
            BorderRadius.circular(30),
            child:
            LinearProgressIndicator(
              value: progress
                  .clamp(
                0.0,
                1.0,
              )
                  .toDouble(),
              backgroundColor:
              Colors.white
                  .withOpacity(
                0.07,
              ),
              color:
              Colors.amberAccent,
              minHeight:
              screenWidth * 0.022,
            ),
          ),

          SizedBox(
            height:
            screenWidth * 0.025,
          ),

          if (targetCount > 0)
            Row(
              children: [
                Text(
                  '현재 현황',
                  style: TextStyle(
                    color:
                    Colors.white38,
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth *
                        0.027,
                  ),
                ),

                const Spacer(),

                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text:
                        '$completed',
                        style:
                        TextStyle(
                          color:
                          Colors.white,
                          fontFamily:
                          'kopub',
                          fontSize:
                          screenWidth *
                              0.032,
                          fontWeight:
                          FontWeight
                              .bold,
                        ),
                      ),

                      TextSpan(
                        text:
                        ' / $targetCount $unit',
                        style:
                        TextStyle(
                          color: Colors
                              .white54,
                          fontFamily:
                          'kopub',
                          fontSize:
                          screenWidth *
                              0.029,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            Text(
              '아직 진행률 데이터를 계산할 수 없어요.',
              style: TextStyle(
                color:
                Colors.white38,
                fontFamily:
                'kopub',
                fontSize:
                screenWidth * 0.028,
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================
  // STATUS
  // =========================================================

  _ChallengeStatus _buildStatus(
      Challenge challenge,
      ) {
    final today =
    stripTime(
      DateTime.now(),
    );

    final attempt =
    challenge.attempts.isNotEmpty
        ? challenge.attempts.last
        : null;

    final startDate =
    attempt?.startDate.toLocal();

    int? duration;

    if (attempt?.stageIndex != null &&
        challenge
            .stageDurations
            .isNotEmpty) {
      final index =
      attempt!.stageIndex!;

      if (index >= 0 &&
          index <
              challenge
                  .stageDurations
                  .length) {
        duration =
        challenge
            .stageDurations[index];
      }
    }

    duration ??=
        attempt?.selectedDuration;

    if (duration == null &&
        attempt?.endDate != null &&
        startDate != null) {
      final start =
      stripTime(
        startDate,
      );

      final end =
      stripTime(
        attempt!.endDate!
            .toLocal(),
      );

      duration =
          end.difference(start).inDays +
              1;
    }

    if (duration == null &&
        challenge.stageType ==
            ChallengeStageType.single &&
        challenge.period ==
            ChallengePeriod.daysBased &&
        challenge.durationOptions
            ?.isNotEmpty ==
            true) {
      duration =
          challenge
              .durationOptions!
              .first;
    }

    if (startDate != null &&
        duration != null) {
      final start =
      stripTime(
        startDate,
      );

      final end =
      start.add(
        Duration(
          days:
          duration - 1,
        ),
      );

      if (today.isBefore(start)) {
        final days =
            start
                .difference(today)
                .inDays;

        return _ChallengeStatus(
          text:
          '시작까지 D-$days',
          icon:
          Icons.flag_outlined,
        );
      }

      if (today.isAtSameMomentAs(
        end,
      )) {
        return const _ChallengeStatus(
          text:
          '오늘이 마지막 날이에요',
          icon:
          Icons.timer_outlined,
        );
      }

      if (today.isAfter(start) &&
          today.isBefore(end)) {
        final days =
            end
                .difference(today)
                .inDays;

        return _ChallengeStatus(
          text:
          '종료까지 D-$days',
          icon:
          Icons.schedule_rounded,
        );
      }

      if (today.isAfter(end)) {
        return const _ChallengeStatus(
          text:
          '도전 기간이 종료되었어요',
          icon:
          Icons.check_rounded,
        );
      }

      return _ChallengeStatus(
        text:
        '종료까지 D-${end.difference(today).inDays}',
        icon:
        Icons.schedule_rounded,
      );
    }

    if (challenge.endDate != null) {
      final end =
      stripTime(
        challenge.endDate!
            .toLocal(),
      );

      if (today.isAtSameMomentAs(
        end,
      )) {
        return const _ChallengeStatus(
          text:
          '오늘이 마지막 날이에요',
          icon:
          Icons.timer_outlined,
        );
      }

      if (today.isBefore(end)) {
        return _ChallengeStatus(
          text:
          '종료까지 D-${end.difference(today).inDays}',
          icon:
          Icons.schedule_rounded,
        );
      }

      return const _ChallengeStatus(
        text:
        '도전 기간이 종료되었어요',
        icon:
        Icons.check_rounded,
      );
    }

    return const _ChallengeStatus(
      text:
      '정해진 기한이 없는 자유 챌린지예요',
      icon:
      Icons.all_inclusive_rounded,
    );
  }

  // =========================================================
  // PAGE PROGRESS
  // =========================================================

  Map<String, int>
  _pageSumProgressFromTargets(
      dynamic data,
      ) {
    Map<String, dynamic>
    recordPages =
    <String, dynamic>{};

    if (data is Map) {
      final top =
      data['bookReadPages'];

      if (top is Map) {
        recordPages =
        Map<String, dynamic>.from(
          top,
        );
      } else {
        final inner =
        data['recordData'];

        if (inner is Map &&
            inner['bookReadPages']
            is Map) {
          recordPages =
          Map<String, dynamic>.from(
            inner['bookReadPages'],
          );
        }
      }
    }

    final savedMap =
    <String, BookModel>{
      for (final book
      in savedBooks)
        if (_keyForBook(book) !=
            null)
          _keyForBook(book)!:
          book,
    };

    int totalPages = 0;
    int readPages = 0;

    for (final target
    in _targetBooks) {
      final key =
      _keyForBook(
        target,
      );

      if (key == null) {
        continue;
      }

      final total =
      target.pageCount > 0
          ? target.pageCount
          : savedMap[key]
          ?.pageCount ??
          0;

      if (total <= 0) {
        continue;
      }

      final fromRecord =
          int.tryParse(
            recordPages[key]
                ?.toString() ??
                '',
          ) ??
              0;

      final fromSaved =
          savedMap[key]
              ?.pageRead ??
              0;

      final read =
      fromRecord > 0
          ? fromRecord
          : fromSaved;

      final clipped =
      read.clamp(
        0,
        total,
      );

      totalPages +=
          total;

      readPages +=
          clipped;
    }

    return {
      'completed':
      readPages,
      'target':
      totalPages,
    };
  }

  // =========================================================
  // COMMON
  // =========================================================

  DateTime stripTime(
      DateTime date,
      ) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  String _getUnit(
      Challenge challenge,
      ChallengeCheckActionType checkType,
      ) {
    if (challenge.method == ChallengeMethod.timeBased) {
      return '분';
    }

    switch (checkType) {
      case ChallengeCheckActionType.pageAuto:
        return '페이지';

      case ChallengeCheckActionType.timerAuto:
      case ChallengeCheckActionType.manual:
        return '회';

      case ChallengeCheckActionType.libraryAuto:
        return '권';

      default:
        return '';
    }
  }
}

class _ChallengeStatus {
  final String text;
  final IconData icon;

  const _ChallengeStatus({
    required this.text,
    required this.icon,
  });
}
