import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:dayverse_book/service/friend_service.dart';
import 'package:dayverse_book/widget/card_box.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'dart:math' as math;
import 'package:dayverse_book/widget/book_spine_widget.dart';

import 'book_register_screen.dart';

class FriendScreen extends StatefulWidget {
  final String friendUid;

  const FriendScreen({
    super.key,
    required this.friendUid,
  });

  @override
  State<FriendScreen> createState() =>
      _FriendScreenState();
}

class _FriendScreenState
    extends State<FriendScreen> {
  FriendProfile? _profile;

  bool _isLoading = true;
  bool _isRemovingFriend = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _loadFriendProfile();
  }

  Future<void> _loadFriendProfile() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile =
      await FriendService.instance.getFriendProfile(
        widget.friendUid,
      );

// ==========================================
// 친구 책등 데이터 확인
// ==========================================
      debugPrint(
        '[FRIEND SPINE] 총 ${profile.books.length}권',
      );

      for (final book in profile.books) {
        debugPrint(
          '[FRIEND SPINE] '
              'title=${book.title} / '
              'spineUrl=${book.spineUrl} / '
              'coverUrl=${book.displayImageUrl}',
        );
      }

      if (!mounted) return;

      setState(() {
        _profile = profile;
      });
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '[FriendScreen] 친구 프로필 로드 실패: '
            '${e.code} / ${e.message}',
      );

      if (!mounted) return;

      setState(() {
        _errorMessage =
            e.message ??
                '친구 정보를 불러오지 못했습니다.';
      });
    } catch (e) {
      debugPrint(
        '[FriendScreen] 친구 프로필 로드 실패: $e',
      );

      if (!mounted) return;

      setState(() {
        _errorMessage =
        '친구 정보를 불러오지 못했습니다.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(
      String message,
      ) {
    if (!mounted) return;

    final messenger =
    ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  String _categoryLabel(
      String category,
      ) {
    switch (category) {
      case 'done':
        return '완독';

      case 'reading':
        return '읽는 중';

      case 'toRead':
      case 'to_read':
      case 'want':
        return '읽을 예정';

      default:
        return '';
    }
  }

  Color _categoryColor(
      String category,
      ) {
    switch (category) {
      case 'done':
        return Colors.amberAccent;

      case 'reading':
        return Colors.lightGreenAccent;

      default:
        return Colors.white54;
    }
  }

  Future<void> _showRemoveFriendDialog() async {
    final profile =
        _profile;

    if (profile == null ||
        _isRemovingFriend) {
      return;
    }

    final shouldRemove =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
          const Color(0xFF16483F),
          title: const Text(
            '친구 삭제',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontWeight:
              FontWeight.bold,
            ),
          ),
          content: Text(
            '${profile.nickname}님을 친구에서 삭제할까요?',
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'kopub',
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                '취소',
                style: TextStyle(
                  color: Colors.white54,
                  fontFamily: 'kopub',
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontFamily: 'kopub',
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldRemove != true) {
      return;
    }

    setState(() {
      _isRemovingFriend = true;
    });

    try {
      await FriendService.instance
          .removeFriend(
        profile.uid,
      );

      if (!mounted) return;

      _showMessage(
        '${profile.nickname}님을 친구에서 삭제했습니다.',
      );

      Navigator.pop(
        context,
        true,
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      _showMessage(
        e.message ??
            '친구를 삭제하지 못했습니다.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        '친구를 삭제하지 못했습니다.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRemovingFriend = false;
        });
      }
    }
  }

  void _openProfileImageViewer(
      String imageUrl,
      ) {
    final trimmedUrl =
    imageUrl.trim();

    if (trimmedUrl.isEmpty) {
      return;
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor:
        Colors.black,
        transitionDuration:
        const Duration(
          milliseconds: 220,
        ),
        reverseTransitionDuration:
        const Duration(
          milliseconds: 180,
        ),
        pageBuilder: (
            context,
            animation,
            secondaryAnimation,
            ) {
          return FadeTransition(
            opacity: animation,
            child: Scaffold(
              backgroundColor:
              Colors.black,
              body: SafeArea(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Center(
                        child:
                        InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          boundaryMargin:
                          const EdgeInsets
                              .all(
                            80,
                          ),
                          child:
                          CachedNetworkImage(
                            imageUrl: trimmedUrl,
                            fit: BoxFit.contain,

                            placeholder: (_, __) {
                              return const SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white54,
                                ),
                              );
                            },

                            errorWidget: (_, __, ___) {
                              return const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.white54,
                                    size: 54,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    '이미지를 불러오지 못했습니다.',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontFamily: 'kopub',
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      top: 10,
                      right: 12,
                      child: Material(
                        color: Colors.black
                            .withOpacity(
                          0.45,
                        ),
                        shape:
                        const CircleBorder(),
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(
                              context,
                            );
                          },
                          customBorder:
                          const CircleBorder(),
                          child:
                          const Padding(
                            padding:
                            EdgeInsets.all(
                              10,
                            ),
                            child: Icon(
                              Icons
                                  .close_rounded,
                              color:
                              Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileImage({
    required double size,
    required String imageUrl,
  }) {
    final hasImage =
        imageUrl.trim().isNotEmpty;

    return GestureDetector(
      onTap: hasImage
          ? () {
        _openProfileImageViewer(
          imageUrl,
        );
      }
          : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
          Colors.white.withOpacity(
            0.08,
          ),
          border: Border.all(
            color:
            Colors.white.withOpacity(
              0.10,
            ),
          ),
        ),
        child: ClipOval(
          child: !hasImage
              ? Image.asset(
            'assets/image/profile_default.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          )
              : CachedNetworkImage(
            imageUrl: imageUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            memCacheWidth: 400,

            placeholder: (_, __) {
              return Image.asset(
                'assets/image/profile_default.png',
                width: size,
                height: size,
                fit: BoxFit.cover,
              );
            },

            errorWidget: (_, __, ___) {
              return Image.asset(
                'assets/image/profile_default.png',
                width: size,
                height: size,
                fit: BoxFit.cover,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(
      FriendProfile profile,
      double w,
      ) {
    final imageSize =
        w * 0.24;

    return Column(
      children: [
        _buildProfileImage(
          size: imageSize,
          imageUrl:
          profile.profileImageUrl,
        ),

        SizedBox(
          height: w * 0.035,
        ),

        Text(
          profile.nickname,
          maxLines: 1,
          overflow:
          TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontSize: w * 0.052,
            fontWeight:
            FontWeight.w600,
          ),
        ),

        if (profile.bio.isNotEmpty) ...[
          SizedBox(
            height: w * 0.018,
          ),

          Padding(
            padding:
            EdgeInsets.symmetric(
              horizontal: w * 0.05,
            ),
            child: Text(
              profile.bio,
              textAlign:
              TextAlign.center,
              maxLines: 3,
              overflow:
              TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white
                    .withOpacity(
                  0.55,
                ),
                fontFamily: 'kopub',
                fontSize: w * 0.032,
                height: 1.45,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOverviewCard({
    required BuildContext context,
    required int totalRead,
    required int totalReadingMinutes,
    required int totalReadingDays,
    required int longestStreakDays,
  }) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    return CardBox(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.022,
        vertical: screenHeight * 0.018,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildOverviewItem(
              screenWidth: screenWidth,
              icon: Icons.schedule_rounded,
              value: _formatOverviewMinutes(
                totalReadingMinutes,
              ),
              label: '총 독서시간',
            ),
          ),

          _buildOverviewDivider(
            screenHeight,
          ),

          Expanded(
            child: _buildOverviewItem(
              screenWidth: screenWidth,
              icon: Icons.menu_book_rounded,
              value: '$totalRead권',
              label: '총 완독',
            ),
          ),

          _buildOverviewDivider(
            screenHeight,
          ),

          Expanded(
            child: _buildOverviewItem(
              screenWidth: screenWidth,
              icon: Icons.check_circle,
              value: '$totalReadingDays일',
              label: '총 독서일',
            ),
          ),

          _buildOverviewDivider(
            screenHeight,
          ),

          Expanded(
            child: _buildOverviewItem(
              screenWidth: screenWidth,
              icon: Icons.local_fire_department_rounded,
              value: '$longestStreakDays일',
              label: '최장 연속',
            ),
          ),
        ],
      ),
    );
  }

  String _formatOverviewMinutes(
      int totalMinutes,
      ) {
    if (totalMinutes <= 0) {
      return '0분';
    }

    final hours =
        totalMinutes ~/ 60;

    final minutes =
        totalMinutes % 60;

    if (hours == 0) {
      return '$minutes분';
    }

    if (minutes == 0) {
      return '$hours시간';
    }

    return '$hours시간 $minutes분';
  }

  Widget _buildOverviewDivider(
      double screenHeight,
      ) {
    return Container(
      width: 1,
      height: screenHeight * 0.055,
      color: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildOverviewItem({
    required double screenWidth,
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.amberAccent,
          size: screenWidth * 0.04,
        ),

        SizedBox(
          height: screenWidth * 0.011,
        ),

        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.032,
            fontWeight: FontWeight.bold,
          ),
        ),

        SizedBox(
          height: screenWidth * 0.005,
        ),

        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.52),
            fontFamily: 'kopub',
            fontSize: screenWidth * 0.022,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }


  Widget _buildLibrarySection(
      FriendProfile profile,
      double w,
      ) {
    final books = profile.books;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ==========================================
        // 전체 서재 헤더
        // ==========================================
        Row(
          children: [
            Text(
              '전체 서재',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: w * 0.04,
                fontWeight: FontWeight.w600,
              ),
            ),

            const Spacer(),

            Text(
              '${books.length}권',
              style: TextStyle(
                color: Colors.white.withOpacity(0.38),
                fontFamily: 'kopub',
                fontSize: w * 0.028,
              ),
            ),
          ],
        ),

        SizedBox(height: w * 0.04),

        // ==========================================
        // 책이 없는 경우
        // ==========================================
        if (books.isEmpty)
          _buildEmptyLibrary(w)
        else
        // ========================================
        // LibraryScreen과 동일한 책등 서재
        // ========================================
          LayoutBuilder(
            builder: (context, constraints) {
              final shelfWidth = constraints.maxWidth;

              final shelves = _buildFriendSpineShelves(
                books: books,
                screenWidth: w,
                shelfWidth: shelfWidth,
              );

              return Column(
                children: List.generate(
                  shelves.length,
                      (index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: w * 0.04,
                      ),
                      child: _buildFriendSpineShelf(
                        books: shelves[index],
                        screenWidth: w,
                        shelfWidth: shelfWidth,
                      ),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }


  double _friendSpineWidth(
      FriendBookItem book,
      double screenWidth,
      ) {
    final baseWidth = screenWidth * 0.050;

    final widthFactor =
        0.88 +
            ((book.title.hashCode.abs() % 25) / 100);

    return baseWidth * widthFactor;
  }


  List<List<FriendBookItem>> _buildFriendSpineShelves({
    required List<FriendBookItem> books,
    required double screenWidth,
    required double shelfWidth,
  }) {
    final gap = screenWidth * 0.007;

    final shelves = <List<FriendBookItem>>[];

    var currentShelf = <FriendBookItem>[];

    double usedWidth = 0;

    for (final book in books) {
      final bookWidth = _friendSpineWidth(
        book,
        screenWidth,
      );

      final requiredWidth = currentShelf.isEmpty
          ? bookWidth
          : gap + bookWidth;

      if (currentShelf.isNotEmpty &&
          usedWidth + requiredWidth > shelfWidth) {
        shelves.add(currentShelf);

        currentShelf = <FriendBookItem>[];

        usedWidth = 0;
      }

      if (currentShelf.isNotEmpty) {
        usedWidth += gap;
      }

      currentShelf.add(book);

      usedWidth += bookWidth;
    }

    if (currentShelf.isNotEmpty) {
      shelves.add(currentShelf);
    }

    return shelves;
  }



  Widget _buildFriendSpineShelf({
    required List<FriendBookItem> books,
    required double screenWidth,
    required double shelfWidth,
  }) {
    final bookHeight = screenWidth * 0.50;

    final baseGap = screenWidth * 0.006;
    final maxGap = screenWidth * 0.018;

    // ==========================================
    // Glass / Acrylic shelf dimensions
    // ==========================================
    final shelfThickness = screenWidth * 0.014;
    final shelfGlowHeight = screenWidth * 0.008;

    final totalBookWidth = books.fold<double>(
      0,
          (sum, book) =>
      sum + _friendSpineWidth(book, screenWidth),
    );

    final remainingWidth = math.max(
      0.0,
      shelfWidth - totalBookWidth,
    );

    double gap = baseGap;

    if (books.length > 1) {
      final distributedGap =
          remainingWidth / (books.length - 1);

      gap = math.min(
        maxGap,
        math.max(baseGap, distributedGap),
      );
    }

    double currentX = 0;

    final positionedBooks = <Widget>[];

    // ==========================================
    // 책등 배치
    // ==========================================
    for (final book in books) {
      final width = _friendSpineWidth(
        book,
        screenWidth,
      );

      final x = currentX;

      positionedBooks.add(
        Positioned(
          left: x,
          bottom: shelfThickness + shelfGlowHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,

            onTap: () {
              final registrationBook =
              book.toRegistrationBook();

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookRegisterScreen(
                    book: registrationBook,
                    initialCategory: 'want',
                  ),
                ),
              );
            },

            child: BookSpineWidget(
              title: book.title,
              author: book.author,
              spineUrl: book.spineUrl,
              coverUrl: book.displayImageUrl,
              width: width,
              height: bookHeight,
            ),
          ),
        ),
      );

      currentX += width + gap;
    }

    return SizedBox(
      width: shelfWidth,
      height: bookHeight +
          shelfThickness +
          shelfGlowHeight +
          screenWidth * 0.018,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ======================================
          // Books
          // ======================================
          ...positionedBooks,

          // ======================================
          // 아주 약한 하단 glow
          // ======================================
          Positioned(
            left: screenWidth * 0.015,
            right: screenWidth * 0.015,
            bottom: 0,
            child: Container(
              height: shelfGlowHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.08),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),

          // ======================================
          // Acrylic / Frosted glass shelf
          // ======================================
          Positioned(
            left: 0,
            right: 0,
            bottom: shelfGlowHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: shelfThickness,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.11),

                  borderRadius:
                  BorderRadius.circular(999),

                  border: Border.all(
                    color: Colors.white.withOpacity(0.22),
                    width: 0.7,
                  ),

                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.18),
                      Colors.white.withOpacity(0.07),
                    ],
                  ),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),

                    BoxShadow(
                      color: Colors.white.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ======================================
          // 유리 상단 엣지
          // ======================================
          Positioned(
            left: screenWidth * 0.012,
            right: screenWidth * 0.012,
            bottom:
            shelfGlowHeight + shelfThickness - 1,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.02),
                    Colors.white.withOpacity(0.32),
                    Colors.white.withOpacity(0.02),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildBookItem(
      FriendBookItem book,
      double w,
      ) {
    final imageUrl =
    book.displayImageUrl.trim();

    final categoryLabel =
    _categoryLabel(
      book.category,
    );

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                width:
                double.infinity,
                decoration:
                BoxDecoration(
                  color: Colors.white
                      .withOpacity(
                    0.06,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    9,
                  ),
                  border: Border.all(
                    color: Colors.white
                        .withOpacity(
                      0.06,
                    ),
                  ),
                ),
                clipBehavior:
                Clip.antiAlias,
                child: imageUrl.isEmpty
                    ? Center(
                  child: Icon(
                    Icons
                        .menu_book_outlined,
                    color: Colors
                        .white
                        .withOpacity(
                      0.25,
                    ),
                    size:
                    w * 0.10,
                  ),
                )
                    : CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 300,

                  placeholder: (_, __) {
                    return Container(
                      color: Colors.white.withOpacity(0.04),
                    );
                  },

                  errorWidget: (_, __, ___) {
                    return Center(
                      child: Icon(
                        Icons.menu_book_outlined,
                        color: Colors.white.withOpacity(0.25),
                        size: w * 0.10,
                      ),
                    );
                  },
                ),
              ),

              if (categoryLabel.isNotEmpty)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.72),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: _categoryColor(
                          book.category,
                        ).withOpacity(0.25),
                      ),
                    ),
                    child: Text(
                      categoryLabel,
                      style: TextStyle(
                        color: _categoryColor(
                          book.category,
                        ),
                        fontFamily: 'kopub',
                        fontSize: w * 0.020,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        SizedBox(
          height: w * 0.015,
        ),

        Text(
          book.title,
          maxLines: 2,
          overflow:
          TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontSize: w * 0.028,
            fontWeight:
            FontWeight.w500,
            height: 1.25,
          ),
        ),

        if (book.author.isNotEmpty) ...[
          SizedBox(
            height: w * 0.006,
          ),

          Text(
            book.author,
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white
                  .withOpacity(
                0.35,
              ),
              fontFamily: 'kopub',
              fontSize:
              w * 0.024,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyLibrary(
      double w,
      ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: w * 0.08,
        horizontal: w * 0.04,
      ),
      decoration: BoxDecoration(
        color:
        Colors.white.withOpacity(
          0.04,
        ),
        borderRadius:
        BorderRadius.circular(15),
        border: Border.all(
          color:
          Colors.white.withOpacity(
            0.05,
          ),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons
                .auto_stories_outlined,
            color:
            Colors.white.withOpacity(
              0.23,
            ),
            size: w * 0.085,
          ),

          SizedBox(
            height: w * 0.025,
          ),

          Text(
            '아직 등록된 책이 없습니다.',
            style: TextStyle(
              color: Colors.white
                  .withOpacity(
                0.50,
              ),
              fontFamily: 'kopub',
              fontSize: w * 0.031,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(
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
            Icon(
              Icons
                  .error_outline_rounded,
              color:
              Colors.white.withOpacity(
                0.35,
              ),
              size: w * 0.11,
            ),

            SizedBox(
              height: w * 0.03,
            ),

            Text(
              _errorMessage ??
                  '친구 정보를 불러오지 못했습니다.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color: Colors.white
                    .withOpacity(
                  0.55,
                ),
                fontFamily: 'kopub',
                fontSize:
                w * 0.032,
              ),
            ),

            SizedBox(
              height: w * 0.04,
            ),

            TextButton(
              onPressed:
              _loadFriendProfile,
              child: const Text(
                '다시 시도',
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
        ),
      ),
    );
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final w =
        MediaQuery.of(context)
            .size
            .width;

    final profile =
        _profile;

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
          profile?.nickname ??
              '친구',
          maxLines: 1,
          overflow:
          TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontSize: w * 0.043,
            fontWeight:
            FontWeight.w600,
          ),
        ),
        actions: [
          if (profile != null)
            PopupMenuButton<String>(
              color:
              const Color(
                0xFF16483F,
              ),
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: Colors.white,
              ),
              onSelected: (
                  value,
                  ) {
                if (value ==
                    'remove') {
                  _showRemoveFriendDialog();
                }
              },
              itemBuilder: (
                  context,
                  ) {
                return const [
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(
                          Icons
                              .person_remove_outlined,
                          color:
                          Colors.redAccent,
                          size: 20,
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        Text(
                          '친구 삭제',
                          style:
                          TextStyle(
                            color:
                            Colors.white,
                            fontFamily:
                            'kopub',
                          ),
                        ),
                      ],
                    ),
                  ),
                ];
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child:
        CircularProgressIndicator(
          color:
          Colors.amberAccent,
        ),
      )
          : _errorMessage != null ||
          profile == null
          ? _buildError(w)
          : RefreshIndicator(
        color:
        Colors.amberAccent,
        backgroundColor:
        const Color(
          0xFF16483F,
        ),
        onRefresh:
        _loadFriendProfile,
        child:
        ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding:
          EdgeInsets.fromLTRB(
            w * 0.045,
            w * 0.025,
            w * 0.045,
            w * 0.12,
          ),
          children: [
            _buildProfileSection(
              profile,
              w,
            ),

            SizedBox(
              height:
              w * 0.065,
            ),

            _buildOverviewCard(
              context: context,
              totalRead:
              profile.overview.totalReadBooks,
              totalReadingMinutes:
              profile.overview.totalReadingMinutes,
              totalReadingDays:
              profile.overview.totalReadingDays,
              longestStreakDays:
              profile.overview.longestStreakDays,
            ),

            SizedBox(
              height:
              w * 0.065,
            ),

            _buildLibrarySection(
              profile,
              w,
            ),
          ],
        ),
      ),
    );
  }
}
