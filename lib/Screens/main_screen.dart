import 'package:flutter/material.dart';
import 'home.dart';
import 'messages_screen.dart';
import 'appliances_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';
import '../services/notification_service.dart';
import '../services/location_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<MessagesScreenState> _messagesKey = GlobalKey<MessagesScreenState>();

  // Dùng IndexedStack để giữ nguyên trạng thái của các tab khi chuyển qua lại
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // Tự động cập nhật tọa độ cho khách hàng khi vào app
    LocationService.updateStatus();
    // Kiểm tra thông báo chờ (Deep Link Grab style)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.checkPendingNotification();
    });
    _screens = [
      HomeScreen(key: _homeKey),
      MessagesScreen(key: _messagesKey),
      const SizedBox(), // Chỗ trống cho Nút nổi AI
      const AppliancesScreen(),
      const ProfileScreen(),
    ];
  }

  Future<void> _openAIChat() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatScreen()),
    );
    // Khi người dùng bấm nút back (trở về) từ ChatScreen, code sẽ tiếp tục ở đây.
    // Gọi hàm loadHistory() của HomeScreen để tải lại danh sách
    _homeKey.currentState?.loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBody giúp Body tràn xuống dưới Navbar, giữ FAB cố định không bị SnackBar đẩy lên
      extendBody: true, 
      // IndexedStack giúp chuyển tab không bị load lại trang từ đầu
      body: IndexedStack(index: _currentIndex, children: _screens),

      // Nút Nổi AI (Luôn hiện trên mọi Tab)
      floatingActionButton: FloatingActionButton(
        onPressed: _openAIChat,
        backgroundColor: Colors.transparent, // Tắt màu mặc định đi
        elevation: 4,
        child: Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            // Đổi từ màu cam quê kiểng sang Gradient Cyberpunk cực chất giống nút Login bên ngoài
            gradient: LinearGradient(
              colors: [Color(0xff00E676), Color(0xff00B0FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(
            Icons.auto_awesome, // Dấu sao AI lấp lánh cực đẹp
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Thanh Navbar
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index != 2) {
            // Bỏ qua index 2 vì nó là nút AI
            setState(() {
              _currentIndex = index;
            });
            if (index == 1) {
              _messagesKey.currentState?.refreshInbox();
            }
          }
        },
      ),
    );
  }
}

// ─── Component Navbar ──────────────────────────────────────────────
class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      // FIX 1: Đổi từ Colors.white sang màu xanh đen thẫm của hệ thống
      color: const Color(0xff111B3D), 
      height: 80, 
      padding: EdgeInsets.zero, 
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      elevation: 15,
      child: SafeArea( 
        top: false, 
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(icon: Icons.home_filled, label: "Trang chủ", index: 0),
            _buildNavItem(icon: Icons.chat_bubble_outline, label: "Tin nhắn", index: 1),
            const SizedBox(width: 48), // Chừa chỗ cho nút nổi
            _buildNavItem(icon: Icons.menu_book, label: "Kho thiết bị", index: 3),
            _buildNavItem(icon: Icons.person, label: "Cá nhân", index: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = currentIndex == index;
    
    // FIX 2: Đổi activeColor sang xanh ngọc/neon để nổi bật trên nền tối
    const activeColor = Color(0xff00E676);
    // FIX 3: Đổi inactiveColor sang màu xám sáng nhẹ (grey shade) để dễ nhìn hơn trên nền tối
    const inactiveColor = Color(0xff8E9AA6); 

    return Expanded( 
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer( 
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                color: isSelected ? activeColor : inactiveColor,
                size: isSelected ? 28 : 24,
              ),
            ),
            const SizedBox(height: 2), 
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? activeColor : inactiveColor,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
