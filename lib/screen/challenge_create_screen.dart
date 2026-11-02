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
import 'package:dayverse_book/widget/calendar_widget.dart';
import 'package:dayverse_book/screen/challenge_ongoing_screen.dart'; // 네 경로에 맞춰서
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:dayverse_book/widget/multi_book_search_dialog.dart';
import 'package:dayverse_book/widget/card_box.dart';

class ChallengeCreateScreen extends StatefulWidget {
  const ChallengeCreateScreen({super.key});

  @override
  State<ChallengeCreateScreen> createState() => _ChallengeCreateScreenState();
}

class _ChallengeCreateScreenState extends State<ChallengeCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _shortDescController = TextEditingController();
  final _longDescController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  File? _imageFile;

  // ✅ 단일 → 여러 권
  List<BookModel> _selectedBooks = [];

  bool _saving = false;
  String _savingText = "챌린지 생성하기"; // 👈 추가

  // ---------- actions ----------
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1200,
    );

    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
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

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnack("챌린지 제목을 입력해주세요.");
      return;
    }
    if (title.length > 50) {
      _showSnack("제목은 50자 이내로 입력해주세요.");
      return;
    }

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

    final isPremium = context.read<UserDataProvider>().isPremiumActive;
    final challengeProvider = context.read<ChallengeProvider>();
    final hasActiveCustom = challengeProvider.allChallenges.any(
          (c) => c.isCustom == true && c.isJoined == true && c.isCompleted == false,
    );

    if (!isPremium && hasActiveCustom) {
      await _showLimitDialog();
      return;
    }

    if (challengeProvider.hasDuplicateCustomTitle(title)) {
      await _showDuplicateTitleDialog();
      return;
    }

    setState(() {
      _saving = true;
      _savingText = "이미지 준비 중...";
    });

    try {
      final shortDesc = _shortDescController.text.trim();
      final longDesc = _longDescController.text.trim();

      final selectedDays = _daysBetweenInclusive(_startDate!, _endDate!);
      final nowId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      setState(() => _savingText = "이미지 업로드 중...");

      final imageUrl = _imageFile != null
          ? await _uploadChallengeImageToStorage(
        userId: uid,
        sourceFile: _imageFile!,
        challengeId: nowId,
      )
          : 'assets/image/custom_default.png';

      setState(() => _savingText = "챌린지 생성 중...");

      final challenge = Challenge(
        id: nowId,
        title: title,
        shortDescription: shortDesc.isEmpty ? "사용자 커스텀 챌린지" : shortDesc,
        longDescription: longDesc.isEmpty ? null : longDesc,
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

      await context.read<ChallengeProvider>().addCustomChallenge(
        userId: uid,
        custom: challenge,
      );

      setState(() => _savingText = "도서 정보 저장 중...");

      final savedBooksProvider = context.read<SavedBooksProvider>();
      for (final b in _selectedBooks) {
        final validPageRead =
        (b.pageRead > 0 && (b.pageCount == null || b.pageRead < b.pageCount!))
            ? b.pageRead
            : 1;

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
          MaterialPageRoute(
            builder: (_) => ChallengeOngoingScreen(challenge: updated),
          ),
        );
      } else {
        _showSnack("생성한 챌린지를 찾을 수 없습니다.");
      }
    } catch (e, stack) {
      debugPrint('❌ 커스텀 챌린지 생성 실패: $e');
      debugPrint('❌ stack: $stack');

      if (e is FirebaseException) {
        debugPrint('❌ Firebase code: ${e.code}');
        debugPrint('❌ Firebase message: ${e.message}');
        _showSnack("이미지 업로드 실패: ${e.code}");
      } else {
        _showSnack("챌린지 생성 중 문제가 발생했습니다.");
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _savingText = "챌린지 생성하기";
        });
      }
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
          "• 프리미엄 구독 회원: 챌린지 생성 무제한\n"
              "• 무료 회원: 동시에 1개만 유지 가능\n\n"
              "현재 진행 중인 ‘커스텀 챌린지’가 있다면 \n새로 만들 수 없어요.\n\n"
              "기존 커스텀 챌린지를 완료하거나 \n포기(실패)하면 다시 만들 수 있어요.",
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

  Future<void> _showCheerUpDialog(
      Challenge updated,
      ) async {
    final screenWidth =
        MediaQuery.of(context).size.width;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Future.delayed(
          const Duration(milliseconds: 1600),
              () {
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
          },
        );

        return AlertDialog(
          backgroundColor: const Color(0xFF16483F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          contentPadding: EdgeInsets.all(
            screenWidth * 0.055,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: screenWidth * 0.16,
                height: screenWidth * 0.16,
                decoration: BoxDecoration(
                  color:
                  Colors.amberAccent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.emoji_events_outlined,
                  color: Colors.amberAccent,
                  size: screenWidth * 0.08,
                ),
              ),

              SizedBox(height: screenWidth * 0.035),

              Text(
                '챌린지를 시작했어요!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.041,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: screenWidth * 0.018),

              Text(
                '‘${updated.title}’\n끝까지 완주해보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.033,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openMultiBookSearchDialog() async {
    final selectedBooks =
    await showDialog<List<BookModel>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MultiBookSearchDialog(
        initialSelectedBooks: _selectedBooks,
      ),
    );

    if (!mounted || selectedBooks == null) {
      return;
    }

    setState(() {
      _selectedBooks = selectedBooks;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _shortDescController.dispose();
    _longDescController.dispose();
    super.dispose();
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
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
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            '커스텀 챌린지 만들기',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                left: screenWidth * 0.04,
                right: screenWidth * 0.04,
                top: screenWidth * 0.025,
                bottom: screenHeight * 0.16 + bottomSafeArea,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildBasicInfoCard(screenWidth),

                    SizedBox(height: screenWidth * 0.03),

                    _buildBookSelectionCard(screenWidth),

                    SizedBox(height: screenWidth * 0.03),

                    _buildPeriodCard(screenWidth),

                    SizedBox(height: screenHeight * 0.03),
                  ],
                ),
              ),
            ),

            _buildCreateButton(
              context,
              screenWidth,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard(double screenWidth) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.tune_rounded,
            title: '기본 정보',
            description: '나만의 챌린지를 소개해주세요.',
            screenWidth: screenWidth,
          ),

          SizedBox(height: screenWidth * 0.045),

          _buildImageSelector(screenWidth),

          SizedBox(height: screenWidth * 0.04),

          _buildLabeledField(
            label: '챌린지 제목',
            required: true,
            screenWidth: screenWidth,
            child: TextFormField(
              controller: _titleController,
              maxLength: 50,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.035,
              ),
              cursorColor: Colors.amberAccent,
              decoration: _inputDecoration(
                hint: '예: 한 달에 책 3권 읽기',
                screenWidth: screenWidth,
              ).copyWith(
                counterText: '',
              ),
            ),
          ),

          SizedBox(height: screenWidth * 0.035),

          _buildLabeledField(
            label: '한 줄 소개',
            screenWidth: screenWidth,
            child: TextFormField(
              controller: _shortDescController,
              maxLines: 2,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.035,
              ),
              cursorColor: Colors.amberAccent,
              decoration: _inputDecoration(
                hint: '챌린지를 짧게 소개해주세요.',
                screenWidth: screenWidth,
              ),
            ),
          ),

          SizedBox(height: screenWidth * 0.035),

          _buildLabeledField(
            label: '상세 설명',
            screenWidth: screenWidth,
            child: TextFormField(
              controller: _longDescController,
              minLines: 4,
              maxLines: 6,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.035,
                height: 1.5,
              ),
              cursorColor: Colors.amberAccent,
              decoration: _inputDecoration(
                hint: '도전 이유, 목표, 진행 방법 등을 자유롭게 작성해주세요.',
                screenWidth: screenWidth,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String description,
    required double screenWidth,
  }) {
    return Row(
      children: [
        Container(
          width: screenWidth * 0.09,
          height: screenWidth * 0.09,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            color: Colors.white70,
            size: screenWidth * 0.05,
          ),
        ),

        SizedBox(width: screenWidth * 0.025),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.04,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: screenWidth * 0.006),

              Text(
                description,
                style: TextStyle(
                  color: Colors.white54,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.029,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageSelector(double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '대표 이미지',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.033,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: screenWidth * 0.015),
            Text(
              '선택',
              style: TextStyle(
                color: Colors.white38,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.029,
              ),
            ),
          ],
        ),

        SizedBox(height: screenWidth * 0.02),

        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _saving ? null : _pickImage,
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _imageFile == null
                        ? Colors.white.withOpacity(0.08)
                        : Colors.white.withOpacity(0.15),
                  ),
                ),
                child: _imageFile != null
                    ? Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.file(
                        _imageFile!,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),

                    Positioned(
                      top: screenWidth * 0.025,
                      right: screenWidth * 0.025,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.025,
                          vertical: screenWidth * 0.015,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: screenWidth * 0.035,
                            ),
                            SizedBox(width: screenWidth * 0.012),
                            Text(
                              '변경',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'kopub',
                                fontSize: screenWidth * 0.028,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: screenWidth * 0.14,
                      height: screenWidth * 0.14,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        color: Colors.white54,
                        size: screenWidth * 0.065,
                      ),
                    ),

                    SizedBox(height: screenWidth * 0.025),

                    Text(
                      '대표 이미지 추가',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'kopub',
                        fontSize: screenWidth * 0.034,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: screenWidth * 0.01),

                    Text(
                      '정사각형 이미지가 가장 잘 보여요.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontFamily: 'kopub',
                        fontSize: screenWidth * 0.028,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateButton(
      BuildContext context,
      double screenWidth,
      ) {
    final bottomSafeArea =
        MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: screenWidth * 0.04,
          right: screenWidth * 0.04,
          top: screenWidth * 0.06,
          bottom: bottomSafeArea + screenWidth * 0.035,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              const Color(0xFF013328).withOpacity(0),
              const Color(0xFF013328),
            ],
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: Colors.amberAccent,
              disabledBackgroundColor:
              Colors.amberAccent.withOpacity(0.55),
              padding: EdgeInsets.symmetric(
                vertical: screenWidth * 0.043,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _saving
                ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: screenWidth * 0.04,
                  height: screenWidth * 0.04,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF013328),
                  ),
                ),
                SizedBox(width: screenWidth * 0.025),
                Text(
                  _savingText,
                  style: TextStyle(
                    color: const Color(0xFF013328),
                    fontFamily: 'kopub',
                    fontSize: screenWidth * 0.038,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
                : Text(
              '챌린지 생성하기',
              style: TextStyle(
                color: const Color(0xFF013328),
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabeledField({
    required String label,
    required double screenWidth,
    required Widget child,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.033,
                fontWeight: FontWeight.bold,
              ),
            ),

            if (required) ...[
              SizedBox(width: screenWidth * 0.01),
              Text(
                '*',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: screenWidth * 0.035,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else ...[
              SizedBox(width: screenWidth * 0.015),
              Text(
                '선택',
                style: TextStyle(
                  color: Colors.white38,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.028,
                ),
              ),
            ],
          ],
        ),

        SizedBox(height: screenWidth * 0.018),

        child,
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required double screenWidth,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.white38,
        fontFamily: 'kopub',
        fontSize: screenWidth * 0.032,
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.035,
        vertical: screenWidth * 0.035,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.amberAccent.withOpacity(0.65),
          width: 1.2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
    );
  }

  Widget _buildBookSelectionCard(double screenWidth) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.library_books_outlined,
            title: '도서 선택',
            description: '챌린지에서 읽을 책을 선택해주세요.',
            screenWidth: screenWidth,
          ),

          SizedBox(height: screenWidth * 0.04),

          _buildBookSelectionBox(screenWidth),

          if (_selectedBooks.isNotEmpty) ...[
            SizedBox(height: screenWidth * 0.01),

            Center(
              child: Text(
                '선택한 책의 읽은 페이지를 기준으로 진행돼요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.028,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBookSelectionBox(double screenWidth) {
    final hasBooks = _selectedBooks.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _saving ? null : _openMultiBookSearchDialog,
            borderRadius: BorderRadius.circular(13),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(screenWidth * 0.035),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: screenWidth * 0.105,
                    height: screenWidth * 0.105,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      hasBooks
                          ? Icons.library_books_rounded
                          : Icons.add_rounded,
                      color: Colors.white70,
                      size: screenWidth * 0.055,
                    ),
                  ),

                  SizedBox(width: screenWidth * 0.03),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasBooks
                              ? '선택한 도서 ${_selectedBooks.length}권'
                              : '도서 검색 및 선택',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'kopub',
                            fontSize: screenWidth * 0.035,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(height: screenWidth * 0.01),

                        Text(
                          hasBooks
                              ? '눌러서 책을 추가하거나 변경하세요.'
                              : '여러 권을 한 번에 선택할 수 있어요.',
                          style: TextStyle(
                            color: Colors.white54,
                            fontFamily: 'kopub',
                            fontSize: screenWidth * 0.029,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white38,
                    size: screenWidth * 0.06,
                  ),
                ],
              ),
            ),
          ),
        ),

        if (hasBooks) ...[
          SizedBox(height: screenWidth * 0.025),

          ..._selectedBooks.map(
                (book) => _buildSelectedBookRow(
              book,
              screenWidth,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectedBookRow(
      BookModel book,
      double screenWidth,
      ) {
    final imageWidth = screenWidth * 0.125;
    final imageHeight = imageWidth * 1.4;
    final imageUrl = book.imageUrl?.trim() ?? '';

    final publisher = book.publisher?.trim() ?? '';

    final detailText = [
      if (book.author.trim().isNotEmpty) book.author,
      if (publisher.isNotEmpty) publisher,
    ].join(' · ');

    return Container(
      margin: EdgeInsets.only(
        bottom: screenWidth * 0.02,
      ),
      padding: EdgeInsets.all(screenWidth * 0.025),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: imageWidth,
            height: imageHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 7,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                imageUrl,
                width: imageWidth,
                height: imageHeight,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return _selectedBookPlaceholder(
                    imageWidth,
                    imageHeight,
                  );
                },
              )
                  : _selectedBookPlaceholder(
                imageWidth,
                imageHeight,
              ),
            ),
          ),

          SizedBox(width: screenWidth * 0.03),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize: screenWidth * 0.033,
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                  ),
                ),

                if (detailText.isNotEmpty) ...[
                  SizedBox(height: screenWidth * 0.012),
                  Text(
                    detailText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white54,
                      fontFamily: 'kopub',
                      fontSize: screenWidth * 0.028,
                    ),
                  ),
                ],

                if (book.pageCount > 0) ...[
                  SizedBox(height: screenWidth * 0.008),
                  Text(
                    '총 ${book.pageCount}쪽',
                    style: TextStyle(
                      color: Colors.white38,
                      fontFamily: 'kopub',
                      fontSize: screenWidth * 0.026,
                    ),
                  ),
                ],
              ],
            ),
          ),

          IconButton(
            tooltip: '도서 제외',
            onPressed: _saving
                ? null
                : () => _removeSelectedBook(book),
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  void _removeSelectedBook(BookModel book) {
    setState(() {
      final itemId = (book.itemId ?? '').trim();

      _selectedBooks.removeWhere((selected) {
        final selectedItemId =
        (selected.itemId ?? '').trim();

        if (itemId.isNotEmpty &&
            selectedItemId.isNotEmpty) {
          return itemId == selectedItemId;
        }

        return selected.title == book.title &&
            selected.author == book.author;
      });
    });
  }

  Widget _buildPeriodCard(double screenWidth) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.calendar_month_outlined,
            title: '챌린지 기간',
            description: '도전을 진행할 기간을 설정해주세요.',
            screenWidth: screenWidth,
          ),

          SizedBox(height: screenWidth * 0.04),

          Row(
            children: [
              Expanded(
                child: _buildDateCard(
                  label: '시작일',
                  value: _fmt(_startDate),
                  isSelected: _startDate != null,
                  onTap: () => _openCalendar(isStart: true),
                  screenWidth: screenWidth,
                ),
              ),

              SizedBox(width: screenWidth * 0.02),

              Expanded(
                child: _buildDateCard(
                  label: '종료일',
                  value: _fmt(_endDate),
                  isSelected: _endDate != null,
                  onTap: () => _openCalendar(isStart: false),
                  screenWidth: screenWidth,
                ),
              ),
            ],
          ),

          if (_startDate != null && _endDate != null) ...[
            SizedBox(height: screenWidth * 0.03),

            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.035,
                vertical: screenWidth * 0.025,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.045),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.flag_outlined,
                    color: Colors.white54,
                    size: screenWidth * 0.04,
                  ),
                  SizedBox(width: screenWidth * 0.015),
                  Text(
                    '총 ${_daysBetweenInclusive(_startDate!, _endDate!)}일 동안 도전해요.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'kopub',
                      fontSize: screenWidth * 0.031,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateCard({
    required String label,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
    required double screenWidth,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _saving ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.025,
            vertical: screenWidth * 0.03,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.07),
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white54,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.03,
                ),
              ),

              SizedBox(height: screenWidth * 0.018),

              Icon(
                Icons.calendar_today_outlined,
                color: isSelected
                    ? Colors.white70
                    : Colors.white38,
                size: screenWidth * 0.045,
              ),

              SizedBox(height: screenWidth * 0.018),

              Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Colors.white38,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.032,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectedBookPlaceholder(
      double width,
      double height,
      ) {
    return Container(
      width: width,
      height: height,
      color: Colors.white12,
      child: const Icon(
        Icons.menu_book_rounded,
        color: Colors.white54,
      ),
    );
  }

  Future<String> _uploadChallengeImageToStorage({
    required String userId,
    required File sourceFile,
    required String challengeId,
  }) async {
    if (userId.isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }

    final ext = sourceFile.path.contains('.')
        ? sourceFile.path.split('.').last.toLowerCase()
        : 'jpg';

    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      _ => 'image/jpeg',
    };

    final ref = FirebaseStorage.instance
        .ref()
        .child('users')
        .child(userId)
        .child('custom_challenges')
        .child('$challengeId.$ext');

    final uploadTask = await ref.putFile(
      sourceFile,
      SettableMetadata(contentType: contentType),
    );

    return await uploadTask.ref.getDownloadURL();
  }

}
