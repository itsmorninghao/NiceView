class NiceViewException implements Exception {
  const NiceViewException(this.message);

  final String message;

  @override
  String toString() => message;
}

class QuotaExceededException extends NiceViewException {
  const QuotaExceededException(super.message);
}

class ServerLockoutException extends NiceViewException {
  const ServerLockoutException(super.message);
}

class ImageNotFoundException extends NiceViewException {
  const ImageNotFoundException(super.message);
}

class EmptyTagException extends NiceViewException {
  const EmptyTagException(super.message);
}
