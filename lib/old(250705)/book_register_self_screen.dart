import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:dayverse_book/provider/saved_books_provider.dart';
import 'package:dayverse_book/utils/book_utils.dart';
import 'package:dayverse_book/model/book_model.dart';


class BookRegisterSelfScreen extends StatefulWidget {
  const BookRegisterSelfScreen({super.key});

  @override
  _BookRegisterSelfScreenState createState() => _BookRegisterSelfScreenState();
}

class _BookRegisterSelfScreenState extends State<BookRegisterSelfScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _publisherController = TextEditingController();
  final TextEditingController _isbnController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  File? _selectedImage;

  String selectedCategory = "done";
  DateTime? startDate = DateTime.now();
  DateTime? endDate = DateTime.now();

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await showModalBottomSheet<XFile>(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("카메라로 촬영"),
              onTap: () async {
                Navigator.pop(context,
                    await picker.pickImage(source: ImageSource.camera));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text("앨범에서 선택"),
              onTap: () async {
                Navigator.pop(context,
                    await picker.pickImage(source: ImageSource.gallery));
              },
            ),
          ],
        );
      },
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 10) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF013328),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text("책 직접 등록하기",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            TextButton(
              onPressed: _saveBook,
              child: const Text("저장",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _selectedImage != null
                        ? Image.file(_selectedImage!,
                            width: 120, height: 180, fit: BoxFit.cover)
                        : Container(
                            width: 120,
                            height: 180,
                            color: Colors.grey[700],
                            child: const Center(
                              child: Text("이미지를 직접 등록하세요",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 14)),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField("책 제목", _titleController),
              _buildTextField("저자", _authorController),
              _buildTextField("출판사", _publisherController),
              _buildTextField("ISBN", _isbnController),
              _buildTextField("책 소개", _descriptionController, maxLines: 3),
              const Divider(color: Colors.white38, thickness: 1, height: 30),
              _buildCategorySelector(),
              const SizedBox(height: 15),
              if (selectedCategory == "done" || selectedCategory == "reading")
                _buildDateSelector(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white70)),
        const SizedBox(height: 5),
        Container(
          height: maxLines == 1 ? 48 : null,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 16, color: Colors.white),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: "입력하세요...",
              hintStyle: TextStyle(color: Colors.white54),
              contentPadding: EdgeInsets.only(bottom: 5),
            ),
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _categoryButton("읽은 책", "done"),
        _categoryButton("읽는 중인 책", "reading"),
        _categoryButton("읽을 예정인 책", "want"),
      ],
    );
  }

  Widget _categoryButton(String title, String value) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedCategory = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: selectedCategory == value ? Colors.white : Colors.white24,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selectedCategory == value
                  ? const Color(0xFF013328)
                  : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _datePicker("시작일", startDate ?? DateTime.now(), (date) {
          setState(() {
            startDate = date;
            if (endDate != null && endDate!.isBefore(startDate!)) {
              endDate = startDate;
            }
          });
        }, DateTime(2000), DateTime.now()),
        if (selectedCategory == "done")
          _datePicker("종료일", endDate ?? startDate ?? DateTime.now(), (date) {
            setState(() {
              if (date.isBefore(startDate!)) return;
              endDate = date;
            });
          }, startDate ?? DateTime.now(), DateTime(2100)),
      ],
    );
  }

  Widget _datePicker(String label, DateTime date, Function(DateTime) onDateSelected, DateTime firstDate, DateTime lastDate) {
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          DateTime? picked = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: firstDate,
            lastDate: lastDate,
          );
          if (picked != null) onDateSelected(picked);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              Text(
                DateFormat('yy/MM/dd').format(date),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveBook() async {
    if (_titleController.text.trim().isEmpty) {
      _showErrorDialog("책 제목을 입력해주세요!");
      return;
    }

    final id = generateBookId(
      _isbnController.text.trim().isEmpty ? null : _isbnController.text.trim(),
      _titleController.text.trim(),
      _authorController.text.trim(),
    );

    final newBook = BookModel(
      id: id,
      title: _titleController.text.trim(),
      author: _authorController.text.trim(),
      publisher: _publisherController.text.trim(),
      isbn: _isbnController.text.trim(),
      description: _descriptionController.text.trim(),
      imageFile: _selectedImage,
      category: selectedCategory,
      startDate: selectedCategory != "want" ? startDate : null,
      endDate: selectedCategory == "done" ? endDate : null,
    );

    final provider = Provider.of<SavedBooksProvider>(context, listen: false);
    final isDuplicate = provider.savedBooks.any((b) => b.id == id);
    if (isDuplicate) {
      _showErrorDialog("이미 등록된 책입니다!");
      return;
    }

    provider.addOrUpdateBook(newBook);
    showBookSavedDialog(context, _titleController.text);
  }

  void showBookSavedDialog(BuildContext context, String bookTitle) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(milliseconds: 1300), () {
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          }
        });

        return AlertDialog(
          backgroundColor: Colors.amberAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "$bookTitle\n책이 등록되었습니다!",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        Future.delayed(const Duration(seconds: 2), () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });

        return AlertDialog(
          backgroundColor: Colors.redAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}
