import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import 'package:smart_elec/providers/user_provider.dart';
import 'package:smart_elec/services/api_service.dart';

class TechProfileScreen extends StatefulWidget {
  const TechProfileScreen({super.key});

  @override
  State<TechProfileScreen> createState() => _TechProfileScreenState();
}

class _TechProfileScreenState extends State<TechProfileScreen> {

  // Trạng thái ảnh đại diện
  Uint8List? _avatarBytes;     // Dữ liệu ảnh nhị phân (base64 đã decode)
  bool _isUploadingAvatar = false;
  bool _isLoadingProfile = true;

  // Thông tin người dùng
  String? _fullName;
  String? _phoneNumber;
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // --- TẢI THÔNG TIN PROFILE (bao gồm ảnh đại diện dạng base64) ---
  Future<void> _loadProfile() async {
    try {
      final data = await ApiService.getProfile();
      if (!mounted) return;

      setState(() {
        _fullName = data['fullName'] as String?;
        _phoneNumber = data['phoneNumber'] as String?;
        _email = data['email'] as String?;

        // Backend trả về avatarBase64 — decode thẳng thành bytes để hiển thị
        final avatarBase64 = data['avatarBase64'] as String?;
        if (avatarBase64 != null && avatarBase64.isNotEmpty) {
          _avatarBytes = base64Decode(avatarBase64);
        }
        _isLoadingProfile = false;
      });
    } catch (e) {
      debugPrint('❌ [TechProfile] Lỗi tải profile: $e');
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  // --- MỞ BOTTOMSHEET CHỌN ẢNH ---
  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dấu kéo
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const Text(
              'Cập nhật ảnh đại diện',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 20),
            // Nút chụp ảnh mới
            _buildPickerOption(
              icon: Icons.camera_alt_rounded,
              label: 'Chụp ảnh mới',
              color: Colors.blueAccent,
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
            // Nút chọn từ thư viện
            _buildPickerOption(
              icon: Icons.photo_library_rounded,
              label: 'Chọn từ thư viện',
              color: Colors.blueAccent,
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.13),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- CHỌN ẢNH VÀ UPLOAD LÊN BACKEND ---
  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        imageQuality: 100, // Cắt trước rồi mới nén chất lượng
      );

      if (picked == null) return; // Người dùng hủy chọn ảnh

      // Cắt ảnh thành hình vuông chuẩn
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 75,
        maxWidth: 800,
        maxHeight: 800,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Căn chỉnh ảnh đại diện',
            toolbarColor: Colors.blueAccent,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Căn chỉnh ảnh đại diện',
            aspectRatioLockEnabled: true,
            resetButtonHidden: true,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );

      if (croppedFile == null) return; // Người dùng hủy cắt ảnh

      setState(() => _isUploadingAvatar = true);

      // Gửi file lên backend → backend lưu dưới dạng Bytes → trả về base64
      final base64Result = await ApiService.uploadAvatar(croppedFile.path);

      if (!mounted) return;
      setState(() {
        _avatarBytes = base64Decode(base64Result); // Decode base64 → bytes để hiển thị ngay
        _isUploadingAvatar = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Ảnh đại diện đã được cập nhật!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('❌ [TechProfile] Lỗi upload avatar: $e');
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      
      String errorMsg = e.toString().replaceAll("Exception: ", "");
      // Bắt lỗi khi giả lập hoặc máy thật không có/từ chối camera
      if (errorMsg.toLowerCase().contains('camera_access_denied') || 
          errorMsg.toLowerCase().contains('no_available_camera')) {
        errorMsg = 'Không tìm thấy máy ảnh trên thiết bị hoặc bị từ chối quyền.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Lỗi: $errorMsg'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // --- ĐĂNG XUẤT ---
  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Đăng xuất',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Bạn có chắc muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator()),
        );
      }

      if (context.mounted) {
        await Provider.of<UserProvider>(context, listen: false).logout();
      }

      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      debugPrint('❌ [TechProfileScreen] Lỗi đăng xuất: $e');
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi đăng xuất. Vui lòng thử lại!'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- WIDGET AVATAR CÓ ICON CAMERA ---
  Widget _buildAvatarWithCamera() {
    return GestureDetector(
      onTap: _isUploadingAvatar ? null : _showAvatarPicker,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          // Avatar bo tròn
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blueAccent, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.2),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: _isUploadingAvatar
                  // Hiển thị loading spinner khi đang upload
                  ? Container(
                      color: Colors.blueAccent.withOpacity(0.1),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.blueAccent,
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  : _avatarBytes != null
                      // Ảnh từ database (bytes decode từ base64) — không bao giờ bị méo
                      ? Image.memory(
                          _avatarBytes!,
                          fit: BoxFit.cover,
                          width: 104,
                          height: 104,
                        )
                      // Placeholder mặc định khi chưa có ảnh
                      : Container(
                          color: Colors.blueAccent,
                          child: const Icon(
                            Icons.engineering,
                            size: 55,
                            color: Colors.white,
                          ),
                        ),
            ),
          ),

          // Icon camera nhỏ ở góc dưới phải
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Cá nhân Kỹ thuật',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar với camera icon
                  _buildAvatarWithCamera(),
                  const SizedBox(height: 16),

                  // Tên kỹ thuật viên
                  Text(
                    _fullName ?? 'Kỹ thuật viên SmartElec',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _phoneNumber ?? 'Chuyên viên sửa chữa',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (_email != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _email!,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 50),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      onPressed: () => _handleLogout(context),
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      label: const Text(
                        'Đăng xuất tài khoản',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
