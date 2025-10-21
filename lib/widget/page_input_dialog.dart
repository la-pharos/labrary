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
  State<PageInputDialog> createState() => _PageInputDialogState();
}

class _PageInputDialogState extends State<PageInputDialog> {
  late TextEditingController _controller;
  String? _errorText;
  bool isFullyRead = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPage?.toString() ?? '');
  }

  void _validateAndSubmit() {
    final text = _controller.text.trim();
    final page = int.tryParse(text);

    if (text.isEmpty) {
      widget.onConfirm?.call(null, false);
      Navigator.of(context).pop({'page': null, 'done': false});
    } else if (page == null || page < 1) {
      setState(() => _errorText = "1쪽 이상 입력해주세요.");
    } else if (page > widget.totalPages) {
      setState(() => _errorText = "총 페이지 수(${widget.totalPages})를 넘을 수 없어요.");
    } else {
      final isDone = page == widget.totalPages;
      widget.onConfirm?.call(page, isDone);
      Navigator.of(context).pop({'page': page, 'done': isDone});
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final fontSizeTitle = screenWidth * 0.05; // 약 20~22
    final fontSizeBody = screenWidth * 0.035;
    final fontSizeInput = screenWidth * 0.03;
    final fontSizeButton = screenWidth * 0.03;
    final dialogPadding = screenWidth * 0.04;

    return Dialog(
      backgroundColor: const Color(0xFF0A1D27),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(dialogPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogHeader(context, fontSizeTitle),
            SizedBox(height: screenHeight * 0.015),
            Text(
              "총 ${widget.totalPages}페이지 중 몇 페이지까지 읽으셨나요?",
              style: TextStyle(
                fontSize: fontSizeBody,
                color: Colors.white,
                fontFamily: 'kopub',
              ),
            ),
            SizedBox(height: screenHeight * 0.02),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.white, fontSize: fontSizeInput),
              decoration: InputDecoration(
                hintText: "읽은 페이지수를 입력하세요.",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                errorText: _errorText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (text) {
                final page = int.tryParse(text);
                setState(() {
                  isFullyRead = page == widget.totalPages;
                });
              },
              onSubmitted: (_) => _validateAndSubmit(),
            ),
            if (isFullyRead) ...[
              SizedBox(height: screenHeight * 0.01),
              Center(
                child: Text(
                  "🎉 책을 모두 읽으셨네요!",
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: 'kopub',
                    fontSize: fontSizeBody,
                  ),
                ),
              ),
            ],
            SizedBox(height: screenHeight * 0.025),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _validateAndSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.018),
                ),
                child: Text(
                  "기록 완료",
                  style: TextStyle(
                    color: Colors.black,
                    fontFamily: 'kopub',
                    fontWeight: FontWeight.bold,
                    fontSize: fontSizeButton,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(BuildContext context, double fontSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "페이지 입력",
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            fontFamily: 'kopub',
            color: Colors.white,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}