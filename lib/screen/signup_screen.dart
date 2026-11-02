import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import 'package:dayverse_book/service/user_data_loader.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/provider/custom_library_provider.dart';
import 'package:dayverse_book/provider/user_data_provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dayverse_book/service/signup_service.dart';

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

  // ✅ 포커스 노드 4개
  final _emailFocus = FocusNode();
  final _nicknameFocus = FocusNode();
  final _pwFocus = FocusNode();
  final _pw2Focus = FocusNode();

  bool _obscurePassword = true;

  bool? _isNicknameAvailable;
  bool? _isEmailAvailable;

  bool isSubmitting = false;

  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  @override
  void dispose() {
    emailController.dispose();
    nicknameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    _emailFocus.dispose();
    _nicknameFocus.dispose();
    _pwFocus.dispose();
    _pw2Focus.dispose();

    super.dispose();
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
              style: TextStyle(
                  color: isMet ? Colors.green : Colors.red, fontSize: 13)),
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ✅ 기존 _buildInput 확장: focusNode / formatter / action / submit 등 넣을 수 있게
  Widget _buildInput(
      String label,
      TextEditingController controller, {
        FocusNode? focusNode,
        bool obscure = false,
        VoidCallback? onChangedReset,
        TextInputType? keyboardType,
        TextInputAction? textInputAction,
        VoidCallback? onEditingComplete,
        ValueChanged<String>? onSubmitted,
        List<TextInputFormatter>? inputFormatters,
        Iterable<String>? autofillHints,
        bool autocorrect = true,
        bool enableSuggestions = true,
      }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure ? _obscurePassword : false,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onEditingComplete: onEditingComplete,
      onSubmitted: onSubmitted,
      autofillHints: autofillHints,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      inputFormatters: inputFormatters,
      onChanged: (_) {
        setState(() {});
        onChangedReset?.call();
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white38),
        ),
        suffixIcon: obscure
            ? IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.white70,
          ),
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
        )
            : null,
      ),
      style: const TextStyle(color: Colors.white),
    );
  }

  Future<void> _signup() async {
    if (isSubmitting) return;
    setState(() => isSubmitting = true);

    try {
      final email = emailController.text.trim();
      final nickname = nicknameController.text.trim();
      final password = passwordController.text.trim();
      final confirmPassword = confirmPasswordController.text.trim();

      final nicknameRegExp = RegExp(r'^[가-힣a-zA-Z0-9]{2,12}$');

      if (email.isEmpty ||
          nickname.isEmpty ||
          password.isEmpty ||
          confirmPassword.isEmpty) {
        _showError("모든 항목을 입력해주세요.");
        return;
      }

      if (!emailRegex.hasMatch(email)) {
        _showError("올바른 이메일 형식을 입력해주세요.");
        return;
      }

      if (password != confirmPassword) {
        _showError("비밀번호가 일치하지 않습니다.");
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

      if (_isEmailAvailable != true) {
        _showError("이메일 중복확인을 완료해주세요.");
        return;
      }
      if (_isNicknameAvailable != true) {
        _showError("닉네임 중복확인을 완료해주세요.");
        return;
      }


      final currentUser = FirebaseAuth.instance.currentUser;
      UserCredential userCredential;

      if (currentUser != null && currentUser.isAnonymous) {
        final credential =
        EmailAuthProvider.credential(email: email, password: password);
        userCredential = await currentUser.linkWithCredential(credential);
        debugPrint("✅ 익명 계정과 연동 완료: ${userCredential.user?.uid}");
      } else {
        userCredential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        debugPrint("✅ 새 계정 생성: ${userCredential.user?.uid}");
      }

      final user = userCredential.user;
      if (user == null) {
        _showError("회원가입에 실패했습니다. 다시 시도해주세요.");
        return;
      }

      if (!user.emailVerified) {
        await user.sendEmailVerification();
        debugPrint("📩 이메일 인증 메일 발송 완료");
      }

      final nicknameNormalized =
      await SignupService.instance.claimNickname(nickname);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'email': user.email,
        'nickname': nickname,
        'nicknameNormalized': nicknameNormalized,
        'bio': '',
        'profileImageUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
        'isPremium': false,
        'phone': '',
        'emailVerified': false,
      }, SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('justSignedUp', true);

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/verify_email',
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message = '회원가입에 실패했습니다.';

      if (e.code == 'email-already-in-use' ||
          e.code == 'credential-already-in-use') {
        message = '이미 사용 중인 이메일입니다.';
      } else if (e.code == 'weak-password') {
        message = '비밀번호가 너무 약합니다.';
      } else if (e.code == 'invalid-credential') {
        message = '잘못된 인증 정보입니다.';
      }

      _showError(message);
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '🔥 회원가입 Functions 오류: ${e.code} / ${e.message}',
      );

      if (e.code == 'already-exists') {
        if (mounted) {
          setState(() {
            _isNicknameAvailable = false;
          });
        }

        _showError(
          '이미 사용 중인 닉네임입니다. 다른 닉네임을 선택해주세요.',
        );
      } else if (e.code == 'permission-denied') {
        if (mounted) {
          setState(() {
            _isNicknameAvailable = false;
          });
        }

        _showError('사용할 수 없는 닉네임입니다.');
      } else if (e.code == 'invalid-argument') {
        if (mounted) {
          setState(() {
            _isNicknameAvailable = false;
          });
        }

        _showError(
          e.message ??
              '닉네임은 2~12자, 한글/영문/숫자만 사용할 수 있습니다.',
        );
      } else if (e.code == 'unauthenticated') {
        _showError('로그인 인증 정보를 확인할 수 없습니다.');
      } else {
        _showError(
          e.message ?? '회원가입 처리 중 오류가 발생했습니다.',
        );
      }
    } catch (e) {
      debugPrint('🔥 signup unknown error: $e');
      _showError('알 수 없는 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }


  Future<void> _checkNicknameAvailability() async {
    final nickname = nicknameController.text.trim();
    final nicknameRegExp = RegExp(r'^[가-힣a-zA-Z0-9]{2,12}$');

    if (!nicknameRegExp.hasMatch(nickname)) {
      _showError('닉네임은 2~12자, 한글/영문/숫자만 사용할 수 있습니다.');
      return;
    }

    try {
      await _ensureAuthenticatedForSignup();

      final available = await SignupService.instance
          .checkNicknameAvailability(nickname);

      if (!mounted) return;

      setState(() {
        _isNicknameAvailable = available;
      });

      _showError(
        available
            ? '사용 가능한 닉네임입니다.'
            : '이미 사용 중인 닉네임입니다.',
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '❌ 닉네임 중복확인 실패: ${e.code} / ${e.message}',
      );

      if (mounted) {
        setState(() {
          _isNicknameAvailable = false;
        });
      }

      if (e.code == 'permission-denied') {
        _showError('사용할 수 없는 닉네임입니다.');
      } else if (e.code == 'already-exists') {
        _showError('이미 사용 중인 닉네임입니다.');
      } else if (e.code == 'invalid-argument') {
        _showError(
          e.message ??
              '닉네임은 2~12자, 한글/영문/숫자만 사용할 수 있습니다.',
        );
      } else {
        _showError(
          e.message ?? '닉네임 중복확인 중 오류가 발생했습니다.',
        );
      }
    } catch (e) {
      debugPrint('❌ 닉네임 중복확인 실패: $e');

      if (mounted) {
        setState(() {
          _isNicknameAvailable = false;
        });
      }

      _showError('닉네임 중복확인 중 오류가 발생했습니다.');
    }
  }

  Future<void> _checkEmailAvailability() async {
    final email = emailController.text.trim().toLowerCase();

    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      _showError('올바른 이메일 형식을 입력해주세요.');
      return;
    }

    try {
      await _ensureAuthenticatedForSignup();

      final available = await SignupService.instance
          .checkEmailAvailability(email);

      if (!mounted) return;

      setState(() {
        _isEmailAvailable = available;
      });

      _showError(
        available
            ? '사용 가능한 이메일입니다.'
            : '이미 사용 중인 이메일입니다.',
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '❌ 이메일 중복확인 실패: ${e.code} / ${e.message}',
      );

      _showError(
        e.message ?? '이메일 중복확인 중 오류가 발생했습니다.',
      );
    } catch (e) {
      debugPrint('❌ 이메일 중복확인 실패: $e');
      _showError('이메일 중복확인 중 오류가 발생했습니다.');
    }
  }

  Future<void> _ensureAuthenticatedForSignup() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
      debugPrint('✅ 회원가입 중복확인용 익명 로그인 완료');
    }
  }

  @override
  Widget build(BuildContext context) {
    final password = passwordController.text;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1D27),

      // ✅ LoginScreen과 동일: Tab / Shift+Tab 포커스 이동 강제
      body: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.tab): const NextFocusIntent(),
          LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.tab):
          const PreviousFocusIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            NextFocusIntent: CallbackAction<NextFocusIntent>(
              onInvoke: (intent) {
                FocusScope.of(context).nextFocus();
                return null;
              },
            ),
            PreviousFocusIntent: CallbackAction<PreviousFocusIntent>(
              onInvoke: (intent) {
                FocusScope.of(context).previousFocus();
                return null;
              },
            ),
          },
          child: FocusTraversalGroup(
            policy: WidgetOrderTraversalPolicy(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 21, vertical: 36),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [

                          Image.asset(
                            'assets/image/logo_mark.png',
                            height: MediaQuery.of(context).size.height * 0.16,
                            fit: BoxFit.contain,
                          ),

                          const Text("회원가입",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontFamily: 'kopub')),
                          const SizedBox(height: 30),

                          // ✅ 이메일 + 중복확인
                          Row(
                            children: [
                              Expanded(
                                child: _buildInput(
                                  "이메일",
                                  emailController,
                                  focusNode: _emailFocus,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  onEditingComplete: () => FocusScope.of(context)
                                      .requestFocus(_nicknameFocus),
                                  autofillHints: const [
                                    AutofillHints.username,
                                    AutofillHints.email
                                  ],
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  inputFormatters: [
                                    // ✅ 이메일은 ASCII만
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[ -~]')),
                                  ],
                                  onChangedReset: () =>
                                      setState(() => _isEmailAvailable = null),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _checkEmailAvailability,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white),
                                child: const Text(
                                  "중복확인",
                                  style: TextStyle(
                                      color: Color(0xFF0A1D27),
                                      fontFamily: 'kopub'),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // ✅ 닉네임 + 중복확인 (한글 허용)
                          Row(
                            children: [
                              Expanded(
                                child: _buildInput(
                                  "닉네임",
                                  nicknameController,
                                  focusNode: _nicknameFocus,
                                  keyboardType: TextInputType.text,
                                  textInputAction: TextInputAction.next,
                                  onEditingComplete: () =>
                                      FocusScope.of(context).requestFocus(_pwFocus),
                                  onChangedReset: () =>
                                      setState(() => _isNicknameAvailable = null),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _checkNicknameAvailability,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white),
                                child: const Text(
                                  "중복확인",
                                  style: TextStyle(
                                      color: Color(0xFF0A1D27),
                                      fontFamily: 'kopub'),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "닉네임은 2~12자, 한글/영문/숫자만 사용할 수 있습니다.",
                              style:
                              TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ✅ 비밀번호 (ASCII만)
                          _buildInput(
                            "비밀번호",
                            passwordController,
                            focusNode: _pwFocus,
                            obscure: true,
                            keyboardType: TextInputType.visiblePassword,
                            textInputAction: TextInputAction.next,
                            onEditingComplete: () =>
                                FocusScope.of(context).requestFocus(_pw2Focus),
                            autofillHints: const [AutofillHints.newPassword],
                            autocorrect: false,
                            enableSuggestions: false,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[ -~]')),
                            ],
                          ),

                          const SizedBox(height: 6),
                          _buildPasswordConditions(password),

                          const SizedBox(height: 12),

                          // ✅ 비밀번호 확인 (ASCII만) + Enter로 가입
                          _buildInput(
                            "비밀번호 확인",
                            confirmPasswordController,
                            focusNode: _pw2Focus,
                            obscure: true,
                            keyboardType: TextInputType.visiblePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _signup(),
                            autofillHints: const [AutofillHints.newPassword],
                            autocorrect: false,
                            enableSuggestions: false,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[ -~]')),
                            ],
                          ),

                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            child: isSubmitting
                                ? const Center(
                              child: CircularProgressIndicator(
                                valueColor:
                                AlwaysStoppedAnimation<Color>(
                                    Colors.amberAccent),
                              ),
                            )
                                : ElevatedButton(
                              onPressed: _signup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amberAccent,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
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
                            onPressed: () =>
                                Navigator.pushReplacementNamed(context, '/login'),
                            child: const Text("이미 계정이 있으신가요?",
                                style: TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
