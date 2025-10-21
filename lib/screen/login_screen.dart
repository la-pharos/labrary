import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dayverse_book/service/user_data_loader.dart'; // ✅ 추가
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/provider/custom_library_provider.dart';
import 'package:dayverse_book/provider/user_data_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';




class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _obscurePassword = true;

  bool _isLoading = false;

  bool _isPasswordValid(String password) {
    return password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password) &&
        RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password);
  }

  Future<void> _login() async {
    setState(() => _isLoading = true); // ✅ 로딩 시작

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (!mounted) return;

      await loadUserDataAfterLogin(
        savedBooksProvider: context.read<SavedBooksProvider>(),
        customLibraryProvider: context.read<CustomLibraryProvider>(),
        challengeProvider: context.read<ChallengeProvider>(),
        userDataProvider: context.read<UserDataProvider>(),
      );

      if (!mounted) return;

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알 수 없는 오류가 발생했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false); // ✅ 로딩 종료
    }
  }


  @override
  Widget build(BuildContext context) {
    final password = passwordController.text;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1D27),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1D27),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = MediaQuery.of(context).size.height;
          final screenWidth = MediaQuery.of(context).size.width;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Labrary\n 로그인",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontFamily: 'kopub',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: screenHeight * 0.06),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: '이메일',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white38),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: passwordController,
                      obscureText: _obscurePassword,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white38),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 30),
                    _isLoading
                        ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(color: Colors.amberAccent),
                    )
                        : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16), // 더 터치하기 좋게
                        ),
                        child: const Text(
                          "로그인",
                          style: TextStyle(color: Color(0xFF0A1D27), fontFamily: 'kopub'),
                        ),
                      ),
                    ),
                    SizedBox(height: 10,),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/find_account');
                      },
                      child: const Text("아이디 / 비밀번호 찾기", style: TextStyle(color: Colors.white70)),
                    ),
                    TextButton(
                      onPressed: _showTermsDialog,
                      child: const Text("계정이 없으신가요? 회원가입", style: TextStyle(color: Colors.white70)),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          );
        },
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: const Text("약관 모두 동의", style: TextStyle(fontWeight: FontWeight.bold)),
                      value: agreeAll,
                      onChanged: (value) => checkAgreeAll(value ?? false),
                    ),
                    const Divider(),

                    // 서비스 이용약관
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            title: const Text("(필수) 서비스 이용약관 동의"),
                            value: agreeService,
                            onChanged: (value) => checkIndividual(value ?? false, agreePrivacy),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ),
                        // 서비스 이용약관 버튼
                        TextButton(
                          onPressed: () => _openNotionLink("https://laser-celestite-d8b.notion.site/2384357caf3c805d852cda200ab53094"),
                          child: const Text("보기", style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),

                    // 개인정보 수집 및 이용
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            title: const Text("(필수) 개인정보 수집 및 이용 동의"),
                            value: agreePrivacy,
                            onChanged: (value) => checkIndividual(agreeService, value ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ),
                        // 개인정보 처리방침 버튼
                        TextButton(
                          onPressed: () => _openNotionLink("https://laser-celestite-d8b.notion.site/2384357caf3c8065ac74f8237ba34438"),
                          child: const Text("보기", style: TextStyle(fontSize: 12)),
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
                        backgroundColor: (agreeService && agreePrivacy) ? Colors.amber : Colors.grey.shade300,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text("가입하기", style: TextStyle(color: Colors.black)),
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

  void _showPolicyDialog(BuildContext context, String title, String assetPath) async {
    final content = await DefaultAssetBundle.of(context).loadString(assetPath);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(child: Text(content)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("닫기"),
          ),
        ],
      ),
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
