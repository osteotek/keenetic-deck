enum ConnectionTargetKind {
  direct,
  localNetwork,
  keendns,
}

class ConnectionTarget {
  const ConnectionTarget({
    required this.kind,
    required this.uri,
  });

  final ConnectionTargetKind kind;
  final Uri uri;
}

