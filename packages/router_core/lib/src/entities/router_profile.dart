class RouterProfile {
  const RouterProfile({
    required this.id,
    required this.name,
    required this.address,
    required this.login,
    this.networkIp,
    this.keendnsUrls = const <String>[],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String address;
  final String login;
  final String? networkIp;
  final List<String> keendnsUrls;
  final DateTime createdAt;
  final DateTime updatedAt;

  RouterProfile copyWith({
    String? id,
    String? name,
    String? address,
    String? login,
    String? networkIp,
    List<String>? keendnsUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RouterProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      login: login ?? this.login,
      networkIp: networkIp ?? this.networkIp,
      keendnsUrls: keendnsUrls ?? this.keendnsUrls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

