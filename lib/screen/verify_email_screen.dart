import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:dayverse_book/service/user_data_loader.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/provider/custom_library_provider.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/provider/user_data_provider.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _sending = false;
  bool _checking = false;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _resend() async {
    if (_sending) return;
    setState(() => _sending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) {
        _snack('로그인이 필요합니다.');
        return;
      }

      await user.sendEmailVerification();

      _snack('인증 메일을 다시 보냈습니다. 메일함(스팸함 포함)을 확인해주세요.');
    } catch (e) {
      _snack('재전송 실패: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) {
        _snack('로그인이 필요합니다.');
        return;
      }

      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;

      if (refreshed == null) {
        _snack('유저 정보를 불러오지 못했습니다. 다시 시도해주세요.');
        return;
      }

      if (!refreshed.emailVerified) {
        _snack('아직 이메일 인증이 완료되지 않았어요. 메일함을 확인해주세요.');
        return;
      }

      // ✅ Firestore에도 인증 완료 기록 (원하면 나중에 검색/필터링에 사용)
      await FirebaseFirestore.instance.collection('users').doc(refreshed.uid).set({
        'emailVerified': true,
        'emailVerifiedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ✅ 네 앱 구조상: 여기서 유저 데이터 로드까지 끝내고 main 진입해야 UserDataGate에서 안 걸림
      await loadUserDataAfterLogin(
        savedBooksProvider: context.read<SavedBooksProvider>(),
        customLibraryProvider: context.read<CustomLibraryProvider>(),
        challengeProvider: context.read<ChallengeProvider>(),
        userDataProvider: context.read<UserDataProvider>(),
      );

      if (!mounted) return;

      context.read<UserDataProvider>().markAsLoaded();

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/main',
            (r) => false,
        arguments: {'showWelcome': true}, // ✅ justSignedUp로도 뜨지만, 확실하게
      );
    } catch (e) {
      _snack('확인 실패: $e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      // 로그아웃 후엔 다시 익명로그인이 main()에서 되긴 하지만,
      // 로그인 화면으로 보내서 흐름 명확히.
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    } catch (e) {
      _snack('로그아웃 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1D27),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1D27),
        elevation: 0,
        title: const Text('이메일 인증', style: TextStyle(color: Colors.white, fontFamily: 'kopub')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const Text(
              "메일함에서 인증 링크를 눌러주세요.",
              style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'kopub'),
            ),
            const SizedBox(height: 12),
            const Text(
              "인증이 완료되면 아래 ‘인증 확인’ 버튼을 눌러주세요.\n메일이 안 오면 스팸함도 확인해 주세요.",
              style: TextStyle(color: Colors.white70, height: 1.4, fontFamily: 'kopub'),
            ),
            const SizedBox(height: 24),

            // ✅ (선택) 현재 로그인 이메일 표시
            Builder(
              builder: (_) {
                final email = FirebaseAuth.instance.currentUser?.email ?? '';
                return Text(
                  email.isEmpty ? '' : "현재 이메일: $email",
                  style: const TextStyle(color: Colors.white54, fontFamily: 'kopub'),
                );
              },
            ),

            const Spacer(),

            ElevatedButton(
              onPressed: _sending ? null : _resend,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _sending
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("인증 메일 재전송", style: TextStyle(color: Colors.black, fontFamily: 'kopub')),
            ),
            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: _checking ? null : _check,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _checking
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("인증 확인", style: TextStyle(color: Color(0xFF0A1D27), fontFamily: 'kopub')),
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: _logout,
              child: const Text("다른 이메일로 다시 하기 (로그아웃)", style: TextStyle(color: Colors.white70, fontFamily: 'kopub')),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
