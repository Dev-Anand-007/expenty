class RouteNames {
  RouteNames._();

  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const dashboard = '/dashboard';
  static const addTransaction = '/add-transaction';
  static const editTransaction = '/edit-transaction';

  /// Groups (split expenses with friends)
  static const createGroup = '/groups/new';
  static const groupDetail = '/groups/:id';
  static const addGroupExpense = '/groups/:id/add-expense';
  static const editGroupExpense = '/groups/:id/edit-expense';

  static const profile = '/profile';
  static const settings = '/settings';

  static String group(String id) => '/groups/$id';
}
