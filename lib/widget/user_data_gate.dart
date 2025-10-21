import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/provider/user_data_provider.dart';

class UserDataGate extends StatelessWidget {
  final Widget child;

  const UserDataGate({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isLoaded = context.watch<UserDataProvider>().isLoaded;
    final size = MediaQuery.of(context).size;

    if (!isLoaded) {
      return Scaffold(
        backgroundColor: const Color(0xFF013328),
        body: LayoutBuilder(
          builder: (context, c) {
            final logoH = c.maxHeight * 0.35;          // 로고 표시 높이
            final pullUp = -c.maxHeight * 0.07;        // 텍스트 조금 위로(음수면 위)

            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ▽ 로고 하단 여백 과감히 크롭 (heightFactor 더 낮출수록 아래를 더 잘라냄)
                  SizedBox(
                    height: logoH,
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: 0.9,             // 0.60~0.70 사이로 취향 조절
                        child: Image.asset(
                          'assets/image/logo_mark.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.amberAccent,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return child;
  }
}