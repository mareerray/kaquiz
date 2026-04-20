class Friend {
  final String id;
  final String name;
  final String avatarUrl;
  final double? latitude;
  final double? longitude;

  Friend({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.latitude,
    this.longitude,
  });
}
