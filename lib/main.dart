import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

// Providers
import 'providers/device_provider.dart';
import 'providers/job_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/user_provider.dart';

// Screens
import 'Screens/splash.dart';
import 'Screens/login_screen.dart';
import 'Screens/register_screen.dart';
import 'Screens/main_screen.dart';
import 'Screens_Technic/job_board_screen.dart';
import 'Screens_Technic/technician_main_screen.dart';
import 'Screens_Technic/chat_screen.dart';
import 'Screens_Technic/job_detail_screen.dart';

import 'services/notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Services

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("❌ Firebase error: $e");
  }

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("❌ .env error: $e");
  }

  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint("❌ Notification error: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => JobProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartElec',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Inter', // Hoặc font bác đang dùng
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        // Route cho màn hình Chat chi tiết (Dùng chung hoặc riêng tùy bác)
        if (settings.name == '/chat_detail') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => TechChatScreen(
              sessionId: args['sessionId'],
              receiver: args['receiver'],
            ),
          );
        }

        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/register':
            return MaterialPageRoute(builder: (_) => const RegisterScreen());
          case '/main':
            return MaterialPageRoute(builder: (_) => const MainScreen());
          case '/tech_main':
            return MaterialPageRoute(
              builder: (_) => const TechnicianMainScreen(),
            );
          case '/job_board':
            return MaterialPageRoute(builder: (_) => const JobBoardScreen());
          case '/job_detail':
            final id = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => JobDetailScreen(jobId: id),
            );
          default:
            return MaterialPageRoute(builder: (_) => const SplashScreen());
        }
      },
    );
  }
}
