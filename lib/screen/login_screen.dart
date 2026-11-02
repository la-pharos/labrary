import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dayverse_book/service/user_data_loader.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/provider/custom_library_provider.dart';
import 'package:dayverse_book/provider/user_data_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // ✅ 추가: 포커스 노드
  final _emailFocus = FocusNode();
  final _pwFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;

  bool _isPasswordValid(String password) {
    return password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password) &&
        RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password);
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _emailFocus.dispose();
    _pwFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);

    final email = emailController.text.trim();
    final pw = passwordController.text.trim();

    if (email.isEmpty || pw.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("이메일과 비밀번호를 입력해주세요.")),
        );
      }
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final userCredential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pw,
      );

      if (!mounted) return;

      final user = userCredential.user;
      await user?.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser != null && !refreshedUser.emailVerified) {
        if (mounted) setState(() => _isLoading = false);
        Navigator.pushReplacementNamed(context, '/verify_email');
        return;
      }

      await loadUserDataAfterLogin(
        savedBooksProvider: context.read<SavedBooksProvider>(),
        customLibraryProvider: context.read<CustomLibraryProvider>(),
        challengeProvider: context.read<ChallengeProvider>(),
        userDataProvider: context.read<UserDataProvider>(),
      );

      if (!mounted) return;

      context.read<UserDataProvider>().markAsLoaded();

      Navigator.pushReplacementNamed(
        context,
        '/main',
        arguments: {'showWelcome': false},
      );
    } on FirebaseAuthException catch (e) {
      debugPrint("🔥 로그인 에러: ${e.code} - ${e.message}");
      String message;
      switch (e.code) {
        case 'invalid-email':
          message = '이메일 형식을 확인해주세요.';
          break;
        case 'user-not-found':
          message = '존재하지 않는 계정입니다.';
          break;
        case 'wrong-password':
          message = '비밀번호가 틀렸습니다.';
          break;
        case 'user-disabled':
          message = '비활성화된 계정입니다.';
          break;
        case 'too-many-requests':
          message = '너무 많은 시도입니다. 잠시 후 다시 시도해주세요.';
          break;
        default:
          message = '로그인에 실패했습니다. 이메일과 비밀번호를 확인해주세요.';
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알 수 없는 오류가 발생했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1D27),
      //appBar: AppBar(
      //  backgroundColor: const Color(0xFF0A1D27),
      //  elevation: 0,
      //  leading: IconButton(
      //    icon: const Icon(Icons.home_rounded, color: Colors.white),
      //    onPressed: () {
      //      context.read<SavedBooksProvider>().clearData();
      //      context.read<CustomLibraryProvider>().clearLibraries();
      //      context.read<ChallengeProvider>().clearLocalData();
      //      context.read<UserDataProvider>().reset();

      //      Navigator.pushNamedAndRemoveUntil(
      //       context,
      //        '/main',
      //            (route) => false,
      //      );
      //    },
      //  ),
      //),

      // ✅ 핵심: Tab 키를 우리가 직접 포커스 이동으로 처리
      body: Stack(
        children: [


          // ✅ 기존 로그인 내용
          Shortcuts(
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
                    final screenHeight = MediaQuery.of(context).size.height;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: IntrinsicHeight(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // ✅ 기존 "Labrary 로그인" 텍스트 대신 로고
                              Image.asset(
                                'assets/image/logo_mark.png',
                                height: screenHeight * 0.16,
                                fit: BoxFit.contain,
                              ),

                              const Text(
                                "로그인",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontFamily: 'Kopub',
                                ),
                              ),

                              SizedBox(height: screenHeight * 0.07),

                              // ✅ 이메일
                              TextField(
                                focusNode: _emailFocus,
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                onEditingComplete: () =>
                                    FocusScope.of(context).requestFocus(_pwFocus),
                                autofillHints: const [
                                  AutofillHints.username,
                                  AutofillHints.email,
                                ],
                                autocorrect: false,
                                enableSuggestions: false,
                                smartDashesType: SmartDashesType.disabled,
                                smartQuotesType: SmartQuotesType.disabled,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[ -~]')),
                                ],
                                decoration: const InputDecoration(
                                  labelText: '이메일',
                                  labelStyle: TextStyle(color: Colors.white70),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.white38),
                                  ),
                                ),
                                style: const TextStyle(color: Colors.white),
                              ),

                              const SizedBox(height: 20),

                              // ✅ 비밀번호
                              TextField(
                                focusNode: _pwFocus,
                                controller: passwordController,
                                obscureText: _obscurePassword,
                                keyboardType: TextInputType.visiblePassword,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _login(),
                                autofillHints: const [AutofillHints.password],
                                autocorrect: false,
                                enableSuggestions: false,
                                smartDashesType: SmartDashesType.disabled,
                                smartQuotesType: SmartQuotesType.disabled,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[ -~]')),
                                ],
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: '비밀번호',
                                  labelStyle: const TextStyle(color: Colors.white70),
                                  enabledBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.white38),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.white70,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                style: const TextStyle(color: Colors.white),
                              ),

                              const SizedBox(height: 6),

                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '영문 대소문자, 숫자, 특수문자 포함 8자 이상 입력',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 30),

                              _isLoading
                                  ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: CircularProgressIndicator(
                                  color: Colors.amberAccent,
                                ),
                              )
                                  : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amberAccent,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  child: const Text(
                                    "로그인",
                                    style: TextStyle(
                                      color: Color(0xFF0A1D27),
                                      fontFamily: 'kopub',
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),

                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/find_account');
                                },
                                child: const Text(
                                  "아이디 / 비밀번호 찾기",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),

                              TextButton(
                                onPressed: _showTermsDialog,
                                child: const Text(
                                  "계정이 없으신가요? 회원가입",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),

                              const SizedBox(height: 30),
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
        ],
      ),
    );
  }

  void _showTermsDialog() {
    bool agreeAll = false;
    bool agreeService = false;
    bool agreePrivacy = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void checkAgreeAll(bool value) {
              setState(() {
                agreeAll = value;
                agreeService = value;
                agreePrivacy = value;
              });
            }

            void checkIndividual(bool service, bool privacy) {
              setState(() {
                agreeService = service;
                agreePrivacy = privacy;
                agreeAll = agreeService && agreePrivacy;
              });
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: const Text("약관 모두 동의",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      value: agreeAll,
                      onChanged: (value) => checkAgreeAll(value ?? false),
                    ),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            title: const Text("(필수) 서비스 이용약관 동의"),
                            value: agreeService,
                            onChanged: (value) =>
                                checkIndividual(value ?? false, agreePrivacy),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _openNotionLink(
                              "https://viixi.kr/labrary/terms/"),
                          child: const Text("보기",
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            title: const Text("(필수) 개인정보 수집 및 이용 동의"),
                            value: agreePrivacy,
                            onChanged: (value) =>
                                checkIndividual(agreeService, value ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _openNotionLink(
                              "https://viixi.kr/labrary/privacy/"),
                          child: const Text("보기",
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: (agreeService && agreePrivacy)
                          ? () {
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(context, '/signup');
                      }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (agreeService && agreePrivacy)
                            ? Colors.amber
                            : Colors.grey.shade300,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text("가입하기",
                          style: TextStyle(color: Colors.black)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openNotionLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('약관 링크를 열 수 없습니다')),
      );
    }
  }
}
