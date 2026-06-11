import 'package:flutter/material.dart';

// Đảm bảo class AppColors đã được định nghĩa hoặc import từ home.txt
class AppColors {
  static const Color kPrimaryOrange = Color(0xFFFF7A00);
  static const Color kDarkOrange = Color(0xFFE65C00); 
  static const Color kLightOrange = Color(0xFFFFF3E0); 
  static const Color kBackground = Color(0xFFF9FAFB); 
  static const Color kInputBackground = Colors.white;
  static const Color kTextPrimary = Color(0xFF1F2937);
  static const Color kTextSecondary = Color(0xFF6B7280);
  static const Color kMutedGrey = Color(0xFF9CA3AF);
  static const Color kIdleBorder = Color(0xFFE5E7EB);
}

class QuickBookingDialog extends StatefulWidget {
  final Function(String device, String symptom) onConfirm;

  const QuickBookingDialog({super.key, required this.onConfirm});

  @override
  State<QuickBookingDialog> createState() => _QuickBookingDialogState();
}

class _QuickBookingDialogState extends State<QuickBookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _symptomController = TextEditingController();

  final List<String> _devices = [
    "Điều hòa / Máy lạnh",
    "Tủ lạnh",
    "Máy giặt",
    "Tivi / Smart TV",
    "Bếp từ / Bếp ga",
    "Quạt điện",
    "Bình nóng lạnh",
    "Thiết bị điện tử khác",
  ];

  String? _selectedDevice;

  @override
  void dispose() {
    _symptomController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || _selectedDevice == null) {
      return;
    }
    Navigator.pop(context);
    widget.onConfirm(
      _selectedDevice!,
      _symptomController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Định nghĩa Style đường viền đồng bộ cho Theme sáng
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.kIdleBorder, width: 1),
    );

    final focusBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.kPrimaryOrange, width: 1.5),
    );

    return AlertDialog(
      backgroundColor: Colors.white, // Chuyển hẳn sang nền Trắng Premium
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.flash_on, color: AppColors.kPrimaryOrange), // Icon đổi thành cam rực rỡ
          SizedBox(width: 8),
          Text(
            "Đặt thợ khẩn cấp",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.kTextPrimary),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Chọn loại thiết bị và mô tả ngắn gọn sự cố để thợ biết đường chuẩn bị dụng cụ nhé.",
                style: TextStyle(fontSize: 13, color: AppColors.kTextSecondary),
              ),
              const SizedBox(height: 16),

              // Dropdown Chọn thiết bị - Đồng bộ Light Theme mới
              DropdownButtonFormField<String>(
                value: _selectedDevice,
                dropdownColor: Colors.white, // Danh sách xổ xuống màu nền trắng sạch sẽ
                menuMaxHeight: 220,
                iconEnabledColor: AppColors.kPrimaryOrange,
                style: const TextStyle(color: AppColors.kTextPrimary),
                items: _devices
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(
                            d,
                            style: const TextStyle(fontSize: 14, color: AppColors.kTextPrimary),
                          ),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedDevice = val),
                validator: (val) => val == null ? "Vui lòng chọn loại thiết bị" : null,
                decoration: InputDecoration(
                  labelText: "Chọn thiết bị",
                  labelStyle: const TextStyle(color: AppColors.kTextSecondary),
                  filled: true,
                  fillColor: AppColors.kInputBackground,
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: focusBorder,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Ô nhập mô tả sự cố - Đồng bộ Light Theme mới
              TextFormField(
                controller: _symptomController,
                maxLines: 3,
                style: const TextStyle(color: AppColors.kTextPrimary),
                validator: (v) => (v == null || v.trim().isEmpty) ? "Vui lòng nhập mô tả sự cố" : null,
                decoration: InputDecoration(
                  labelText: "Mô tả sự cố (VD: Máy không mát, chảy nước...)",
                  labelStyle: const TextStyle(color: AppColors.kTextSecondary),
                  filled: true,
                  fillColor: AppColors.kInputBackground,
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: focusBorder,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Hủy", style: TextStyle(color: AppColors.kTextSecondary, fontWeight: FontWeight.w500)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.kPrimaryOrange, // Chuyển sang nút Cam thương hiệu
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text("TIẾP TỤC", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}