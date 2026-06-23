import 'package:flutter/material.dart';
import 'job_board_screen.dart';
import 'tech_messages_screen.dart';
import 'profile_screen.dart';
import '../Screens/chat_screen.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import 'tech_color.dart';
import 'tech_my_jobs_screen.dart';

class TechnicianMainScreen extends StatefulWidget {
  const TechnicianMainScreen({super.key});

  @override
  State<TechnicianMainScreen> createState() => _TechnicianMainScreenState();
}

class _TechnicianMainScreenState extends State<TechnicianMainScreen> {
  int _currentIndex = 0;
  final GlobalKey<TechMessagesScreenState> _messagesKey = GlobalKey<TechMessagesScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    LocationService.updateStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.checkPendingNotification();
    });
    _screens = [
      const JobBoardScreen(), 
      TechMessagesScreen(key: _messagesKey), 
      const SizedBox(), 
      const TechMyJobsScreen(),
      const TechProfileScreen(), 
    ];
  }

  void _openAIAssistant() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TechAIAssistantBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, 
      body: IndexedStack(index: _currentIndex, children: _screens),

      floatingActionButton: FloatingActionButton(
        onPressed: _openAIAssistant,
        backgroundColor: TechColors.primary,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(), // Tạo khe hở cho nút AI
        notchMargin: 8.0,
        elevation: 20,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(icon: Icons.radar, label: "Tìm đơn", index: 0),
            _buildNavItem(icon: Icons.chat_bubble_outline, label: "Tin nhắn", index: 1),
            const SizedBox(width: 48), // Chừa chỗ cho nút nổi AI
            _buildNavItem(icon: Icons.assignment_turned_in_outlined, label: "Đơn của tôi", index: 3),
            _buildNavItem(icon: Icons.person_outline, label: "Cá nhân", index: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    final isSelected = _currentIndex == index;
    const activeColor = TechColors.primary;
    final inactiveColor = Colors.grey.shade400;

    return InkWell(
      onTap: () {
        setState(() => _currentIndex = index);
        if (index == 1) {
          _messagesKey.currentState?.refreshInbox();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? activeColor : inactiveColor, size: 26),
          Text(label, style: TextStyle(color: isSelected ? activeColor : inactiveColor, fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

// ─── Giao diện Trợ lý AI cho thợ (Dạng BottomSheet cho hiện đại) ───
class TechAIAssistantBottomSheet extends StatelessWidget {
  const TechAIAssistantBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: TechColors.primary, size: 28),
                const SizedBox(width: 12),
                const Text("Trợ lý Kỹ thuật AI", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildAICard(context, "💡 Tra cứu mã lỗi", "Giải mã các ký hiệu lỗi của máy lạnh, máy giặt...", "Hãy tra cứu mã lỗi và hướng dẫn cách khắc phục giúp tôi."),
                _buildAICard(context, "📖 Sơ đồ mạch điện", "Xem sơ đồ đấu dây của các dòng thiết bị phổ biến", "Tôi muốn xem sơ đồ mạch điện chi tiết. Hãy cung cấp cho tôi."),
                _buildAICard(context, "⚡ Tư vấn an toàn", "Quy trình xử lý các ca rò điện, cháy chập nguy hiểm", "Tôi đang xử lý một ca rò điện/cháy chập. Hãy tư vấn quy trình an toàn ngay lập tức."),
                const SizedBox(height: 20),
                const Center(child: Text("Hệ thống RAG đã được tích hợp kiến thức chuyên môn.", style: TextStyle(color: Colors.green, fontStyle: FontStyle.italic))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAICard(BuildContext context, String title, String desc, String query) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: TechColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.bolt, color: TechColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.pop(context); 
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(initialQuery: query),
            ),
          );
        },
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});
  @override
  Widget build(BuildContext context) => Center(child: Text("Màn hình $title đang phát triển", style: const TextStyle(color: Colors.grey)));
}
