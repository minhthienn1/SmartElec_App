import 'package:flutter/material.dart';

class QuickBookingDialog extends StatefulWidget {
  final Function(String device, String symptom) onConfirm;

  const QuickBookingDialog({super.key, required this.onConfirm});

  @override
  State<QuickBookingDialog> createState() => _QuickBookingDialogState();
}

class _QuickBookingDialogState extends State<QuickBookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _symptomController = TextEditingController();

  // Danh sách các loại thiết bị phổ biến để chọn nhanh
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
    // Đóng Dialog trước để tránh race condition khi onConfirm thực hiện Navigator.push
    Navigator.pop(context);
    // Trả về thiết bị và mô tả sự cố
    widget.onConfirm(
      _selectedDevice!,
      _symptomController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xff081125), // Đổi sang Premium Dark Theme đồng bộ
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.flash_on, color: Colors.amber),
          SizedBox(width: 8),
          Text(
            "Đặt thợ khẩn cấp",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
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
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 16),

              // Dropdown Chọn thiết bị - Đồng bộ Dark Theme + Hạn chế chiều cao menu
              DropdownButtonFormField<String>(
                value: _selectedDevice,
                dropdownColor: const Color(0xff1A244D), // Nền của danh sách xổ xuống tối màu
                menuMaxHeight: 220, // ⚡ Hạn chế chiều cao menu xổ xuống và tự động bật Scroll
                style: const TextStyle(color: Colors.white),
                items: _devices
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(
                            d,
                            style: const TextStyle(fontSize: 14, color: Colors.white),
                          ),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedDevice = val),
                validator: (val) => val == null ? "Vui lòng chọn loại thiết bị" : null,
                decoration: InputDecoration(
                  labelText: "Chọn thiết bị",
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: const Color(0xff1A244D),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Ô nhập mô tả sự cố - Đồng bộ Dark Theme
              TextFormField(
                controller: _symptomController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                validator: (v) => (v == null || v.trim().isEmpty) ? "Vui lòng nhập mô tả sự cố" : null,
                decoration: InputDecoration(
                  labelText: "Mô tả sự cố (VD: Máy không mát, chảy nước...)",
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: const Color(0xff1A244D),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
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
          child: const Text("Hủy", style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent, // Đồng bộ xanh dương cao cấp
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text("TIẾP TỤC", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
