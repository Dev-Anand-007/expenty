import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';

import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/change_password_usecase.dart';
import '../../features/auth/domain/usecases/delete_account_usecase.dart';
import '../../features/auth/domain/usecases/google_sign_in_usecase.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/signup_usecase.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/domain/usecases/forgot_password_usecase.dart';
import '../../features/auth/domain/usecases/send_email_verification_usecase.dart';
import '../../features/auth/domain/usecases/is_logged_in_usecase.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';

import '../../features/transactions/data/datasources/transaction_remote_datasource.dart';
import '../../features/transactions/data/repositories/transaction_repository_impl.dart';
import '../../features/transactions/domain/repositories/transaction_repository.dart';
import '../../features/transactions/domain/usecases/add_transaction_usecase.dart';
import '../../features/transactions/domain/usecases/delete_transaction_usecase.dart';
import '../../features/transactions/domain/usecases/update_transaction_usecase.dart';
import '../../features/transactions/domain/usecases/watch_transactions_usecase.dart';
import '../../features/transactions/presentation/bloc/transactions_bloc.dart';

import '../../features/wallet/data/datasources/wallet_remote_datasource.dart';
import '../../features/wallet/data/repositories/wallet_repository_impl.dart';
import '../../features/wallet/domain/repositories/wallet_repository.dart';
import '../../features/wallet/domain/usecases/add_balance_usecase.dart';
import '../../features/wallet/domain/usecases/reset_balance_usecase.dart';
import '../../features/wallet/domain/usecases/watch_wallet_usecase.dart';
import '../../features/wallet/presentation/bloc/wallet_bloc.dart';

import '../../features/groups/data/datasources/group_remote_datasource.dart';
import '../../features/groups/data/repositories/group_repository_impl.dart';
import '../../features/groups/domain/repositories/group_repository.dart';
import '../../features/groups/domain/usecases/add_group_expense_usecase.dart';
import '../../features/groups/domain/usecases/add_group_member_usecase.dart';
import '../../features/groups/domain/usecases/create_group_usecase.dart';
import '../../features/groups/domain/usecases/delete_group_expense_usecase.dart';
import '../../features/groups/domain/usecases/find_member_by_email_usecase.dart';
import '../../features/groups/domain/usecases/find_member_by_username_usecase.dart';
import '../../features/groups/domain/usecases/leave_group_usecase.dart';
import '../../features/groups/domain/usecases/rename_group_usecase.dart';
import '../../features/groups/domain/usecases/sync_own_profile_usecase.dart';
import '../../features/groups/domain/usecases/update_group_expense_usecase.dart';
import '../../features/groups/domain/usecases/watch_group_expenses_usecase.dart';
import '../../features/groups/domain/usecases/watch_group_usecase.dart';
import '../../features/groups/domain/usecases/watch_my_groups_usecase.dart';
import '../../features/groups/presentation/bloc/group_detail_bloc.dart';
import '../../features/groups/presentation/bloc/groups_bloc.dart';

import '../../features/profile/data/datasources/profile_remote_datasource.dart';
import '../../features/profile/data/datasources/profile_storage_datasource.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/domain/usecases/get_profile_usecase.dart';
import '../../features/profile/domain/usecases/set_username_usecase.dart';
import '../../features/profile/domain/usecases/update_display_name_usecase.dart';
import '../../features/profile/domain/usecases/update_profile_photo_usecase.dart';
import '../../features/profile/presentation/bloc/profile_bloc.dart';

import 'package:firebase_storage/firebase_storage.dart';

final sl = GetIt.instance;

Future<void> setupLocator() async {
  /// Firebase
  sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);

  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);

  /// Data Source
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(
      firebaseAuth: sl<FirebaseAuth>(),
      firestore: sl<FirebaseFirestore>(),
    ),
  );

  /// Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl<AuthRemoteDataSource>()),
  );

  /// Use Cases
  sl.registerLazySingleton<LoginUseCase>(
    () => LoginUseCase(sl<AuthRepository>()),
  );

  sl.registerLazySingleton<SignupUseCase>(
    () => SignupUseCase(sl<AuthRepository>()),
  );

  sl.registerLazySingleton<LogoutUseCase>(
    () => LogoutUseCase(sl<AuthRepository>()),
  );

  sl.registerLazySingleton<ForgotPasswordUseCase>(
    () => ForgotPasswordUseCase(sl<AuthRepository>()),
  );

  sl.registerLazySingleton<SendEmailVerificationUseCase>(
    () => SendEmailVerificationUseCase(sl<AuthRepository>()),
  );

  sl.registerLazySingleton<IsLoggedInUseCase>(
    () => IsLoggedInUseCase(sl<AuthRepository>()),
  );

  sl.registerLazySingleton<ChangePasswordUseCase>(
    () => ChangePasswordUseCase(sl<AuthRepository>()),
  );

  sl.registerLazySingleton<GoogleSignInUseCase>(
    () => GoogleSignInUseCase(sl<AuthRepository>()),
  );

  sl.registerLazySingleton<DeleteAccountUseCase>(
    () => DeleteAccountUseCase(sl<AuthRepository>()),
  );

  /// Bloc
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(
      loginUseCase: sl<LoginUseCase>(),
      signupUseCase: sl<SignupUseCase>(),
      logoutUseCase: sl<LogoutUseCase>(),
      forgotPasswordUseCase: sl<ForgotPasswordUseCase>(),
      sendEmailVerificationUseCase: sl<SendEmailVerificationUseCase>(),
      isLoggedInUseCase: sl<IsLoggedInUseCase>(),
      changePasswordUseCase: sl<ChangePasswordUseCase>(),
      googleSignInUseCase: sl<GoogleSignInUseCase>(),
      deleteAccountUseCase: sl<DeleteAccountUseCase>(),
    ),
  );

  /// Transactions
  sl.registerLazySingleton<TransactionRemoteDataSource>(
    () => TransactionRemoteDataSourceImpl(
      firestore: sl<FirebaseFirestore>(),
      auth: sl<FirebaseAuth>(),
    ),
  );

  sl.registerLazySingleton<TransactionRepository>(
    () => TransactionRepositoryImpl(
      remoteDataSource: sl<TransactionRemoteDataSource>(),
    ),
  );

  sl.registerLazySingleton<WatchTransactionsUseCase>(
    () => WatchTransactionsUseCase(sl<TransactionRepository>()),
  );

  sl.registerLazySingleton<AddTransactionUseCase>(
    () => AddTransactionUseCase(sl<TransactionRepository>()),
  );

  sl.registerLazySingleton<DeleteTransactionUseCase>(
    () => DeleteTransactionUseCase(sl<TransactionRepository>()),
  );

  sl.registerLazySingleton<UpdateTransactionUseCase>(
    () => UpdateTransactionUseCase(sl<TransactionRepository>()),
  );

  sl.registerFactory<TransactionsBloc>(
    () => TransactionsBloc(
      watchTransactions: sl<WatchTransactionsUseCase>(),
      addTransaction: sl<AddTransactionUseCase>(),
      updateTransaction: sl<UpdateTransactionUseCase>(),
      deleteTransaction: sl<DeleteTransactionUseCase>(),
    ),
  );

  /// Wallet
  sl.registerLazySingleton<WalletRemoteDataSource>(
    () => WalletRemoteDataSourceImpl(
      firestore: sl<FirebaseFirestore>(),
      auth: sl<FirebaseAuth>(),
    ),
  );

  sl.registerLazySingleton<WalletRepository>(
    () => WalletRepositoryImpl(remoteDataSource: sl<WalletRemoteDataSource>()),
  );

  sl.registerLazySingleton<WatchWalletUseCase>(
    () => WatchWalletUseCase(sl<WalletRepository>()),
  );

  sl.registerLazySingleton<AddBalanceUseCase>(
    () => AddBalanceUseCase(sl<WalletRepository>()),
  );

  sl.registerLazySingleton<ResetBalanceUseCase>(
    () => ResetBalanceUseCase(sl<WalletRepository>()),
  );

  sl.registerFactory<WalletBloc>(
    () => WalletBloc(
      watchWallet: sl<WatchWalletUseCase>(),
      addBalance: sl<AddBalanceUseCase>(),
      addTransaction: sl<AddTransactionUseCase>(),
    ),
  );

  /// Groups (Splitwise-style shared expenses)
  sl.registerLazySingleton<GroupRemoteDataSource>(
    () => GroupRemoteDataSourceImpl(
      firestore: sl<FirebaseFirestore>(),
      auth: sl<FirebaseAuth>(),
    ),
  );

  sl.registerLazySingleton<GroupRepository>(
    () => GroupRepositoryImpl(remoteDataSource: sl<GroupRemoteDataSource>()),
  );

  sl.registerLazySingleton<WatchMyGroupsUseCase>(
    () => WatchMyGroupsUseCase(sl<GroupRepository>()),
  );

  sl.registerLazySingleton<CreateGroupUseCase>(
    () => CreateGroupUseCase(sl<GroupRepository>()),
  );

  sl.registerLazySingleton<FindMemberByEmailUseCase>(
    () => FindMemberByEmailUseCase(sl<GroupRepository>()),
  );

  sl.registerLazySingleton<FindMemberByUsernameUseCase>(
    () => FindMemberByUsernameUseCase(sl<GroupRepository>()),
  );

  sl.registerLazySingleton<SyncOwnProfileUseCase>(
    () => SyncOwnProfileUseCase(sl<GroupRepository>()),
  );

  sl.registerLazySingleton<WatchGroupUseCase>(
    () => WatchGroupUseCase(sl<GroupRepository>()),
  );

  sl.registerLazySingleton<WatchGroupExpensesUseCase>(
    () => WatchGroupExpensesUseCase(sl<GroupRepository>()),
  );

  sl.registerLazySingleton<AddGroupExpenseUseCase>(
    () => AddGroupExpenseUseCase(sl<GroupRepository>()),
  );

  sl.registerLazySingleton<DeleteGroupExpenseUseCase>(
    () => DeleteGroupExpenseUseCase(sl<GroupRepository>()),
  );

  sl.registerLazySingleton<UpdateGroupExpenseUseCase>(
    () => UpdateGroupExpenseUseCase(sl<GroupRepository>()),
  );

  sl.registerLazySingleton<RenameGroupUseCase>(
    () => RenameGroupUseCase(sl<GroupRepository>()),
  );

  sl.registerLazySingleton<AddGroupMemberUseCase>(
    () => AddGroupMemberUseCase(sl<GroupRepository>()),
  );

  sl.registerLazySingleton<LeaveGroupUseCase>(
    () => LeaveGroupUseCase(sl<GroupRepository>()),
  );

  sl.registerFactory<GroupsBloc>(
    () => GroupsBloc(
      watchMyGroups: sl<WatchMyGroupsUseCase>(),
      createGroup: sl<CreateGroupUseCase>(),
      syncOwnProfile: sl<SyncOwnProfileUseCase>(),
    ),
  );

  sl.registerFactory<GroupDetailBloc>(
    () => GroupDetailBloc(
      watchGroup: sl<WatchGroupUseCase>(),
      watchExpenses: sl<WatchGroupExpensesUseCase>(),
      addGroupExpense: sl<AddGroupExpenseUseCase>(),
      deleteGroupExpense: sl<DeleteGroupExpenseUseCase>(),
      updateGroupExpense: sl<UpdateGroupExpenseUseCase>(),
      renameGroup: sl<RenameGroupUseCase>(),
      addGroupMember: sl<AddGroupMemberUseCase>(),
      leaveGroup: sl<LeaveGroupUseCase>(),
    ),
  );

  /// Profile (personal details, avatar, username)
  sl.registerLazySingleton<FirebaseStorage>(() => FirebaseStorage.instance);

  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(
      firebaseAuth: sl<FirebaseAuth>(),
      firestore: sl<FirebaseFirestore>(),
    ),
  );

  sl.registerLazySingleton<ProfileStorageDataSource>(
    () => ProfileStorageDataSourceImpl(storage: sl<FirebaseStorage>()),
  );

  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(
      firebaseAuth: sl<FirebaseAuth>(),
      remoteDataSource: sl<ProfileRemoteDataSource>(),
      storageDataSource: sl<ProfileStorageDataSource>(),
    ),
  );

  sl.registerLazySingleton<GetProfileUseCase>(
    () => GetProfileUseCase(sl<ProfileRepository>()),
  );

  sl.registerLazySingleton<UpdateDisplayNameUseCase>(
    () => UpdateDisplayNameUseCase(sl<ProfileRepository>()),
  );

  sl.registerLazySingleton<SetUsernameUseCase>(
    () => SetUsernameUseCase(sl<ProfileRepository>()),
  );

  sl.registerLazySingleton<UpdateProfilePhotoUseCase>(
    () => UpdateProfilePhotoUseCase(sl<ProfileRepository>()),
  );

  sl.registerFactory<ProfileBloc>(
    () => ProfileBloc(
      getProfile: sl<GetProfileUseCase>(),
      updateDisplayName: sl<UpdateDisplayNameUseCase>(),
      setUsername: sl<SetUsernameUseCase>(),
      updateProfilePhoto: sl<UpdateProfilePhotoUseCase>(),
    ),
  );
}
