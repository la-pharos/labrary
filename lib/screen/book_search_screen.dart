import 'package:flutter/material.dart';
import 'package:dayverse_book/model/book_model.dart';
import 'package:dayverse_book/screen/book_register_screen.dart';
import 'package:dayverse_book/old(250705)/book_register_self_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/service/book_api_service.dart';
import 'package:dayverse_book/widget/ad_banner_placeholder.dart';

enum SearchState { idle, focused, submitted }

class BookSearchScreen extends StatefulWidget {
  const BookSearchScreen({super.key});

  @override
  _BookSearchScreenState createState() => _BookSearchScreenState();
}

class _BookSearchScreenState extends State<BookSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  SearchState _searchState = SearchState.idle;
  List<BookModel> _searchResults = [];
  bool _isLoading = false;

  List<BookModel> _bestsellers = [];
  bool _isBestsellerLoading = false;

  void _searchBooks(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _searchState = SearchState.submitted;
      _isLoading = true;
      _searchResults = [];
    });

    try {
      final result = await BookApiService.searchBooksCombined(query);
      setState(() => _searchResults = result);
    } catch (e) {
      debugPrint("📛 검색 실패: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("검색 중 오류가 발생했습니다.")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _scanBarcode() async {
    final String? scannedISBN = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BarcodeScannerScreen()),
    );

    if (scannedISBN != null) {
      _searchController.text = scannedISBN;
      _searchBooks(scannedISBN);
    }
  }

  @override
  void initState() {
    super.initState();

    _loadBestsellers(); // ✅ 여기 추가
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _searchController.text.isEmpty) {
        setState(() => _searchState = SearchState.focused);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final savedBooksProvider = Provider.of<SavedBooksProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final adHeight = screenHeight * 0.08;

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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            "책 추가하기",
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'kopub',
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.bold,
            ),
          ),
          //actions: [
          //  IconButton(
          //    icon: const Icon(Icons.document_scanner_outlined, color: Colors.white),
          //    onPressed: _scanBarcode,
          //  ),
          //],
        ),
        body: Stack(
          children: [
            // ✅ Stack이 화면 전체를 쓰게 만듦
            SizedBox(
              height: screenHeight,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: screenWidth * 0.04,
                    right: screenWidth * 0.04,
                    top: screenWidth * 0.04,
                    bottom: adHeight,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ 검색창
                      TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white24,
                          hintText: "책 제목 / 작가를 입력하세요",
                          hintStyle: TextStyle(
                            color: Colors.white54,
                            fontFamily: 'kopub',
                            fontSize: screenWidth * 0.035,
                          ),
                          prefixIcon: const Icon(Icons.search, color: Colors.white),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchResults.clear();
                                _searchState = SearchState.idle;
                              });
                            },
                          )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (query) => _searchBooks(query),
                        onChanged: (text) {
                          if (text.isEmpty) {
                            setState(() => _searchState = SearchState.idle);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // ✅ 리스트 뷰
                      _buildSearchResultView(
                        savedBooksProvider,
                        screenWidth,
                        screenHeight,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ✅ 광고는 진짜 화면 하단에 고정
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BottomAdBannerBar(),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSearchResultView(SavedBooksProvider provider, double screenWidth, double screenHeight) {
    if (_isLoading || _isBestsellerLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_searchState) {
      case SearchState.focused:
        return const SizedBox.shrink();

      case SearchState.submitted:
        if (_searchResults.isEmpty) {
          return Center(
            child: Text(
              "검색 결과가 없습니다.",
              style: TextStyle(
                color: Colors.white54,
                fontFamily: 'kopub',
                fontSize: screenWidth * 0.04,
              ),
            ),
          );
        }
        return _buildBookList(context, _searchResults, provider, screenWidth);

      case SearchState.idle:
      default:
        return _bestsellers.isEmpty
            ? Center(
          child: Text(
            "베스트셀러를 불러오는 중입니다.",
            style: TextStyle(
              color: Colors.white54,
              fontSize: screenWidth * 0.035,
            ),
          ),
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
              child: Center(
                child: Text(
                  "어제 베스트셀러 TOP 10",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.035,
                    fontFamily: 'kopub',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: screenHeight * 1.2, // ⬅️ 높이는 상황에 맞게 조정 가능
              child: _buildBookList(context, _bestsellers, provider, screenWidth, showRank: true),
            ),

          ],
        );
    }
  }

  Widget _buildBookList(
      BuildContext context,
      List<BookModel> books,
      SavedBooksProvider provider,
      double screenWidth, {
        bool showRank = false,
        double bottomExtra = 0,
      }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final adHeight = screenHeight * 0.08;

    return ListView.builder(
      // 🔧 핵심 수정
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),

      padding: EdgeInsets.only(bottom: adHeight + bottomExtra + 24),
      itemCount: books.length + 1,
      itemBuilder: (context, index) {
        if (index == books.length) {
          return SizedBox(height: screenHeight * 0.02);
        }

        final book = books[index];
        final isDuplicate = provider.savedBooks.any((b) => b.id == book.id);

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => BookRegisterScreen(book: book)),
            );
          },
          child: _buildBookTile(book, screenWidth, index: showRank ? index + 1 : null),
        );
      },
    );
  }

  Widget _buildBookTile(BookModel book, double screenWidth, {int? index}) {
    final imageWidth = screenWidth * 0.13;
    final imageHeight = screenWidth * 0.18;

    return Container(
      margin: EdgeInsets.symmetric(vertical: screenWidth * 0.01),
      padding: EdgeInsets.all(screenWidth * 0.02),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (index != null)
            Padding(
              padding: EdgeInsets.only(right: screenWidth * 0.03),
              child: Text(
                "$index",
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'kopub',
                ),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Image.network(
              book.imageUrl ?? "",
              width: imageWidth,
              height: imageHeight,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: imageWidth,
                height: imageHeight,
                color: Colors.grey,
                child: const Icon(Icons.book, color: Colors.white, size: 30),
              ),
            ),
          ),
          SizedBox(width: screenWidth * 0.03),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize: screenWidth * 0.03,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: screenWidth * 0.005),
                Text(
                  "${book.author} • ${book.publisher ?? ''}",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: screenWidth * 0.03,
                    fontFamily: 'kopub',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadBestsellers() async {
    setState(() {
      _isBestsellerLoading = true;
    });

    try {
      final result = await BookApiService.fetchBestsellersWithNaverData(); // ✅ 수정된 통합 함수 사용
      setState(() {
        _bestsellers = result;
      });
    } catch (e) {
      debugPrint("📛 베스트셀러 불러오기 실패: $e");
    } finally {
      setState(() {
        _isBestsellerLoading = false;
      });
    }
  }

}

class BarcodeScannerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("ISBN 바코드 스캔", style: TextStyle(color: Colors.white)),
      ),
      body: MobileScanner(
        onDetect: (BarcodeCapture capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final String? scannedISBN = barcodes.first.rawValue;
            if (scannedISBN != null) {
              Navigator.pop(context, scannedISBN);
            }
          }
        },
      ),
    );
  }

}
