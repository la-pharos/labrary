import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/provider/custom_library_provider.dart';
import 'package:dayverse_book/screen/book_search_screen.dart';
import 'package:dayverse_book/screen/library_search_screen.dart';
import 'package:dayverse_book/screen/book_detail_screen.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/constants/dummy_book_list.dart';
import 'package:dayverse_book/widget/login_please_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';


enum DoneBookSortOption { newest, rating }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  LibraryScreenState createState() => LibraryScreenState();
}

class LibraryScreenState extends State<LibraryScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  DoneBookSortOption _doneBookSortOption = DoneBookSortOption.newest;

  void goToOverviewPage() {
    setState(() {
      _currentPage = 0;
      _pageController.jumpToPage(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final provider = Provider.of<CustomLibraryProvider>(context);
    final savedBooks = Provider.of<SavedBooksProvider>(context).savedBooks;


    if (provider.orderedLibraryNames.isEmpty && !provider.isLibraryBeingCreated) {
      Future.microtask(() => provider.fetchLibraries());
    }

    final customLibraries = provider.orderedLibraryNames;
    final totalPages = 4 + customLibraries.length;

    return Scaffold(
      backgroundColor: const Color(0xFF013328),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: screenHeight * 0.055),
          _buildTopNavigationBar(screenWidth, savedBooks, customLibraries),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: totalPages + 1,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                if (index == 0) return _buildLibraryOverviewPage();
                if (index >= 1 && index <= 4) return _buildBookPage(index);
                if (index < 5 + customLibraries.length)
                  return _buildCustomLibraryPage(customLibraries[index - 5]);
                return _buildAddLibraryPage();
              },
            ),
          ),
          _buildPageIndicator(totalPages + 1),
        ],
      ),
    );
  }

  /// ✅ 상단 네비게이션 바
  Widget _buildTopNavigationBar(double screenWidth,List<BookModel> savedBooks, List<String> customLibraries) {
    final screenWidth = MediaQuery.of(context).size.width;
    final allCategories = ["전체", "읽은 책", "읽는 중인 책", "읽을 예정인 책", ...customLibraries];
    final bool isCustom = _currentPage >= 5;
    final bool isHome = _currentPage == 0;

    final String currentCategory = _currentPage > 0 && _currentPage <= allCategories.length
        ? allCategories[_currentPage - 1]
        : "";

    final int bookCount = _getBookCountForPage(savedBooks, customLibraries, index: _currentPage);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05,
        vertical: screenWidth * 0.0055,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          isHome
              ?  Text(
            "LIBRARY",
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
            ),
          )
              : Expanded(
            child: GestureDetector(
              onTap: _showCategorySelectionDialog,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      "$currentCategory ($bookCount권)",
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'kopub',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
          ),
          SizedBox(width: screenWidth * 0.03),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isHome) ...[
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  tooltip: "책 추가하기",
                  onPressed: _navigateToBookSearch,
                ),
                SizedBox(width: screenWidth * 0.02),
                IconButton(
                  icon: const Icon(Icons.create_new_folder_outlined, color: Colors.white),
                  tooltip: "서재 만들기",
                  onPressed: _showAddLibraryDialog,
                ),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  tooltip: "책 검색",
                  onPressed: () => _handleSearchPressed(currentCategory),
                ),
                if (_currentPage == 2)
                  PopupMenuButton<DoneBookSortOption>(
                    icon: const Icon(Icons.sort, color: Colors.white),
                    tooltip: "정렬",
                    color: const Color(0xFF1B2C2E), // ✅ 메뉴 배경색
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16), // ✅ 둥근 모서리
                    ),
                    onSelected: (option) {
                      setState(() {
                        _doneBookSortOption = option;
                      });
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: DoneBookSortOption.newest,
                        child: Text(
                          "등록순",
                          style: TextStyle(
                            color: _doneBookSortOption == DoneBookSortOption.newest
                                ? Colors.amberAccent
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'kopub',
                          ),
                        ),
                      ),
                      PopupMenuItem(
                        value: DoneBookSortOption.rating,
                        child: Text(
                          "별점 높은 순",
                          style: TextStyle(
                            color: _doneBookSortOption == DoneBookSortOption.rating
                                ? Colors.amberAccent
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'kopub',
                          ),
                        ),
                      ),
                    ],
                  ),
                if (isCustom)
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    tooltip: "서재 설정",
                    onPressed: () {
                      final libraryIndex = _currentPage - 5;
                      final name = customLibraries[libraryIndex];
                      _openLibrarySettings(name);
                    },
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToBookSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BookSearchScreen()),
    );
  }

  // 서재 카테고리 선택 후 페이지 변경
  void _handleSearchPressed(String category) {
    final savedBooks = Provider.of<SavedBooksProvider>(context, listen: false).savedBooks;
    final customLibrariesProvider = Provider.of<CustomLibraryProvider>(context, listen: false);
    List<BookModel> booksToSearch = [];

    if (_currentPage == 1) {
      booksToSearch = savedBooks;
    } else if (_currentPage == 2) {
      booksToSearch = savedBooks.where((b) => b.category == 'done').toList();
    } else if (_currentPage == 3) {
      booksToSearch = savedBooks.where((b) => b.category == 'reading').toList();
    } else if (_currentPage == 4) {
      booksToSearch = savedBooks.where((b) => b.category == 'want').toList();
    } else if (_currentPage >= 5) {
      final libName = customLibrariesProvider.orderedLibraryNames[_currentPage - 5];
      booksToSearch = savedBooks.where((b) => b.customLibraries.contains(libName)).toList();
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LibrarySearchScreen(savedBooks: booksToSearch),
      ),
    );
  }

  int _getBookCountForPage(List<BookModel> savedBooks, List<String> customLibraries, {required int index}) {
    if (index == 1) {
      // ✅ "전체" 서재 → 모든 책 카운트
      return savedBooks.length;
    } else if (index == 2) {
      return savedBooks.where((book) => book.category == 'done').length;
    } else if (index == 3) {
      return savedBooks.where((book) => book.category == 'reading').length;
    } else if (index == 4) {
      return savedBooks.where((book) => book.category == 'want').length;
    } else if (index >= 5) {
      final libraryName = customLibraries[index - 5];

      // 🔍 정확하게 해당 서재에 속한 책 ID만 가져오기
      final provider = Provider.of<CustomLibraryProvider>(context, listen: false);
      final bookIdsInLibrary = provider.libraries[libraryName] ?? [];

      // ✅ 실제로 저장된 책 목록 중 해당 서재에 있는 것만 세기
      final count = savedBooks.where((book) => bookIdsInLibrary.contains(book.id)).length;

      return count;
    } else {
      return 0;
    }
  }

  void _showCategorySelectionDialog() {
    final defaultCategories = ["서재 홈", "전체", "읽은 책", "읽는 중인 책", "읽을 예정인 책"];
    final customLibraryProvider = Provider.of<CustomLibraryProvider>(context, listen: false);
    final savedBooks = Provider.of<SavedBooksProvider>(context, listen: false).savedBooks;
    final customLibraries = customLibraryProvider.libraries;
    final orderedCustom = customLibraryProvider.orderedLibraryNames;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF0A1D27),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.6,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("서재 선택", style: TextStyle(color: Colors.white, fontFamily: 'kopub', fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      // ✅ 서재 홈 + 기본 카테고리 항목
                      ...defaultCategories.asMap().entries.map((entry) {
                        final index = entry.key;
                        final category = entry.value;
                        final pageIndex = index; // 서재 홈 = 0, 전체 = 1, 읽은 책 = 2 ...

                        final isSelected = _currentPage == pageIndex;

                        return ListTile(
                          leading: category == "서재 홈" ? const Icon(Icons.home, color: Colors.amberAccent) : null,
                          title: Text(
                            category,
                            style: TextStyle(
                              color: isSelected ? Colors.amberAccent : Colors.white,
                              fontFamily: 'kopub',
                            ),
                          ),
                          trailing: isSelected ? const Icon(Icons.check, color: Colors.amberAccent) : null,
                            onTap: () {
                              Navigator.pop(context);
                              setState(() {
                                _currentPage = pageIndex;
                                _pageController.jumpToPage(pageIndex);
                              });
                            }
                        );
                      }),

                      if (customLibraries.isNotEmpty) const Divider(color: Colors.white30),

                      // ✅ 커스텀 서재 항목
                      ...orderedCustom.map((name) {
                        final count = savedBooks.where((b) => customLibraries[name]!.contains(b.id)).length;

                        return ListTile(
                          leading: const Icon(Icons.folder, color: Colors.amberAccent),
                          title: Text(
                            "$name ($count권)",
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _currentPage == (5 + orderedCustom.indexOf(name)) ? Colors.amberAccent : Colors.white,
                              fontFamily: 'kopub',
                            ),
                          ),
                          trailing: _currentPage == (5 + orderedCustom.indexOf(name))
                              ? const Icon(Icons.check, color: Colors.amberAccent)
                              : null,
                            onTap: () {
                              Navigator.pop(context);
                              final tappedName = name;

                              // ✅ 다음 프레임에서 최신 Provider 상태 기준으로 index 계산
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                final updatedList = Provider.of<CustomLibraryProvider>(context, listen: false).orderedLibraryNames;
                                final pageIndex = 5 + updatedList.indexOf(tappedName);
                                setState(() {
                                  _currentPage = pageIndex;
                                  _pageController.jumpToPage(pageIndex);
                                });
                              });
                            }
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 대표 페이지
  Widget _buildLibraryOverviewPage() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final savedBooks = Provider.of<SavedBooksProvider>(context).savedBooks;
    final provider = Provider.of<CustomLibraryProvider>(context);
    final customLibraries = provider.libraries;
    final orderedNames = provider.orderedLibraryNames;
    final defaultCategories = ["전체", "읽은 책", "읽는 중인 책", "읽을 예정인 책"];

    List<Map<String, dynamic>> defaultItems = List.generate(defaultCategories.length, (i) {
      return {
        "name": defaultCategories[i],
        "index": i + 1,
        "count": _getBookCountForPage(savedBooks, customLibraries.keys.toList(), index: i + 1),
        "isCustom": false,
      };
    });

    List<Map<String, dynamic>> customItems = List.generate(orderedNames.length, (index) {
      final name = orderedNames[index];
      final count = _getBookCountForPage(savedBooks, customLibraries.keys.toList(), index: 5 + index);
      return {
        "name": name,
        "index": 5 + index,
        "count": count,
        "isCustom": true,
      };
    });

    List<Map<String, dynamic>> allItems = [...defaultItems, ...customItems];

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SizedBox( // ✅ Fixed!
        height: MediaQuery.of(context).size.height * 0.85, // 또는 double.infinity
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              GridView.count(
                crossAxisCount: screenWidth > 600 ? 3 : 2,
                crossAxisSpacing: screenWidth * 0.03,
                mainAxisSpacing: screenWidth * 0.03,
                childAspectRatio: 1,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                children: defaultItems.map((item) => _buildLibraryCard(
                  item,
                  titleSize: screenWidth * 0.04,
                  countSize: screenWidth * 0.035,
                )).toList(),
              ),

              SizedBox(height: screenHeight * 0.02),

              if (orderedNames.isNotEmpty) ...[
                const Divider(color: Colors.white30, thickness: 0.8),

                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorder: (oldIndex, newIndex) {
                    if (oldIndex < newIndex) newIndex -= 1;
                    Provider.of<CustomLibraryProvider>(context, listen: false)
                        .reorderLibrary(oldIndex, newIndex);
                  },
                  children: List.generate(orderedNames.length, (index) {
                    final name = orderedNames[index];
                    final ids = customLibraries[name] ?? [];
                    final count = savedBooks.where((b) => ids.contains(b.id)).length;

                    return ListTile(
                      key: ValueKey('custom_library_${index}_$name'),
                      contentPadding: EdgeInsets.symmetric(vertical: screenHeight * 0.005),
                      title: Text(
                        name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: screenWidth * 0.055,
                          fontFamily: 'kopub',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        "$count권",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: screenWidth * 0.04,
                          fontFamily: 'kopub',
                        ),
                      ),
                      trailing: const Icon(Icons.drag_handle, color: Colors.white70),
                      onTap: () => _onLibraryTap(name),
                    );
                  }),
                ),
              ],
              SizedBox(height: screenHeight * 0.1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLibraryCard(
      Map<String, dynamic> item, {
        double titleSize = 16,
        double countSize = 14,
      }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentPage = item["index"];
          _pageController.jumpToPage(item["index"]);
        });
      },
      child: Container(
        padding: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item["name"],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontWeight: FontWeight.bold,
                fontSize: titleSize,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "${item["count"]}권",
              style: TextStyle(
                color: Colors.white70,
                fontFamily: 'kopub',
                fontWeight: FontWeight.w500,
                fontSize: countSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 서재 만들기 다이얼로그
  void _showAddLibraryDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        final width = MediaQuery.of(context).size.width;

        return AlertDialog(
          backgroundColor: const Color(0xFF1B2C2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          title: const Text(
            "새 서재 만들기",
            style: TextStyle(fontFamily: 'kopub', fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: width > 480 ? 400 : double.infinity,
            ),
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontFamily: 'kopub'),
              decoration: const InputDecoration(
                hintText: "서재 이름을 입력하세요.",
                hintStyle: TextStyle(fontFamily: 'kopub', fontSize: 15, height: 1.4, color: Colors.white70),
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text("생성", style: TextStyle(color: Colors.amberAccent)),
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;

                final user = FirebaseAuth.instance.currentUser;
                if (user == null || user.isAnonymous) {
                  Navigator.pop(context);
                  await showLoginRequiredDialog(context);
                  return;
                }

                final provider = Provider.of<CustomLibraryProvider>(context, listen: false);
                final isDuplicate = provider.orderedLibraryNames.contains(name);

                if (isDuplicate) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF1B2C2E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      title: const Text(
                        "중복된 이름",
                        style: TextStyle(color: Colors.redAccent, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'kopub'),
                      ),
                      content: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: width > 480 ? 400 : double.infinity,
                        ),
                        child: const Text(
                          "이미 같은 이름의 서재가 있어요.\n다른 이름을 입력해주세요.",
                          style: TextStyle(color: Colors.white, fontFamily: 'kopub'),
                        ),
                      ),
                      actions: [
                        TextButton(
                          child: const Text("확인", style: TextStyle(color: Colors.amberAccent)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                try {
                  await provider.createLibrary(name, context: context); // ✅ context 전달
                } catch (e) {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF1B2C2E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text(
                        "서재 생성 제한",
                        style: TextStyle(color: Colors.redAccent, fontFamily: 'kopub'),
                      ),
                      content: const Text(
                        "최대 3개의 서재만 생성할 수 있어요.\n프리미엄 업그레이드 시 무제한 생성이 가능합니다.",
                        style: TextStyle(color: Colors.white70, fontFamily: 'kopub'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("확인", style: TextStyle(color: Colors.amberAccent)),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                Navigator.pop(context); // 다이얼로그 닫기

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF1B2C2E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    title: const Text(
                      "서재 생성 완료",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'kopub'),
                    ),
                    content: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: width > 480 ? 400 : double.infinity,
                      ),
                      child: Text(
                        "'$name' 서재가 생성되었습니다!",
                        style: const TextStyle(color: Colors.white70, fontFamily: 'kopub'),
                      ),
                    ),
                  ),
                );

                Future.delayed(const Duration(milliseconds: 2000), () {
                  Navigator.pop(context);
                  setState(() {
                    _currentPage = 0;
                    _pageController.jumpToPage(0);
                  });
                });
              },
            ),
            TextButton(
              child: const Text("취소", style: TextStyle(color: Colors.redAccent)),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  /// 하단 인디케이터
  Widget _buildPageIndicator(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (index) {
          return Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentPage == index ? Colors.white : Colors.white24,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBookPage(int index) {
    final savedBooks = context.watch<SavedBooksProvider>().savedBooks;
    List<BookModel> filteredBooks;

    switch (index) {
      case 2:
        filteredBooks = savedBooks.where((b) => b.category == "done").toList();
        if (_doneBookSortOption == DoneBookSortOption.rating) {
          filteredBooks.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
        }
        break;
      case 3:
        filteredBooks = savedBooks.where((b) => b.category == "reading").toList();
        break;
      case 4:
        filteredBooks = savedBooks.where((b) => b.category == "want").toList();
        break;
      default:
        filteredBooks = savedBooks;
    }

    return _buildBookGrid(filteredBooks);
  }

  // 서재 생성 중 클릭 불가 처리
  Widget _buildCustomLibraryPage(String libraryName) {
    final provider = Provider.of<CustomLibraryProvider>(context);

    // 서재 생성 중일 때는 이동 불가능
    if (provider.isLibraryBeingCreated) {
      return Center(child: CircularProgressIndicator());
    }

    final savedBooks = Provider.of<SavedBooksProvider>(context).savedBooks;
    final bookIds = provider.libraries[libraryName] ?? [];
    final filteredBooks = savedBooks.where((b) => bookIds.contains(b.id)).toList();
    return _buildBookGrid(filteredBooks);
  }

  // 서재 클릭 시 생성 완료 후에만 이동 가능
  void _onLibraryTap(String libraryName) {
    final provider = Provider.of<CustomLibraryProvider>(context, listen: false);

    if (!provider.isLibraryBeingCreated) {
      final pageIndex = 5 + provider.orderedLibraryNames.indexOf(libraryName);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageController.animateToPage(
          pageIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );

        setState(() {
          _currentPage = pageIndex;
        });
      });
    }
  }

  /// 책 배열
  Widget _buildBookGrid(List<BookModel> books) {
    final screenWidth = MediaQuery.of(context).size.width;

    int crossAxisCount = 3;
    if (screenWidth > 1000) {
      crossAxisCount = 5;
    } else if (screenWidth > 700) {
      crossAxisCount = 4;
    }

    final spacing = screenWidth * 0.025;

    // ⬇️ 카드 세로 살짝 늘림 (0.50 → 0.47)
    final tileAspectRatio = screenWidth < 380 ? 0.46 : 0.47;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.02,
        vertical: screenWidth * 0.015,
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: spacing * 0.6),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: tileAspectRatio, // ✅ 여기만 바꿔도 대부분 해결
        ),
        itemCount: books.length,
        itemBuilder: (context, index) => _buildBookItem(books[index]),
      ),
    );
  }

  /// 책 정보 (표지 및 별점, 진행도 등)
  Widget _buildBookItem(BookModel book) {
    final screenWidth = MediaQuery.of(context).size.width;

    final imageUrl = (book.imageUrl?.isNotEmpty == true ? book.imageUrl! : '')
        .replaceAll('coversum', 'cover');
    final isAssetImage = imageUrl.startsWith("assets/");

    final imageWidget = isAssetImage
        ? Image.asset(imageUrl, fit: BoxFit.contain)
        : Image.network(
      imageUrl,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey,
        child: const Icon(Icons.book, color: Colors.white, size: 40),
      ),
    );

    final hasPage = (book.pageCount ?? 0) > 0;
    final ratio = book.progressRatio.clamp(0.0, 1.0);
    final percentText = "${book.progressPercent}%";

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BookDetailScreen(book: book)),
        );
        setState(() {});
      },
      child: Container(
        width: screenWidth * 0.25,
        padding: EdgeInsets.all(screenWidth * 0.02),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 표지
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.all(screenWidth * 0.015),
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: imageWidget,
                  ),
                ),
              ),
            ),
            SizedBox(height: screenWidth * 0.02),

            // 제목
            Text(
              book.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.032,
                fontWeight: FontWeight.bold,
              ),
            ),

            // ✅ 상태 영역: done → 별점, reading → 진행률, want → 생략
            if (book.category == "done" && book.rating != null) ...[
              SizedBox(height: screenWidth * 0.015),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 15),
                  const SizedBox(width: 2),
                  Text(
                    "${book.rating!.toStringAsFixed(1)}",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenWidth * 0.035,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'kopub',
                    ),
                  ),
                ],
              ),
            ] else if (book.category == "reading") ...[
              SizedBox(height: screenWidth * 0.015),
              if (hasPage) ...[
                // 미니 진행바
                SizedBox(
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 4,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                    ),
                  ),
                ),
                SizedBox(height: screenWidth * 0.008),
                Text(
                  percentText,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: screenWidth * 0.03,
                    fontFamily: 'kopub',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ]else ...[
              Text(
                "\n시작 전",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: screenWidth * 0.032,
                  fontFamily: 'kopub',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// ?
  Widget _buildAddLibraryPage() {
    return Center(
      child: ElevatedButton(
        onPressed: _showAddLibraryDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amberAccent,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        ),
        child: const Text("서재 만들기", style: TextStyle(color: Colors.black, fontFamily: 'kopub', fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  /// 커스텀 서재 설정창
  void _openLibrarySettings(String libraryName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFF1B2C2E),
      builder: (context) {
        final height = MediaQuery.of(context).size.height;
        final viewInsets = MediaQuery.of(context).viewInsets;

        return Padding(
          padding: EdgeInsets.only(
            bottom: viewInsets.bottom,
            left: 16,
            right: 16,
            top: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: height * 0.6),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTransparentListTile(
                    icon: Icons.edit,
                    iconColor: Colors.amberAccent,
                    text: "서재 이름 변경",
                    onTap: () {
                      Navigator.pop(context);
                      _showRenameLibraryDialog(libraryName);
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildTransparentListTile(
                    icon: Icons.add_circle_outline,
                    iconColor: Colors.amberAccent,
                    text: "서재에 책 추가",
                    onTap: () {
                      Navigator.pop(context);
                      _showAddBooksToLibraryDialog(libraryName);
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildTransparentListTile(
                    icon: Icons.remove_circle_outline,
                    iconColor: Colors.white70,
                    text: "서재에서 책 제거",
                    onTap: () {
                      Navigator.pop(context);
                      _showRemoveBooksFromLibraryDialog(libraryName);
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildTransparentListTile(
                    icon: Icons.delete_forever,
                    iconColor: Colors.redAccent,
                    text: "서재 삭제",
                    onTap: () {
                      Navigator.pop(context);
                      _confirmDeleteLibrary(libraryName);
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransparentListTile({
    required IconData icon,
    required Color iconColor,
    required String text,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'kopub',
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  // 서재 이름 변경
  void _showRenameLibraryDialog(String oldName) {
    final controller = TextEditingController(text: oldName);
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        final width = MediaQuery.of(context).size.width;

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            backgroundColor: const Color(0xFF1B2C2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            title: const Text(
              "서재 이름 변경",
              style: TextStyle(
                fontFamily: 'kopub',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: width > 480 ? 400 : double.infinity,
              ),
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontFamily: 'kopub'),
                decoration: const InputDecoration(
                  hintText: "새 이름 입력",
                  hintStyle: TextStyle(
                    fontFamily: 'kopub',
                    fontSize: 15,
                    height: 1.4,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
            actions: [
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 20),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent),
                  ),
                )
              else ...[
                TextButton(
                  child: const Text("확인", style: TextStyle(color: Colors.amberAccent)),
                  onPressed: () async {
                    final newName = controller.text.trim();
                    final customLibraryProvider = Provider.of<CustomLibraryProvider>(context, listen: false);
                    final savedBooksProvider = Provider.of<SavedBooksProvider>(context, listen: false);

                    final isDuplicate = customLibraryProvider.orderedLibraryNames
                        .any((name) => name == newName && name != oldName);

                    if (newName.isEmpty) return;

                    if (isDuplicate) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("이미 존재하는 서재 이름입니다."),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }

                    setState(() => isLoading = true); // 🔄 로딩 시작

                    try {
                      await customLibraryProvider.renameLibrary(oldName, newName);
                      await savedBooksProvider.renameCustomLibraryInBooks(oldName, newName);
                      await customLibraryProvider.fetchLibraries();

                      if (!context.mounted) return;
                      Navigator.pop(context); // ✅ 다이얼로그 닫기
                      setState(() {});        // ✅ 화면 갱신
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("오류 발생: $e"),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      setState(() => isLoading = false); // 🔁 실패 시 로딩 다시 해제
                    }
                  },
                ),
                TextButton(
                  child: const Text("취소", style: TextStyle(color: Colors.redAccent)),
                  onPressed: () => Navigator.pop(context),
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  // 서재에 책 추가
  void _showAddBooksToLibraryDialog(String libraryName) {
    final savedBooksProvider = Provider.of<SavedBooksProvider>(context, listen: false);
    final allBooks = savedBooksProvider.savedBooks;
    final customLibraryProvider = Provider.of<CustomLibraryProvider>(context, listen: false);

    final booksNotInLibrary = allBooks.where((book) {
      final libraries = (book.customLibraries as List?) ?? [];
      return !libraries.contains(libraryName);
    }).toList();

    if (booksNotInLibrary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("추가할 수 있는 책이 없습니다.")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        final width = MediaQuery.of(context).size.width;
        final Set<String> selectedBookIds = {};

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1B2C2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.all(20),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              title: const Center(
                child: Text(
                  "서재에 책 추가",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'kopub',
                  ),
                ),
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: width > 480 ? 400 : double.infinity,
                ),
                child: SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: Scrollbar(
                    child: ListView(
                      children: booksNotInLibrary.map((book) {
                        final bookId = book.id as String;
                        final title = book.title ?? "제목 없음";
                        final isSelected = selectedBookIds.contains(bookId);

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              isSelected
                                  ? selectedBookIds.remove(bookId)
                                  : selectedBookIds.add(bookId);
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(color: Colors.white, fontFamily: 'kopub'),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                                Icon(
                                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: isSelected ? Colors.amberAccent : Colors.white54,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      child: const Text("추가", style: TextStyle(color: Colors.amberAccent)),
                      onPressed: () {
                        Future.wait([
                          for (final bookId in selectedBookIds)
                            savedBooksProvider.addBookToCustomLibrary(
                              bookId,
                              libraryName,
                              customLibraryProvider: customLibraryProvider,
                            ),
                        ]).then((_) {
                          Navigator.pop(context);
                        });
                      },
                    ),
                    TextButton(
                      child: const Text("취소", style: TextStyle(color: Colors.redAccent)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 서재에서 책 제거
  void _showRemoveBooksFromLibraryDialog(String libraryName) {
    final savedBooksProvider = Provider.of<SavedBooksProvider>(context, listen: false);
    final customLibraryProvider = Provider.of<CustomLibraryProvider>(context, listen: false);
    final books = savedBooksProvider.savedBooks;

    final bookIdsInLibrary = customLibraryProvider.libraries[libraryName] ?? [];
    final booksInLibrary = books.where((b) => bookIdsInLibrary.contains(b.id)).toList();

    if (booksInLibrary.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1B2C2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          title: const Text("알림", style: TextStyle(color: Colors.white, fontFamily: 'kopub')),
          content: const Text("이 서재에는 책이 없습니다.", style: TextStyle(color: Colors.white70, fontFamily: 'kopub')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("확인", style: TextStyle(color: Colors.amberAccent, fontFamily: 'kopub')),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        final width = MediaQuery.of(context).size.width;
        final Set<String> selectedBookIds = {};
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1B2C2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.all(20),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              title: const Center(
                child: Text(
                  "서재에서 책 제거",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'kopub',
                  ),
                ),
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: width > 480 ? 400 : double.infinity,
                ),
                child: SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: Scrollbar(
                    child: ListView(
                      children: booksInLibrary.map((book) {
                        final bookId = book.id;
                        final title = book.title ?? "제목 없음";
                        final isSelected = selectedBookIds.contains(bookId);

                        return GestureDetector(
                          onTap: () {
                            if (isLoading) return; // 방지
                            setState(() {
                              isSelected
                                  ? selectedBookIds.remove(bookId)
                                  : selectedBookIds.add(bookId);
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(color: Colors.white, fontFamily: 'kopub'),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                                Icon(
                                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: isSelected ? Colors.redAccent : Colors.white54,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent),
                        ),
                      )
                    else
                      TextButton(
                        child: const Text("제거", style: TextStyle(color: Colors.amberAccent)),
                        onPressed: () async {
                          setState(() => isLoading = true);
                          for (final bookId in selectedBookIds) {
                            await savedBooksProvider.removeBookFromCustomLibrary(
                              bookId,
                              libraryName,
                              customLibraryProvider: customLibraryProvider,
                            );
                          }
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                      ),
                    TextButton(
                      child: const Text("취소", style: TextStyle(color: Colors.redAccent)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 서재 삭제
  void _confirmDeleteLibrary(String libraryName) {
    showDialog(
      context: context,
      builder: (_) {
        final width = MediaQuery.of(context).size.width;

        return AlertDialog(
          backgroundColor: const Color(0xFF1B2C2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          title: const Text(
            "서재 삭제",
            style: TextStyle(fontFamily: 'kopub', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: width > 480 ? 400 : double.infinity,
            ),
            child: const Text(
              "정말로 이 서재를 삭제할까요?\n삭제한 서재는 복구할 수 없어요.",
              style: TextStyle(fontFamily: 'kopub', fontSize: 15, height: 1.4, color: Colors.white70),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final provider = Provider.of<CustomLibraryProvider>(context, listen: false);
                final savedBooksProvider = Provider.of<SavedBooksProvider>(context, listen: false);

                provider.findLibraryIdByName(libraryName).then((libraryId) {
                  if (libraryId != null) {
                    provider.deleteLibrary(libraryId, savedBooksProvider).then((_) {
                      Navigator.pop(context);
                      setState(() {
                        _currentPage = 0;
                        _pageController.jumpToPage(0);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('\'$libraryName\' 서재가 삭제되었습니다.', style: const TextStyle(color: Colors.black)),
                          backgroundColor: Colors.amberAccent,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    });
                  } else {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('서재를 찾을 수 없습니다.'),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                });
              },
              child: const Text("삭제", style: TextStyle(color: Colors.amberAccent)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소", style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

}
