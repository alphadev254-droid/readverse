import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/reader/reader_screen.dart';
import '../screens/document_details/document_details_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/library/library_management_screen.dart';
import '../screens/favorites/favorites_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isAuth = authProvider.isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/forgot-password';
      final isSplash = state.matchedLocation == '/';

      if (isSplash) return null;
      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _fadePage(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (_, state) => _fadePage(state, const SignupScreen()),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (_, state) => _fadePage(state, const ForgotPasswordScreen()),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (_, state) => _fadePage(state, const HomeScreen()),
      ),
      GoRoute(
        path: '/reader/:docId',
        pageBuilder: (_, state) => _slidePage(
          state,
          ReaderScreen(docId: state.pathParameters['docId']!),
        ),
      ),
      GoRoute(
        path: '/document-details/:docId',
        pageBuilder: (_, state) => _fadePage(
          state,
          DocumentDetailsScreen(docId: state.pathParameters['docId']!),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (_, state) => _fadePage(state, const SettingsScreen()),
      ),
      GoRoute(
        path: '/library-management',
        pageBuilder: (_, state) => _fadePage(state, const LibraryManagementScreen()),
      ),
      GoRoute(
        path: '/favorites',
        pageBuilder: (_, state) => _fadePage(state, const FavoritesScreen()),
      ),
    ],
  );
}

CustomTransitionPage _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

CustomTransitionPage _slidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (_, animation, __, child) => SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
      child: child,
    ),
  );
}
