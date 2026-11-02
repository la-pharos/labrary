import 'package:flutter/material.dart';

import 'package:dayverse_book/widget/card_box.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChallengeTogetherMember {
  final String uid;
  final String nickname;
  final String profileImageUrl;
  final double progress;

  const ChallengeTogetherMember({
    required this.uid,
    required this.nickname,
    required this.profileImageUrl,
    required this.progress,
  });
}

class ChallengeTogetherCard
    extends StatelessWidget {
  final List<ChallengeTogetherMember> members;
  final VoidCallback onInviteTap;
  final bool isLoading;

  const ChallengeTogetherCard({
    super.key,
    required this.members,
    required this.onInviteTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(
        screenWidth * 0.04,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          // =====================================================
          // HEADER
          // =====================================================

          Row(
            children: [
              Container(
                width:
                screenWidth * 0.09,
                height:
                screenWidth * 0.09,
                decoration:
                BoxDecoration(
                  color: Colors.amberAccent
                      .withOpacity(
                    0.10,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    11,
                  ),
                ),
                child: Icon(
                  Icons.groups_rounded,
                  color:
                  Colors.amberAccent,
                  size:
                  screenWidth * 0.045,
                ),
              ),

              SizedBox(
                width:
                screenWidth * 0.025,
              ),

              Expanded(
                child: Text(
                  members.isEmpty
                      ? '친구와 함께 도전해보세요'
                      : '${members.length}명과 함께 도전 중',
                  style: TextStyle(
                    color:
                    Colors.white,
                    fontFamily:
                    'kopub',
                    fontSize:
                    screenWidth *
                        0.033,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // =====================================================
// 참여 중인 친구
//
// 기존 멤버 데이터가 있으면
// 로딩 중이어도 그대로 표시한다.
// =====================================================

          if (members.isNotEmpty) ...[
            SizedBox(
              height:
              screenWidth * 0.04,
            ),

            ...members.asMap().entries.map(
                  (entry) {
                final index =
                    entry.key;

                final member =
                    entry.value;

                return Column(
                  children: [
                    _buildMemberRow(
                      member,
                      screenWidth,
                    ),

                    if (index !=
                        members.length - 1)
                      Padding(
                        padding:
                        EdgeInsets.symmetric(
                          vertical:
                          screenWidth * 0.025,
                        ),
                        child: Divider(
                          height: 1,
                          color: Colors.white
                              .withOpacity(
                            0.06,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ]

// =====================================================
// 최초 로딩
//
// 아직 멤버 데이터가 없을 때만
// 작고 가벼운 로딩 표시
// =====================================================

          else if (isLoading) ...[
            SizedBox(
              height:
              screenWidth * 0.035,
            ),

            Row(
              children: [
                SizedBox(
                  width:
                  screenWidth * 0.035,
                  height:
                  screenWidth * 0.035,
                  child:
                  const CircularProgressIndicator(
                    color:
                    Colors.amberAccent,
                    strokeWidth:
                    2,
                  ),
                ),

                SizedBox(
                  width:
                  screenWidth * 0.02,
                ),

                Expanded(
                  child: Text(
                    '함께 도전 중인 친구를 불러오는 중...',
                    style: TextStyle(
                      color: Colors.white
                          .withOpacity(
                        0.45,
                      ),
                      fontFamily:
                      'kopub',
                      fontSize:
                      screenWidth * 0.027,
                    ),
                  ),
                ),
              ],
            ),
          ]

// =====================================================
// 친구 없음
// =====================================================

          else ...[
              SizedBox(
                height:
                screenWidth * 0.035,
              ),

              Text(
                '함께 도전하면 서로의 진행률을 확인할 수 있어요.',
                style: TextStyle(
                  color: Colors.white
                      .withOpacity(
                    0.45,
                  ),
                  fontFamily:
                  'kopub',
                  fontSize:
                  screenWidth * 0.028,
                  height:
                  1.5,
                ),
              ),
            ],

          // =====================================================
          // INVITE BUTTON
          // =====================================================

          SizedBox(
            height:
            screenWidth * 0.04,
          ),

          _buildInviteButton(
            screenWidth,
          ),
        ],
      ),
    );
  }

  Widget _buildMemberRow(
      ChallengeTogetherMember member,
      double screenWidth,
      ) {
    final progress =
    member.progress
        .clamp(
      0.0,
      1.0,
    )
        .toDouble();

    final percentage =
    (progress * 100)
        .round()
        .clamp(
      0,
      100,
    );

    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.center,
      children: [
        _buildProfileImage(
          member,
          screenWidth,
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
              Row(
                crossAxisAlignment:
                CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      member.nickname,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      TextStyle(
                        color:
                        Colors.white,
                        fontFamily:
                        'kopub',
                        fontSize:
                        screenWidth *
                            0.03,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),

                  SizedBox(
                    width:
                    screenWidth *
                        0.02,
                  ),

                  Text(
                    '$percentage%',
                    style:
                    TextStyle(
                      color:
                      Colors.amberAccent,
                      fontFamily:
                      'kopub',
                      fontSize:
                      screenWidth *
                          0.031,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ],
              ),

              SizedBox(
                height:
                screenWidth * 0.017,
              ),

              ClipRRect(
                borderRadius:
                BorderRadius.circular(
                  30,
                ),
                child:
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor:
                  Colors.white
                      .withOpacity(
                    0.07,
                  ),
                  color:
                  Colors.amberAccent,
                  minHeight:
                  screenWidth * 0.014,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInviteButton(
      double screenWidth,
      ) {
    return SizedBox(
      width:
      double.infinity,
      child: OutlinedButton(
        onPressed:
        onInviteTap,
        style:
        OutlinedButton.styleFrom(
          foregroundColor:
          Colors.amberAccent,

          side: BorderSide(
            color: Colors.amberAccent
                .withOpacity(
              0.28,
            ),
          ),

          backgroundColor:
          Colors.amberAccent
              .withOpacity(
            0.06,
          ),

          padding:
          EdgeInsets.symmetric(
            vertical:
            screenWidth * 0.031,
          ),

          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              12,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment:
          MainAxisAlignment.center,
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .person_add_alt_1_rounded,
              size:
              screenWidth * 0.038,
            ),

            SizedBox(
              width:
              screenWidth * 0.015,
            ),

            Text(
              members.isEmpty
                  ? '친구 초대하기'
                  : '친구 추가로 초대하기',
              style: TextStyle(
                fontFamily:
                'kopub',
                fontSize:
                screenWidth *
                    0.029,
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage(
      ChallengeTogetherMember member,
      double screenWidth,
      ) {
    final size =
        screenWidth * 0.09;

    if (member.profileImageUrl
        .trim()
        .isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration:
        BoxDecoration(
          shape:
          BoxShape.circle,
          color: Colors.white
              .withOpacity(
            0.07,
          ),
        ),
        child: Icon(
          Icons.person_rounded,
          color: Colors.white
              .withOpacity(
            0.40,
          ),
          size:
          screenWidth * 0.045,
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: member.profileImageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,

        // 실제 표시 크기가 작으니
        // 메모리에 너무 큰 이미지로 올리지 않음
        memCacheWidth: 200,

        placeholder: (_, __) {
          return Container(
            width: size,
            height: size,
            color: Colors.white.withOpacity(0.07),
            alignment: Alignment.center,
            child: Icon(
              Icons.person_rounded,
              color: Colors.white38,
              size: screenWidth * 0.045,
            ),
          );
        },

        errorWidget: (_, __, ___) {
          return Container(
            width: size,
            height: size,
            color: Colors.white.withOpacity(0.07),
            alignment: Alignment.center,
            child: Icon(
              Icons.person_rounded,
              color: Colors.white38,
              size: screenWidth * 0.045,
            ),
          );
        },
      ),
    );
  }
}
