import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'custom_loading_button.dart';
import '../Screens/location_picker_screen.dart';

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

class BookingBottomSheet extends StatefulWidget {
  final int sessionId;
  final String? deviceType;
  final String? symptom;
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialCity;
  final String? initialDistrict;
  final String? initialStreet;
  final Future<void> Function(Map<String, dynamic> bookingData) onConfirm;

  const BookingBottomSheet({
    super.key,
    required this.sessionId,
    this.deviceType,
    this.symptom,
    this.initialLatitude,
    this.initialLongitude,
    this.initialCity,
    this.initialDistrict,
    this.initialStreet,
    required this.onConfirm,
  });

  @override
  State<BookingBottomSheet> createState() => _BookingBottomSheetState();
}

class _BookingBottomSheetState extends State<BookingBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;
  late TextEditingController _detailAddressController;
  bool _isLoading = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<UserProvider>(context, listen: false).user;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    _cityController = TextEditingController(text: widget.initialCity ?? '');
    _detailAddressController = TextEditingController(text: widget.initialStreet ?? user?.address ?? '');
    _latitude = widget.initialLatitude;
    _longitude = widget.initialLongitude;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _detailAddressController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _latitude = result['lat'];
        _longitude = result['lng'];
        _cityController.text = result['city'] ?? '';
        _detailAddressController.text = result['street'] ?? '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Đã lấy địa chỉ từ bản đồ!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleConfirm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final fullAddress = "${_detailAddressController.text.trim()}, ${_cityController.text.trim()}";

    setState(() => _isLoading = true);
    try {
      await widget.onConfirm({
        'contactName': _nameController.text.trim(),
        'contactPhone': _phoneController.text.trim(),
        'address': fullAddress,
        'latitude': _latitude,
        'longitude': _longitude,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Lỗi: ${e.toString().replaceAll('Exception: ', '')}"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.kIdleBorder, width: 1),
    );

    final focusBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.kPrimaryOrange, width: 1.5),
    );

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 16),
      decoration: const BoxDecoration(
        color: AppColors.kBackground, 
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.kMutedGrey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Chi tiết yêu cầu thợ",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.kTextPrimary, 
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.kLightOrange,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.kPrimaryOrange.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.build_circle,
                        color: AppColors.kPrimaryOrange,
                        size: 36,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.deviceType ?? "Thiết bị không xác định",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.kTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.symptom ?? "Đã được chẩn đoán bởi AI",
                              style: const TextStyle(
                                color: AppColors.kTextSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  "Thông tin liên hệ",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.kTextSecondary),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: AppColors.kTextPrimary),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Vui lòng nhập tên" : null,
                  decoration: InputDecoration(
                    labelText: "Tên người nhận",
                    labelStyle: const TextStyle(color: AppColors.kTextSecondary),
                    prefixIcon: const Icon(Icons.person_outline, color: AppColors.kMutedGrey),
                    filled: true,
                    fillColor: AppColors.kInputBackground,
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    focusedBorder: focusBorder,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: AppColors.kTextPrimary),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Vui lòng nhập SĐT" : null,
                  decoration: InputDecoration(
                    labelText: "Số điện thoại",
                    labelStyle: const TextStyle(color: AppColors.kTextSecondary),
                    prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.kMutedGrey),
                    filled: true,
                    fillColor: AppColors.kInputBackground,
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    focusedBorder: focusBorder,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Vị trí sửa chữa",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.kTextSecondary),
                    ),
                    TextButton.icon(
                      onPressed: _fetchLocation,
                      icon: const Icon(Icons.my_location, size: 16, color: AppColors.kPrimaryOrange),
                      label: const Text(
                        "Lấy vị trí từ bản đồ",
                        style: TextStyle(fontSize: 12, color: AppColors.kPrimaryOrange, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                TextFormField(
                  controller: _cityController,
                  style: const TextStyle(color: AppColors.kTextPrimary),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Thiếu Tỉnh/Thành phố" : null,
                  decoration: InputDecoration(
                    labelText: "Tỉnh/Thành phố",
                    labelStyle: const TextStyle(color: AppColors.kTextSecondary),
                    prefixIcon: const Icon(Icons.map_outlined, color: AppColors.kMutedGrey),
                    filled: true,
                    fillColor: AppColors.kInputBackground,
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    focusedBorder: focusBorder,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _detailAddressController,
                  maxLines: 2,
                  style: const TextStyle(color: AppColors.kTextPrimary),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Vui lòng nhập số nhà/đường" : null,
                  decoration: InputDecoration(
                    labelText: "Số nhà, tên đường, phường/xã...",
                    labelStyle: const TextStyle(color: AppColors.kTextSecondary),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Icon(Icons.location_on_outlined, color: AppColors.kMutedGrey),
                    ),
                    filled: true,
                    fillColor: AppColors.kInputBackground,
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    focusedBorder: focusBorder,
                  ),
                ),

                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: CustomLoadingButton(
                      text: "XÁC NHẬN & TÌM THỢ",
                      isLoading: _isLoading,
                      onPressed: _handleConfirm,
                      // Đổi sang màu cam đồng bộ rực rỡ
                      gradientColors: const [AppColors.kPrimaryOrange, AppColors.kDarkOrange],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}