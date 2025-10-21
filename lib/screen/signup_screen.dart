import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:dayverse_book/service/user_data_loader.dart'; // ✅ 추가
import 'package:provider/provider.dart';

import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/provider/custom_library_provider.dart';
import 'package:dayverse_book/provider/user_data_provider.dart';
import 'package:country_picker/country_picker.dart';



class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final emailController = TextEditingController();
  final nicknameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final phoneController = TextEditingController();
  final otpController = TextEditingController();
  String? _verificationId;
  bool _otpSent = false;
  bool _phoneVerified = false;

  bool _obscurePassword = true;

  bool? _isNicknameAvailable;
  bool? _isEmailAvailable;

  String _selectedCountryCode = '+82';
  String _selectedCountryName = 'South Korea';

  PhoneAuthCredential? _cachedPhoneCredential;

  bool isSubmitting = false;
  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');


  @override
  void dispose() {
    emailController.dispose();
    nicknameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    phoneController.dispose();
    otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = phoneController.text.trim();
    final fullPhoneNumber = '$_selectedCountryCode$phone';

    // 🔒 전화번호 중복 확인 먼저!
    final duplicate = await _isPhoneTaken(fullPhoneNumber); // +821012345678로 확인
    if (duplicate) {
      _showError("이미 사용 중인 전화번호입니다.");
      return;
    }

    // 🔐 Firebase OTP 전송
    FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: fullPhoneNumber,
      codeSent: (verificationId, _) {
        setState(() {
          _verificationId = verificationId;
          _otpSent = true;
        });
      },
      verificationCompleted: (PhoneAuthCredential credential) async {
        _phoneVerified = true;
        setState(() {});
      },
      verificationFailed: (FirebaseAuthException e) {
        _showError("전화번호 인증 실패: ${e.message}");
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> _verifyOtp() async {
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otpController.text.trim(),
      );

      _cachedPhoneCredential = cred; // ✅ 저장만 해둔다

      _phoneVerified = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("전화번호 인증이 완료되었습니다.")),
      );
      setState(() {});
    } catch (e) {
      _showError("인증번호가 올바르지 않습니다.");
    }
  }

  bool _isPasswordValid(String password) {
    return password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password) &&
        RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password);
  }

  Widget _buildPasswordConditions(String password) {
    bool lengthOk = password.length >= 8;
    bool upperOk = RegExp(r'[A-Z]').hasMatch(password);
    bool lowerOk = RegExp(r'[a-z]').hasMatch(password);
    bool numberOk = RegExp(r'[0-9]').hasMatch(password);
    bool specialOk = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password);

    Widget condition(String text, bool isMet) {
      return Row(
        children: [
          Icon(isMet ? Icons.check_circle : Icons.cancel,
              size: 18, color: isMet ? Colors.green : Colors.red),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(color: isMet ? Colors.green : Colors.red, fontSize: 13)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        condition("8자 이상", lengthOk),
        condition("대문자 포함", upperOk),
        condition("소문자 포함", lowerOk),
        condition("숫자 포함", numberOk),
        condition("특수문자 포함", specialOk),
      ],
    );
  }

  Future<void> _signup() async {
    setState(() => isSubmitting = true); // ✅ 로딩 시작

    try {
      final email = emailController.text.trim();
      final nickname = nicknameController.text.trim();
      final password = passwordController.text.trim();
      final confirmPassword = confirmPasswordController.text.trim();
      final nicknameRegExp = RegExp(r'^[가-힣a-zA-Z0-9]{2,12}$');

      if (!_phoneVerified) {
        _showError("전화번호 인증이 필요합니다.");
        return;
      }

      if (email.isEmpty || nickname.isEmpty || password.isEmpty || phoneController.text.trim().isEmpty || otpController.text.trim().isEmpty) {
        _showError("모든 항목을 입력해주세요.");
        return;
      }

      if (!nicknameRegExp.hasMatch(nickname)) {
        _showError("닉네임은 2~12자, 한글/영문/숫자만 사용할 수 있습니다.");
        return;
      }

      if (!_isPasswordValid(password)) {
        _showError("비밀번호가 조건을 만족하지 않습니다.");
        return;
      }

      if (await _isNicknameTaken(nickname)) {
        _showError("이미 사용 중인 닉네임입니다.");
        return;
      }

      if (await _isEmailTaken(email)) {
        _showError("이미 사용 중인 이메일입니다.");
        return;
      }

      if (await _isPhoneTaken(phoneController.text.trim())) {
        _showError("이미 사용 중인 전화번호입니다.");
        return;
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      final credential = EmailAuthProvider.credential(email: email, password: password);
      UserCredential userCredential;

      if (currentUser != null && currentUser.isAnonymous) {
        userCredential = await currentUser.linkWithCredential(credential);
        print("✅ 익명 계정과 연동 완료: ${userCredential.user?.uid}");
      } else {
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        print("✅ 새 계정 생성: ${userCredential.user?.uid}");
      }

      final user = userCredential.user;

      // ✅ 전화번호 연동
      if (_cachedPhoneCredential != null) {
        try {
          await user?.linkWithCredential(_cachedPhoneCredential!);
          print("✅ 전화번호 연동 성공");
        } catch (e) {
          print("⚠️ 전화번호 연동 실패: $e");
        }
      }

      if (user != null) {
        await user.reload();

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'nickname': nickname,
          'bio': '',
          'profileImageUrl': '',
          'createdAt': Timestamp.now(),
          'isPremium': false,
          'phone': phoneController.text.trim(),
        }, SetOptions(merge: true));

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('justSignedUp', true);

        await loadUserDataAfterLogin(
          savedBooksProvider: context.read<SavedBooksProvider>(),
          customLibraryProvider: context.read<CustomLibraryProvider>(),
          challengeProvider: context.read<ChallengeProvider>(),
          userDataProvider: context.read<UserDataProvider>(),
        );

        if (!mounted) return;

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/main',
              (route) => false,
          arguments: {'showWelcome': true},
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = '회원가입에 실패했습니다.';
      if (e.code == 'email-already-in-use') {
        message = '이미 사용 중인 이메일입니다.';
      } else if (e.code == 'weak-password') {
        message = '비밀번호가 너무 약합니다.';
      } else if (e.code == 'invalid-credential') {
        message = '잘못된 인증 정보입니다.';
      }
      _showError(message);
    } finally {
      setState(() => isSubmitting = false); // ✅ 로딩 종료
    }
  }

  Future<bool> _isNicknameTaken(String nickname) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('nickname', isEqualTo: nickname)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildInput(String label, TextEditingController controller,
      {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure ? _obscurePassword : false,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white38),
        ),
        suffixIcon: obscure
            ? IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white70),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        )
            : null,
      ),
      style: const TextStyle(color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    final password = passwordController.text;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1D27),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 36),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("회원가입", style: TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'kopub')),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Expanded(child: _buildInput("이메일", emailController)),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _checkEmailAvailability,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                          child: const Text("중복확인", style: TextStyle(color: Color(0xFF0A1D27), fontFamily: 'kopub')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _buildInput("닉네임", nicknameController)),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _checkNicknameAvailability,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                          child: const Text("중복확인", style: TextStyle(color: Color(0xFF0A1D27), fontFamily: 'kopub')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "닉네임은 2~12자, 한글/영문/숫자만 사용할 수 있습니다.",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildInput("비밀번호", passwordController, obscure: true),
                    const SizedBox(height: 6),
                    _buildPasswordConditions(password),
                    const SizedBox(height: 20),
                    _buildPhoneVerificationSection(),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: isSubmitting
                          ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                        ),
                      )
                          : ElevatedButton(
                        onPressed: _signup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amberAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16), // 더 터치하기 좋게
                        ),
                        child: const Text(
                          "가입하기",
                          style: TextStyle(
                            color: Color(0xFF0A1D27),
                            fontFamily: 'kopub',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                      child: const Text("이미 계정이 있으신가요?", style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _checkNicknameAvailability() async {
    final nickname = nicknameController.text.trim();
    if (nickname.isEmpty) return;

    final taken = await _isNicknameTaken(nickname);
    setState(() {
      _isNicknameAvailable = !taken;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(taken ? "이미 사용 중인 닉네임입니다." : "사용 가능한 닉네임입니다.")),
    );
  }

  Future<void> _checkEmailAvailability() async {
    final email = emailController.text.trim();

    // 🔐 1. 비어있거나 이메일 형식이 아니면 리턴
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("올바른 이메일 형식을 입력해주세요.")),
      );
      return;
    }

    // 🔍 2. 이메일 중복 확인
    final taken = await _isEmailTaken(email);
    setState(() {
      _isEmailAvailable = !taken;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(taken ? "이미 사용 중인 이메일입니다." : "사용 가능한 이메일입니다.")),
    );
  }

  Future<bool> _isEmailTaken(String email) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<bool> _isPhoneTaken(String phone) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: phone)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Widget _buildPhoneVerificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 전화번호 입력 + 인증 버튼 한 줄
        Row(
          children: [
            // 국가번호 + 전화번호 입력
            Expanded(
              flex: 6,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _showCountryPickerBottomSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.white38)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _selectedCountryCode,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "전화번호 입력",
                        hintStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white38),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.amberAccent),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 인증번호 받기 버튼
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 12),
                  ),
                  child: const Text("인증번호 받기", style: TextStyle(fontSize: 12, color: Colors.black)),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),
        const Text(
          "하이픈(-) 없이 숫자만 입력해주세요. 예) 01012345678",
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 12),

        if (_otpSent) ...[
          // 인증번호 입력 + 확인 버튼 한 줄
          Row(
            children: [
              Expanded(
                flex: 6,
                child: TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "인증번호 입력",
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.amberAccent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 12),
                    ),
                    child: const Text("인증번호 확인", style: TextStyle(fontSize: 13, color: Colors.black)),
                  ),
                ),
              ),
            ],
          ),
          if (_phoneVerified) ...[
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 6),
                Text("전화번호 인증 완료", style: TextStyle(color: Colors.green)),
              ],
            ),
          ],
        ],
      ],
    );
  }

  void _showCountryPickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A1D27),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '국가 선택',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: countryList.length,
                  itemBuilder: (context, index) {
                    final country = countryList[index];
                    return ListTile(
                      onTap: () {
                        setState(() {
                          _selectedCountryCode = country['code']!;
                          _selectedCountryName = country['name']!;
                        });
                        Navigator.pop(context);
                      },
                      leading: Text(country['flag'] ?? '🌐', style: const TextStyle(fontSize: 20)),
                      title: Text(
                        '${country['name']} (${country['code']})',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  final List<Map<String, String>> countryList = [
    {'name': 'South Korea', 'code': '+82', 'flag': '🇰🇷'},
    {'name': 'United States', 'code': '+1', 'flag': '🇺🇸'},
    {'name': 'Japan', 'code': '+81', 'flag': '🇯🇵'},
    {'name': 'United Kingdom', 'code': '+44', 'flag': '🇬🇧'},
    {'name': 'Germany', 'code': '+49', 'flag': '🇩🇪'},
    {'name': 'France', 'code': '+33', 'flag': '🇫🇷'},
    {'name': 'China', 'code': '+86', 'flag': '🇨🇳'},
    {'name': 'Canada', 'code': '+1', 'flag': '🇨🇦'},
    {'name': 'Australia', 'code': '+61', 'flag': '🇦🇺'},
    // 필요한 만큼 추가
  ];

}
