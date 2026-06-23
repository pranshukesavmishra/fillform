import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fillformai/features/auth/presentation/pages/splash_screen.dart';
import 'package:fillformai/features/auth/presentation/pages/onboarding_screen.dart';
import 'package:fillformai/features/auth/presentation/pages/login_screen.dart';
import 'package:fillformai/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:fillformai/features/opportunities/presentation/pages/opportunity_list_screen.dart';
import 'package:fillformai/features/opportunities/presentation/pages/opportunity_detail_screen.dart';
import 'package:fillformai/features/applications/presentation/pages/application_screen.dart';
import 'package:fillformai/features/career_twin/presentation/pages/career_twin_screen.dart';
import 'package:fillformai/features/profile/presentation/pages/profile_screen.dart';
import 'package:fillformai/features/agents/presentation/pages/agent_list_screen.dart';
import 'package:fillformai/features/documents/presentation/pages/documents_screen.dart';
import 'package:fillformai/shared/widgets/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    routes: [
      // Splash
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth flow
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/login/verify',
        builder: (context, state) => LoginScreen(
          phone: state.uri.queryParameters['phone'],
        ),
      ),

      // Main shell with bottom nav
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => _fadeTransition(
              state, const DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/opportunities',
            pageBuilder: (context, state) => _fadeTransition(
              state, const OpportunityListScreen(),
            ),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => OpportunityDetailScreen(
                  opportunityId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: ':id/apply',
                builder: (context, state) => ApplicationScreen(
                  opportunityId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/career-twin',
            pageBuilder: (context, state) => _fadeTransition(
              state, const CareerTwinScreen(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => _fadeTransition(
              state, const ProfileScreen(),
            ),
          ),
          GoRoute(
            path: '/agents',
            pageBuilder: (context, state) => _fadeTransition(
              state, const AgentListScreen(),
            ),
          ),
          GoRoute(
            path: '/documents',
            pageBuilder: (context, state) => _fadeTransition(
              state, const DocumentsScreen(),
            ),
          ),
        ],
      ),
    ],

    redirect: (context, state) {
      // TODO: Check auth state from riverpod and redirect accordingly
      // final isAuthenticated = ref.read(authProvider).isAuthenticated;
      // if (!isAuthenticated && !publicRoutes.contains(state.matchedLocation)) {
      //   return '/login';
      // }
      return null;
    },

    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 64),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            TextButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

CustomTransitionPage<void> _fadeTransition(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}
