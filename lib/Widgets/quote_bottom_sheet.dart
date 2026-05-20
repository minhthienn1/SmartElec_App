import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import 'custom_loading_button.dart';

class QuoteBottomSheet extends StatefulWidget {
  final int sessionId;

  const QuoteBottomSheet({super.key, required this.sessionId});

  @override
  State<QuoteBottomSheet> createState() => _QuoteBottomSheetState();
}

class _QuoteBottomSheetState extends State<QuoteBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _timeController = TextEditingController();
  bool _isSending = false;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);
    try {
      final amount = double.parse(
        _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
      );

      await context.read<ChatProvider>().sendQuote(
        widget.sessionId,
        _titleController.text.trim(),
        amount,
        _timeController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã gửi báo giá thành công!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xff081125), // Nền tối đồng bộ với chat_screen
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Icon(Icons.receipt_long, color: Colors.blueAccent),
                  SizedBox(width: 8),
                  Text(
                    "Tạo Báo Giá Mới",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildTextField(
                _titleController,
                "Tiêu đề dịch vụ",
                "VD: Thay lốc tủ lạnh Samsung",
                Icons.build,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _amountController,
                "Số tiền dự kiến (VNĐ)",
                "VD: 1500000",
                Icons.payments_outlined,
                isNumber: true,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _timeController,
                "Thời gian thực hiện",
                "VD: 2 giờ",
                Icons.timer_outlined,
              ),
              const SizedBox(height: 30),
              CustomLoadingButton(
                text: "GỬI BÁO GIÁ NGAY",
                isLoading: _isSending,
                onPressed: _submit,
                height: 55,
                borderRadius: 15,
                gradientColors: [Colors.blueAccent, Colors.blue.shade700],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      validator: (v) =>
          v == null || v.isEmpty ? "Vui lòng nhập thông tin" : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: const Color(0xff1A244D), // Hộp nhập màu tối cao cấp
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}
