// lib/core/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/members/presentation/screens/members_list_screen.dart';
import '../../features/members/presentation/screens/member_detail_screen.dart';
import '../../features/members/presentation/screens/add_member_screen.dart';
import '../../features/courses/presentation/screens/courses_screen.dart';
import '../../features/courses/presentation/screens/course_detail_screen.dart';
import '../../features/attendance/presentation/screens/attendance_screen.dart';
import '../../features/finance/presentation/screens/finance_screen.dart';
import '../../features/admissions/presentation/screens/admissions_screen.dart';
import '../../features/staff/presentation/screens/staff_screen.dart';
import '../../features/schedule/presentation/screens/schedule_screen.dart';
import '../api/dio_client.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter createRouter() => GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/dashboard',
      redirect: (context, state) async {
        final isLoggedIn = await DioClient.getToken() != null;
        final isAuthRoute = state.matchedLocation.startsWith('/auth');
        if (!isLoggedIn && !isAuthRoute) return '/auth/login';
        if (isLoggedIn && isAuthRoute) return '/dashboard';
        return null;
      },
      routes: [
        // ── Auth ──────────────────────────────────────────────────
        GoRoute(
          path: '/auth/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/auth/register',
          builder: (_, __) => const RegisterScreen(),
        ),

        // ── Main shell with bottom nav ────────────────────────────
        ShellRoute(
          builder: (context, state, child) =>
              MainShell(child: child, location: state.matchedLocation),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, __) => const DashboardScreen(),
            ),
            GoRoute(
              path: '/members',
              builder: (_, __) => const MembersListScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (_, __) => const AddMemberScreen(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (_, state) =>
                      MemberDetailScreen(id: state.pathParameters['id']!),
                ),
              ],
            ),
            GoRoute(
              path: '/courses',
              builder: (_, __) => const CoursesScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) =>
                      CourseDetailScreen(id: state.pathParameters['id']!),
                ),
              ],
            ),
            GoRoute(
              path: '/attendance',
              builder: (_, __) => const AttendanceScreen(),
            ),
            GoRoute(
              path: '/finance',
              builder: (_, __) => const FinanceScreen(),
            ),
            GoRoute(
              path: '/admissions',
              builder: (_, __) => const AdmissionsScreen(),
            ),
            GoRoute(
              path: '/staff',
              builder: (_, __) => const StaffScreen(),
            ),
            GoRoute(
              path: '/schedule',
              builder: (_, __) => const ScheduleScreen(),
            ),
          ],
        ),
      ],
    );

// ── Bottom-nav shell ─────────────────────────────────────────────
class MainShell extends StatelessWidget {
  const MainShell({
    super.key,
    required this.child,
    required this.location,
  });

  final Widget child;
  final String location;

  static const _tabs = [
    _TabItem(icon: Icons.dashboard_outlined,    label: 'Dashboard',  route: '/dashboard'),
    _TabItem(icon: Icons.people_outline,        label: 'Members',    route: '/members'),
    _TabItem(icon: Icons.school_outlined,       label: 'Courses',    route: '/courses'),
    _TabItem(icon: Icons.check_circle_outline,  label: 'Attendance', route: '/attendance'),
    _TabItem(icon: Icons.account_balance_wallet_outlined, label: 'Finance', route: '/finance'),
    _TabItem(icon: Icons.how_to_reg_outlined,   label: 'Admissions', route: '/admissions'),
    _TabItem(icon: Icons.badge_outlined,        label: 'Staff',      route: '/staff'),
    _TabItem(icon: Icons.calendar_month_outlined, label: 'Schedule', route: '/schedule'),
  ];

  int get _currentIndex {
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) =>
            context.go(_tabs[i].route),
        destinations: _tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icon),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}

class _TabItem {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.route,
  });
  final IconData icon;
  final String label;
  final String route;
}
