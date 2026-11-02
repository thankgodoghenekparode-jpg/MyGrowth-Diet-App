class ConnectLink {
  const ConnectLink({
    required this.id,
    required this.title,
    required this.url,
    this.description,
    this.icon,
    this.qrCodeUrl,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String title;
  final String url;
  final String? description;
  final String? icon;
  final String? qrCodeUrl;
  final int sortOrder;
  final bool isActive;

  factory ConnectLink.fromJson(Map<String, dynamic> json) {
    return ConnectLink(
      id: json['id'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      qrCodeUrl: json['qrCodeUrl'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
