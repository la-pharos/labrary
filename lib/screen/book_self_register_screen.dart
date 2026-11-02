import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/service/book_image_service.dart';
import 'package:dayverse_book/widget/calendar_widget.dart';
import 'package:dayverse_book/widget/card_box.dart';
import 'package:dayverse_book/provider/custom_library_provider.dart';

class BookSelfRegisterScreen extends StatefulWidget {
  final String? initialCategory;
  final String? targetCustomLibrary;

  const BookSelfRegisterScreen({
    super.key,
    this.initialCategory,
    this.targetCustomLibrary,
  });

  @override
  State<BookSelfRegisterScreen> createState() =>
      _BookSelfRegisterScreenState();
}

class _BookSelfRegisterScreenState
    extends State<BookSelfRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _publisherController =
  TextEditingController();
  final TextEditingController _isbnController = TextEditingController();
  final TextEditingController _pageCountController =
  TextEditingController();
  final TextEditingController _pageReadController =
  TextEditingController(text: '1');

  XFile? _selectedImage;

  String selectedCategory = 'done';

  DateTime? startDate;
  DateTime? endDate;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    selectedCategory = _resolveInitialCategory();

    if (selectedCategory == 'want') {
      _pageReadController.text = '0';
    } else {
      _pageReadController.text = '1';
    }

    final now = DateTime.now();
    startDate = now;
    endDate = now;
  }

  String _resolveInitialCategory() {
    const validCategories = {
      'done',
      'reading',
      'want',
    };

    final initialCategory = widget.initialCategory;

    if (initialCategory != null &&
        validCategories.contains(initialCategory)) {
      return initialCategory;
    }

    return 'done';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _publisherController.dispose();
    _isbnController.dispose();
    _pageCountController.dispose();
    _pageReadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 10) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF013328),
        appBar: _buildAppBar(screenWidth),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.01,
            ),
            child: Column(
              children: [
                _buildCoverSection(screenWidth),

                SizedBox(height: screenWidth * 0.03),

                _buildBookInfoSection(screenWidth),

                SizedBox(height: screenWidth * 0.03),

                _buildRegisterSection(screenWidth),

                SizedBox(height: screenHeight * 0.1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 앱바
  PreferredSizeWidget _buildAppBar(double screenWidth) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back,
          color: Colors.white,
        ),
        onPressed: _isSaving
            ? null
            : () {
          Navigator.pop(context);
        },
      ),
      title: Text(
        '책 직접 등록하기',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'kopub',
          fontSize: screenWidth * 0.045,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : _saveBook,
          child: _isSaving
              ? SizedBox(
            width: screenWidth * 0.045,
            height: screenWidth * 0.045,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : Text(
            '저장',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(width: screenWidth * 0.02),
      ],
    );
  }

  /// 책 표지 선택 카드
  Widget _buildCoverSection(double screenWidth) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.image_outlined,
            title: '책 표지',
            screenWidth: screenWidth,
          ),

          SizedBox(height: screenWidth * 0.04),

          _buildFieldLabel(
            label: '책 이미지',
            screenWidth: screenWidth,
            requiredField: true,
          ),

          SizedBox(height: screenWidth * 0.02),

          Center(
            child: SizedBox(
              width: screenWidth * 0.58,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isSaving ? null : _pickBookImage,
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 1 / 1.4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _selectedImage == null
                              ? Colors.white.withOpacity(0.08)
                              : Colors.white.withOpacity(0.15),
                        ),
                      ),
                      child: _selectedImage != null
                          ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Image.file(
                              File(_selectedImage!.path),
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
                                  SizedBox(
                                    width: screenWidth * 0.012,
                                  ),
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

                          Positioned(
                            bottom: screenWidth * 0.025,
                            right: screenWidth * 0.025,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isSaving
                                    ? null
                                    : () {
                                  setState(() {
                                    _selectedImage = null;
                                  });
                                },
                                borderRadius:
                                BorderRadius.circular(20),
                                child: Container(
                                  width: screenWidth * 0.09,
                                  height: screenWidth * 0.09,
                                  decoration: BoxDecoration(
                                    color:
                                    Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.white,
                                    size: screenWidth * 0.045,
                                  ),
                                ),
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
                            '책 표지 추가',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'kopub',
                              fontSize: screenWidth * 0.034,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: screenWidth * 0.01),

                          Text(
                            '세로형 이미지가 가장 잘 보여요.',
                            textAlign: TextAlign.center,
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
            ),
          ),
          SizedBox(height: screenWidth * 0.02),

        ],
      ),
    );
  }

  /// 직접 입력할 책 정보
  Widget _buildBookInfoSection(double screenWidth) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.edit_note_rounded,
            title: '책 정보 입력',
            screenWidth: screenWidth,
          ),

          SizedBox(height: screenWidth * 0.04),

          _buildInputField(
            controller: _titleController,
            label: '제목',
            hintText: '책 제목을 입력하세요',
            screenWidth: screenWidth,
            requiredField: true,
            textInputAction: TextInputAction.next,
          ),

          SizedBox(height: screenWidth * 0.03),

          _buildInputField(
            controller: _authorController,
            label: '지은이',
            hintText: '지은이를 입력하세요',
            screenWidth: screenWidth,
            requiredField: true,
            textInputAction: TextInputAction.next,
          ),

          SizedBox(height: screenWidth * 0.03),

          _buildInputField(
            controller: _pageCountController,
            label: '총 페이지',
            hintText: '총 페이지 수를 입력하세요',
            screenWidth: screenWidth,
            requiredField: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 5,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            validator: _validatePageCount,
            onChanged: (_) {
              setState(() {});

              final totalPage =
                  int.tryParse(_pageCountController.text.trim()) ?? 0;

              if (selectedCategory == 'reading' && totalPage > 1) {
                final currentPage =
                    int.tryParse(_pageReadController.text.trim()) ?? 1;

                if (currentPage >= totalPage) {
                  _pageReadController.text = (totalPage - 1).toString();
                }
              }
            },
          ),

          SizedBox(height: screenWidth * 0.03),

          _buildInputField(
            controller: _publisherController,
            label: '출판사',
            hintText: '출판사를 알고 있다면 입력하세요',
            screenWidth: screenWidth,
            requiredField: false,
            textInputAction: TextInputAction.next,
          ),

          SizedBox(height: screenWidth * 0.03),

          _buildInputField(
            controller: _isbnController,
            label: 'ISBN',
            hintText: 'ISBN을 알고 있다면 입력하세요',
            screenWidth: screenWidth,
            requiredField: false,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.characters,
            maxLength: 17,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'[0-9Xx-]'),
              ),
            ],
            validator: _validateIsbn,
          ),

          SizedBox(height: screenWidth * 0.03),

        ],
      ),
    );
  }

  Widget _buildFieldLabel({
    required String label,
    required double screenWidth,
    bool requiredField = false,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.033,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (requiredField) ...[
          SizedBox(width: screenWidth * 0.01),
          Text(
            '*',
            style: TextStyle(
              color: Colors.amberAccent,
              fontSize: screenWidth * 0.035,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required double screenWidth,
    bool requiredField = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(
          label: label,
          screenWidth: screenWidth,
          requiredField: requiredField,
        ),

        SizedBox(height: screenWidth * 0.015),

        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.035,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.055),
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.white30,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.033,
            ),
            counterText: '',
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
              borderSide: const BorderSide(
                color: Colors.amberAccent,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.redAccent,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.redAccent,
              ),
            ),
            errorStyle: TextStyle(
              color: Colors.redAccent.shade100,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.029,
            ),
          ),
          validator: validator ??
                  (value) {
                if (!requiredField) {
                  return null;
                }

                if (value == null || value.trim().isEmpty) {
                  return '$label을(를) 입력해주세요.';
                }

                return null;
              },
        ),
      ],
    );
  }

  /// 카테고리 및 날짜
  Widget _buildRegisterSection(double screenWidth) {
    final pageCount =
        int.tryParse(_pageCountController.text.trim()) ?? 0;

    final maxPage = pageCount > 1 ? pageCount - 1 : 1;

    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.library_add_outlined,
            title: '책 등록',
            screenWidth: screenWidth,
          ),

          SizedBox(height: screenWidth * 0.04),

          _buildCategorySelector(screenWidth),

          if (selectedCategory == 'done' ||
              selectedCategory == 'reading') ...[
            SizedBox(height: screenWidth * 0.04),

            if (selectedCategory == 'done')
              _buildDateSelector(screenWidth)
            else
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        showCalendarDialog(
                          context: context,
                          selectedDate:
                          startDate ?? DateTime.now(),
                          minDate: DateTime(2000),
                          maxDate: DateTime.now(),
                          onDatePicked: (picked) {
                            setState(() {
                              startDate = picked;
                            });
                          },
                          isStartDate: true,
                        );
                      },
                      child: _buildDateCard(
                        '시작일',
                        startDate ?? DateTime.now(),
                        screenWidth,
                      ),
                    ),
                  ),

                  SizedBox(width: screenWidth * 0.02),

                  Expanded(
                    child: _buildPageInputCard(
                      screenWidth,
                      maxPage,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required double screenWidth,
  }) {
    return Row(
      children: [
        Container(
          width: screenWidth * 0.085,
          height: screenWidth * 0.085,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Colors.white70,
            size: screenWidth * 0.05,
          ),
        ),

        SizedBox(width: screenWidth * 0.025),

        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: screenWidth * 0.04,
            fontWeight: FontWeight.bold,
            fontFamily: 'kopub',
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector(double screenWidth) {
    return Row(
      children: [
        _categoryButton(
          '읽은 책',
          'done',
          screenWidth,
        ),
        _categoryButton(
          '읽는 중인 책',
          'reading',
          screenWidth,
        ),
        _categoryButton(
          '읽을 예정인 책',
          'want',
          screenWidth,
        ),
      ],
    );
  }

  Widget _categoryButton(
      String title,
      String value,
      double screenWidth,
      ) {
    final isSelected = selectedCategory == value;

    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.008,
        ),
        child: Material(
          color: isSelected
              ? Colors.amberAccent
              : Colors.white.withOpacity(0.055),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () {
              setState(() {
                selectedCategory = value;

                if (value == 'want') {
                  _pageReadController.text = '0';
                } else if (_pageReadController.text == '0') {
                  _pageReadController.text = '1';
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: screenWidth * 0.03,
                horizontal: screenWidth * 0.01,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Colors.amberAccent
                      : Colors.white.withOpacity(0.07),
                ),
              ),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF013328)
                      : Colors.white70,
                  fontFamily: 'kopub',
                  fontWeight: FontWeight.bold,
                  fontSize: screenWidth * 0.032,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(double screenWidth) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              showCalendarDialog(
                context: context,
                selectedDate: startDate ?? DateTime.now(),
                minDate: DateTime(2000),
                maxDate: DateTime.now(),
                onDatePicked: (picked) {
                  setState(() {
                    startDate = picked;

                    if (endDate != null &&
                        endDate!.isBefore(startDate!)) {
                      endDate = startDate;
                    }
                  });
                },
                isStartDate: true,
              );
            },
            child: _buildDateCard(
              '시작일',
              startDate ?? DateTime.now(),
              screenWidth,
            ),
          ),
        ),

        SizedBox(width: screenWidth * 0.02),

        Expanded(
          child: GestureDetector(
            onTap: () {
              showCalendarDialog(
                context: context,
                selectedDate: endDate ?? DateTime.now(),
                minDate: startDate ?? DateTime(2000),
                maxDate: DateTime.now(),
                onDatePicked: (picked) {
                  setState(() {
                    endDate = picked;
                  });
                },
                isStartDate: false,
              );
            },
            child: _buildDateCard(
              '종료일',
              endDate ?? DateTime.now(),
              screenWidth,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateCard(
      String label,
      DateTime date,
      double screenWidth,
      ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.025,
        vertical: screenWidth * 0.025,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
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
              color: Colors.white60,
              fontSize: screenWidth * 0.032,
              fontFamily: 'kopub',
            ),
          ),

          SizedBox(height: screenWidth * 0.015),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                color: Colors.white54,
                size: screenWidth * 0.038,
              ),
              SizedBox(width: screenWidth * 0.015),
              Text(
                DateFormat('yy/MM/dd').format(date),
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.037,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageInputCard(
      double screenWidth,
      int maxPage,
      ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.025,
        vertical: screenWidth * 0.025,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Column(
        children: [
          Text(
            '읽은 페이지',
            style: TextStyle(
              color: Colors.white60,
              fontSize: screenWidth * 0.032,
              fontFamily: 'kopub',
            ),
          ),

          SizedBox(height: screenWidth * 0.012),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: TextField(
                  controller: _pageReadController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 5,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize: screenWidth * 0.04,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    final entered = int.tryParse(value);

                    if (entered == null || value.isEmpty) {
                      return;
                    }

                    if (entered < 1 || entered > maxPage) {
                      final clamped =
                      entered.clamp(1, maxPage);

                      _pageReadController.text =
                          clamped.toString();

                      _pageReadController.selection =
                          TextSelection.collapsed(
                            offset: _pageReadController.text.length,
                          );
                    }
                  },
                ),
              ),
              Text(
                '쪽',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: screenWidth * 0.032,
                  fontFamily: 'kopub',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickBookImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (image == null || !mounted) {
        return;
      }

      setState(() {
        _selectedImage = image;
      });
    } catch (e) {
      debugPrint('책 이미지 선택 실패: $e');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이미지를 불러오지 못했습니다.'),
        ),
      );
    }
  }

  String? _validateIsbn(String? value) {
    final isbn = (value ?? '')
        .replaceAll('-', '')
        .replaceAll(' ', '')
        .trim()
        .toUpperCase();

    // ISBN은 선택 입력
    if (isbn.isEmpty) {
      return null;
    }

    final isbn10Pattern = RegExp(r'^[0-9]{9}[0-9X]$');
    final isbn13Pattern = RegExp(r'^[0-9]{13}$');

    if (!isbn10Pattern.hasMatch(isbn) &&
        !isbn13Pattern.hasMatch(isbn)) {
      return 'ISBN은 10자리 또는 13자리여야 합니다.';
    }

    return null;
  }

  String? _validatePageCount(String? value) {
    final pageCount = int.tryParse(value?.trim() ?? '');

    if (pageCount == null) {
      return '총 페이지 수를 입력해주세요.';
    }

    if (pageCount < 1) {
      return '총 페이지 수는 1 이상이어야 합니다.';
    }

    return null;
  }

  Future<void> _saveBook() async {
    FocusScope.of(context).unfocus();

    if (_isSaving) {
      return;
    }

    final isValid =
        _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('책 표지를 선택해주세요.'),
        ),
      );
      return;
    }

    if (selectedCategory == 'done' &&
        startDate != null &&
        endDate != null &&
        endDate!.isBefore(startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('종료일은 시작일보다 빠를 수 없습니다.'),
        ),
      );
      return;
    }

    final totalPage =
    int.parse(_pageCountController.text.trim());

    final inputPage =
        int.tryParse(_pageReadController.text.trim()) ?? 1;

    final int pageRead;

    switch (selectedCategory) {
      case 'done':
        pageRead = totalPage;
        break;

      case 'reading':
        if (totalPage <= 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '총 페이지가 1쪽인 책은 읽는 중으로 등록할 수 없습니다.',
              ),
            ),
          );
          return;
        }

        pageRead = inputPage.clamp(
          1,
          totalPage - 1,
        );
        break;

      case 'want':
      default:
        pageRead = 0;
        break;
    }

    setState(() {
      _isSaving = true;
    });

    String? uploadedImageUrl;

    try {
      final provider = context.read<SavedBooksProvider>();

      final normalizedIsbn = _isbnController.text
          .replaceAll('-', '')
          .replaceAll(' ', '')
          .trim()
          .toUpperCase();

      /*
     * 먼저 이미지 업로드 전에 임시 모델을 만들어
     * 동일한 ISBN·제목·저자의 책이 이미 있는지 검사한다.
     */
      final duplicateCheckBook = BookModel.selfRegistered(
        title: _titleController.text,
        author: _authorController.text,
        publisher: _publisherController.text,
        isbn: normalizedIsbn,
        pageCount: totalPage,
        imageUrl: '',
        category: selectedCategory,
        startDate:
        selectedCategory == 'done' ||
            selectedCategory == 'reading'
            ? startDate
            : null,
        endDate:
        selectedCategory == 'done'
            ? endDate
            : null,
        pageRead: pageRead,
      );

      if (provider.containsBookId(duplicateCheckBook.id)) {
        if (!mounted) {
          return;
        }

        _showDuplicateDialog(
          duplicateCheckBook.title,
        );
        return;
      }

      uploadedImageUrl =
      await BookImageService.uploadSelfRegisteredBookCover(
        imageFile: File(_selectedImage!.path),
      );

      final newBook = BookModel.selfRegistered(
        title: _titleController.text,
        author: _authorController.text,
        publisher: _publisherController.text,
        isbn: normalizedIsbn,
        pageCount: totalPage,
        imageUrl: uploadedImageUrl,
        category: selectedCategory,
        startDate:
        selectedCategory == 'done' ||
            selectedCategory == 'reading'
            ? startDate
            : null,
        endDate:
        selectedCategory == 'done'
            ? endDate
            : null,
        pageRead: pageRead,
      );

      await provider.addSelfRegisteredBook(newBook);

      final targetCustomLibrary =
      widget.targetCustomLibrary?.trim();

      if (targetCustomLibrary != null &&
          targetCustomLibrary.isNotEmpty) {
        final customLibraryProvider =
        context.read<CustomLibraryProvider>();

        await provider.addBookToCustomLibrary(
          newBook.id,
          targetCustomLibrary,
          customLibraryProvider:
          customLibraryProvider,
        );
      }

      if (!mounted) {
        return;
      }

      await _showBookSavedDialog(newBook);

      if (!mounted) {
        return;
      }

      Navigator.pop(context, newBook);
    } catch (e) {
      debugPrint('직접 등록 실패: $e');

      /*
     * 이미지 업로드는 성공했지만 Firestore 저장이 실패한 경우
     * Storage에 남은 고아 이미지를 정리한다.
     */
      if (uploadedImageUrl != null) {
        try {
          await BookImageService.deleteBookCover(
            uploadedImageUrl,
          );
        } catch (deleteError) {
          debugPrint(
            '업로드된 표지 정리 실패: $deleteError',
          );
        }
      }

      if (!mounted) {
        return;
      }

      final message = e is StateError &&
          e.message == '이미 등록된 책입니다.'
          ? '이미 등록된 책입니다.'
          : '책을 등록하지 못했습니다.';

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showDuplicateDialog(String title) {
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.redAccent.shade100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              screenWidth * 0.025,
            ),
          ),
          title: Text(
            '이미 등록된 책입니다!',
            style: TextStyle(
              color: Colors.black,
              fontFamily: 'kopub',
              fontWeight: FontWeight.bold,
              fontSize: screenWidth * 0.045,
            ),
          ),
          content: Text(
            '『$title』은(는) 이미 등록된 책이에요!',
            style: TextStyle(
              color: Colors.black87,
              fontFamily: 'kopub',
              fontWeight: FontWeight.w500,
              fontSize: screenWidth * 0.035,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                '확인',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.04,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showBookSavedDialog(
      BookModel book,
      ) async {
    final screenWidth = MediaQuery.of(context).size.width;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Future.delayed(
          const Duration(milliseconds: 1300),
              () {
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
          },
        );

        return AlertDialog(
          backgroundColor: Colors.amberAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              screenWidth * 0.025,
            ),
          ),
          content: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  screenWidth * 0.015,
                ),
                child: Image.network(
                  book.imageUrl ?? '',
                  width: screenWidth * 0.13,
                  height: screenWidth * 0.18,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      width: screenWidth * 0.13,
                      height: screenWidth * 0.18,
                      color: Colors.grey,
                      child: const Icon(
                        Icons.book,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
              SizedBox(width: screenWidth * 0.03),
              Flexible(
                child: Text(
                  '『${book.title}』\n책이 등록되었습니다!',
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    fontFamily: 'kopub',
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}
