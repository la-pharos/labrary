import 'package:flutter/material.dart';

import 'package:dayverse_book/service/friend_service.dart';

class ChallengeFriendInviteSheet
    extends StatefulWidget {
  const ChallengeFriendInviteSheet({
    super.key,
  });

  @override
  State<ChallengeFriendInviteSheet>
  createState() =>
      _ChallengeFriendInviteSheetState();
}

class _ChallengeFriendInviteSheetState
    extends State<ChallengeFriendInviteSheet> {
  final Set<String> _selectedFriendUids =
  <String>{};

  List<FriendItem> _friends = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _loadFriends();
  }

  Future<void> _loadFriends() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final friends =
      await FriendService.instance
          .getFriends();

      if (!mounted) return;

      setState(() {
        _friends = friends;
      });
    } catch (e) {
      debugPrint(
        '[ChallengeFriendInviteSheet] '
            '친구 목록 로드 실패: $e',
      );

      if (!mounted) return;

      setState(() {
        _errorMessage =
        '친구 목록을 불러오지 못했습니다.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleFriend(
      FriendItem friend,
      ) {
    setState(() {
      if (_selectedFriendUids
          .contains(friend.uid)) {
        _selectedFriendUids.remove(
          friend.uid,
        );
      } else {
        _selectedFriendUids.add(
          friend.uid,
        );
      }
    });
  }

  void _completeSelection() {
    final selectedFriends =
    _friends
        .where(
          (friend) =>
          _selectedFriendUids
              .contains(
            friend.uid,
          ),
    )
        .toList();

    Navigator.pop(
      context,
      selectedFriends,
    );
  }

  Widget _buildProfileImage(
      String imageUrl,
      double screenWidth,
      ) {
    final size =
        screenWidth * 0.115;

    if (imageUrl.trim().isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
          Colors.white.withOpacity(
            0.08,
          ),
        ),
        child: Icon(
          Icons.person_rounded,
          color:
          Colors.white.withOpacity(
            0.55,
          ),
          size:
          screenWidth * 0.06,
        ),
      );
    }

    return ClipOval(
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: 300,
        errorBuilder: (
            context,
            error,
            stackTrace,
            ) {
          return Container(
            width: size,
            height: size,
            color:
            Colors.white.withOpacity(
              0.08,
            ),
            child: Icon(
              Icons.person_rounded,
              color:
              Colors.white.withOpacity(
                0.55,
              ),
              size:
              screenWidth * 0.06,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFriendItem(
      FriendItem friend,
      double screenWidth,
      ) {
    final isSelected =
    _selectedFriendUids.contains(
      friend.uid,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
        BorderRadius.circular(14),
        onTap: () {
          _toggleFriend(
            friend,
          );
        },
        child: AnimatedContainer(
          duration:
          const Duration(
            milliseconds: 150,
          ),
          padding:
          EdgeInsets.symmetric(
            horizontal:
            screenWidth * 0.035,
            vertical:
            screenWidth * 0.03,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.amberAccent
                .withOpacity(
              0.07,
            )
                : Colors.white
                .withOpacity(
              0.035,
            ),
            borderRadius:
            BorderRadius.circular(
              14,
            ),
            border: Border.all(
              color: isSelected
                  ? Colors.amberAccent
                  .withOpacity(
                0.38,
              )
                  : Colors.white
                  .withOpacity(
                0.065,
              ),
            ),
          ),
          child: Row(
            children: [
              _buildProfileImage(
                friend.profileImageUrl,
                screenWidth,
              ),

              SizedBox(
                width:
                screenWidth * 0.03,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      friend.nickname,
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
                        screenWidth *
                            0.035,
                        fontWeight:
                        FontWeight
                            .w600,
                      ),
                    ),

                    if (friend.bio
                        .trim()
                        .isNotEmpty) ...[
                      SizedBox(
                        height:
                        screenWidth *
                            0.007,
                      ),

                      Text(
                        friend.bio,
                        maxLines: 1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        TextStyle(
                          color: Colors
                              .white
                              .withOpacity(
                            0.42,
                          ),
                          fontFamily:
                          'kopub',
                          fontSize:
                          screenWidth *
                              0.027,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(
                width:
                screenWidth * 0.02,
              ),

              AnimatedContainer(
                duration:
                const Duration(
                  milliseconds: 150,
                ),
                width:
                screenWidth * 0.065,
                height:
                screenWidth * 0.065,
                decoration:
                BoxDecoration(
                  shape:
                  BoxShape.circle,
                  color: isSelected
                      ? Colors
                      .amberAccent
                      : Colors.white
                      .withOpacity(
                    0.05,
                  ),
                  border:
                  Border.all(
                    color: isSelected
                        ? Colors
                        .amberAccent
                        : Colors.white
                        .withOpacity(
                      0.15,
                    ),
                  ),
                ),
                child: isSelected
                    ? Icon(
                  Icons
                      .check_rounded,
                  color:
                  const Color(
                    0xFF013328,
                  ),
                  size:
                  screenWidth *
                      0.04,
                )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(
      double screenWidth,
      ) {
    return Padding(
      padding:
      EdgeInsets.symmetric(
        vertical:
        screenWidth * 0.16,
      ),
      child: const Center(
        child:
        CircularProgressIndicator(
          color:
          Colors.amberAccent,
          strokeWidth: 2.5,
        ),
      ),
    );
  }

  Widget _buildError(
      double screenWidth,
      ) {
    return Padding(
      padding:
      EdgeInsets.symmetric(
        vertical:
        screenWidth * 0.10,
      ),
      child: Column(
        children: [
          Icon(
            Icons
                .error_outline_rounded,
            color:
            Colors.white.withOpacity(
              0.35,
            ),
            size:
            screenWidth * 0.09,
          ),

          SizedBox(
            height:
            screenWidth * 0.025,
          ),

          Text(
            _errorMessage ??
                '친구 목록을 불러오지 못했습니다.',
            textAlign:
            TextAlign.center,
            style: TextStyle(
              color:
              Colors.white.withOpacity(
                0.5,
              ),
              fontFamily:
              'kopub',
              fontSize:
              screenWidth * 0.03,
            ),
          ),

          SizedBox(
            height:
            screenWidth * 0.025,
          ),

          TextButton(
            onPressed:
            _loadFriends,
            child: const Text(
              '다시 시도',
              style:
              TextStyle(
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
      ),
    );
  }

  Widget _buildEmpty(
      double screenWidth,
      ) {
    return Padding(
      padding:
      EdgeInsets.symmetric(
        vertical:
        screenWidth * 0.12,
      ),
      child: Column(
        children: [
          Icon(
            Icons
                .people_outline_rounded,
            color:
            Colors.white.withOpacity(
              0.25,
            ),
            size:
            screenWidth * 0.10,
          ),

          SizedBox(
            height:
            screenWidth * 0.025,
          ),

          Text(
            '함께 도전할 친구가 없습니다.',
            style:
            TextStyle(
              color:
              Colors.white.withOpacity(
                0.55,
              ),
              fontFamily:
              'kopub',
              fontSize:
              screenWidth * 0.032,
              fontWeight:
              FontWeight.w500,
            ),
          ),

          SizedBox(
            height:
            screenWidth * 0.012,
          ),

          Text(
            '먼저 친구를 추가해주세요.',
            style:
            TextStyle(
              color:
              Colors.white.withOpacity(
                0.32,
              ),
              fontFamily:
              'kopub',
              fontSize:
              screenWidth * 0.027,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final screenWidth =
        MediaQuery.of(context)
            .size
            .width;

    final screenHeight =
        MediaQuery.of(context)
            .size
            .height;

    final selectedCount =
        _selectedFriendUids.length;

    return SafeArea(
      top: false,
      child: Container(
        constraints:
        BoxConstraints(
          maxHeight:
          screenHeight * 0.78,
        ),
        decoration:
        const BoxDecoration(
          color:
          Color(0xFF16483F),
          borderRadius:
          BorderRadius.vertical(
            top:
            Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            SizedBox(
              height:
              screenWidth * 0.025,
            ),

            Container(
              width:
              screenWidth * 0.11,
              height: 4,
              decoration:
              BoxDecoration(
                color: Colors.white
                    .withOpacity(
                  0.18,
                ),
                borderRadius:
                BorderRadius.circular(
                  999,
                ),
              ),
            ),

            Padding(
              padding:
              EdgeInsets.fromLTRB(
                screenWidth * 0.05,
                screenWidth * 0.04,
                screenWidth * 0.03,
                screenWidth * 0.025,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          '함께 도전할 친구',
                          style:
                          TextStyle(
                            color:
                            Colors.white,
                            fontFamily:
                            'kopub',
                            fontSize:
                            screenWidth *
                                0.045,
                            fontWeight:
                            FontWeight
                                .bold,
                          ),
                        ),

                        SizedBox(
                          height:
                          screenWidth *
                              0.008,
                        ),

                        Text(
                          '챌린지에 초대할 친구를 선택해주세요.',
                          style:
                          TextStyle(
                            color: Colors
                                .white
                                .withOpacity(
                              0.45,
                            ),
                            fontFamily:
                            'kopub',
                            fontSize:
                            screenWidth *
                                0.028,
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );
                    },
                    icon:
                    const Icon(
                      Icons
                          .close_rounded,
                      color:
                      Colors.white54,
                    ),
                  ),
                ],
              ),
            ),

            Divider(
              height: 1,
              thickness: 1,
              color: Colors.white
                  .withOpacity(
                0.07,
              ),
            ),

            Flexible(
              child: _isLoading
                  ? _buildLoading(
                screenWidth,
              )
                  : _errorMessage !=
                  null
                  ? SingleChildScrollView(
                child:
                _buildError(
                  screenWidth,
                ),
              )
                  : _friends
                  .isEmpty
                  ? SingleChildScrollView(
                child:
                _buildEmpty(
                  screenWidth,
                ),
              )
                  : ListView.separated(
                padding:
                EdgeInsets.all(
                  screenWidth *
                      0.04,
                ),
                itemCount:
                _friends
                    .length,
                separatorBuilder:
                    (
                    context,
                    index,
                    ) {
                  return SizedBox(
                    height:
                    screenWidth *
                        0.018,
                  );
                },
                itemBuilder:
                    (
                    context,
                    index,
                    ) {
                  return _buildFriendItem(
                    _friends[
                    index],
                    screenWidth,
                  );
                },
              ),
            ),

            if (!_isLoading &&
                _errorMessage == null &&
                _friends.isNotEmpty)
              Container(
                width:
                double.infinity,
                padding:
                EdgeInsets.fromLTRB(
                  screenWidth * 0.045,
                  screenWidth * 0.025,
                  screenWidth * 0.045,
                  screenWidth * 0.035,
                ),
                decoration:
                BoxDecoration(
                  border:
                  Border(
                    top:
                    BorderSide(
                      color: Colors
                          .white
                          .withOpacity(
                        0.07,
                      ),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    if (selectedCount >
                        0) ...[
                      Text(
                        '$selectedCount명 선택됨',
                        style:
                        TextStyle(
                          color: Colors
                              .white
                              .withOpacity(
                            0.45,
                          ),
                          fontFamily:
                          'kopub',
                          fontSize:
                          screenWidth *
                              0.027,
                        ),
                      ),

                      SizedBox(
                        height:
                        screenWidth *
                            0.018,
                      ),
                    ],

                    SizedBox(
                      width:
                      double.infinity,
                      child:
                      ElevatedButton(
                        onPressed:
                        selectedCount ==
                            0
                            ? null
                            : _completeSelection,
                        style:
                        ElevatedButton
                            .styleFrom(
                          elevation: 0,
                          backgroundColor:
                          Colors
                              .amberAccent,
                          disabledBackgroundColor:
                          Colors
                              .amberAccent
                              .withOpacity(
                            0.28,
                          ),
                          foregroundColor:
                          const Color(
                            0xFF013328,
                          ),
                          padding:
                          EdgeInsets
                              .symmetric(
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
                        Text(
                          selectedCount ==
                              0
                              ? '친구를 선택해주세요'
                              : '$selectedCount명 선택 완료',
                          style:
                          TextStyle(
                            fontFamily:
                            'kopub',
                            fontSize:
                            screenWidth *
                                0.033,
                            fontWeight:
                            FontWeight
                                .bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}