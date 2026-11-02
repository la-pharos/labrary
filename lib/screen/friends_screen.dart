import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:dayverse_book/service/friend_service.dart';
import 'package:dayverse_book/screen/friend_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() =>
      _FriendsScreenState();
}

class _FriendsScreenState
    extends State<FriendsScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  FriendSearchResult? _searchResult;

  List<FriendRequestItem> _receivedRequests = [];
  List<FriendItem> _friends = [];

  bool _isSearching = false;
  bool _isLoadingRequests = false;
  bool _isLoadingFriends = false;
  bool _isSendingFriendRequest = false;

  final Set<String> _processingRequestIds =
  <String>{};

  String? _searchMessage;

  @override
  void initState() {
    super.initState();

    final cachedFriends =
        FriendService.instance
            .cachedFriends;

    if (cachedFriends != null) {
      _friends =
      List<FriendItem>.from(
        cachedFriends,
      );
    }

    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadReceivedRequests(),
      _loadFriends(),
    ]);
  }

  Future<void> _loadReceivedRequests() async {
    if (_isLoadingRequests) return;

    setState(() {
      _isLoadingRequests = true;
    });

    try {
      final requests =
      await FriendService.instance
          .getReceivedFriendRequests();

      if (!mounted) return;

      setState(() {
        _receivedRequests = requests;
      });
    } catch (e) {
      debugPrint(
        '[FriendsScreen] 친구 요청 로드 실패: $e',
      );

      if (!mounted) return;

      _showMessage(
        '친구 요청을 불러오지 못했습니다.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRequests = false;
        });
      }
    }
  }

  Future<void> _loadFriends() async {
    if (_isLoadingFriends) return;

    setState(() {
      _isLoadingFriends = true;
    });

    try {
      // 캐시가 있으면 이미 initState에서 먼저 화면에 보여주고 있음.
      // 여기서는 서버에서 최신 친구 정보를 다시 가져온다.
      final friends =
      await FriendService.instance.getFriends(
        forceRefresh: true,
      );

      debugPrint(
        '✅ [FriendsScreen] 불러온 친구 수: ${friends.length}',
      );

      if (!mounted) return;

      setState(() {
        _friends = friends;
      });
    } catch (e) {
      debugPrint(
        '[FriendsScreen] 친구 목록 로드 실패: $e',
      );

      if (!mounted) return;

      // 기존 캐시 친구가 이미 화면에 있다면
      // 굳이 오류 메시지까지 띄우지 않아도 됨
      if (_friends.isEmpty) {
        _showMessage(
          '친구 목록을 불러오지 못했습니다.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFriends = false;
        });
      }
    }
  }

  Future<void> _searchUser() async {
    if (_isSearching) return;

    final nickname =
    _searchController.text.trim();

    if (nickname.isEmpty) {
      _showMessage(
        '검색할 닉네임을 입력해주세요.',
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResult = null;
      _searchMessage = null;
    });

    try {
      final result =
      await FriendService.instance
          .searchUserByNickname(
        nickname,
      );

      if (!mounted) return;

      setState(() {
        _searchResult = result;

        if (result == null) {
          _searchMessage =
          '사용자를 찾을 수 없습니다.';
        }
      });
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '[FriendsScreen] 사용자 검색 실패: '
            '${e.code} / ${e.message}',
      );

      if (!mounted) return;

      setState(() {
        _searchMessage =
            e.message ??
                '사용자 검색 중 오류가 발생했습니다.';
      });
    } catch (e) {
      debugPrint(
        '[FriendsScreen] 사용자 검색 실패: $e',
      );

      if (!mounted) return;

      setState(() {
        _searchMessage =
        '사용자 검색 중 오류가 발생했습니다.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _sendFriendRequest(
      FriendSearchResult user,
      ) async {
    if (_isSendingFriendRequest) {
      return;
    }

    setState(() {
      _isSendingFriendRequest = true;
    });

    try {
      await FriendService.instance
          .sendFriendRequest(
        user.uid,
      );

      if (!mounted) return;

      _showMessage(
        '${user.nickname}님에게 친구 요청을 보냈습니다.',
      );

      setState(() {
        _searchResult = null;
        _searchMessage = null;
        _searchController.clear();
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      _showMessage(
        e.message ??
            '친구 요청을 보내지 못했습니다.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        '친구 요청을 보내지 못했습니다.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingFriendRequest = false;
        });
      }
    }
  }

  Future<void> _acceptRequest(
      FriendRequestItem request,
      ) async {
    if (_processingRequestIds
        .contains(request.requestId)) {
      return;
    }

    setState(() {
      _processingRequestIds.add(
        request.requestId,
      );
    });

    try {
      await FriendService.instance
          .acceptFriendRequest(
        request.requestId,
      );

      if (!mounted) return;

      _showMessage(
        '${request.nickname}님과 친구가 되었습니다.',
      );

      await Future.wait([
        _loadReceivedRequests(),
        _loadFriends(),
      ]);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      _showMessage(
        e.message ??
            '친구 요청을 수락하지 못했습니다.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        '친구 요청을 수락하지 못했습니다.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingRequestIds.remove(
            request.requestId,
          );
        });
      }
    }
  }

  Future<void> _rejectRequest(
      FriendRequestItem request,
      ) async {
    if (_processingRequestIds
        .contains(request.requestId)) {
      return;
    }

    setState(() {
      _processingRequestIds.add(
        request.requestId,
      );
    });

    try {
      await FriendService.instance
          .rejectFriendRequest(
        request.requestId,
      );

      if (!mounted) return;

      _showMessage(
        '친구 요청을 거절했습니다.',
      );

      await _loadReceivedRequests();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      _showMessage(
        e.message ??
            '친구 요청을 거절하지 못했습니다.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        '친구 요청을 거절하지 못했습니다.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingRequestIds.remove(
            request.requestId,
          );
        });
      }
    }
  }

  Future<void> _openFriend(
      FriendItem friend,
      ) async {
    final changed =
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FriendScreen(
              friendUid: friend.uid,
            ),
      ),
    );

    if (changed == true) {
      await _loadFriends();
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Widget _buildProfileImage(
      String imageUrl, {
        double radius = 24,
      }) {
    final trimmedUrl = imageUrl.trim();

    if (trimmedUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white.withOpacity(0.1),
        child: Icon(
          Icons.person_rounded,
          color: Colors.white.withOpacity(0.75),
          size: radius,
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white.withOpacity(0.1),
      backgroundImage: CachedNetworkImageProvider(
        trimmedUrl,
        maxWidth: 200,
        maxHeight: 200,
      ),
    );
  }

  Widget _buildSearchSection(
      double w,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          '함께 읽을 친구를 찾아보세요.',
          style: TextStyle(
            color: Colors.white
                .withOpacity(0.55),
            fontFamily: 'kopub',
            fontSize: w * 0.032,
            height: 1.4,
          ),
        ),

        SizedBox(height: w * 0.035),

        Container(
          decoration: BoxDecoration(
            color:
            Colors.white.withOpacity(0.07),
            borderRadius:
            BorderRadius.circular(14),
            border: Border.all(
              color:
              Colors.white.withOpacity(0.08),
            ),
          ),
          child: TextField(
            controller: _searchController,
            textInputAction:
            TextInputAction.search,
            onSubmitted: (_) =>
                _searchUser(),
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: w * 0.034,
            ),
            decoration: InputDecoration(
              hintText: '닉네임으로 친구 검색',
              hintStyle: TextStyle(
                color: Colors.white
                    .withOpacity(0.35),
                fontFamily: 'kopub',
                fontSize: w * 0.033,
              ),
              border: InputBorder.none,
              contentPadding:
              EdgeInsets.symmetric(
                horizontal: w * 0.035,
                vertical: w * 0.035,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: Colors.white
                    .withOpacity(0.45),
                size: w * 0.052,
              ),
              suffixIcon: _isSearching
                  ? Padding(
                padding: EdgeInsets.all(
                  w * 0.035,
                ),
                child:
                const CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                  Colors.amberAccent,
                ),
              )
                  : IconButton(
                onPressed:
                _searchUser,
                icon: Icon(
                  Icons
                      .arrow_forward_rounded,
                  color:
                  Colors.amberAccent,
                  size: w * 0.055,
                ),
              ),
            ),
          ),
        ),

        if (_searchResult != null) ...[
          SizedBox(height: w * 0.025),
          _buildSearchResult(
            _searchResult!,
            w,
          ),
        ],

        if (_searchMessage != null) ...[
          SizedBox(height: w * 0.02),

          Padding(
            padding: EdgeInsets.only(
              left: w * 0.01,
            ),
            child: Text(
              _searchMessage!,
              style: TextStyle(
                color: Colors.white
                    .withOpacity(0.45),
                fontFamily: 'kopub',
                fontSize: w * 0.03,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchResult(
      FriendSearchResult user,
      double w,
      ) {
    return Container(
      padding: EdgeInsets.all(
        w * 0.035,
      ),
      decoration: BoxDecoration(
        color:
        const Color(0xFF16483F),
        borderRadius:
        BorderRadius.circular(15),
        border: Border.all(
          color:
          Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          _buildProfileImage(
            user.profileImageUrl,
            radius: 23,
          ),

          SizedBox(width: w * 0.03),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  user.nickname,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize: w * 0.036,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),

                if (user.bio.isNotEmpty) ...[
                  SizedBox(
                    height: w * 0.007,
                  ),

                  Text(
                    user.bio,
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white
                          .withOpacity(0.45),
                      fontFamily: 'kopub',
                      fontSize: w * 0.028,
                    ),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(width: w * 0.02),

          SizedBox(
            height: w * 0.09,
            child: ElevatedButton(
              onPressed: _isSendingFriendRequest
                  ? null
                  : () {
                _sendFriendRequest(
                  user,
                );
              },
              style:
              ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor:
                Colors.amberAccent,
                foregroundColor:
                const Color(0xFF013328),
                padding:
                EdgeInsets.symmetric(
                  horizontal: w * 0.028,
                ),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),
              ),
              child: _isSendingFriendRequest
                  ? SizedBox(
                width: w * 0.04,
                height: w * 0.04,
                child:
                const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF013328),
                ),
              )
                  : Text(
                '친구 추가',
                style: TextStyle(
                  fontFamily: 'kopub',
                  fontSize: w * 0.028,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsSection(
      double w,
      ) {
    if (_isLoadingRequests) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.amberAccent,
        ),
      );
    }

    if (_receivedRequests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '받은 요청',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: w * 0.04,
                fontWeight:
                FontWeight.w600,
              ),
            ),

            SizedBox(width: w * 0.018),

            Container(
              padding:
              EdgeInsets.symmetric(
                horizontal: w * 0.022,
                vertical: w * 0.008,
              ),
              decoration: BoxDecoration(
                color: Colors.amberAccent,
                borderRadius:
                BorderRadius.circular(
                  999,
                ),
              ),
              child: Text(
                '${_receivedRequests.length}',
                style: TextStyle(
                  color:
                  const Color(0xFF013328),
                  fontFamily: 'kopub',
                  fontSize: w * 0.025,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: w * 0.022),

        Column(
          children:
          _receivedRequests.map(
                (request) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: w * 0.018,
                ),
                child:
                _buildRequestItem(
                  request,
                  w,
                ),
              );
            },
          ).toList(),
        ),
      ],
    );
  }

  Widget _buildRequestItem(
      FriendRequestItem request,
      double w,
      ) {
    final isProcessing =
    _processingRequestIds.contains(
      request.requestId,
    );

    return Container(
      padding: EdgeInsets.all(
        w * 0.035,
      ),
      decoration: BoxDecoration(
        color:
        const Color(0xFF16483F),
        borderRadius:
        BorderRadius.circular(15),
        border: Border.all(
          color:
          Colors.white.withOpacity(0.07),
        ),
      ),
      child: Row(
        children: [
          _buildProfileImage(
            request.profileImageUrl,
            radius: 22,
          ),

          SizedBox(width: w * 0.028),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  request.nickname,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize: w * 0.035,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),

                if (request.bio.isNotEmpty) ...[
                  SizedBox(
                    height: w * 0.006,
                  ),

                  Text(
                    request.bio,
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white
                          .withOpacity(0.45),
                      fontFamily: 'kopub',
                      fontSize: w * 0.027,
                    ),
                  ),
                ],
              ],
            ),
          ),

          TextButton(
            onPressed: isProcessing
                ? null
                : () {
              _rejectRequest(
                request,
              );
            },
            child: Text(
              '거절',
              style: TextStyle(
                color: isProcessing
                    ? Colors.white24
                    : Colors.white.withOpacity(0.45),
                fontFamily: 'kopub',
                fontSize: w * 0.027,
              ),
            ),
          ),

          SizedBox(width: w * 0.005),

          SizedBox(
            height: w * 0.085,
            child: ElevatedButton(
              onPressed: isProcessing
                  ? null
                  : () {
                _acceptRequest(
                  request,
                );
              },
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor:
                Colors.amberAccent,
                disabledBackgroundColor:
                Colors.amberAccent
                    .withOpacity(0.65),
                foregroundColor:
                const Color(0xFF013328),
                padding: EdgeInsets.symmetric(
                  horizontal: w * 0.025,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(10),
                ),
              ),
              child: isProcessing
                  ? SizedBox(
                width: w * 0.038,
                height: w * 0.038,
                child:
                const CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                  Color(0xFF013328),
                ),
              )
                  : Text(
                '수락',
                style: TextStyle(
                  fontFamily: 'kopub',
                  fontSize: w * 0.027,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsSection(
      double w,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '내 친구',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: w * 0.04,
                fontWeight:
                FontWeight.w600,
              ),
            ),

            SizedBox(width: w * 0.018),

            Text(
              '${_friends.length}',
              style: TextStyle(
                color: Colors.white
                    .withOpacity(0.4),
                fontFamily: 'kopub',
                fontSize: w * 0.03,
              ),
            ),
          ],
        ),

        SizedBox(height: w * 0.022),

        if (_friends.isEmpty &&
            _isLoadingFriends)
          const Center(
            child:
            CircularProgressIndicator(
              color:
              Colors.amberAccent,
            ),
          )
        else if (_friends.isEmpty)
          _buildEmptyFriends(w)
        else
          Container(
            decoration: BoxDecoration(
              color:
              const Color(0xFF16483F),
              borderRadius:
              BorderRadius.circular(15),
              border: Border.all(
                color: Colors.white
                    .withOpacity(0.07),
              ),
            ),
            child: Column(
              children: List.generate(
                _friends.length,
                    (index) {
                  final friend =
                  _friends[index];

                  return Column(
                    children: [
                      Material(
                        color:
                        Colors.transparent,
                        child: InkWell(
                          borderRadius:
                          BorderRadius.circular(
                            15,
                          ),
                          onTap: () =>
                              _openFriend(
                                friend,
                              ),
                          child: Padding(
                            padding:
                            EdgeInsets.symmetric(
                              horizontal:
                              w * 0.035,
                              vertical:
                              w * 0.03,
                            ),
                            child: Row(
                              children: [
                                _buildProfileImage(
                                  friend
                                      .profileImageUrl,
                                  radius: 22,
                                ),

                                SizedBox(
                                  width:
                                  w * 0.03,
                                ),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                    children: [
                                      Text(
                                        friend
                                            .nickname,
                                        maxLines:
                                        1,
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
                                          w * 0.035,
                                          fontWeight:
                                          FontWeight
                                              .w600,
                                        ),
                                      ),

                                      if (friend
                                          .bio
                                          .isNotEmpty) ...[
                                        SizedBox(
                                          height:
                                          w * 0.006,
                                        ),
                                        Text(
                                          friend
                                              .bio,
                                          maxLines:
                                          1,
                                          overflow:
                                          TextOverflow
                                              .ellipsis,
                                          style:
                                          TextStyle(
                                            color: Colors
                                                .white
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
                                    ],
                                  ),
                                ),

                                Icon(
                                  Icons
                                      .chevron_right_rounded,
                                  color: Colors
                                      .white
                                      .withOpacity(
                                    0.28,
                                  ),
                                  size:
                                  w * 0.055,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      if (index !=
                          _friends.length -
                              1)
                        Padding(
                          padding:
                          EdgeInsets.only(
                            left: w * 0.16,
                            right:
                            w * 0.035,
                          ),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: Colors.white
                                .withOpacity(
                              0.055,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyFriends(
      double w,
      ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: w * 0.07,
        horizontal: w * 0.04,
      ),
      decoration: BoxDecoration(
        color:
        Colors.white.withOpacity(0.04),
        borderRadius:
        BorderRadius.circular(15),
        border: Border.all(
          color:
          Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.people_outline_rounded,
            color:
            Colors.white.withOpacity(0.25),
            size: w * 0.085,
          ),

          SizedBox(height: w * 0.025),

          Text(
            '아직 친구가 없습니다.',
            style: TextStyle(
              color: Colors.white
                  .withOpacity(0.55),
              fontFamily: 'kopub',
              fontSize: w * 0.032,
              fontWeight:
              FontWeight.w500,
            ),
          ),

          SizedBox(height: w * 0.01),

          Text(
            '닉네임으로 친구를 찾아보세요.',
            style: TextStyle(
              color: Colors.white
                  .withOpacity(0.3),
              fontFamily: 'kopub',
              fontSize: w * 0.028,
            ),
          ),
        ],
      ),
    );
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
        title: Text(
          '친구',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontSize: w * 0.043,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
        iconTheme:
        const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: RefreshIndicator(
        color: Colors.amberAccent,
        backgroundColor:
        const Color(0xFF16483F),
        onRefresh: _loadInitialData,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            w * 0.045,
            w * 0.015,
            w * 0.045,
            w * 0.12,
          ),
          children: [
            _buildSearchSection(w),

            if (_receivedRequests
                .isNotEmpty) ...[
              SizedBox(
                height: w * 0.065,
              ),
              _buildRequestsSection(w),
            ],

            SizedBox(
              height: w * 0.065,
            ),

            _buildFriendsSection(w),
          ],
        ),
      ),
    );
  }
}
