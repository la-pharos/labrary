import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:dayverse_book/widget/ad_banner_placeholder.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dayverse_book/service/signup_service.dart';
import 'package:dayverse_book/widget/card_box.dart';
import 'dart:typed_data';
import 'package:dayverse_book/screen/setting_screen/profile_image_crop_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final nicknameController = TextEditingController();
  final introController = TextEditingController();
  User? user;
  File? _selectedImage;
  String? userPhotoUrl;
  bool _useDefaultProfileImage = false;

  bool _isUploading = false;
  bool _isProfileLoading = true;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _loadUserProfile();
    }
  }

  Future<void> _loadUserProfile() async {
    final uid = user?.uid;

    if (uid == null) {
      if (mounted) {
        setState(() {
          _isProfileLoading = false;
        });
      }
      return;
    }

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid);

    try {
      final cachedDoc = await userRef.get(
        const GetOptions(source: Source.cache),
      );

      if (cachedDoc.exists && mounted) {
        _applyUserProfile(cachedDoc.data()!);
      }
    } catch (e) {
      debugPrint('⚠️ 프로필 캐시 로드 실패: $e');
    }

    try {
      final serverDoc = await userRef.get(
        const GetOptions(source: Source.server),
      );

      if (serverDoc.exists && mounted) {
        _applyUserProfile(serverDoc.data()!);
      }
    } catch (e) {
      debugPrint('⚠️ 프로필 서버 로드 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProfileLoading = false;
        });
      }
    }
  }

  void _applyUserProfile(Map<String, dynamic> data) {
    final imageUrl =
    (data['profileImageUrl'] ?? '').toString().trim();

    nicknameController.text =
        (data['nickname'] ?? '').toString();

    introController.text =
        (data['bio'] ?? '').toString();

    setState(() {
      userPhotoUrl = imageUrl;
      _selectedImage = null;
      _useDefaultProfileImage =
          imageUrl.isEmpty;
    });
    if (imageUrl.isNotEmpty) {
      precacheImage(
        CachedNetworkImageProvider(imageUrl),
        context,
      ).catchError((error) {
        debugPrint('⚠️ 프로필 이미지 사전 로드 실패: $error');
      });
    }
  }

  bool _isValidNickname(String nickname) {
    final trimmed = nickname.trim();
    final regExp = RegExp(r'^[a-zA-Z0-9가-힣]{2,12}$');
    return regExp.hasMatch(trimmed);
  }

  Future<File?> _compressImage(File file) async {
    final dir = await Directory.systemTemp;
    final targetPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 80,
      minWidth: 600,
      minHeight: 600,
    );

    if (result == null) return null;
    return File(result.path); // ✅ 이렇게 변환
  }

  String _addCacheBuster(String url) {
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String?> _uploadProfileImage(File imageFile) async {
    try {
      // 1) 압축 시도
      File? fileToUpload;
      try {
        final compressedFile = await _compressImage(imageFile);
        fileToUpload = compressedFile ?? imageFile; // ✅ 실패면 원본 사용
      } catch (_) {
        fileToUpload = imageFile; // ✅ 예외여도 원본 사용
      }

      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${user!.uid}.jpg');

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000, immutable',
      );

      final task = await ref.putFile(fileToUpload!, metadata);
      final url = await task.ref.getDownloadURL();

      return _addCacheBuster(url); // ✅ 캐시 버스터
    } catch (e) {
      print('🔥 프로필 이미지 업로드 실패: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (_isUploading) return;

    final currentUser = user;

    if (currentUser == null) {
      _showMessage('로그인 정보를 찾을 수 없습니다.');
      return;
    }

    final nickname = nicknameController.text.trim();
    final bio = introController.text.trim();

    if (!_isValidNickname(nickname)) {
      _showMessage(
        '닉네임은 2~12자의 한글, 영문, 숫자만 사용할 수 있어요.',
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 닉네임 중복, 예약어 검사 및 nicknames 문서 관리를
      // Cloud Function에서 먼저 처리한다.
      await SignupService.instance.changeNickname(
        nickname,
      );

      String? imageUrl;

      if (_selectedImage != null) {
        imageUrl = await _uploadProfileImage(
          _selectedImage!,
        );

        if (imageUrl == null) {
          throw Exception(
            '프로필 이미지 업로드에 실패했습니다.',
          );
        }
      }

      final updateData = <String, dynamic>{
        'bio': bio,

        if (_useDefaultProfileImage)
          'profileImageUrl':
          FieldValue.delete()
        else if (imageUrl != null)
          'profileImageUrl':
          imageUrl,

        'updatedAt':
        FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set(
        updateData,
        SetOptions(
          merge: true,
        ),
      );

// =====================================================
// 친구들이 가지고 있는
// 내 프로필 정보도 최신 상태로 동기화
// =====================================================

      try {
        final functions =
        FirebaseFunctions.instanceFor(
          region: 'asia-northeast3',
        );

        final callable =
        functions.httpsCallable(
          'syncFriendProfile',
        );

        await callable.call();
      } catch (e) {
        // 내 프로필 자체 저장은 이미 성공했으므로
        // 친구 동기화 오류 때문에 저장 전체를 실패시키지 않는다.
        debugPrint(
          '⚠️ 친구 프로필 동기화 실패: $e',
        );
      }

      if (!mounted) return;

      _showMessage(
        '프로필이 저장되었습니다.',
      );

      Navigator.pop(
        context,
        true,
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '❌ 닉네임 변경 실패: ${e.code} / ${e.message}',
      );

      if (e.code == 'already-exists') {
        _showMessage('이미 사용 중인 닉네임입니다.');
      } else if (e.code == 'permission-denied') {
        _showMessage('사용할 수 없는 닉네임입니다.');
      } else if (e.code == 'invalid-argument') {
        _showMessage(
          e.message ??
              '닉네임은 2~12자의 한글, 영문, 숫자만 사용할 수 있어요.',
        );
      } else if (e.code == 'unauthenticated') {
        _showMessage('로그인이 필요합니다.');
      } else {
        _showMessage(
          e.message ?? '닉네임 변경 중 오류가 발생했습니다.',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 프로필 저장 실패: $e');
      debugPrint('$stackTrace');

      _showMessage(
        '프로필 저장 중 오류가 발생했습니다.',
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  void dispose() {
    nicknameController.dispose();
    introController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();

    final picked =
    await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (picked == null) {
      return;
    }

    try {
      final bytes =
      await picked.readAsBytes();

      if (!mounted) return;

      final croppedBytes =
      await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ProfileImageCropScreen(
                imageBytes: bytes,
              ),
        ),
      );

      if (croppedBytes == null) {
        return;
      }

      final tempDir =
      await Directory.systemTemp;

      final croppedFile =
      File(
        '${tempDir.path}/'
            'profile_crop_'
            '${DateTime.now().millisecondsSinceEpoch}'
            '.jpg',
      );

      await croppedFile.writeAsBytes(
        croppedBytes,
        flush: true,
      );

      if (!mounted) return;

      setState(() {
        _selectedImage =
            croppedFile;

        userPhotoUrl = null;

        _useDefaultProfileImage =
        false;
      });
    } catch (e) {
      debugPrint(
        '❌ 프로필 이미지 선택/크롭 실패: $e',
      );

      if (!mounted) return;

      _showMessage(
        '프로필 사진을 불러오지 못했습니다.',
      );
    }
  }

  void _selectDefaultProfileImage() {
    if (_isUploading) {
      return;
    }

    setState(() {
      _selectedImage =
      null;

      userPhotoUrl =
      null;

      _useDefaultProfileImage =
      true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 20) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF013328),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            '프로필 변경',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed:
              _isUploading ? null : _saveProfile,
              child: Text(
                '저장',
                style: TextStyle(
                  color: _isUploading
                      ? Colors.white38
                      : Colors.amberAccent,
                  fontFamily: 'kopub',
                  fontSize: screenWidth * 0.038,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  left: screenWidth * 0.04,
                  right: screenWidth * 0.04,
                  top: screenWidth * 0.025,
                  bottom: screenHeight * 0.14,
                ),
                child: Column(
                  children: [
                    _buildProfileImageSection(screenWidth),

                    SizedBox(height: screenWidth * 0.045),

                    _buildNicknameCard(screenWidth),

                    SizedBox(height: screenWidth * 0.03),

                    _buildBioCard(screenWidth),

                    SizedBox(height: screenHeight * 0.04),
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

            if (_isUploading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.55),
                  alignment: Alignment.center,
                  child: _buildSavingIndicator(
                    screenWidth,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImageSection(
      double screenWidth,
      ) {
    final avatarSize = screenWidth * 0.36;
    final imageUrl = userPhotoUrl?.trim() ?? '';

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
                border: Border.all(
                  color: Colors.white.withOpacity(0.10),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.20),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipOval(
                child: _buildProfileImageContent(
                  avatarSize: avatarSize,
                  imageUrl: imageUrl,
                ),
              ),
            ),

            Positioned(
              right: screenWidth * 0.005,
              bottom: screenWidth * 0.005,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 3,
                child: InkWell(
                  onTap:
                  _isUploading ? null : _pickImage,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: EdgeInsets.all(
                      screenWidth * 0.025,
                    ),
                    child: Icon(
                      Icons.photo_camera_rounded,
                      color: const Color(0xFF013328),
                      size: screenWidth * 0.055,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: screenWidth * 0.025),

        Row(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed:
              _isUploading
                  ? null
                  : _pickImage,
              icon: Icon(
                Icons.image_outlined,
                color:
                Colors.white60,
                size:
                screenWidth *
                    0.042,
              ),
              label: Text(
                '사진 변경',
                style: TextStyle(
                  color:
                  Colors.white60,
                  fontFamily:
                  'kopub',
                  fontSize:
                  screenWidth *
                      0.03,
                ),
              ),
            ),

            SizedBox(
              width:
              screenWidth *
                  0.015,
            ),

            Container(
              width: 1,
              height:
              screenWidth *
                  0.04,
              color:
              Colors.white
                  .withOpacity(
                0.12,
              ),
            ),

            SizedBox(
              width:
              screenWidth *
                  0.015,
            ),

            TextButton.icon(
              onPressed:
              _isUploading
                  ? null
                  : _selectDefaultProfileImage,
              icon: Icon(
                Icons.person_outline_rounded,
                color:
                _useDefaultProfileImage
                    ? Colors.amberAccent
                    : Colors.white60,
                size:
                screenWidth *
                    0.042,
              ),
              label: Text(
                '기본 이미지',
                style: TextStyle(
                  color:
                  _useDefaultProfileImage
                      ? Colors.amberAccent
                      : Colors.white60,
                  fontFamily:
                  'kopub',
                  fontSize:
                  screenWidth *
                      0.03,
                  fontWeight:
                  _useDefaultProfileImage
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileImageContent({
    required double avatarSize,
    required String imageUrl,
  }) {
    if (_selectedImage != null) {
      return Image.file(
        _selectedImage!,
        width: avatarSize,
        height: avatarSize,
        fit: BoxFit.cover,
        alignment: Alignment.center,
      );
    }

    if (_useDefaultProfileImage) {
      return Image.asset(
        'assets/image/profile_default.png',
        width: avatarSize,
        height: avatarSize,
        fit: BoxFit.cover,
      );
    }

    if (_selectedImage != null) {
      return Image.file(
        _selectedImage!,
        width: avatarSize,
        height: avatarSize,
        fit: BoxFit.cover,
        alignment:
        Alignment.center,
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      key: ValueKey(imageUrl),
      width: avatarSize,
      height: avatarSize,
      fit: BoxFit.cover,
      alignment: Alignment.center,

      memCacheWidth: 600,

      placeholder: (_, __) {
        return Container(
          color: Colors.white.withOpacity(0.06),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white54,
          ),
        );
      },

      errorWidget: (_, __, ___) {
        return Image.asset(
          'assets/image/profile_default.png',
          width: avatarSize,
          height: avatarSize,
          fit: BoxFit.cover,
        );
      },
    );
  }

  Widget _buildNicknameCard(double screenWidth) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.badge_outlined,
            title: '닉네임',
            description: '다른 사용자에게 표시되는 이름이에요.',
            screenWidth: screenWidth,
          ),

          SizedBox(height: screenWidth * 0.04),

          _buildTextField(
            hint: '닉네임을 입력하세요.',
            controller: nicknameController,
            screenWidth: screenWidth,
            maxLength: 12,
          ),

          SizedBox(height: screenWidth * 0.012),

          Text(
            '2~12자의 한글, 영문, 숫자만 사용할 수 있어요.',
            style: TextStyle(
              color: Colors.white38,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.027,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioCard(double screenWidth) {
    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.notes_rounded,
            title: '자기소개',
            description: '나를 간단하게 소개해주세요.',
            screenWidth: screenWidth,
          ),

          SizedBox(height: screenWidth * 0.04),

          _buildTextField(
            hint: '나를 멋지게 소개해보세요.',
            controller: introController,
            screenWidth: screenWidth,
            minLines: 4,
            maxLines: 6,
            maxLength: 120,
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

  Widget _buildTextField({
    required String hint,
    required TextEditingController controller,
    required double screenWidth,
    int? maxLength,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      minLines: minLines,
      maxLines: maxLines,
      style: TextStyle(
        color: Colors.white,
        fontFamily: 'kopub',
        fontSize: screenWidth * 0.034,
        height: 1.45,
      ),
      cursorColor: Colors.amberAccent,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white38,
          fontFamily: 'kopub',
          fontSize: screenWidth * 0.032,
        ),
        counterStyle: TextStyle(
          color: Colors.white38,
          fontFamily: 'kopub',
          fontSize: screenWidth * 0.026,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.035,
          vertical: screenWidth * 0.035,
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
            color: Colors.amberAccent.withOpacity(0.65),
            width: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildSavingIndicator(
      double screenWidth,
      ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.06,
        vertical: screenWidth * 0.045,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF16483F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: screenWidth * 0.045,
            height: screenWidth * 0.045,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.amberAccent,
            ),
          ),

          SizedBox(width: screenWidth * 0.03),

          Text(
            '프로필을 저장하고 있어요.',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.034,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

}
