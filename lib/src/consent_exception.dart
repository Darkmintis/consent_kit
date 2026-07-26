/// Exception thrown by ConsentKit when consent operations fail.
class ConsentKitException implements Exception {
  /// A human-readable description of what went wrong.
  final String message;

  /// Optional original error that caused this exception.
  final Object? cause;

  const ConsentKitException(this.message, {this.cause});

  @override
  String toString() {
    if (cause != null) {
      return 'ConsentKitException: $message (caused by: $cause)';
    }
    return 'ConsentKitException: $message';
  }
}

/// Exception thrown when an operation is attempted before initialization.
class ConsentKitNotInitializedException extends ConsentKitException {
  ConsentKitNotInitializedException()
      : super(
          'ConsentKit is not initialized. Call ConsentKit.initialize() first.',
        );
}

/// Exception thrown on unsupported platforms (web, desktop, etc.).
class ConsentKitUnsupportedPlatformException extends ConsentKitException {
  ConsentKitUnsupportedPlatformException()
      : super(
          'ConsentKit only supports Android and iOS. '
          'This platform is not supported.',
        );
}
