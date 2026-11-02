import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/provider/custom_library_provider.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/widget/ad_banner_placeholder.dart';
import 'package:dayverse_book/screen/find_account_screen.dart';
import 'package:dayverse_book/provider/user_data_provider.dart';
import 'package:dayverse_book/widget/card_box.dart';
import 'package:flutter/services.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.trim().isNotEmpty == true
        ? user!.email!
        : '정보 없음';

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
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
            '계정 관리',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: screenWidth * 0.04,
                  right: screenWidth * 0.04,
                  top: screenWidth * 0.025,
                  bottom: screenHeight * 0.13,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAccountInfoCard(
                      screenWidth: screenWidth,
                      email: email,
                    ),

                    SizedBox(height: screenWidth * 0.03),

                    _buildSecurityCard(
                      context,
                      screenWidth,
                    ),

                    SizedBox(height: screenWidth * 0.03),

                    _buildAccountActionsCard(
                      context,
                      screenWidth,
                    ),

                    SizedBox(height: screenWidth * 0.04),
                  ],
                ),
              ),
            ),

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

  Widget _buildAccountInfoCard({
    required double screenWidth,
    required String email,
  }) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.person_outline_rounded,
            title: '계정 정보',
            description: '현재 로그인한 계정이에요.',
            screenWidth: screenWidth,
          ),

          SizedBox(height: screenWidth * 0.04),

          Container(
            width: double.infinity,
            padding: EdgeInsets.all(screenWidth * 0.035),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.07),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: screenWidth * 0.09,
                  height: screenWidth * 0.09,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.055),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.alternate_email_rounded,
                    color: Colors.white60,
                    size: screenWidth * 0.047,
                  ),
                ),

                SizedBox(width: screenWidth * 0.03),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '이메일',
                        style: TextStyle(
                          color: Colors.white54,
                          fontFamily: 'kopub',
                          fontSize: screenWidth * 0.029,
                        ),
                      ),

                      SizedBox(height: screenWidth * 0.008),

                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'kopub',
                          fontSize: screenWidth * 0.034,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard(
      BuildContext context,
      double screenWidth,
      ) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(
        vertical: screenWidth * 0.012,
      ),
      child: Column(
        children: [
          _buildAccountItem(
            icon: Icons.lock_outline_rounded,
            title: '비밀번호 변경',
            description: '현재 비밀번호를 확인한 뒤 변경해요.',
            screenWidth: screenWidth,
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => const PasswordChangeDialog(),
              );
            },
          ),

          _buildMenuDivider(screenWidth),

          _buildAccountItem(
            icon: Icons.manage_search_rounded,
            title: '아이디 / 비밀번호 찾기',
            description: '계정 정보를 찾거나 비밀번호를 재설정해요.',
            screenWidth: screenWidth,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FindAccountScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAccountActionsCard(
      BuildContext context,
      double screenWidth,
      ) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(
        vertical: screenWidth * 0.012,
      ),
      child: Column(
        children: [

          _buildAccountItem(
            icon: Icons.logout_rounded,
            title: '로그아웃',
            description: '현재 계정에서 로그아웃해요.',
            screenWidth: screenWidth,
            color: Colors.white,
            onTap: () => _confirmLogout(context),
          ),

          _buildMenuDivider(screenWidth),

          _buildAccountItem(
            icon: Icons.restart_alt_rounded,
            title: '기록 초기화',
            description: '독서 및 챌린지 기록을 모두 삭제해요.',
            screenWidth: screenWidth,
            color: Colors.orangeAccent,
            onTap: () => _confirmReset(context),
          ),

          _buildMenuDivider(screenWidth),

          _buildAccountItem(
            icon: Icons.person_remove_outlined,
            title: '회원 탈퇴',
            description: '계정과 모든 데이터를 영구 삭제해요.',
            screenWidth: screenWidth,
            color: Colors.redAccent,
            onTap: () => _confirmDeleteAccount(context),
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

  Widget _buildAccountItem({
    required IconData icon,
    required String title,
    required String description,
    required double screenWidth,
    Color color = Colors.white,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.035,
            vertical: screenWidth * 0.03,
          ),
          child: Row(
            children: [
              Container(
                width: screenWidth * 0.085,
                height: screenWidth * 0.085,
                decoration: BoxDecoration(
                  color: color.withOpacity(
                    color == Colors.white ? 0.055 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color == Colors.white
                      ? Colors.white60
                      : color,
                  size: screenWidth * 0.047,
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
                        color: color,
                        fontFamily: 'kopub',
                        fontSize: screenWidth * 0.035,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    SizedBox(height: screenWidth * 0.008),

                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontFamily: 'kopub',
                        fontSize: screenWidth * 0.027,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white30,
                size: screenWidth * 0.055,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuDivider(double screenWidth) {
    return Padding(
      padding: EdgeInsets.only(
        left: screenWidth * 0.15,
        right: screenWidth * 0.035,
      ),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Colors.white.withOpacity(0.055),
      ),
    );
  }

  Future<bool> _showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    Color confirmColor = Colors.redAccent,
  }) async {
    final screenWidth = MediaQuery.of(context).size.width;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B2C2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              color: Colors.white60,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.034,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                confirmText,
                style: TextStyle(
                  color: confirmColor,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.035,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                '취소',
                style: TextStyle(
                  color: Colors.white60,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.035,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(color: Colors.white))),
    );
  }

  Future<void> _confirmLogout(
      BuildContext context,
      ) async {
    final confirmed = await _showConfirmDialog(
      context: context,
      title: '로그아웃',
      message: '현재 계정에서 로그아웃할까요?',
      confirmText: '로그아웃',
      confirmColor: Colors.redAccent,
    );

    if (!confirmed || !context.mounted) return;

    context.read<SavedBooksProvider>().clearData();
    context.read<CustomLibraryProvider>().clearLibraries();
    context.read<ChallengeProvider>().clearLocalData();

    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    context.read<UserDataProvider>().reset();

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
          (route) => false,
    );
  }

  Future<void> _confirmReset(
      BuildContext context,
      ) async {
    final confirmed = await _showConfirmDialog(
      context: context,
      title: '기록 초기화',
      message: '모든 독서 및 챌린지 기록이 삭제됩니다.\n'
          '초기화한 기록은 되돌릴 수 없어요.',
      confirmText: '초기화',
      confirmColor: Colors.redAccent,
    );

    if (!confirmed || !context.mounted) return;

    try {
      await resetUserRecords();

      if (!context.mounted) return;

      final savedBooksProvider =
      context.read<SavedBooksProvider>();
      final customLibraryProvider =
      context.read<CustomLibraryProvider>();
      final challengeProvider =
      context.read<ChallengeProvider>();

      final uid =
          FirebaseAuth.instance.currentUser?.uid;

      savedBooksProvider.clearData();
      customLibraryProvider.clearLibraries();

      if (uid != null) {
        await challengeProvider.clearChallengeStates(
          userId: uid,
        );
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '기록이 초기화되었습니다.',
            style: TextStyle(fontFamily: 'kopub'),
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ 기록 초기화 실패: $e');
      debugPrint('$stackTrace');

      if (!context.mounted) return;

      _showError(
        context,
        '기록 초기화 중 오류가 발생했습니다.',
      );
    }
  }

  Future<void> resetUserRecords() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      debugPrint('[RESET] 유저 UID 없음');
      return;
    }

    debugPrint('[RESET] 초기화 시작 - UID: $uid');

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid);

    final subCollections = [
      'savedBooks',
      'bookRecords',
      'readingTimerLogs',
      'challengeRecords',
      'libraries',
    ];

    for (final collectionName in subCollections) {
      final snapshot =
      await userRef.collection(collectionName).get();

      debugPrint(
        '[RESET] $collectionName 문서 수: '
            '${snapshot.docs.length}',
      );

      for (final document in snapshot.docs) {
        await document.reference.delete();

        debugPrint(
          '[RESET] $collectionName - 삭제됨: '
              '${document.id}',
        );
      }
    }

    debugPrint('[RESET] 기록 초기화 완료');
  }

  Future<void> _confirmDeleteAccount(
      BuildContext context,
      ) async {
    final confirmed = await _showConfirmDialog(
      context: context,
      title: '회원 탈퇴',
      message: '계정과 모든 데이터가 영구적으로 삭제됩니다.\n'
          '탈퇴 후에는 되돌릴 수 없어요.',
      confirmText: '탈퇴하기',
      confirmColor: Colors.redAccent,
    );

    if (!confirmed || !context.mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == null) {
      _showError(
        context,
        '로그인 정보가 없습니다.',
      );
      return;
    }

    final password = await _showPasswordDialog(context);

    if (password == null ||
        password.trim().isEmpty ||
        !context.mounted) {
      return;
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password.trim(),
      );

      await user.reauthenticateWithCredential(
        credential,
      );

      final uid = user.uid;
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid);

      final subCollections = [
        'savedBooks',
        'bookRecords',
        'readingTimerLogs',
        'challengeRecords',
        'libraries',
      ];

      for (final collectionName in subCollections) {
        final snapshot = await userRef
            .collection(collectionName)
            .get();

        for (final document in snapshot.docs) {
          await document.reference.delete();
        }
      }

      await userRef.delete();
      await user.delete();

      if (!context.mounted) return;

      context.read<SavedBooksProvider>().clearData();
      context.read<CustomLibraryProvider>().clearLibraries();
      context.read<ChallengeProvider>().clearLocalData();
      context.read<UserDataProvider>().reset();

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;

      if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        _showError(
          context,
          '비밀번호가 올바르지 않습니다.',
        );
      } else if (e.code == 'requires-recent-login') {
        _showError(
          context,
          '보안을 위해 다시 로그인한 후 시도해주세요.',
        );
      } else {
        _showError(
          context,
          '회원 탈퇴에 실패했습니다.',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 회원 탈퇴 실패: $e');
      debugPrint('$stackTrace');

      if (!context.mounted) return;

      _showError(
        context,
        '회원 탈퇴 중 오류가 발생했습니다.',
      );
    }
  }

  Future<String?> _showPasswordDialog(
      BuildContext context,
      ) async {
    final controller = TextEditingController();
    final screenWidth =
        MediaQuery.of(context).size.width;

    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor:
            const Color(0xFF16483F),
            shape: RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(18),
              side: BorderSide(
                color:
                Colors.white.withOpacity(0.08),
              ),
            ),
            title: Text(
              '비밀번호 확인',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.034,
              ),
              cursorColor: Colors.amberAccent,
              decoration: InputDecoration(
                filled: true,
                fillColor:
                Colors.white.withOpacity(0.05),
                hintText: '현재 비밀번호',
                hintStyle: TextStyle(
                  color: Colors.white38,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.032,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white
                        .withOpacity(0.07),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.amberAccent
                        .withOpacity(0.7),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
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
                  Navigator.pop(
                    dialogContext,
                    controller.text.trim(),
                  );
                },
                child: const Text(
                  '확인',
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
    } finally {
      controller.dispose();
    }
  }

}

class PasswordChangeDialog extends StatefulWidget {
  const PasswordChangeDialog({super.key});

  @override
  State<PasswordChangeDialog> createState() =>
      _PasswordChangeDialogState();
}

class _PasswordChangeDialogState
    extends State<PasswordChangeDialog> {
  final currentPasswordController =
  TextEditingController();
  final newPasswordController =
  TextEditingController();

  bool isCurrentPasswordValid = false;
  bool isChecking = false;
  bool isChanging = false;
  String errorText = '';

  bool _isPasswordValid(String password) {
    return password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password) &&
        RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password);
  }

  Future<void> _checkCurrentPassword() async {
    final currentPassword =
    currentPasswordController.text.trim();

    if (currentPassword.isEmpty) {
      setState(() {
        errorText = '현재 비밀번호를 입력해주세요.';
      });
      return;
    }

    setState(() {
      isChecking = true;
      errorText = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user?.email == null) {
        throw Exception('로그인 정보를 찾을 수 없습니다.');
      }

      final credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(
        credential,
      );

      if (!mounted) return;

      setState(() {
        isCurrentPasswordValid = true;
        isChecking = false;
        errorText = '';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = '현재 비밀번호가 올바르지 않습니다.';
        isChecking = false;
      });
    }
  }

  Future<void> _changePassword() async {
    final newPassword =
    newPasswordController.text.trim();

    if (newPassword.isEmpty) {
      setState(() {
        errorText = '새 비밀번호를 입력해주세요.';
      });
      return;
    }

    if (!_isPasswordValid(newPassword)) {
      setState(() {
        errorText =
        '비밀번호는 8자 이상이며 대문자, 소문자, 숫자, 특수문자를 모두 포함해야 합니다.';
      });
      return;
    }

    if (newPassword ==
        currentPasswordController.text.trim()) {
      setState(() {
        errorText = '현재 비밀번호와 다른 비밀번호를 입력해주세요.';
      });
      return;
    }

    setState(() {
      isChanging = true;
      errorText = '';
    });

    try {
      await FirebaseAuth.instance.currentUser
          ?.updatePassword(newPassword);

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '비밀번호가 변경되었습니다.',
            style: TextStyle(
              fontFamily: 'kopub',
            ),
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        isChanging = false;

        if (e.code == 'weak-password') {
          errorText =
          '비밀번호는 8자 이상이며 대문자, 소문자, 숫자, 특수문자를 모두 포함해야 합니다.';
        } else if (e.code == 'requires-recent-login') {
          errorText = '현재 비밀번호를 다시 확인해주세요.';
          isCurrentPasswordValid = false;
        } else {
          errorText = '비밀번호 변경에 실패했습니다.';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isChanging = false;
        errorText = '비밀번호 변경에 실패했습니다.';
      });
    }
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required double screenWidth,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      hintText: hintText,
      hintStyle: TextStyle(
        color: Colors.white38,
        fontFamily: 'kopub',
        fontSize: screenWidth * 0.032,
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.035,
        vertical: screenWidth * 0.032,
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
          color: Colors.white.withOpacity(0.25),
        ),
      ),
    );
  }

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    return AlertDialog(
      backgroundColor: const Color(0xFF1B2C2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      title: Text(
        '비밀번호 변경',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'kopub',
          fontSize: screenWidth * 0.045,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCurrentPasswordValid
                ? '새로운 비밀번호를 입력해주세요.'
                : '현재 비밀번호를 먼저 확인해주세요.',
            style: TextStyle(
              color: Colors.white60,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.034,
              height: 1.5,
            ),
          ),

          SizedBox(height: screenWidth * 0.035),

          if (!isCurrentPasswordValid)
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              autofocus: true,
              enabled: !isChecking,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!isChecking) {
                  _checkCurrentPassword();
                }
              },
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.034,
              ),
              cursorColor: Colors.white70,
              decoration: _buildInputDecoration(
                hintText: '현재 비밀번호',
                screenWidth: screenWidth,
              ),
            ),

          if (isCurrentPasswordValid)
            TextField(
              controller: newPasswordController,
              obscureText: true,
              autofocus: true,
              enabled: !isChanging,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[ -~]'),
                ),
              ],
              onChanged: (_) {
                if (errorText.isNotEmpty) {
                  setState(() {
                    errorText = '';
                  });
                }
              },
              onSubmitted: (_) {
                if (!isChanging) {
                  _changePassword();
                }
              },
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.034,
              ),
              cursorColor: Colors.white70,
              decoration: _buildInputDecoration(
                hintText: '새 비밀번호',
                screenWidth: screenWidth,
              ),
            ),

          if (errorText.isNotEmpty) ...[
            SizedBox(height: screenWidth * 0.025),
            Text(
              errorText,
              style: TextStyle(
                color: Colors.redAccent,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.03,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: isChecking || isChanging
              ? null
              : isCurrentPasswordValid
              ? _changePassword
              : _checkCurrentPassword,
          child: isChecking || isChanging
              ? SizedBox(
            width: screenWidth * 0.04,
            height: screenWidth * 0.04,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.redAccent,
            ),
          )
              : Text(
            isCurrentPasswordValid
                ? '변경'
                : '확인',
            style: TextStyle(
              color: Colors.redAccent,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.035,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        TextButton(
          onPressed: isChecking || isChanging
              ? null
              : () => Navigator.pop(context),
          child: Text(
            '취소',
            style: TextStyle(
              color: Colors.white60,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.035,
            ),
          ),
        ),
      ],
    );
  }
}
