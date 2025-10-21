import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FindAccountScreen extends StatefulWidget {
  const FindAccountScreen({super.key});

  @override
  State<FindAccountScreen> createState() => _FindAccountScreenState();
}

class _FindAccountScreenState extends State<FindAccountScreen> {
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  String foundEmail = "";
  bool isLoading = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  String _verificationId = "";
  final otpController = TextEditingController();
  int? _resendToken;


  Future<void> _findEmailByPhone() async {
    setState(() {
      isLoading = true;
      foundEmail = "";
    });

    final phone = phoneController.text.replaceAll(RegExp(r'\D'), '');

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .get();

      if (query.docs.isNotEmpty) {
        setState(() {
          foundEmail = "가입된 이메일: ${query.docs.first['email']}";
        });
      } else {
        setState(() {
          foundEmail = "해당 번호로 가입된 이메일이 없습니다.";
        });
      }
    } catch (e) {
      setState(() {
        foundEmail = "오류 발생: $e";
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("이메일을 입력해주세요")),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("비밀번호 재설정 메일을 보냈습니다.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("실패: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final padding = screenWidth * 0.05;
    final fontSize = screenWidth * 0.04;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1D27),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("아이디/비밀번호 찾기",
            style: TextStyle(color: Colors.white, fontFamily: 'kopub')),
        leading: const BackButton(color: Colors.white),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionCard(
              icon: "📧",
              title: "아이디 찾기 (전화번호로)",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: phoneController,
                          hintText: "전화번호 입력 (예: 01012345678)",
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _sendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          minimumSize: const Size(10, 48), // 높이 맞춤
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("인증번호 받기", style: TextStyle(color: Colors.black)),
                      ),
                    ],
                  ),


                  if (_otpSent) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: otpController,
                            hintText: "인증번호 입력",
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            minimumSize: const Size(10, 48), // 높이 맞춤
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("인증번호 확인", style: TextStyle(color: Colors.black)),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // 아이디 찾기 버튼 (인증된 경우에만 가능)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_otpVerified && !isLoading) ? _findEmailByPhone : null,
                      style: _buttonStyle(),
                      child: isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                          : const Text("아이디 찾기", style: TextStyle(color: Colors.black)),
                    ),
                  ),
                  if (foundEmail.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(foundEmail,
                        style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),
            _buildSectionCard(
              icon: "🔐",
              title: "비밀번호 재설정 (이메일로)",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(
                    controller: emailController,
                    hintText: "가입된 이메일 입력",
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _sendPasswordResetEmail,
                      style: _buttonStyle(),
                      child: const Text("재설정 메일 보내기",
                          style: TextStyle(color: Colors.black)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$icon $title",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'kopub',
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white54),
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white38),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white38),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.amberAccent),
        ),
      ),
    );
  }

  ButtonStyle _buttonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.amberAccent,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Future<void> _sendOtp() async {
    final raw = phoneController.text.trim();
    if (raw.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("전화번호를 정확히 입력해주세요(예: 01012345678)")),
      );
      return;
    }
    final fullPhone = '+82${raw.substring(1)}'; // 010 → +8210

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: fullPhone,
      timeout: const Duration(seconds: 60),

      forceResendingToken: _resendToken, // ← 연속요청 시 쿨다운 회피에 도움

      verificationCompleted: (PhoneAuthCredential cred) async {
        // 자동완성 시 바로 검증 성공으로만 사용 (로그인 상태는 남기지 않음)
        try {
          await FirebaseAuth.instance.signInWithCredential(cred);
          setState(() => _otpVerified = true);
        } finally {
          await FirebaseAuth.instance.signOut(); // ← 임시 로그인 상태 정리
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        final msg = _mapAuthError(e);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("인증 실패: $msg")));
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken; // ← 저장
          _otpSent = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("인증번호를 전송했습니다.")),
        );
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-app-credential':
      case 'app-not-authorized':
        return '앱 서명/패키지 정보가 일시적으로 검증되지 않았습니다. 잠시 후 다시 시도해주세요.';
      case 'captcha-check-failed':
        return 'reCAPTCHA 확인에 실패했습니다. 다시 시도해주세요.';
      case 'too-many-requests':
        return '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.';
      default:
        return e.message ?? e.code;
    }
  }

  Future<void> _verifyOtp() async {
    final otp = otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("6자리 인증번호를 입력해주세요.")),
      );
      return;
    }

    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otp,
      );
      await FirebaseAuth.instance.signInWithCredential(cred);
      setState(() => _otpVerified = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("인증 성공!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("인증 실패: $e")),
      );
      return;
    } finally {
      // 이 화면에서는 로그인 유지 불필요 → 정리
      await FirebaseAuth.instance.signOut();
    }
  }
}
