class RouterApiException implements Exception {
  const RouterApiException(this.message);

  final String message;

  @override
  String toString() => 'RouterApiException: $message';
}

class RouterAuthenticationException extends RouterApiException {
  const RouterAuthenticationException([super.message = 'Authentication failed']);
}

class RouterRequestException extends RouterApiException {
  const RouterRequestException({
    required this.statusCode,
    required String message,
  }) : super(message);

  final int statusCode;
}

class RouterParseException extends RouterApiException {
  const RouterParseException(super.message);
}
