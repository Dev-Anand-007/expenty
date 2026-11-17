import '../exceptions/app_exception.dart';

abstract class Failure {
  final String message;

  const Failure(this.message);

  AppException toException() => AppException(message);

  @override
  String toString() => message;
}