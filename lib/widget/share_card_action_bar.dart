import 'package:flutter/material.dart';

class ShareCardActionBar extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback onSave;
  final void Function(BuildContext shareContext) onShare;

  const ShareCardActionBar({
    super.key,
    required this.isProcessing,
    required this.onSave,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          screenWidth * 0.05,
          screenWidth * 0.035,
          screenWidth * 0.05,
          screenWidth * 0.04,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF013328),
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                isProcessing ? null : onSave,
                icon: isProcessing
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(
                  Icons.download_rounded,
                  size: 20,
                ),
                label: Text(
                  isProcessing
                      ? '처리 중'
                      : '이미지 저장',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor:
                  Colors.white54,
                  side: BorderSide(
                    color:
                    Colors.white.withOpacity(0.35),
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: screenWidth * 0.035,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'kopub',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            SizedBox(
              width: screenWidth * 0.025,
            ),

            Expanded(
              child: Builder(
                builder: (shareContext) {
                  return ElevatedButton.icon(
                    onPressed: isProcessing
                        ? null
                        : () => onShare(
                      shareContext,
                    ),
                    icon: isProcessing
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                        color:
                        Color(0xFF013328),
                      ),
                    )
                        : const Icon(
                      Icons.ios_share_rounded,
                      size: 20,
                    ),
                    label: Text(
                      isProcessing
                          ? '처리 중'
                          : '공유하기',
                    ),
                    style:
                    ElevatedButton.styleFrom(
                      foregroundColor:
                      const Color(0xFF013328),
                      backgroundColor:
                      Colors.amberAccent,
                      disabledBackgroundColor:
                      Colors.amberAccent
                          .withOpacity(0.6),
                      disabledForegroundColor:
                      const Color(0xFF013328),
                      padding: EdgeInsets.symmetric(
                        vertical:
                        screenWidth * 0.035,
                      ),
                      elevation: 0,
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(12),
                      ),
                      textStyle:
                      const TextStyle(
                        fontFamily: 'kopub',
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
