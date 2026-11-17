import 'package:expenty/app/router/route_names.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/groups/domain/entities/group_expense.dart';
import '../../features/groups/presentation/pages/add_group_expense_page.dart';
import '../../features/groups/presentation/pages/create_group_page.dart';
import '../../features/groups/presentation/pages/group_detail_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/transactions/domain/entities/money_transaction.dart';
import '../../features/transactions/presentation/pages/add_transaction_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: RouteNames.splash,
  routes: [
    GoRoute(
      path: RouteNames.splash,
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: RouteNames.login,
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: RouteNames.register,
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: RouteNames.forgotPassword,
      builder: (context, state) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: RouteNames.addTransaction,
      builder: (context, state) => const AddTransactionPage(),
    ),
    GoRoute(
      path: RouteNames.editTransaction,
      builder: (context, state) => AddTransactionPage(
        existing: state.extra is MoneyTransaction
            ? state.extra as MoneyTransaction
            : null,
      ),
    ),
    // Static path first so it doesn't get swallowed by `/groups/:id`.
    GoRoute(
      path: RouteNames.createGroup,
      builder: (context, state) => const CreateGroupPage(),
    ),
    GoRoute(
      path: RouteNames.groupDetail,
      builder: (context, state) =>
          GroupDetailPage(groupId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: RouteNames.addGroupExpense,
      builder: (context, state) =>
          AddGroupExpensePage(groupId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: RouteNames.editGroupExpense,
      builder: (context, state) => AddGroupExpensePage(
        groupId: state.pathParameters['id']!,
        existing: state.extra is GroupExpense
            ? state.extra as GroupExpense
            : null,
      ),
    ),
    GoRoute(
      path: RouteNames.dashboard,
      builder: (context, state) => const DashboardPage(),
    ),
    GoRoute(
      path: RouteNames.profile,
      builder: (context, state) => const ProfilePage(),
    ),
    GoRoute(
      path: RouteNames.settings,
      builder: (context, state) => const SettingsPage(),
    ),
  ],
);
