import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // Bắt buộc có để dùng ScrollDirection
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
  
  // LOGIC SCROLL: Trạng thái ẩn/hiện của BottomNav và Nút nổi AI
  bool _isBottomNavVisible = true; 
  
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<MessagesScreenState> _messagesKey = GlobalKey<MessagesScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    LocationService.updateStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.checkPendingNotification();
    });
    _screens = [
      HomeScreen(key: _homeKey),
      MessagesScreen(key: _messagesKey),
      const SizedBox(), 
      const AppliancesScreen(),
      const ProfileScreen(),
    ];
  }

  Future<void> _openAIChat() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatScreen()),
    );
    _homeKey.currentState?.loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == ScrollDirection.reverse) {
            
            if (_isBottomNavVisible) {
              setState(() {
                _isBottomNavVisible = false;
              });
            }
          } else if (notification.direction == ScrollDirection.forward) {
            if (!_isBottomNavVisible) {
              setState(() {
                _isBottomNavVisible = true;
              });
            }
          }
          return true;
        },
        child: IndexedStack(index: _currentIndex, children: _screens),
      ),

      floatingActionButton: AnimatedScale(
        scale: _isBottomNavVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.fastOutSlowIn,
        child: FloatingActionButton(
          onPressed: _openAIChat,
          backgroundColor: Colors.transparent,
          elevation: 6,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6D00).withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
              gradient: const LinearGradient(
                colors: [Color(0xFFFF9800), Color(0xFFFF5252)], 
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.auto_awesome, 
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      
      bottomNavigationBar: AnimatedSlide(
        offset: _isBottomNavVisible ? Offset.zero : const Offset(0, 1.0),
        duration: const Duration(milliseconds: 250),
        curve: Curves.fastOutSlowIn,
        child: CustomBottomNav(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index != 2) {
              setState(() {
                _currentIndex = index;
              });
              if (index == 1) {
                _messagesKey.currentState?.refreshInbox();
              }
            }
          },
        ),
      ),
    );
  }
}

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
      color: Colors.white, 
      height: 80,
      padding: EdgeInsets.zero,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      elevation: 20, 
      shadowColor: Colors.black.withOpacity(0.5),
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
    const activeColor = Color(0xFFFF6D00);
    const inactiveColor = Color(0xFF9E9E9E); 

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
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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