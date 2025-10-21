import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dayverse_book/model/challenge_model.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/provider/user_data_provider.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/widget/multi_book_search_selection_box.dart';
import 'package:dayverse_book/widget/calendar_widget.dart';
import 'package:dayverse_book/screen/challenge_ongoing_screen.dart'; // 네 경로에 맞춰서



class ChallengeCreateScreen extends StatefulWidget {
  const ChallengeCreateScreen({super.key});

  @override
  State<ChallengeCreateScreen> createState() => _ChallengeCreateScreenState();
}

class _ChallengeCreateScreenState extends State<ChallengeCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController  = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  File? _imageFile;

  // ✅ 단일 → 여러 권
  List<BookModel> _selectedBooks = [];

  bool _saving = false;

  // ---------- actions ----------
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  DateTime _strip(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _openCalendar({required bool isStart}) async {
    final now = DateTime.now();
    final today = _strip(now);

    // 시작일 달력은 오늘~+365일, 종료일 달력은 (선택된 시작일 또는 오늘)~+365일
    final minDate = isStart ? today : (_startDate != null ? _startDate! : today);
    final maxDate = today.add(const Duration(days: 365));

    // 달력에서 표시할 기본 선택일
    final selected = isStart
        ? (_startDate ?? today)
        : (_endDate ?? (_startDate ?? today));

    await showCalendarDialog(
      context: context,
      selectedDate: _strip(selected),
      minDate: _strip(minDate),
      maxDate: _strip(maxDate),
      isStartDate: isStart,
      onDatePicked: (picked) {
        setState(() {
          if (isStart) {
            _startDate = _strip(picked);
            // 종료일이 시작일보다 앞서면 시작일로 맞춰 줌 (inclusive)
            if (_endDate != null && _endDate!.isBefore(_startDate!)) {
              _endDate = _startDate;
            }
          } else {
            _endDate = _strip(picked);
          }
        });
      },
      // 스테이지 제한일 등 없으니 비워둠
      disabledDates: const [],
    );
  }

  String _fmt(DateTime? d) {
    if (d == null) return "선택하세요";
    return "${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}";
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'kopub'))),
    );
  }

  int _daysBetweenInclusive(DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return e.difference(s).inDays + 1;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    // ✅ 제목 스낵바 검증 (폼 validator 사용 안 함)
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnack("챌린지 제목을 입력해주세요.");
      return;
    }
    if (title.length > 50) {
      _showSnack("제목은 50자 이내로 입력해주세요.");
      return;
    }

    // ⛔️ 폼 밸리데이터 호출 삭제
    // if (!_formKey.currentState!.validate()) return;

    // 도서/기간 스낵바 검증 유지
    if (_selectedBooks.isEmpty) {
      _showSnack("읽을 도서를 한 권 이상 선택해주세요.");
      return;
    }
    if (_startDate == null || _endDate == null) {
      _showSnack("기간을 선택해주세요.");
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      _showSnack("종료일이 시작일보다 빠를 수 없습니다.");
      return;
    }

    // 1) 프리미엄/무료 생성 제한 체크
    final isSubscribed = context.read<UserDataProvider>().isSubscribed;
    final challengeProvider = context.read<ChallengeProvider>();
    final hasActiveCustom = challengeProvider.allChallenges.any(
          (c) => c.isCustom == true && c.isJoined == true && c.isCompleted == false,
    );
    if (!isSubscribed && hasActiveCustom) {
      await _showLimitDialog();
      return;
    }

    // 2) 제목 중복 체크
    if (challengeProvider.hasDuplicateCustomTitle(title)) {
      await _showDuplicateTitleDialog();
      return;
    }

    // 3) 저장 진행
    setState(() => _saving = true);
    try {
      final desc     = _descController.text.trim();
      final imageUrl = _imageFile != null ? _imageFile!.path : 'assets/image/custom_default.png';

      final selectedDays = _daysBetweenInclusive(_startDate!, _endDate!);
      final nowId = 'custom_${DateTime.now().millisecondsSinceEpoch}';

      final challenge = Challenge(
        id: nowId,
        title: title,
        shortDescription: desc.isEmpty ? "사용자 커스텀 챌린지" : desc,
        longDescription: desc.isEmpty ? null : desc,
        stageType: ChallengeStageType.single,
        category: ChallengeCategory.growth,
        method: ChallengeMethod.specificBooks,
        period: ChallengePeriod.daysBased,
        checkMode: ChallengeCheckMode.auto,
        startDate: _startDate,
        endDate: _endDate,
        specificBookMode: SpecificBookMode.userDefined,
        participatingBooks: _selectedBooks,
        requiredBooks: _selectedBooks,
        requiredPages: 1,
        imageUrl: imageUrl,
        goalDisplayText: "페이지 입력으로 진행",
        periodDisplayText: "${selectedDays}일 도전",
        durationOptions: [selectedDays],
        isCustom: true,
        isPremium: false,
        isJoined: true,
        isCompleted: false,
        isRepeatable: false,
        forceBookSelection: true,
        stageDurations: const [],
        attempts: const [],
      );

      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await context.read<ChallengeProvider>().addCustomChallenge(
        userId: uid,
        custom: challenge,
      );

      final savedBooksProvider = context.read<SavedBooksProvider>();
      for (final b in _selectedBooks) {
        final validPageRead = (b.pageRead > 0 && (b.pageCount == null || b.pageRead < b.pageCount!))
            ? b.pageRead : 1;
        await savedBooksProvider.addOrUpdateBook(
          b.copyWith(
            category: 'reading',
            startDate: _startDate,
            pageRead: validPageRead,
          ),
        );
      }

      final updated = context.read<ChallengeProvider>().findChallengeById(nowId);
      if (updated != null && mounted) {
        await _showCheerUpDialog(updated);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ChallengeOngoingScreen(challenge: updated)),
        );
      } else {
        _showSnack("생성한 챌린지를 찾을 수 없습니다.");
      }
    } catch (e) {
      _showSnack("챌린지 생성 중 문제가 발생했습니다.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showLimitDialog() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "생성 제한 안내",
          style: TextStyle(
            fontFamily: 'kopub',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        content: const Text(
          "• 프리미엄 구독 회원: 제한 없이 챌린지 생성 가능\n"
              "• 무료 회원: 동시에 1개만 유지 가능\n\n"
              "현재 진행 중인 ‘커스텀 챌린지’가 있다면 새로 만들 수 없어요.\n"
              "기존 커스텀 챌린지를 완료하거나 포기(실패)하면 다시 만들 수 있어요.",
          style: TextStyle(
            color: Colors.white70,
            fontFamily: 'kopub',
            fontSize: 15,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            child: const Text("확인", style: TextStyle(color: Colors.amberAccent)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showDuplicateTitleDialog() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "제목이 이미 있어요",
          style: TextStyle(fontFamily: 'kopub', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        content: const Text(
          "같은 제목의 사용자 커스텀 챌린지가 이미 존재합니다.\n다른 제목을 입력해 주세요.",
          style: TextStyle(color: Colors.white70, fontFamily: 'kopub', fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            child: const Text("확인", style: TextStyle(color: Colors.amberAccent)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showCheerUpDialog(Challenge updated) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth * 0.035;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop();
        });
        return AlertDialog(
          backgroundColor: Colors.greenAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.deepPurple, size: screenWidth * 0.08),
              SizedBox(width: screenWidth * 0.03),
              Expanded(
                child: Text(
                  "'${updated.title}'\n도전을 시작했습니다!\n응원합니다 💪",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize,
                    fontFamily: 'Kopub',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 20) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF013328),
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text("커스텀 챌린지 생성", style: TextStyle(fontFamily: 'kopub', color: Colors.white)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),

        // ⬇⬇⬇ 여기부터 변경
        body: Stack(
          children: [
            // 스크롤 내용: 하단 버튼 높이만큼 여백 추가(덮이지 않게)
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: w * 0.06, vertical: h * 0.015)
                  .copyWith(bottom: h * 0.15),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ───────── 1) 기본 정보 섹션 ─────────
                    _box(
                      w: w,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle("🔸 기본 정보", w),
                          SizedBox(height: h * 0.014),

                          // (1) 이미지 박스 — 높이를 크게 (예: 120px)
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              height: 120, // 🔼 원하는 높이로 조절 가능
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  if (_imageFile != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        _imageFile!,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.white24,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.add_a_photo, color: Colors.white70, size: 32),
                                    ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Text(
                                      "챌린지 이미지를 등록해보세요 (선택)",
                                      style: TextStyle(color: Colors.white70, fontFamily: 'kopub'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: h * 0.014),

                          // (2) 제목 박스 — 기간 섹션과 동일 스타일 컨테이너 + 보더 없는 TF
                          _uniformBox(
                            child: Row(
                              children: [
                                const Icon(Icons.title, color: Colors.white70),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _titleController,
                                    style: const TextStyle(color: Colors.white, fontFamily: 'kopub'),
                                    cursorColor: Colors.white,
                                    decoration: _flatInputDecoration("챌린지 제목을 입력하세요"),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: h * 0.014),

                          // (3) 설명 박스 — 동일 스타일 + 멀티라인
                          _uniformBox(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 3),
                                  child: Icon(Icons.notes, color: Colors.white70),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _descController,
                                    maxLines: 4,
                                    style: const TextStyle(color: Colors.white, fontFamily: 'kopub'),
                                    cursorColor: Colors.white,
                                    decoration: _flatInputDecoration("챌린지 설명을 입력하세요 (선택)"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: h * 0.018),

                    // ───────── 2) 도서 선택 섹션 ─────────
                    _box(
                      w: w,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle("🔸 도서 선택", w),
                          SizedBox(height: h * 0.014),
                          MultiBookSearchSelectionBox(
                            initialSelectedBooks: _selectedBooks,
                            onBooksChanged: (books) => setState(() => _selectedBooks = books),
                          ),
                          SizedBox(height: h * 0.005),
                          Center(
                            child: const Text(
                              "선택한 도서들의 읽은 페이지 수로 진행됩니다.",
                              style: TextStyle(color: Colors.white54, fontFamily: 'kopub', fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: h * 0.018),

                    // ───────── 3) 챌린지 기간 섹션 ─────────
                    _box(
                      w: w,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle("🔸 챌린지 기간", w),
                          SizedBox(height: h * 0.01),
                          _dateRow(
                            w: w,
                            label: "시작일",
                            value: _fmt(_startDate),
                            onTap: () => _openCalendar(isStart: true),
                          ),
                          SizedBox(height: h * 0.01),
                          _dateRow(
                            w: w,
                            label: "종료일",
                            value: _fmt(_endDate),
                            onTap: () => _openCalendar(isStart: false),
                          ),
                        ],
                      ),
                    ),

                    // ⛔️ 기존 ‘저장 버튼’은 삭제합니다 (하단 고정 버튼으로 대체)
                  ],
                ),
              ),
            ),

            // 하단 고정 버튼
            _buildCreateButton(context, w),
          ],
        ),
        // ⬆⬆⬆ 여기까지 변경
      ),
    );
  }

  Widget _buildCreateButton(BuildContext context, double screenWidth) {
    return Positioned(
      bottom: 30,
      left: screenWidth * 0.05,
      right: screenWidth * 0.05,
      child: ElevatedButton(
        onPressed: _saving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amberAccent,
          disabledBackgroundColor: Colors.amberAccent.withOpacity(0.6),
          padding: EdgeInsets.symmetric(vertical: screenWidth * 0.045),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _saving
            ? SizedBox(
          width: screenWidth * 0.05,
          height: screenWidth * 0.05,
          child: const CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.black)),
        )
            : Text(
          "챌린지 생성하기",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.045,
          ),
        ),
      ),
    );
  }

  // ---------- UI helpers ----------
  Widget _box({required double w, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(w * 0.04),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(w * 0.03),
      ),
      child: child,
    );
  }

  Text _sectionTitle(String text, double w) {
    return Text(
      text,
      style: TextStyle(
          color: Colors.white, fontFamily: 'kopub', fontSize: w * 0.04, fontWeight: FontWeight.bold),
    );
  }

  // 기간 섹션 박스와 동일한 컨테이너
  Widget _uniformBox({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white10,           // 시작/종료일과 동일
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

// 날짜박스 스타일을 그대로 쓰기 위해, 내부 텍스트필드에서 보더/필 제거
  InputDecoration _flatInputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white54, fontFamily: 'kopub'),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    isDense: true,
    contentPadding: EdgeInsets.zero,
  );

  Widget _dateRow({
    required double w,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: w * 0.04),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, color: Colors.white70),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: Colors.white, fontFamily: 'kopub')),
            const Spacer(),
            Text(value, style: const TextStyle(color: Colors.white70, fontFamily: 'kopub')),
          ],
        ),
      ),
    );
  }
}
