import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_elec/providers/device_provider.dart';
import 'package:smart_elec/models/device.dart';
import 'package:smart_elec/Widgets/custom_loading_button.dart';

class AppColors {
  static const Color kPrimaryOrange = Color(0xFFFF7A00);
  static const Color kDarkOrange = Color(0xFFE65C00); 
  static const Color kLightOrange = Color(0xFFFFF3E0); 
  static const Color kBackground = Color(0xFFF9FAFB); 
  static const Color kInputBackground = Colors.white;
  static const Color kTextPrimary = Color(0xFF1F2937);
  static const Color kTextSecondary = Color(0xFF6B7280);
  static const Color kMutedGrey = Color(0xFF9CA3AF);
  static const Color kErrorRed = Color(0xFFEF4444);
  static const Color kIdleBorder = Color(0xFFD1D5DB);
}

class AddDeviceScreen extends StatefulWidget {
  final Device? device;
  const AddDeviceScreen({super.key, this.device});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _formKey = GlobalKey<FormState>();

  String _category = 'Tủ lạnh';
  final _brandNameController = TextEditingController();
  final _modelCodeController = TextEditingController();
  final _locationController = TextEditingController();
  final _warrantyController = TextEditingController();
  final _maintenanceController = TextEditingController();

  bool _isSaving = false;

  final List<String> _categories = [
    'Tủ lạnh',
    'Máy lạnh',
    'Máy giặt',
    'Tivi',
    'Lò vi sóng',
    'Nồi cơm',
    'Ấm đun',
    'Khác',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.device != null) {
      final d = widget.device!;
      if (_categories.contains(d.category)) {
        _category = d.category;
      } else {
        _category = 'Khác';
      }
      _brandNameController.text = d.brandName;
      _modelCodeController.text = d.modelCode ?? '';
      _locationController.text = d.location ?? '';
      if (d.maintenanceCycleMonths != null) {
        _maintenanceController.text = d.maintenanceCycleMonths.toString();
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = <String, dynamic>{
        'category': _category,
        'brandName': _brandNameController.text.trim(),
        'modelCode': _modelCodeController.text.trim(),
        'location': _locationController.text.trim(),
      };

      if (_warrantyController.text.trim().isNotEmpty) {
        data['warrantyMonths'] = int.parse(_warrantyController.text.trim());
      }
      if (_maintenanceController.text.trim().isNotEmpty) {
        data['maintenanceCycleMonths'] = int.parse(
          _maintenanceController.text.trim(),
        );
      }

      final provider = Provider.of<DeviceProvider>(context, listen: false);
      if (widget.device == null) {
        await provider.addNewDevice(data);
      } else {
        await provider.updateDevice(widget.device!.id, data);
      }

      if (!mounted) return;
      _showCustomSnackBar(
        widget.device == null
            ? 'Đã thêm thiết bị mới!'
            : 'Đã cập nhật thiết bị!',
        isError: false,
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _showCustomSnackBar('Lỗi: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showCustomSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: isError ? AppColors.kErrorRed : AppColors.kPrimaryOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _brandNameController.dispose();
    _modelCodeController.dispose();
    _locationController.dispose();
    _warrantyController.dispose();
    _maintenanceController.dispose();
    super.dispose();
  }

  // ─── Builder Helpers ──────────────────────────────────────────────

  InputDecoration _inputDeco(String hint, IconData icon, {String? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.kMutedGrey, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.kPrimaryOrange, size: 22),
      suffixText: suffix,
      suffixStyle: const TextStyle(color: AppColors.kTextSecondary, fontSize: 13),
      filled: true,
      fillColor: AppColors.kInputBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.kIdleBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.kIdleBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.kPrimaryOrange, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.kErrorRed, width: 1),
      ),
    );
  }

  Widget _buildLabel(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.kTextPrimary,
          ),
          children: [
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: AppColors.kErrorRed),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Main Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: AppBar(
        backgroundColor: AppColors.kBackground,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.kTextPrimary, // Đổi sang màu chữ đậm để nổi trên nền trắng
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.device == null ? 'THÊM THIẾT BỊ' : 'CẬP NHẬT',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.kTextPrimary,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Hướng dẫn nhỏ
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.kLightOrange,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.kPrimaryOrange.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.kPrimaryOrange,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Điền đầy đủ thông tin để thêm chính xác thiết bị nhé",
                        style: TextStyle(color: AppColors.kDarkOrange, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildLabel('Loại thiết bị', required: true),
              DropdownButtonFormField<String>(
                value: _category,
                dropdownColor: AppColors.kInputBackground,
                style: const TextStyle(color: AppColors.kTextPrimary, fontSize: 15),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.kTextSecondary,
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _category = val!),
                decoration: _inputDeco(
                  'Chọn loại thiết bị',
                  Icons.category_rounded,
                ),
              ),
              const SizedBox(height: 20),

              _buildLabel('Thương hiệu', required: true),
              TextFormField(
                controller: _brandNameController,
                style: const TextStyle(color: AppColors.kTextPrimary),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Vui lòng nhập tên hãng'
                    : null,
                decoration: _inputDeco(
                  'VD: Sony, Samsung, Daikin...',
                  Icons.branding_watermark_rounded,
                ),
              ),
              const SizedBox(height: 20),

              _buildLabel('Mã máy (Model Code)'),
              TextFormField(
                controller: _modelCodeController,
                style: const TextStyle(color: AppColors.kTextPrimary),
                decoration: _inputDeco(
                  'VD: UA55TU8000...',
                  Icons.qr_code_scanner_rounded,
                ),
              ),
              const SizedBox(height: 20),

              _buildLabel('Vị trí lắp đặt'),
              TextFormField(
                controller: _locationController,
                style: const TextStyle(color: AppColors.kTextPrimary),
                decoration: _inputDeco(
                  'VD: Nhà bếp, Tầng 2...',
                  Icons.room_rounded,
                ),
              ),
              const SizedBox(height: 24),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Bảo hành'),
                        TextFormField(
                          controller: _warrantyController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppColors.kTextPrimary),
                          decoration: _inputDeco(
                            '24',
                            Icons.verified_user_rounded,
                            suffix: 'th',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Chu kỳ bảo trì'),
                        TextFormField(
                          controller: _maintenanceController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppColors.kTextPrimary),
                          decoration: _inputDeco(
                            '6',
                            Icons.history_rounded,
                            suffix: 'th',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: CustomLoadingButton(
            text: widget.device == null ? 'THÊM THIẾT BỊ' : 'LƯU THIẾT BỊ',
            isLoading: _isSaving,
            onPressed: _submitForm,
            height: 54,
            borderRadius: 14,
            gradientColors: const [
              AppColors.kPrimaryOrange,
              AppColors.kDarkOrange,
            ], 
          ),
        ),
      ),
    );
  }
}