import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';

class ProfileImageCropScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const ProfileImageCropScreen({
    super.key,
    required this.imageBytes,
  });

  @override
  State<ProfileImageCropScreen> createState() =>
      _ProfileImageCropScreenState();
}

class _ProfileImageCropScreenState
    extends State<ProfileImageCropScreen> {
  final CropController _cropController =
  CropController();

  bool _isCropping = false;

  void _crop() {
    if (_isCropping) return;

    setState(() {
      _isCropping = true;
    });

    _cropController.crop();
  }

  @override
  Widget build(BuildContext context) {
    final w =
        MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor:
      const Color(0xFF013328),
      appBar: AppBar(
        backgroundColor:
        const Color(0xFF013328),
        elevation: 0,
        centerTitle: true,
        iconTheme:
        const IconThemeData(
          color: Colors.white,
        ),
        title: Text(
          '프로필 사진 조정',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontSize: w * 0.043,
            fontWeight:
            FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed:
            _isCropping
                ? null
                : _crop,
            child: Text(
              '완료',
              style: TextStyle(
                color: _isCropping
                    ? Colors.white38
                    : Colors.amberAccent,
                fontFamily: 'kopub',
                fontSize: w * 0.037,
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: w * 0.04,
          ),

          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: w * 0.07,
            ),
            child: Text(
              '원 안에 프로필로 사용할 부분을 맞춰주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white
                    .withOpacity(0.6),
                fontFamily: 'kopub',
                fontSize: w * 0.032,
              ),
            ),
          ),

          SizedBox(
            height: w * 0.05,
          ),

          Expanded(
            child: Crop(
              controller:
              _cropController,
              image:
              widget.imageBytes,

              aspectRatio: 1,

              withCircleUi: true,

              interactive: true,

              fixCropRect: true,

              baseColor:
              const Color(
                0xFF013328,
              ),

              maskColor:
              Colors.black
                  .withOpacity(
                0.65,
              ),

              radius: 0,

              onCropped: (
                  result,
                  ) {
                switch (result) {
                  case CropSuccess(
                      :final croppedImage,
                  ):
                    Navigator.pop(
                      context,
                      croppedImage,
                    );

                  case CropFailure(
                      :final cause,
                  ):
                    debugPrint(
                      '❌ 프로필 크롭 실패: '
                          '$cause',
                    );

                    if (mounted) {
                      setState(() {
                        _isCropping =
                        false;
                      });
                    }
                }
              },
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(
              w * 0.06,
              w * 0.035,
              w * 0.06,
              w * 0.07,
            ),
            child: Row(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                Icon(
                  Icons
                      .zoom_in_rounded,
                  color: Colors.white
                      .withOpacity(0.4),
                  size: w * 0.04,
                ),

                SizedBox(
                  width: w * 0.018,
                ),

                Text(
                  '사진을 드래그하거나 확대해서 위치를 조정할 수 있어요.',
                  style: TextStyle(
                    color: Colors.white
                        .withOpacity(
                      0.4,
                    ),
                    fontFamily:
                    'kopub',
                    fontSize:
                    w * 0.027,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}