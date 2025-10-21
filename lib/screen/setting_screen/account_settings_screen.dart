import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/provider/custom_library_provider.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/widget/ad_banner_placeholder.dart';
import 'package:dayverse_book/screen/find_account_screen.dart';


class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final horizontalPadding = screenWidth * 0.05;
    final titleFontSize = screenWidth * 0.045;
    final itemFontSize = screenWidth * 0.04;
    final iconSize = screenWidth * 0.04;

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? "정보 없음";
    final phone = user?.phoneNumber ?? "등록되지 않음";

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 20) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF013328),
        appBar: AppBar(
          title: Text(
            "계정 관리",
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: titleFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Stack(
          children: [
            // ✅ 본문 영역
            SizedBox(
              height: screenHeight,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: horizontalPadding,
                    right: horizontalPadding,
                    top: screenHeight * 0.02,
                    bottom: screenHeight * 0.08, // 광고 높이 고려
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStaticAccountItem("이메일", email, itemFontSize),
                      _buildStaticAccountItem("전화번호", phone, itemFontSize),
                      _buildAccountItem(context, "비밀번호 변경", itemFontSize, iconSize, onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => const PasswordChangeDialog(),
                        );
                      }),
                      // ✅ 추가된 부분
                      _buildAccountItem(
                        context,
                        "아이디 / 비밀번호 찾기",
                        itemFontSize,
                        iconSize,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const FindAccountScreen()),
                          );
                        },
                      ),
                      _buildAccountItem(context, "기록 초기화", itemFontSize, iconSize, onTap: () => _confirmReset(context)),
                      _buildAccountItem(context, "로그아웃", itemFontSize, iconSize, color: Colors.redAccent, onTap: () => _confirmLogout(context)),
                      _buildAccountItem(context, "회원 탈퇴", itemFontSize, iconSize, color: Colors.red, onTap: () => _confirmDeleteAccount(context)),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),

            // ✅ 하단 고정 광고
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BottomAdLargeBannerBar(),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(color: Colors.white))),
    );
  }

  Widget _buildStaticAccountItem(String label, String value, double fontSize) {
    return ListTile(
      title: Text(label, style: TextStyle(color: Colors.white, fontFamily: 'kopub', fontSize: fontSize)),
      trailing: Text(value, style: TextStyle(color: Colors.white, fontSize: fontSize, fontFamily: 'kopub')),
    );
  }

  Widget _buildAccountItem(BuildContext context, String title, double fontSize, double iconSize,
      {Color color = Colors.white, VoidCallback? onTap}) {
    return ListTile(
      title: Text(title, style: TextStyle(color: color, fontFamily: 'kopub', fontSize: fontSize)),
      trailing: Icon(Icons.arrow_forward_ios, size: iconSize, color: Colors.white30),
      onTap: onTap,
    );
  }

  void _confirmLogout(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final titleSize = screenWidth * 0.05;
    final contentSize = screenWidth * 0.035;
    final buttonFontSize = screenWidth * 0.04;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "로그아웃",
          style: TextStyle(
            fontFamily: 'kopub',
            fontWeight: FontWeight.bold,
            fontSize: titleSize,
            color: Colors.white,
          ),
        ),
        content: Text(
          "정말 로그아웃하시겠습니까?",
          style: TextStyle(
            fontFamily: 'kopub',
            fontSize: contentSize,
            height: 1.4,
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            child: Text(
              "로그아웃",
              style: TextStyle(color: Colors.redAccent, fontSize: buttonFontSize),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "취소",
              style: TextStyle(fontSize: buttonFontSize),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final titleSize = screenWidth * 0.05;
    final contentSize = screenWidth * 0.035;
    final buttonFontSize = screenWidth * 0.04;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "기록 초기화",
          style: TextStyle(
            fontFamily: 'kopub',
            fontWeight: FontWeight.bold,
            fontSize: titleSize,
            color: Colors.white,
          ),
        ),
        content: Text(
          "모든 기록이 삭제됩니다.\n초기화 후 되돌릴 수 없습니다. 계속할까요?",
          style: TextStyle(
            fontFamily: 'kopub',
            fontSize: contentSize,
            height: 1.4,
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await resetUserRecords();

              final savedBooksProvider = context.read<SavedBooksProvider>();
              final customLibraryProvider = context.read<CustomLibraryProvider>();
              final challengeProvider = context.read<ChallengeProvider>();
              final uid = FirebaseAuth.instance.currentUser?.uid;

              savedBooksProvider.clearData();
              customLibraryProvider.clearLibraries();

              if (uid != null) {
                await challengeProvider.clearChallengeStates(userId: uid);
              }

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("기록이 초기화되었습니다.")),
              );
            },
            child: Text(
              "삭제",
              style: TextStyle(color: Colors.red, fontSize: buttonFontSize),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("취소", style: TextStyle(fontSize: buttonFontSize)),
          ),
        ],
      ),
    );
  }

  Future<void> resetUserRecords() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint("[RESET] 유저 UID 없음");
      return;
    }

    debugPrint("[RESET] 초기화 시작 - UID: $uid");

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    final subCollections = [
      'savedBooks',
      'bookRecords',
      'readingTimerLogs',
      'challengeRecords',
      'libraries',
    ];

    for (final col in subCollections) {
      final snapshot = await userRef.collection(col).get();
      debugPrint("[RESET] $col 문서 수: ${snapshot.docs.length}");

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
        debugPrint("[RESET] $col - 삭제됨: ${doc.id}");
      }
    }

    final userDoc = await userRef.get();
    if (userDoc.exists) {
      final data = userDoc.data()!;
      await userRef.set({
        'nickname': data['nickname'] ?? '',
        'bio': data['bio'] ?? '',
      });
      debugPrint("[RESET] 사용자 문서 기본 정보 초기화 완료");
    }
  }

  void _confirmDeleteAccount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final titleFontSize = screenWidth * 0.05;
    final contentFontSize = screenWidth * 0.04;
    final buttonFontSize = screenWidth * 0.04;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "회원 탈퇴",
          style: TextStyle(
            fontFamily: 'kopub',
            fontWeight: FontWeight.bold,
            fontSize: titleFontSize,
            color: Colors.white,
          ),
        ),
        content: Text(
          "정말로 탈퇴하시겠습니까? 모든 데이터가 삭제됩니다.\n탈퇴 후 데이터는 되돌릴 수 없습니다.",
          style: TextStyle(
            fontFamily: 'kopub',
            fontSize: contentFontSize,
            height: 1.4,
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final user = FirebaseAuth.instance.currentUser;

              if (user == null || user.email == null) {
                _showError(context, "로그인 정보가 없습니다.");
                return;
              }

              final password = await _showPasswordDialog(context);
              if (password == null || password.isEmpty) return;

              try {
                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: password,
                );

                await user.reauthenticateWithCredential(credential);

                final uid = user.uid;
                final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

                final subCollections = [
                  'savedBooks',
                  'bookRecords',
                  'readingTimerLogs',
                  'challengeRecords',
                  'libraries',
                ];

                for (final col in subCollections) {
                  final snapshot = await userRef.collection(col).get();
                  for (final doc in snapshot.docs) {
                    await doc.reference.delete();
                  }
                }

                await userRef.delete();
                await user.delete();

                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              } on FirebaseAuthException catch (e) {
                if (e.code == 'wrong-password') {
                  _showError(context, "비밀번호가 틀렸습니다.");
                } else {
                  _showError(context, "회원 탈퇴 실패: ${e.message}");
                }
              }
            },
            child: Text(
              "탈퇴",
              style: TextStyle(color: Colors.red, fontSize: buttonFontSize),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("취소", style: TextStyle(fontSize: buttonFontSize)),
          ),
        ],
      ),
    );
  }

  Future<String?> _showPasswordDialog(BuildContext context) async {
    final controller = TextEditingController();
    String? result;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('비밀번호 확인'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: '현재 비밀번호를 입력하세요'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              result = controller.text;
              Navigator.of(context).pop();
            },
            child: const Text("확인"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("취소"),
          ),
        ],
      ),
    );

    return result;
  }

}

class PasswordChangeDialog extends StatefulWidget {
  const PasswordChangeDialog({super.key});

  @override
  State<PasswordChangeDialog> createState() => _PasswordChangeDialogState();
}

class _PasswordChangeDialogState extends State<PasswordChangeDialog> {
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  bool isCurrentPasswordValid = false;
  bool isChecking = false;
  String errorText = "";

  Future<void> _checkCurrentPassword() async {
    setState(() {
      isChecking = true;
      errorText = "";
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) throw "로그인 정보를 찾을 수 없습니다.";

      final cred = EmailAuthProvider.credential(
        email: user!.email!,
        password: currentPasswordController.text.trim(),
      );

      await user.reauthenticateWithCredential(cred);

      setState(() {
        isCurrentPasswordValid = true;
        isChecking = false;
      });
    } catch (e) {
      setState(() {
        errorText = "현재 비밀번호가 올바르지 않습니다.";
        isChecking = false;
      });
    }
  }

  Future<void> _changePassword() async {
    final newPassword = newPasswordController.text.trim();
    try {
      await FirebaseAuth.instance.currentUser?.updatePassword(newPassword);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("비밀번호가 변경되었습니다.")),
      );
    } catch (e) {
      setState(() {
        errorText = "비밀번호 변경에 실패했습니다.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final titleFontSize = screenWidth * 0.05;
    final contentFontSize = screenWidth * 0.038;
    final errorFontSize = screenWidth * 0.034;
    final buttonFontSize = screenWidth * 0.04;

    return AlertDialog(
      backgroundColor: const Color(0xFF1B2C2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        "비밀번호 변경",
        style: TextStyle(
          fontFamily: 'kopub',
          fontWeight: FontWeight.bold,
          fontSize: titleFontSize,
          color: Colors.white,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: currentPasswordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "현재 비밀번호",
              labelStyle: TextStyle(color: Colors.white70, fontSize: contentFontSize),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white38),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.amberAccent),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (isCurrentPasswordValid)
            TextField(
              controller: newPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "새 비밀번호",
                labelStyle: TextStyle(color: Colors.white70, fontSize: contentFontSize),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white38),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.amberAccent),
                ),
              ),
            ),
          if (errorText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                errorText,
                style: TextStyle(color: Colors.redAccent, fontSize: errorFontSize),
              ),
            ),
        ],
      ),
      actions: [
        if (!isCurrentPasswordValid)
          TextButton(
            onPressed: isChecking ? null : _checkCurrentPassword,
            child: Text("확인", style: TextStyle(fontSize: buttonFontSize, color: Colors.redAccent)),
          ),
        if (isCurrentPasswordValid)
          TextButton(
            onPressed: _changePassword,
            child: Text("변경", style: TextStyle(fontSize: buttonFontSize, color: Colors.white)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("취소", style: TextStyle(fontSize: buttonFontSize, )),
        ),
      ],
    );
  }
}
