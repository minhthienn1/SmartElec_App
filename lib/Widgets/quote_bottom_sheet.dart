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
            backgroundColor: Color(0xFF10B981), 
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi: $e'),
            backgroundColor: const Color(0xFFE53935), 
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
        color: Colors.white, 
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
                    color: Colors.grey[300], 
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: Color(0xFF1565C0)),
                  SizedBox(width: 8),
                  Text(
                    "Tạo Báo Giá Mới",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A), 
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildTextField(
                _titleController,
                "Tiêu đề dịch vụ",
                "VD: Thay lốc tủ lạnh Samsung",
                Icons.build_rounded,
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
                gradientColors: const [Color(0xFF1565C0), Color(0xFF1565C0)], 
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
      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500), 
      validator: (v) =>
          v == null || v.isEmpty ? "Vui lòng nhập thông tin" : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.normal),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: const Color(0xFF1565C0)), 
        filled: true,
        fillColor: const Color(0xFFF4F6F9), 
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1), 
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5), 
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16, 
        ),
      ),
    );
  }
}