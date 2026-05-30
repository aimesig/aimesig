import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/pages/home_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';

GoRouter createRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final authAsync = ref.read(authStateProvider);
      // .value is the Riverpod 3.x equivalent of .valueOrNull
      final user = authAsync.value;

      final isOnAuthPage = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (user == null && !isOnAuthPage) return '/login';
      if (user != null && isOnAuthPage) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
    ],
  );
}
