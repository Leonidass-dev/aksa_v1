import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart'; // flutterfire configure ile otomatik oluşur
import 'theme/app_theme.dart';
import 'theme/theme_notifier.dart';
import 'screens/onboarding/onboarding_wrapper.dart';
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
import 'services/notification_service.dart';
import 'services/background_service.dart';

bool _onboardingCompleted = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final prefs = await SharedPreferences.getInstance();
  _onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
  
  try {
    // Bildirim Servisini Başlat
    await NotificationService.init();
    await NotificationService.scheduleNudges();
  } catch (e) {
    debugPrint('Bildirim servisi başlatılamadı (Hata: $e). Uygulama devam ediyor.');
  }

  try {
    // Arkaplan Anomali Tespiti (WorkManager)
    await BackgroundService.initialize();
  } catch (e) {
    debugPrint('Arkaplan servisi başlatılamadı (Hata: $e). Uygulama devam ediyor.');
  }

  runApp(const AksaApp());
}

class AksaApp extends StatelessWidget {
  const AksaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, _) => MaterialApp.router(
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
    '/',
    '/onboarding-2',
    '/onboarding-3',
    '/onboarding-4',
    '/login',
    '/register',
    '/forgot-password',
  ];

  if (!isAuth && !publicRoutes.contains(loc)) {
    return '/login';
  }
  
  if (!isAuth && loc == '/' && _onboardingCompleted) {
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
    GoRoute(path: '/', builder: (_, _) => const OnboardingWrapper()),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
    GoRoute(
      path: '/forgot-password',
      builder: (_, _) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/profile-setup',
      builder: (_, _) => const ProfileSetupScreen(),
    ),
    ShellRoute(
      builder: (_, _, child) => MainLayout(child: child),
      routes: [
        GoRoute(
          path: '/app/dashboard',
          builder: (_, _) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/app/nutrition',
          builder: (_, _) => const NutritionScreen(),
        ),
        GoRoute(
          path: '/app/exercise',
          builder: (_, _) => const ExerciseScreen(),
        ),
        GoRoute(path: '/app/alerts', builder: (_, _) => const AlertsScreen()),
        GoRoute(
          path: '/app/reports',
          builder: (_, _) => const ReportsScreen(),
        ),
        GoRoute(
          path: '/app/profile',
          builder: (_, _) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/app/risk-score',
          builder: (_, _) => const RiskScoreScreen(),
        ),
        GoRoute(
          path: '/app/data-entry',
          builder: (_, _) => const DataEntryScreen(),
        ),
        GoRoute(
          path: '/app/assistant',
          builder: (_, _) => const AssistantScreen(),
        ),
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
