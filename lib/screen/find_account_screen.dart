import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FindAccountScreen extends StatefulWidget {
  const FindAccountScreen({
    super.key,
  });

  @override
  State<FindAccountScreen> createState() =>
      _FindAccountScreenState();
}

class _FindAccountScreenState
    extends State<FindAccountScreen> {
  final TextEditingController emailController =
  TextEditingController();

  bool isSending = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: const TextStyle(
              fontFamily: 'kopub',
            ),
          ),
        ),
      );
  }

  Future<void> _sendPasswordResetEmail() async {
    final email =
    emailController.text.trim();

    if (email.isEmpty) {
      _snack(
        '이메일을 입력해주세요.',
      );
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(
        email: email,
      );

      _snack(
        '비밀번호 재설정 메일을 보냈습니다. '
            '메일함과 스팸함을 확인해주세요.',
      );
    } on FirebaseAuthException catch (e) {
      String msg =
          '재설정 메일 전송에 실패했습니다. '
          '잠시 후 다시 시도해주세요.';

      if (e.code == 'invalid-email') {
        msg =
        '올바른 이메일 형식을 입력해주세요.';
      } else if (e.code ==
          'too-many-requests') {
        msg =
        '요청이 너무 많습니다. '
            '잠시 후 다시 시도해주세요.';
      }

      _snack(msg);
    } catch (e) {
      _snack(
        '오류가 발생했습니다. '
            '잠시 후 다시 시도해주세요.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      onHorizontalDragEnd: (details) {
        final velocity =
            details.primaryVelocity ?? 0;

        if (velocity > 500) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor:
        const Color(0xFF0A1D27),

        appBar: AppBar(
          backgroundColor:
          Colors.transparent,
          elevation: 0,
          centerTitle: true,

          leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
            ),
          ),

          title: Text(
            '회원정보 찾기',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize:
              screenWidth * 0.045,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ),

        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics:
            const BouncingScrollPhysics(),
            padding:
            EdgeInsets.fromLTRB(
              screenWidth * 0.055,
              screenWidth * 0.035,
              screenWidth * 0.055,
              screenWidth * 0.08,
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.center,
              children: [
                _buildIntro(
                  screenWidth,
                ),

                SizedBox(
                  height:
                  screenWidth * 0.055,
                ),

                _buildPasswordResetCard(
                  screenWidth,
                ),

                SizedBox(
                  height:
                  screenWidth * 0.035,
                ),

                _buildEmailGuideCard(
                  screenWidth,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntro(
      double screenWidth,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.center,
      children: [
        Container(
          width:
          screenWidth * 0.12,
          height:
          screenWidth * 0.12,
          decoration:
          BoxDecoration(
            color: Colors.amberAccent
                .withOpacity(0.08),
            borderRadius:
            BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.lock_reset_rounded,
            color: Colors.amberAccent,
            size:
            screenWidth * 0.06,
          ),
        ),

        SizedBox(
          height:
          screenWidth * 0.035,
        ),

        Text(
          '비밀번호를 잊으셨나요?',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontSize:
            screenWidth * 0.052,
            fontWeight:
            FontWeight.bold,
          ),
        ),

        SizedBox(
          height:
          screenWidth * 0.018,
        ),

        Text(
          '가입한 이메일로 비밀번호 재설정 링크를 보내드려요.',
          style: TextStyle(
            color: Colors.white
                .withOpacity(0.52),
            fontFamily: 'kopub',
            fontSize:
            screenWidth * 0.032,
            height: 1.55,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordResetCard(
      double screenWidth,
      ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        screenWidth * 0.045,
      ),
      decoration: BoxDecoration(
        color:
        Colors.white.withOpacity(0.045),
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color:
          Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width:
                screenWidth * 0.09,
                height:
                screenWidth * 0.09,
                decoration:
                BoxDecoration(
                  color: Colors.white
                      .withOpacity(0.055),
                  borderRadius:
                  BorderRadius.circular(
                    11,
                  ),
                ),
                child: Icon(
                  Icons
                      .mail_outline_rounded,
                  color:
                  Colors.white70,
                  size:
                  screenWidth * 0.045,
                ),
              ),

              SizedBox(
                width:
                screenWidth * 0.025,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      '비밀번호 재설정',
                      style: TextStyle(
                        color:
                        Colors.white,
                        fontFamily:
                        'kopub',
                        fontSize:
                        screenWidth *
                            0.038,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    SizedBox(
                      height:
                      screenWidth *
                          0.006,
                    ),

                    Text(
                      '가입한 이메일을 입력해주세요.',
                      style: TextStyle(
                        color:
                        Colors.white54,
                        fontFamily:
                        'kopub',
                        fontSize:
                        screenWidth *
                            0.027,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(
            height:
            screenWidth * 0.04,
          ),

          _buildTextField(
            controller:
            emailController,
            hintText:
            '이메일',
            keyboardType:
            TextInputType.emailAddress,
            screenWidth:
            screenWidth,
          ),

          SizedBox(
            height:
            screenWidth * 0.03,
          ),

          SizedBox(
            width:
            double.infinity,
            child:
            ElevatedButton(
              onPressed:
              isSending
                  ? null
                  : _sendPasswordResetEmail,

              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                Colors.amberAccent,
                disabledBackgroundColor:
                Colors.amberAccent
                    .withOpacity(0.45),
                foregroundColor:
                const Color(
                  0xFF0A1D27,
                ),
                elevation: 0,
                padding:
                EdgeInsets.symmetric(
                  vertical:
                  screenWidth *
                      0.038,
                ),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),
                ),
              ),

              child:
              isSending
                  ? SizedBox(
                width:
                screenWidth *
                    0.05,
                height:
                screenWidth *
                    0.05,
                child:
                const CircularProgressIndicator(
                  strokeWidth:
                  2.2,
                  color:
                  Color(
                    0xFF0A1D27,
                  ),
                ),
              )
                  : Row(
                mainAxisAlignment:
                MainAxisAlignment
                    .center,
                children: [
                  Icon(
                    Icons
                        .send_rounded,
                    size:
                    screenWidth *
                        0.042,
                  ),

                  SizedBox(
                    width:
                    screenWidth *
                        0.015,
                  ),

                  Text(
                    '재설정 메일 보내기',
                    style:
                    TextStyle(
                      fontFamily:
                      'kopub',
                      fontSize:
                      screenWidth *
                          0.032,
                      fontWeight:
                      FontWeight
                          .bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(
            height:
            screenWidth * 0.025,
          ),

          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Colors.white38,
                size:
                screenWidth * 0.035,
              ),

              SizedBox(
                width:
                screenWidth * 0.012,
              ),

              Expanded(
                child: Text(
                  '메일이 보이지 않는다면 스팸함이나 프로모션함도 확인해주세요.',
                  style: TextStyle(
                    color:
                    Colors.white38,
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth * 0.025,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmailGuideCard(
      double screenWidth,
      ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        screenWidth * 0.04,
      ),
      decoration: BoxDecoration(
        color:
        Colors.white.withOpacity(0.025),
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color:
          Colors.white.withOpacity(0.055),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width:
            screenWidth * 0.08,
            height:
            screenWidth * 0.08,
            decoration:
            BoxDecoration(
              color: Colors.white
                  .withOpacity(0.045),
              borderRadius:
              BorderRadius.circular(10),
            ),
            child: Icon(
              Icons
                  .alternate_email_rounded,
              color: Colors.white54,
              size:
              screenWidth * 0.041,
            ),
          ),

          SizedBox(
            width:
            screenWidth * 0.025,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  '아이디가 기억나지 않나요?',
                  style: TextStyle(
                    color:
                    Colors.white,
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth * 0.032,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),

                SizedBox(
                  height:
                  screenWidth * 0.01,
                ),

                Text(
                  'Labrary는 가입한 이메일 주소를 아이디로 사용해요.',
                  style: TextStyle(
                    color:
                    Colors.white54,
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth * 0.027,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required double screenWidth,
    TextInputType keyboardType =
        TextInputType.text,
    List<TextInputFormatter>?
    inputFormatters,
  }) {
    return TextField(
      controller:
      controller,
      keyboardType:
      keyboardType,
      inputFormatters:
      inputFormatters,
      enabled:
      !isSending,
      textInputAction:
      TextInputAction.done,
      onSubmitted:
          (_) {
        if (!isSending) {
          _sendPasswordResetEmail();
        }
      },
      style: TextStyle(
        color:
        Colors.white,
        fontFamily:
        'kopub',
        fontSize:
        screenWidth * 0.033,
      ),
      cursorColor:
      Colors.amberAccent,
      decoration:
      InputDecoration(
        hintText:
        hintText,
        hintStyle:
        TextStyle(
          color:
          Colors.white38,
          fontFamily:
          'kopub',
          fontSize:
          screenWidth *
              0.031,
        ),
        prefixIcon:
        Icon(
          Icons
              .mail_outline_rounded,
          color:
          Colors.white38,
          size:
          screenWidth * 0.045,
        ),
        filled:
        true,
        fillColor:
        Colors.black
            .withOpacity(
          0.12,
        ),
        contentPadding:
        EdgeInsets.symmetric(
          horizontal:
          screenWidth *
              0.035,
          vertical:
          screenWidth *
              0.034,
        ),
        enabledBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            13,
          ),
          borderSide:
          BorderSide(
            color:
            Colors.white
                .withOpacity(
              0.08,
            ),
          ),
        ),
        disabledBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            13,
          ),
          borderSide:
          BorderSide(
            color:
            Colors.white
                .withOpacity(
              0.04,
            ),
          ),
        ),
        focusedBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            13,
          ),
          borderSide:
          BorderSide(
            color:
            Colors.amberAccent
                .withOpacity(
              0.75,
            ),
          ),
        ),
        border:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            13,
          ),
        ),
      ),
    );
  }
}