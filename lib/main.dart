import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart'; // flutterfire configure ile otomatik oluşur
import 'theme/app_theme.dart';
import 'theme/theme_notifier.dart';
import 'screens/onboarding/onboarding1_screen.dart';
import 'screens/onboarding/onboarding2_screen.dart';
import 'screens/onboarding/onboarding3_screen.dart';
import 'screens/onboarding/onboarding4_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/nutrition_screen.dart';
import 'screens/exercise_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/risk_score_screen.dart';
import 'screens/data_entry_screen.dart';
import 'screens/assistant_screen.dart';
import 'widgets/bottom_nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AksaApp());
}

class AksaApp extends StatelessWidget {
  const AksaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => MaterialApp.router(
        title: 'AKSA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        darkTheme: AppTheme.darkTheme,
        themeMode: mode,
        routerConfig: _router,
      ),
    );
  }
}

// Auth durumuna göre yönlendirme
String? _authGuard(BuildContext context, GoRouterState state) {
  final user = FirebaseAuth.instance.currentUser;
  final isAuth = user != null;
  final loc = state.uri.toString();

  final publicRoutes = [
    '/', '/onboarding-2', '/onboarding-3', '/onboarding-4',
    '/login', '/register', '/forgot-password', '/profile-setup',
  ];

  if (!isAuth && !publicRoutes.contains(loc)) {
    return '/login';
  }
  if (isAuth && publicRoutes.contains(loc)) {
    return '/app/dashboard';
  }
  return null;
}

final _router = GoRouter(
  initialLocation: '/',
  redirect: _authGuard,
  refreshListenable: _AuthNotifier(),
  routes: [
    GoRoute(path: '/',          builder: (_, __) => const Onboarding1Screen()),
    GoRoute(path: '/onboarding-2', builder: (_, __) => const Onboarding2Screen()),
    GoRoute(path: '/onboarding-3', builder: (_, __) => const Onboarding3Screen()),
    GoRoute(path: '/onboarding-4', builder: (_, __) => const Onboarding4Screen()),
    GoRoute(path: '/login',        builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register',     builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
    GoRoute(path: '/profile-setup', builder: (_, __) => const ProfileSetupScreen()),
    ShellRoute(
      builder: (_, __, child) => MainLayout(child: child),
      routes: [
        GoRoute(path: '/app/dashboard',  builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/app/nutrition',  builder: (_, __) => const NutritionScreen()),
        GoRoute(path: '/app/exercise',   builder: (_, __) => const ExerciseScreen()),
        GoRoute(path: '/app/alerts',     builder: (_, __) => const AlertsScreen()),
        GoRoute(path: '/app/reports',    builder: (_, __) => const ReportsScreen()),
        GoRoute(path: '/app/profile',    builder: (_, __) => const ProfileScreen()),
        GoRoute(path: '/app/risk-score', builder: (_, __) => const RiskScoreScreen()),
        GoRoute(path: '/app/data-entry', builder: (_, __) => const DataEntryScreen()),
        GoRoute(path: '/app/assistant',  builder: (_, __) => const AssistantScreen()),
      ],
    ),
  ],
);

// Auth değişikliklerini GoRouter'a bildir
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }
}