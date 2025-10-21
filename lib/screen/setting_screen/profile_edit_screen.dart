import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:dayverse_book/widget/ad_banner_placeholder.dart';


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
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _loadUserProfile();
    }
  }

  void _loadUserProfile() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      nicknameController.text = data['nickname'] ?? '';
      introController.text = data['bio'] ?? '';

      final imageUrl = data['profileImageUrl'];
      if (imageUrl != null && mounted) {
        setState(() {
          userPhotoUrl = imageUrl;
          _selectedImage = null;
        });
      }
    }
  }

  bool _isValidNickname(String nickname) {
    final trimmed = nickname.trim();
    final regExp = RegExp(r'^[a-zA-Z0-9가-힣]{2,12}$');
    return regExp.hasMatch(trimmed);
  }

  Future<bool> _isNicknameDuplicated(String nickname) async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('nickname', isEqualTo: nickname)
        .get();
    return query.docs.any((doc) => doc.id != user!.uid);
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
        cacheControl: 'no-cache, no-store, max-age=0, must-revalidate',
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
    final nickname = nicknameController.text.trim();
    final bio = introController.text.trim();

    if (!_isValidNickname(nickname)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("닉네임은 2~12자의 한글, 영문, 숫자만 사용할 수 있어요.")),
      );
      return;
    }

    if (await _isNicknameDuplicated(nickname)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("이미 사용 중인 닉네임입니다.")),
      );
      return;
    }

    setState(() => _isUploading = true);

    String? imageUrl;
    if (_selectedImage != null) {
      imageUrl = await _uploadProfileImage(_selectedImage!);
    }

    final updateData = {
      'nickname': nickname,
      'bio': bio,
      if (imageUrl != null) 'profileImageUrl': imageUrl,
    };

    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update(updateData);

    setState(() => _isUploading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("프로필이 저장되었습니다.")),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        userPhotoUrl = null; // ✅ 기존 이미지 제거 (기본 이미지로 복원)
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final horizontalPadding = screenWidth * 0.05;
    final avatarRadius = screenWidth * 0.18;
    final iconSize = screenWidth * 0.05;
    final titleFontSize = screenWidth * 0.045;
    final buttonFontSize = screenWidth * 0.04;
    final labelFontSize = screenWidth * 0.04;
    final hintFontSize = screenWidth * 0.035;

    return GestureDetector(
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
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white, size: iconSize),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            '프로필 변경',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: titleFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: _isUploading ? null : _saveProfile,
              child: Text(
                '저장',
                style: TextStyle(
                  color: _isUploading ? Colors.white54 : Colors.white,
                  fontSize: buttonFontSize,
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            // ✅ 본문 내용 (SafeArea + ScrollView)
            SizedBox(
              height: screenHeight,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: horizontalPadding,
                    right: horizontalPadding,
                    bottom: screenHeight * 0.08, // ✅ 광고 높이만큼 패딩
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: screenHeight * 0.04),
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: avatarRadius,
                            backgroundImage: _selectedImage != null
                                ? FileImage(_selectedImage!)
                                : (userPhotoUrl != null && userPhotoUrl!.trim().isNotEmpty
                                ? NetworkImage(userPhotoUrl!)
                                : const AssetImage("assets/image/profile_default.png") as ImageProvider),
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                padding: EdgeInsets.all(iconSize * 0.4),
                                child: Icon(Icons.add_a_photo, size: iconSize, color: Colors.black87),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.05),
                      _buildInputField("닉네임", nicknameController, "닉네임을 입력하세요",
                          labelFontSize, hintFontSize, isMultiline: false),
                      _buildInputField("자기소개", introController, "나를 멋지게 소개해 봐요 :)",
                          labelFontSize, hintFontSize, isMultiline: true),
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

            // ✅ 업로드 중 로딩 표시
            if (_isUploading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, String hint,
      double labelFontSize, double hintFontSize,
      {bool isMultiline = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white70, fontSize: labelFontSize)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: controller,
            style: TextStyle(color: Colors.white, fontSize: hintFontSize + 1),
            maxLines: isMultiline ? null : 1,
            minLines: isMultiline ? 3 : 1,
            keyboardType: isMultiline ? TextInputType.multiline : TextInputType.text,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white38, fontSize: hintFontSize),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
