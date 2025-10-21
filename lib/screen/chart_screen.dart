import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/main.dart';
import 'package:dayverse_book/screen/level_screen.dart';
import 'package:dayverse_book/screen/note_screen.dart';
import 'package:dayverse_book/screen/challenge_done_screen.dart';
import 'package:dayverse_book/screen/challenge_screen.dart';
import 'package:dayverse_book/screen/reward_screen.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/utils/level_utils.dart';
import 'package:dayverse_book/service/reading_log_service.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:dayverse_book/widget/ad_banner_placeholder.dart';


class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<String, int> dailyReadingMinutes = {};
  bool showAllRecords = false;

  @override
  void initState() {
    super.initState();
    _loadDailyReadingMinutes(force: true);
  }

  Future<void> _loadDailyReadingMinutes({bool force = false}) async {
    if (force || dailyReadingMinutes.isEmpty) {
      final map = await ReadingLogService.getTotalReadingMinutesByDate();
      if (!mounted) return; // ✅ 화면이 아직 살아있을 때만 setState
      setState(() {
        dailyReadingMinutes = map;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final savedBooksProvider = Provider.of<SavedBooksProvider>(context);
    final challengeProvider = Provider.of<ChallengeProvider>(context);

    final savedBooks = savedBooksProvider.savedBooks;
    final joinedChallenges = challengeProvider.joinedChallenges;
    final completedChallenges = challengeProvider.completedChallenges;

    final totalRead = savedBooks.where((b) => b.category == 'done').length;
    final currentLevel = LevelUtils.getCurrentLevel(totalRead);
    final booksToNext = currentLevel.end + 1 - totalRead;

    final paddingH = screenWidth * 0.05;
    final sectionGap = screenHeight * 0.02;

    return Scaffold(
      backgroundColor: const Color(0xFF013328),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: screenHeight * 0.065),
          _buildTopBar(screenWidth),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: screenHeight * 0.01,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: sectionGap * 0.5),
                  _buildOverviewCard(context, completedChallenges),
                  SizedBox(height: sectionGap),
                  const Divider(color: Colors.white24, thickness: 1),
                  SizedBox(height: sectionGap),
                  Text("독서 레벨",
                      style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontFamily: 'kopub',
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  SizedBox(height: sectionGap),
                  _buildLevelCard(context, currentLevel, totalRead, booksToNext),
                  SizedBox(height: sectionGap * 2),
                  Text("독서 통계",
                      style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontFamily: 'kopub',
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  SizedBox(height: sectionGap),
                  _buildStatisticsGrid(context, savedBooks),
                  SizedBox(height: sectionGap * 0.5),
                  _buildCalendar(context),
                  SizedBox(height: sectionGap * 0.5),
                  _buildSelectedDayInfo(context),
                  SizedBox(height: sectionGap * 2),
                  _buildNoteSection(context),
                  SizedBox(height: sectionGap * 2),
                  _buildCompletedChallengesSection(context, completedChallenges),                  SizedBox(height: sectionGap * 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05,
        vertical: screenWidth * 0.0055,
      ),
      child: Text(
        "ABOUT",
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'kopub',
          fontSize: screenWidth * 0.045,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildOverviewCard(BuildContext context, List completedChallenges) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final totalMinutes = dailyReadingMinutes.values.fold(0, (sum, v) => sum + v);
    final readingDays = dailyReadingMinutes.keys.length;
    final rewards = 0; // placeholder

    final int hours = totalMinutes ~/ 60;
    final int minutes = totalMinutes % 60;
    final String formattedTime = hours > 0 ? "${hours}h ${minutes}m" : "${minutes}m";

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenHeight * 0.02,
      ),
      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildOverviewItem(context, Icons.timer, "총 독서시간", formattedTime),
          _buildOverviewItem(context, Icons.calendar_today, "누적 독서일", "$readingDays일"),
          _buildOverviewItem(context, Icons.emoji_events, "획득 리워드", "준비중!"),
        ],
      ),
    );
  }

  Widget _buildOverviewItem(BuildContext context, IconData icon, String label, String value) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Column(
      children: [
        Icon(icon, color: Colors.amberAccent, size: screenWidth * 0.06),
        SizedBox(height: screenWidth * 0.015),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontWeight: FontWeight.bold,
            fontSize: screenWidth * 0.035,
          ),
        ),
        SizedBox(height: screenWidth * 0.005),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.03,
          ),
        ),
      ],
    );
  }

  Widget _buildLevelCard(BuildContext context, LevelInfo level, int totalRead, int toNext) {
    final screenWidth = MediaQuery.of(context).size.width;
    final progress = ((totalRead - level.start) / (level.end - level.start + 1)).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => LevelScreen(totalRead: totalRead, currentLevel: level, booksToNext: toNext)));
      },
      child: Container(
        padding: EdgeInsets.all(screenWidth * 0.04),
        height: screenWidth * 0.35,
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              LevelUtils.buildShieldIcon(level),
              SizedBox(width: screenWidth * 0.02),
              Text(level.name, style: TextStyle(fontFamily: 'kopub', fontSize: screenWidth * 0.045, fontWeight: FontWeight.bold, color: level.color)),
            ]),
            SizedBox(height: screenWidth * 0.025),
            Text(
              level.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontFamily: 'kopub',
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * 0.035,
              ),
            ),
            const Spacer(),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              color: level.color,
              minHeight: 8,
              borderRadius: BorderRadius.circular(10),
            ),
            SizedBox(height: screenWidth * 0.02),
            Text("다음 레벨까지 ${toNext}권 남음",
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'kopub',
                  fontWeight: FontWeight.bold,
                  fontSize: screenWidth * 0.03,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsGrid(BuildContext context, List<BookModel> books) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    final screenWidth = MediaQuery.of(context).size.width;
    final double boxWidth = (screenWidth - 40 - 16) / 2;

    int totalBooks = books.where((b) => b.category == "done").length;
    int yearBooks = books.where((b) => b.category == "done" && b.endDate?.year == now.year).length;
    int monthBooks = books.where((b) => b.category == "done" && b.endDate?.year == now.year && b.endDate?.month == now.month).length;
    int weekBooks = books.where((b) {
      if (b.category != "done" || b.endDate == null) return false;
      final d = DateTime(b.endDate!.year, b.endDate!.month, b.endDate!.day);
      return !d.isBefore(startOfWeek) && !d.isAfter(endOfWeek);
    }).length;

    return FutureBuilder<Map<String, int>>(
      future: ReadingLogService.getTotalReadingMinutesByDate(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final dailyMinutes = snapshot.data!;
        int totalMinutes = dailyMinutes.values.fold(0, (sum, v) => sum + v);
        int yearMinutes = dailyMinutes.entries.where((e) => DateTime.parse(e.key).year == now.year).fold(0, (sum, e) => sum + e.value);
        int monthMinutes = dailyMinutes.entries.where((e) {
          final d = DateTime.parse(e.key);
          return d.year == now.year && d.month == now.month;
        }).fold(0, (sum, e) => sum + e.value);
        int weekMinutes = dailyMinutes.entries.where((e) {
          final d = DateTime.parse(e.key);
          final dOnly = DateTime(d.year, d.month, d.day);
          return !dOnly.isBefore(startOfWeek) && !dOnly.isAfter(endOfWeek);
        }).fold(0, (sum, e) => sum + e.value);

        return Center(
          child: Column(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _buildStatBox("전체 권수", "$totalBooks권", boxWidth),
                  _buildStatBox("올해 권수", "$yearBooks권", boxWidth),
                  _buildStatBox("이번 달 권수", "$monthBooks권", boxWidth),
                  _buildStatBox("이번 주 권수", "$weekBooks권", boxWidth),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 1,
                width: double.infinity,
                color: Colors.white24,
                margin: const EdgeInsets.symmetric(horizontal: 20),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _buildStatBox("전체 독서시간", "${totalMinutes}분", boxWidth),
                  _buildStatBox("올해 독서시간", "${yearMinutes}분", boxWidth),
                  _buildStatBox("이번 달 독서시간", "${monthMinutes}분", boxWidth),
                  _buildStatBox("이번 주 독서시간", "${weekMinutes}분", boxWidth),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatBox(String title, String subtitle, double width) {
    return Container(
      width: width,
      height: width * 0.5,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'kopub',
              fontWeight: FontWeight.bold,
              fontSize: width * 0.075, // 🔽 약간 줄임
            ),
          ),
          SizedBox(height: width * 0.04), // 🔽 간격 줄임
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: width * 0.085, // 🔽 약간 줄임
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 📌 Calendar 위젯 추가
  Widget _buildCalendar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: TableCalendar(
        locale: 'en_US',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _selectedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
          });
        },
        startingDayOfWeek: StartingDayOfWeek.monday, // 📌 요일 시작: 월요일
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: 'kopub',
            fontWeight: FontWeight.bold,
          ),
          leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
          rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: Colors.white),
          weekendStyle: TextStyle(color: Colors.redAccent),
        ),
        calendarStyle: CalendarStyle(
          defaultTextStyle: const TextStyle(color: Colors.white),
          weekendTextStyle: const TextStyle(color: Colors.white),
          todayTextStyle: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold), // 오늘 날짜: 노란색
          todayDecoration: const BoxDecoration(), // ✅ 오늘 날짜 원형 제거
          selectedTextStyle: const TextStyle(color: Colors.black),
          selectedDecoration: const BoxDecoration(
            color: Colors.amberAccent,
            shape: BoxShape.circle,
          ),
          markerDecoration: BoxDecoration(
            color: Colors.amberAccent,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 1,
          outsideTextStyle: const TextStyle(color: Colors.white24),
        ),
        eventLoader: (day) {
          final key = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
          return dailyReadingMinutes.containsKey(key) ? [dailyReadingMinutes[key]] : [];
        },
      ),
    );
  }

  Widget _buildSelectedDayInfo(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final key = "${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}";
    final totalMinutes = dailyReadingMinutes[key] ?? 0;
    final savedBooks = Provider.of<SavedBooksProvider>(context).savedBooks;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ReadingLogService.getTimerLogsForDate(_selectedDay),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = snapshot.data ?? [];

        final Map<String, Map<String, dynamic>> groupedRecords = {};
        for (final record in records) {
          final title = record['title'] ?? '';
          if (!groupedRecords.containsKey(title)) {
            groupedRecords[title] = {
              'title': title,
              'durationMinutes': 0,
            };
          }
          groupedRecords[title]!['durationMinutes'] += record['durationMinutes'] ?? 0;
        }

        final visibleRecords = showAllRecords
            ? groupedRecords.values.toList()
            : groupedRecords.values.take(3).toList();
        final hasMore = groupedRecords.length > 3;

        return Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
          padding: EdgeInsets.all(screenWidth * 0.04),
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "총 독서 시간: ${totalMinutes}분",
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontFamily: 'kopub',
                  fontWeight: FontWeight.bold,
                  fontSize: screenWidth * 0.035,
                ),
              ),
              SizedBox(height: screenWidth * 0.03),
              if (records.isEmpty)
                Text(
                  "이 날에는 독서 기록이 없습니다.",
                  style: TextStyle(
                      color: Colors.white38,
                      fontFamily: 'kopub',
                      fontSize: screenWidth * 0.035),
                )
              else ...[
                Column(
                  children: visibleRecords.map((record) {
                    final title = record['title'] ?? '';
                    final minutes = record['durationMinutes'] ?? 0;
                    final matchedBook = savedBooks.firstWhere(
                          (b) => b.title == title,
                      orElse: () => BookModel(title: title, author: '작자 미상'),
                    );
                    return _buildBookListItem(
                      context,
                      matchedBook.title,
                      matchedBook.author,
                      matchedBook.imageUrl,
                      minutes,
                    );
                  }).toList(),
                ),
                if (hasMore)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        showAllRecords = !showAllRecords;
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.only(top: screenWidth * 0.02),
                      child: Center(
                        child: Text(
                          showAllRecords ? "접기 ▲" : "펼쳐보기 ▼",
                          style: TextStyle(
                            color: Colors.white60,
                            fontFamily: 'kopub',
                            fontSize: screenWidth * 0.035,
                          ),
                        ),
                      ),
                    ),
                  ),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildBookListItem(BuildContext context, String title, String? author, String? imageUrl, int minutes) {
    final screenWidth = MediaQuery.of(context).size.width;
    final imageWidth = screenWidth * 0.15;
    final imageHeight = imageWidth * 1.35;

    return Container(
      margin: EdgeInsets.only(bottom: screenWidth * 0.02),
      padding: EdgeInsets.all(screenWidth * 0.02),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: (imageUrl?.isNotEmpty == true)
                ? Image.network(
              imageUrl!,
              width: imageWidth,
              height: imageHeight,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: imageWidth,
                height: imageHeight,
                color: Colors.white12,
                child: const Icon(Icons.broken_image, color: Colors.white30),
              ),
            )
                : Container(
              width: imageWidth,
              height: imageHeight,
              color: Colors.white12,
              child: const Icon(Icons.book, color: Colors.white30),
            ),
          ),
          SizedBox(width: screenWidth * 0.03),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.035,
                    fontFamily: 'kopub',
                  ),
                ),
                SizedBox(height: screenWidth * 0.01),
                Text(
                  author ?? '작자 미상',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: screenWidth * 0.03,
                    fontFamily: 'kopub',
                  ),
                ),
                SizedBox(height: screenWidth * 0.01),
                Text(
                  "$minutes분 읽음",
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontSize: screenWidth * 0.03,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'kopub',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 독서 노트
  Widget _buildNoteSection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final savedBooksProvider = Provider.of<SavedBooksProvider>(context);

    final allNotes = savedBooksProvider.bookRecords
        .where((r) => r['content'] != '독서 타이머 기록')
        .toList();

    allNotes.sort((a, b) {
      final dateA = a['date'];
      final dateB = b['date'];
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    final totalNotes = allNotes.length;
    final latestNote = totalNotes > 0 ? allNotes.first : null;
    final book = latestNote != null
        ? savedBooksProvider.getBookById(latestNote['bookId'])
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "독서 노트",
          style: TextStyle(
            fontSize: screenWidth * 0.04,
            fontFamily: 'kopub',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: screenWidth * 0.04),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NoteScreen()),
            );
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(screenWidth * 0.045),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "독서 노트를 확인해보세요!",
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize: screenWidth * 0.035,
                  ),
                ),
                SizedBox(height: screenWidth * 0.01),
                Text(
                  totalNotes == 0
                      ? "아직 작성한 노트가 없습니다."
                      : "현재 총 $totalNotes개의 노트가 저장되어 있습니다.",
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontFamily: 'kopub',
                    fontSize: screenWidth * 0.03,
                  ),
                ),
                SizedBox(height: screenWidth * 0.01),
                const Divider(color: Colors.white24, thickness: 1),
                if (latestNote != null && book != null) ...[
                  SizedBox(height: screenWidth * 0.02),
                  Text(
                    "가장 최근 독서 기록",
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'kopub',
                      fontSize: screenWidth * 0.03,
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.02),
                  Container(
                    margin: EdgeInsets.only(top: screenWidth * 0.02),
                    padding: EdgeInsets.all(screenWidth * 0.02),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: (book.imageUrl?.isNotEmpty == true)
                              ? Image.network(
                            book.imageUrl!,
                            width: screenWidth * 0.15,
                            height: screenWidth * 0.15 * 1.35,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: screenWidth * 0.15,
                              height: screenWidth * 0.15 * 1.35,
                              color: Colors.white12,
                              child: const Icon(Icons.broken_image, color: Colors.white30),
                            ),
                          )
                              : Container(
                            width: screenWidth * 0.15,
                            height: screenWidth * 0.15 * 1.35,
                            color: Colors.white12,
                            child: const Icon(Icons.book, color: Colors.white30),
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.03),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book.title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenWidth * 0.035,
                                  fontFamily: 'kopub',
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: screenWidth * 0.01),
                              Text(
                                book.author.isNotEmpty ? book.author : '작자 미상',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: screenWidth * 0.03,
                                  fontFamily: 'kopub',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: screenWidth * 0.01),
                              Text(
                                "📎 ${latestNote['content'] ?? ''}",                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenWidth * 0.03,
                                  fontFamily: 'kopub',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: screenWidth * 0.01),

                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 달성한 챌린지
  Widget _buildCompletedChallengesSection(BuildContext context, List completedChallenges) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "🏆 달성한 챌린지 🏆",
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                fontFamily: 'kopub',
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
          ],
        ),
        SizedBox(height: screenWidth * 0.04),
        if (completedChallenges.isEmpty)
          _buildChallengeLikePlaceholderBox("달성한 챌린지가 없습니다.", screenWidth)
        else
          Column(
            children: completedChallenges.map<Widget>((challenge) {
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChallengeDoneScreen(challenge: challenge)),
                ),
                child: ChallengeCard(challenge: challenge, showAttemptsBadge: true),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildChallengeLikePlaceholderBox(String text, double screenWidth) {
    return Container(
      margin: EdgeInsets.only(bottom: screenWidth * 0.03),
      padding: EdgeInsets.all(screenWidth * 0.025),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: screenWidth * 0.14,
            height: screenWidth * 0.14,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(screenWidth * 0.02),
            ),
            child: const Icon(Icons.hourglass_empty, color: Colors.white70),
          ),
          SizedBox(width: screenWidth * 0.04),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: screenWidth * 0.035,
                fontFamily: 'kopub',
                fontWeight: FontWeight.w300,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPlaceholderBox(BuildContext context, String text) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: screenWidth * 0.03),
      padding: EdgeInsets.all(screenWidth * 0.025),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: screenWidth * 0.035, // 예: 약 16px
          fontFamily: 'kopub',
          color: Colors.white70,
        ),
      ),
    );
  }

}
