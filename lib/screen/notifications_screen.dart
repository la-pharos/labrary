import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:dayverse_book/provider/challenge_provider.dart';
import 'package:dayverse_book/service/challenge_social_service.dart';
import 'package:dayverse_book/screen/challenge_detail_screen.dart';
import 'package:dayverse_book/service/notification_service.dart';
import 'package:dayverse_book/screen/friends_screen.dart';
import 'package:cloud_functions/cloud_functions.dart';

class NotificationsScreen
    extends StatelessWidget {
  const NotificationsScreen({
    super.key,
  });

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
        iconTheme:
        const IconThemeData(
          color: Colors.white,
        ),
        centerTitle: true,
        title: Text(
          '알림',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontSize: w * 0.043,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await NotificationService
                    .instance
                    .markAllAsRead();
              } catch (e) {
                debugPrint(
                  '[NotificationsScreen] '
                      '전체 읽음 처리 실패: $e',
                );
              }
            },
            child: Text(
              '모두 읽음',
              style: TextStyle(
                color:
                Colors.amberAccent,
                fontFamily: 'kopub',
                fontSize: w * 0.029,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),

          SizedBox(width: w * 0.02),
        ],
      ),
      body: StreamBuilder<
          List<AppNotificationItem>>(
        stream: NotificationService
            .instance
            .watchNotifications(),
        builder: (
            context,
            snapshot,
            ) {
          if (snapshot.connectionState ==
              ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child:
              CircularProgressIndicator(
                color:
                Colors.amberAccent,
              ),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState(
              w,
            );
          }

          final notifications =
              snapshot.data ?? [];

          if (notifications.isEmpty) {
            return _buildEmptyState(
              w,
            );
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              w * 0.045,
              w * 0.025,
              w * 0.045,
              w * 0.1,
            ),
            itemCount:
            notifications.length,
            separatorBuilder:
                (_, __) =>
                SizedBox(
                  height: w * 0.018,
                ),
            itemBuilder:
                (context, index) {
              final notification =
              notifications[index];

              return _buildNotificationCard(
                context: context,
                notification:
                notification,
                w: w,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard({
    required BuildContext context,
    required AppNotificationItem
    notification,
    required double w,
  }) {
    final isUnread =
    !notification.isRead;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
        BorderRadius.circular(15),
        onTap: () async {
          if (isUnread) {
            try {
              await NotificationService
                  .instance
                  .markAsRead(
                notification.id,
              );
            } catch (e) {
              debugPrint(
                '[NotificationsScreen] '
                    '읽음 처리 실패: $e',
              );
            }
          }

          if (!context.mounted) {
            return;
          }

          await _handleNotificationTap(
            context,
            notification,
          );
        },
        child: Container(
          padding: EdgeInsets.all(
            w * 0.038,
          ),
          decoration: BoxDecoration(
            color: isUnread
                ? const Color(
              0xFF16483F,
            )
                : Colors.white
                .withOpacity(0.045),
            borderRadius:
            BorderRadius.circular(15),
            border: Border.all(
              color: isUnread
                  ? Colors.amberAccent
                  .withOpacity(0.22)
                  : Colors.white
                  .withOpacity(0.06),
            ),
          ),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              _buildTypeIcon(
                notification.type,
                w,
                isUnread,
              ),

              SizedBox(
                width: w * 0.032,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification
                                .title,
                            maxLines: 1,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style:
                            TextStyle(
                              color:
                              Colors.white,
                              fontFamily:
                              'kopub',
                              fontSize:
                              w *
                                  0.034,
                              fontWeight:
                              isUnread
                                  ? FontWeight
                                  .bold
                                  : FontWeight
                                  .w500,
                            ),
                          ),
                        ),

                        if (isUnread)
                          Container(
                            width:
                            w * 0.018,
                            height:
                            w * 0.018,
                            decoration:
                            const BoxDecoration(
                              color: Colors
                                  .amberAccent,
                              shape: BoxShape
                                  .circle,
                            ),
                          ),
                      ],
                    ),

                    SizedBox(
                      height:
                      w * 0.012,
                    ),

                    Text(
                      notification.body,
                      style: TextStyle(
                        color: Colors.white
                            .withOpacity(
                          isUnread
                              ? 0.72
                              : 0.5,
                        ),
                        fontFamily:
                        'kopub',
                        fontSize:
                        w * 0.03,
                        height: 1.4,
                      ),
                    ),

                    if (notification
                        .createdAt !=
                        null) ...[
                      SizedBox(
                        height:
                        w * 0.018,
                      ),

                      Text(
                        _formatDate(
                          notification
                              .createdAt!,
                        ),
                        style: TextStyle(
                          color: Colors.white
                              .withOpacity(
                            0.3,
                          ),
                          fontFamily:
                          'kopub',
                          fontSize:
                          w * 0.025,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(
                width: w * 0.015,
              ),

              Icon(
                Icons
                    .chevron_right_rounded,
                color: Colors.white
                    .withOpacity(0.22),
                size: w * 0.05,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon(
      String type,
      double w,
      bool isUnread,
      ) {
    IconData icon;

    switch (type) {
      case 'friend_request':
        icon = Icons.person_add_alt_1_rounded;
        break;

      case 'friend_accepted':
        icon = Icons.people_alt_rounded;
        break;

      case 'challenge_invite':
        icon = Icons.emoji_events_rounded;
        break;

      case 'challenge_invite_accepted':
        icon = Icons.check_circle_outline_rounded;
        break;

      case 'announcement':
        icon = Icons.campaign_rounded;
        break;

      default:
        icon = Icons.notifications_rounded;
    }

    return Container(
      width: w * 0.105,
      height: w * 0.105,
      decoration: BoxDecoration(
        color: isUnread
            ? Colors.amberAccent.withOpacity(0.1)
            : Colors.white.withOpacity(0.05),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: isUnread
            ? Colors.amberAccent
            : Colors.white.withOpacity(0.5),
        size: w * 0.05,
      ),
    );
  }

  Future<void> _handleNotificationTap(
      BuildContext context,
      AppNotificationItem notification,
      ) async {
    switch (notification.type) {
      case 'friend_request':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
            const FriendsScreen(),
          ),
        );
        break;

      case 'friend_accepted':
        debugPrint(
          '친구 수락 알림 클릭: '
              '${notification.actorUid}',
        );
        break;

      case 'challenge_invite':
        await _handleChallengeInvite(
          context,
          notification,
        );
        break;

      case 'challenge_invite_accepted':
        debugPrint(
          '챌린지 수락 알림 클릭: '
              '${notification.referenceId}',
        );
        break;

      default:
        break;
    }
  }

  Future<void> _handleChallengeInvite(
      BuildContext context,
      AppNotificationItem notification,
      ) async {
    final groupId =
    notification.referenceId.trim();

    final notificationChallengeId =
    notification.challengeId.trim();

    if (groupId.isEmpty ||
        notificationChallengeId.isEmpty) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            '챌린지 초대 정보를 확인할 수 없습니다.',
          ),
        ),
      );

      return;
    }

    final challengeProvider =
    context.read<ChallengeProvider>();

    try {
      // =====================================================
      // 1. 먼저 ChallengeGroup 초대 정보 조회
      //
      // 중요:
      // 커스텀 챌린지는 초대받은 사람의 Provider에
      // 아직 존재하지 않을 수 있으므로 이걸 먼저 읽는다.
      // =====================================================

      final invitation =
      await ChallengeSocialService.instance
          .getChallengeGroupInvitation(
        groupId: groupId,
      );

      if (!context.mounted) return;

      // =====================================================
      // 2. 알림 정보와 그룹 정보 일치 확인
      // =====================================================

      if (invitation.challengeId !=
          notificationChallengeId) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              '챌린지 초대 정보가 일치하지 않습니다.',
            ),
          ),
        );

        return;
      }

      // =====================================================
      // 3. 이미 그룹에 참여 중인 경우
      // =====================================================

      if (invitation.isMember) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              '이미 함께 도전 중인 챌린지입니다.',
            ),
          ),
        );

        return;
      }

      // =====================================================
      // 4. 더 이상 유효하지 않은 초대
      // =====================================================

      if (!invitation.isInvited) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              '더 이상 유효하지 않은 챌린지 초대입니다.',
            ),
          ),
        );

        return;
      }

      // =====================================================
      // 5. Challenge 결정
      //
      // 시스템 챌린지:
      //   현재 사용자 Provider의 Challenge 사용
      //
      // 커스텀 챌린지:
      //   Provider에 없으므로 초대한 사람의 원본 Challenge 사용
      // =====================================================

      final localChallenge =
      challengeProvider.findChallengeById(
        invitation.challengeId,
      );

      final challenge =
          localChallenge ??
              invitation.challenge;

      if (challenge == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              '초대받은 챌린지 정보를 불러올 수 없습니다.',
            ),
          ),
        );

        return;
      }

      // =====================================================
      // 6. 초대 확인 다이얼로그
      // =====================================================

      final action =
      await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          final w =
              MediaQuery.of(dialogContext)
                  .size
                  .width;

          return AlertDialog(
            backgroundColor:
            const Color(0xFF1B2C2E),

            shape:
            RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(16),
            ),

            title: Text(
              '챌린지 초대',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: w * 0.043,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            content: Text(
              '${notification.actorNickname}님이\n'
                  '\'${challenge.title}\' 챌린지에 '
                  '함께 도전하자고 초대했어요.',
              style: TextStyle(
                color:
                Colors.white70,
                fontFamily:
                'kopub',
                fontSize:
                w * 0.033,
                height: 1.5,
              ),
            ),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    'reject',
                  );
                },
                child: const Text(
                  '거절하기',
                  style: TextStyle(
                    color:
                    Colors.white54,
                    fontFamily:
                    'kopub',
                  ),
                ),
              ),

              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    'view',
                  );
                },
                child: const Text(
                  '챌린지 확인',
                  style: TextStyle(
                    color:
                    Colors.amberAccent,
                    fontFamily:
                    'kopub',
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (action == null ||
          !context.mounted) {
        return;
      }

      // =====================================================
      // 7. 초대 거절
      // =====================================================

      if (action == 'reject') {
        try {
          await ChallengeSocialService.instance
              .rejectChallengeInvite(
            groupId: groupId,
          );

          if (!context.mounted) return;

          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                '챌린지 초대를 거절했습니다.',
              ),
            ),
          );
        } catch (e) {
          debugPrint(
            '❌ 챌린지 초대 거절 실패: $e',
          );

          if (!context.mounted) return;

          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                '챌린지 초대를 처리하지 못했습니다.',
              ),
            ),
          );
        }

        return;
      }

      // =====================================================
      // 8. 챌린지 상세 확인
      // =====================================================

      if (action == 'view') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ChallengeDetailScreen(
                  challenge:
                  challenge,
                  invitation:
                  invitation,
                ),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '❌ 챌린지 초대 정보 조회 실패: '
            '${e.code} / ${e.message}',
      );

      if (!context.mounted) return;

      String message =
          '챌린지 초대 정보를 불러오지 못했습니다.';

      if (e.code == 'not-found') {
        message =
        '존재하지 않는 챌린지 초대입니다.';
      } else if (
      e.code == 'permission-denied') {
        message =
        '더 이상 유효하지 않은 챌린지 초대입니다.';
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
          Text(message),
        ),
      );
    } catch (e) {
      debugPrint(
        '❌ 챌린지 초대 처리 실패: $e',
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            '챌린지 초대 정보를 불러오지 못했습니다.',
          ),
        ),
      );
    }
  }

  Widget _buildEmptyState(
      double w,
      ) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(
          w * 0.08,
        ),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Container(
              width: w * 0.18,
              height: w * 0.18,
              decoration: BoxDecoration(
                color: Colors.white
                    .withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons
                    .notifications_none_rounded,
                color: Colors.white
                    .withOpacity(0.25),
                size: w * 0.085,
              ),
            ),

            SizedBox(
              height: w * 0.035,
            ),

            Text(
              '새로운 알림이 없습니다.',
              style: TextStyle(
                color: Colors.white
                    .withOpacity(0.6),
                fontFamily: 'kopub',
                fontSize: w * 0.034,
                fontWeight:
                FontWeight.w500,
              ),
            ),

            SizedBox(
              height: w * 0.012,
            ),

            Text(
              '친구 요청, 챌린지 초대와\nLabrary 소식이 여기에 표시됩니다.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color: Colors.white
                    .withOpacity(0.3),
                fontFamily: 'kopub',
                fontSize: w * 0.028,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
      double w,
      ) {
    return Center(
      child: Text(
        '알림을 불러오지 못했습니다.',
        style: TextStyle(
          color:
          Colors.white.withOpacity(
            0.5,
          ),
          fontFamily: 'kopub',
          fontSize: w * 0.032,
        ),
      ),
    );
  }

  String _formatDate(
      DateTime date,
      ) {
    final now = DateTime.now();

    final difference =
    now.difference(date);

    if (difference.inMinutes < 1) {
      return '방금 전';
    }

    if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    }

    if (difference.inDays < 1) {
      return '${difference.inHours}시간 전';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    }

    return '${date.year}.${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
