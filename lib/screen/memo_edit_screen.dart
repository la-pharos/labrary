import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/model/memo_model.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/widget/card_box.dart';
import 'package:dayverse_book/widget/ad_banner_placeholder.dart';
import 'package:dayverse_book/screen/share_note_screen.dart';
import 'package:dayverse_book/service/text_recognition_service.dart';
import 'dart:io';
import 'package:dayverse_book/screen/book_detail_screen.dart';

class MemoEditScreen extends StatefulWidget {
  final BookModel book;
  final MemoModel? memo;
  final bool openedFromBookDetail;

  const MemoEditScreen({
    super.key,
    required this.book,
    this.memo,
    this.openedFromBookDetail = false,
  });

  @override
  State<MemoEditScreen> createState() => _MemoEditScreenState();
}

class _MemoEditScreenState extends State<MemoEditScreen> {
  final TextEditingController _contentController = TextEditingController();

  final FocusNode _contentFocusNode = FocusNode();

  final ImagePicker _imagePicker = ImagePicker();

  final TextRecognitionService _textRecognitionService =
      TextRecognitionService();

  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isExtractingText = false;

  late final String _initialContent;
  late final List<String> _initialImageUrls;

  bool get _isEditMode => widget.memo != null;

  bool get _isBusy => _isSaving || _isDeleting || _isExtractingText;


  @override
  void initState() {
    super.initState();

    _initialContent = widget.memo?.content ?? '';
    _initialImageUrls = List<String>.from(
      widget.memo?.imageUrls ?? const [],
    );

    _contentController.text = _initialContent;

    _contentController.addListener(
      _handleContentChanged,
    );

    _contentFocusNode.addListener(
      _handleFocusChanged,
    );
  }

  void _handleFocusChanged() {
    if (!mounted) return;

    setState(() {});
  }

  @override
  void dispose() {
    _contentController.removeListener(
      _handleContentChanged,
    );

    _contentFocusNode.removeListener(
      _handleFocusChanged,
    );

    _contentController.dispose();
    _contentFocusNode.dispose();

    super.dispose();
  }

  void _handleContentChanged() {
    if (!mounted) return;

    setState(() {});
  }

  bool get _hasContent => _contentController.text.trim().isNotEmpty;

  bool get _hasChanges {
    return _contentController.text.trim() != _initialContent.trim();
  }

  bool get _canSave =>
      !_isBusy && (_hasContent || _initialImageUrls.isNotEmpty);

  String get _formattedDate {
    final date = widget.memo?.createdAt ?? DateTime.now();

    return '${date.year}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _saveMemo() async {
    if (_isBusy) return;

    final content = _contentController.text.trim();

    if (content.isEmpty && _initialImageUrls.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              '메모 내용 또는 이미지를 추가해주세요.',
            ),
          ),
        );

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    try {
      final provider = context.read<SavedBooksProvider>();

      if (_isEditMode) {
        await provider.updateMemo(
          memo: widget.memo!,
          content: content,
          imageUrls: _initialImageUrls,
        );
      } else {
        await provider.addMemo(
          bookId: widget.book.id,
          content: content,
          imageUrls: _initialImageUrls,
        );
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode ? '메모를 수정하지 못했습니다.' : '메모를 저장하지 못했습니다.',
            ),
            backgroundColor: Colors.redAccent,
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

  Future<bool> _confirmExit() async {
    if (_isBusy) {
      return false;
    }

    if (!_hasChanges) {
      return true;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B2C2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '메모 작성을 종료할까요?',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            '저장하지 않은 내용은 사라집니다.',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'kopub',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                '계속 작성',
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'kopub',
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                '나가기',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontFamily: 'kopub',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    return shouldExit ?? false;
  }

  Future<void> _handleBackPressed() async {
    final canExit = await _confirmExit();

    if (!mounted || !canExit) return;

    Navigator.pop(context);
  }

  Future<void> _handleBookInformationTap() async {
    if (_isBusy) return;

    FocusScope.of(context).unfocus();

    // BookDetailScreen에서 들어온 경우
    // → 새 BookDetailScreen을 또 만들지 않고 기존 화면으로 돌아감
    if (widget.openedFromBookDetail) {
      final canExit = await _confirmExit();

      if (!mounted || !canExit) return;

      Navigator.pop(context);
      return;
    }

    // MemoScreen 등 다른 화면에서 들어온 경우
    // → 해당 책의 상세 화면을 새로 열어줌
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookDetailScreen(
          book: widget.book,
        ),
      ),
    );
  }

  Future<ImageSource?> _showImageSourceSheet({
    required String title,
  }) async {
    FocusScope.of(context).unfocus();

    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1B2C2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'kopub',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.amberAccent,
                  ),
                  title: const Text(
                    '카메라로 촬영',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'kopub',
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                      ImageSource.camera,
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: Colors.amberAccent,
                  ),
                  title: const Text(
                    '앨범에서 선택',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'kopub',
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                      ImageSource.gallery,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _shareMemo() {
    if (!_isEditMode || _isBusy) {
      return;
    }

    FocusScope.of(context).unfocus();

    final content = _contentController.text.trim();

    if (content.isEmpty && _initialImageUrls.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              '공유할 메모 내용이 없습니다.',
            ),
          ),
        );

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShareNoteScreen(
          book: widget.book,
          memoContent: content,
          savedAt: widget.memo!.createdAt,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteMemo() async {
    if (!_isEditMode || _isBusy) {
      return;
    }

    FocusScope.of(context).unfocus();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B2C2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '메모 삭제',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            '이 메모를 삭제할까요?\n'
            '삭제한 메모는 복구할 수 없습니다.',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'kopub',
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontFamily: 'kopub',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                '취소',
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'kopub',
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await context.read<SavedBooksProvider>().deleteMemo(
            widget.memo!.id,
          );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              '메모를 삭제하지 못했습니다.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );

      setState(() {
        _isDeleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (
        bool didPop,
        dynamic result,
      ) async {
        if (didPop) return;

        await _handleBackPressed();
      },
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;

          if (velocity > 500 && !_isBusy) {
            _handleBackPressed();
          }
        },
        behavior: HitTestBehavior.translucent,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: const Color(0xFF013328),
          appBar: _buildAppBar(
            screenWidth,
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      screenWidth * 0.045,
                      screenWidth * 0.025,
                      screenWidth * 0.045,
                      screenWidth * 0.05,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBookInformation(
                          screenWidth,
                        ),
                        SizedBox(
                          height: screenWidth * 0.035,
                        ),
                        _buildMemoInputSection(
                          screenWidth,
                        ),
                      ],
                    ),
                  ),
                ),
                _buildBottomAdArea(
                  screenWidth,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    double screenWidth,
  ) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: _isBusy ? null : _handleBackPressed,
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      title: Text(
        _isEditMode ? '메모 수정' : '메모 작성',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'kopub',
          fontSize: screenWidth * 0.045,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          enabled: !_isBusy,
          padding: EdgeInsets.zero,
          tooltip: '메모 메뉴',
          icon: Icon(
            Icons.more_vert_rounded,
            color: _isBusy ? Colors.white30 : Colors.white70,
          ),
          color: const Color(0xFF1B2C2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onSelected: (value) {
            if (value == 'extractText') {
              _extractTextFromImage();
            } else if (value == 'share') {
              _shareMemo();
            } else if (value == 'delete') {
              _confirmDeleteMemo();
            }
          },
          itemBuilder: (_) {
            return [
              const PopupMenuItem<String>(
                value: 'extractText',
                child: Row(
                  children: [
                    Icon(
                      Icons.document_scanner_outlined,
                      color: Colors.amberAccent,
                      size: 19,
                    ),
                    SizedBox(width: 12),
                    Text(
                      '텍스트 추출',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'kopub',
                      ),
                    ),
                  ],
                ),
              ),
              if (_isEditMode)
                const PopupMenuItem<String>(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(
                        Icons.ios_share_rounded,
                        color: Colors.white70,
                        size: 19,
                      ),
                      SizedBox(width: 12),
                      Text(
                        '공유하기',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'kopub',
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isEditMode)
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 19,
                      ),
                      SizedBox(width: 12),
                      Text(
                        '삭제하기',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontFamily: 'kopub',
                        ),
                      ),
                    ],
                  ),
                ),
            ];
          },
        ),
        TextButton(
          onPressed: _canSave ? _saveMemo : null,
          child: _isSaving
              ? SizedBox(
                  width: screenWidth * 0.042,
                  height: screenWidth * 0.042,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.amberAccent,
                  ),
                )
              : Text(
                  '저장',
                  style: TextStyle(
                    color: _canSave ? Colors.amberAccent : Colors.white30,
                    fontFamily: 'kopub',
                    fontSize: screenWidth * 0.035,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        SizedBox(
          width: screenWidth * 0.01,
        ),
      ],
    );
  }

  Widget _buildBookInformation(
    double screenWidth,
  ) {
    final imageUrl = widget.book.imageUrl?.trim() ?? '';

    final highResolutionImageUrl = imageUrl.replaceAll(
      'coversum',
      'cover',
    );

    return CardBox(
      onTap: _handleBookInformationTap,
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(
        screenWidth * 0.035,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: screenWidth * 0.16,
              height: screenWidth * 0.23,
              child: highResolutionImageUrl.startsWith('http')
                  ? Image.network(
                      highResolutionImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (
                        context,
                        error,
                        stackTrace,
                      ) {
                        return _buildCoverFallback();
                      },
                    )
                  : _buildCoverFallback(),
            ),
          ),
          SizedBox(
            width: screenWidth * 0.035,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize: screenWidth * 0.038,
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                  ),
                ),
                if (widget.book.author.trim().isNotEmpty) ...[
                  SizedBox(
                    height: screenWidth * 0.018,
                  ),
                  Text(
                    widget.book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white60,
                      fontFamily: 'kopub',
                      fontSize: screenWidth * 0.031,
                    ),
                  ),
                ],
                SizedBox(
                  height: screenWidth * 0.025,
                ),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: Colors.white38,
                      size: screenWidth * 0.036,
                    ),

                    SizedBox(
                      width: screenWidth * 0.012,
                    ),

                    Text(
                      _formattedDate,
                      style: TextStyle(
                        color: Colors.white54,
                        fontFamily: 'kopub',
                        fontSize: screenWidth * 0.03,
                      ),
                    ),

                    if (_formattedUpdatedDate != null) ...[
                      SizedBox(
                        width: screenWidth * 0.018,
                      ),

                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          shape: BoxShape.circle,
                        ),
                      ),

                      SizedBox(
                        width: screenWidth * 0.018,
                      ),

                      Text(
                        '수정 $_formattedUpdatedDate',
                        style: TextStyle(
                          color: Colors.white38,
                          fontFamily: 'kopub',
                          fontSize: screenWidth * 0.028,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: screenWidth * 0.015,
          ),

          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white.withOpacity(0.35),
            size: screenWidth * 0.05,
          ),
        ],
      ),
    );
  }

  Widget _buildCoverFallback() {
    return Container(
      color: Colors.white10,
      child: const Icon(
        Icons.book_rounded,
        color: Colors.white54,
      ),
    );
  }

  Future<void> _extractTextFromImage() async {
    if (_isBusy) return;

    final source = await _showImageSourceSheet(
      title: '텍스트를 추출할 이미지',
    );

    if (source == null || !mounted) {
      return;
    }

    XFile? selectedImage;

    try {
      selectedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2000,
      );
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        source == ImageSource.camera ? '카메라를 실행하지 못했습니다.' : '이미지를 불러오지 못했습니다.',
        isError: true,
      );

      return;
    }

    if (selectedImage == null || !mounted) {
      return;
    }

    setState(() {
      _isExtractingText = true;
    });

    try {
      final extractedText = await _textRecognitionService.recognizeText(
        imagePath: selectedImage.path,
      );

      if (!mounted) return;

      if (extractedText.isEmpty) {
        _showSnackBar(
          '이미지에서 텍스트를 찾지 못했습니다.',
        );
        return;
      }

      await _showOcrResultDialog(
        extractedText,
      );
    } catch (e, stackTrace) {
      debugPrint(
        '❌ [Memo OCR] $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      _showSnackBar(
        '텍스트를 추출하지 못했습니다.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExtractingText = false;
        });
      }
    }
  }

  Future<void> _showOcrResultDialog(
    String extractedText,
  ) async {
    final resultController = TextEditingController(
      text: extractedText,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final screenHeight = MediaQuery.of(dialogContext).size.height;

        return AlertDialog(
          backgroundColor: const Color(0xFF1B2C2E),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 28,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            '텍스트 추출 결과',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: screenHeight * 0.52,
            child: TextField(
              controller: resultController,
              expands: true,
              minLines: null,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: 15,
                height: 1.6,
              ),
              decoration: InputDecoration(
                hintText: '추출된 텍스트를 확인해주세요.',
                hintStyle: const TextStyle(
                  color: Colors.white30,
                  fontFamily: 'kopub',
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(
                  0.055,
                ),
                contentPadding: const EdgeInsets.all(16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Colors.white.withOpacity(
                      0.08,
                    ),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Colors.amberAccent,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                '취소',
                style: TextStyle(
                  color: Colors.white60,
                  fontFamily: 'kopub',
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                if (resultController.text.trim().isEmpty) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                '메모에 추가',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontFamily: 'kopub',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    final result = resultController.text.trim();

    resultController.dispose();

    if (confirmed != true || result.isEmpty || !mounted) {
      return;
    }

    _appendExtractedText(result);
  }

  void _appendExtractedText(
    String extractedText,
  ) {
    final currentText = _contentController.text.trimRight();

    final updatedText =
        currentText.isEmpty ? extractedText : '$currentText\n\n$extractedText';

    _contentController.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(
        offset: updatedText.length,
      ),
    );

    _contentFocusNode.requestFocus();

    _showSnackBar(
      '추출한 텍스트를 메모에 추가했습니다.',
    );
  }

  void _showSnackBar(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.redAccent : null,
        ),
      );
  }

  Widget _buildMemoInputSection(
    double screenWidth,
  ) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(
        screenWidth * 0.04,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: screenWidth * 0.085,
                height: screenWidth * 0.085,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  color: Colors.white70,
                  size: screenWidth * 0.052,
                ),
              ),
              SizedBox(
                width: screenWidth * 0.025,
              ),
              const Expanded(
                child: Text(
                  '독서 메모',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${_contentController.text.length}자',
                style: TextStyle(
                  color: Colors.white38,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.028,
                ),
              ),
            ],
          ),
          SizedBox(
            height: screenWidth * 0.035,
          ),
          Container(
            constraints: BoxConstraints(
              minHeight: screenWidth * 0.9,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.035,
              vertical: screenWidth * 0.025,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.055),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _contentFocusNode.hasFocus
                    ? Colors.amberAccent.withOpacity(0.5)
                    : Colors.white.withOpacity(0.07),
              ),
            ),
            child: TextField(
              controller: _contentController,
              focusNode: _contentFocusNode,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              minLines: 16,
              maxLines: null,
              autofocus: !_isEditMode,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.036,
                height: 1.65,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '책을 읽으며 떠오른 생각이나\n기억하고 싶은 문장을 남겨보세요.',
                hintStyle: TextStyle(
                  color: Colors.white30,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.035,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAdArea(
    double screenWidth,
  ) {
    final mediaQuery = MediaQuery.of(context);

    if (mediaQuery.viewInsets.bottom > 0) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: const Color(0xFF013328),
      child: const Center(
        child: AdBannerPlaceholder(
          adSize: AdSize.banner,
        ),
      ),
    );
  }

  String? get _formattedUpdatedDate {
    final memo = widget.memo;

    if (memo == null) {
      return null;
    }

    final createdAt = memo.createdAt;
    final updatedAt = memo.updatedAt;

    final isSameDay =
        createdAt.year == updatedAt.year &&
            createdAt.month == updatedAt.month &&
            createdAt.day == updatedAt.day;

    if (isSameDay) {
      return null;
    }

    return '${updatedAt.year}.'
        '${updatedAt.month.toString().padLeft(2, '0')}.'
        '${updatedAt.day.toString().padLeft(2, '0')}';
  }

}
