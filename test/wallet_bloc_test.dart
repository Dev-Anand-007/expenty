import 'package:expenty/features/transactions/domain/entities/money_transaction.dart';
import 'package:expenty/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:expenty/features/transactions/domain/usecases/add_transaction_usecase.dart';
import 'package:expenty/features/wallet/domain/entities/wallet.dart';
import 'package:expenty/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:expenty/features/wallet/domain/usecases/add_balance_usecase.dart';
import 'package:expenty/features/wallet/domain/usecases/watch_wallet_usecase.dart';
import 'package:expenty/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:expenty/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:expenty/features/wallet/presentation/bloc/wallet_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWalletRepository implements WalletRepository {
  double balance = 0;

  @override
  Stream<Wallet> watch() async* {
    yield Wallet(balance: balance, updatedAt: DateTime.now());
  }

  @override
  Future<void> addBalance(double amount) async {
    if (amount <= 0) {
      throw Exception('Enter an amount greater than zero');
    }
    balance += amount;
  }

  @override
  Future<void> resetBalance() async {
    balance = 0;
  }
}

class _FakeTransactionRepository implements TransactionRepository {
  final List<MoneyTransaction> added = [];

  @override
  Stream<List<MoneyTransaction>> watchAll() async* {
    yield added;
  }

  @override
  Future<void> add(MoneyTransaction transaction) async {
    added.add(transaction);
  }

  @override
  Future<void> update(MoneyTransaction transaction) async {}

  @override
  Future<void> delete(String id) async {}
}

void main() {
  late _FakeWalletRepository walletRepository;
  late _FakeTransactionRepository transactionRepository;
  late WalletBloc bloc;

  setUp(() {
    walletRepository = _FakeWalletRepository();
    transactionRepository = _FakeTransactionRepository();

    bloc = WalletBloc(
      watchWallet: WatchWalletUseCase(walletRepository),
      addBalance: AddBalanceUseCase(walletRepository),
      addTransaction: AddTransactionUseCase(transactionRepository),
    );
  });

  tearDown(() => bloc.close());

  test('BalanceAdded records a mirrored income row for Activity', () async {
    bloc.add(const BalanceAdded(1500));

    await pumpEventQueue();

    // Wallet field still holds the money...
    expect(walletRepository.balance, 1500);

    // ...and Activity gets a single income row tagged as a wallet top-up.
    expect(transactionRepository.added, hasLength(1));

    final transaction = transactionRepository.added.single;
    expect(transaction.type, TransactionType.income);
    expect(transaction.amount, 1500);
    expect(transaction.category, 'Wallet top-up');
    expect(transaction.id, isEmpty);
    expect(bloc.state.status, WalletStatus.success);
  });

  test('failed wallet write does not record a transaction', () async {
    bloc.add(const BalanceAdded(-5)); // rejects in the sheet's validator

    await pumpEventQueue();

    expect(transactionRepository.added, isEmpty);
  });
}
