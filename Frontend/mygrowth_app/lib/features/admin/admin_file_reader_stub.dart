/// In-memory payload ready to hand to [ApiClient.upload].
class AdminFilePayload {
  const AdminFilePayload({
    required this.bytes,
    required this.filename,
    this.contentType,
  });

  final List<int> bytes;
  final String filename;
  final String? contentType;
}

/// Web stub: browsers cannot read arbitrary local paths, so callers should
/// catch this and offer an external link instead.
Future<AdminFilePayload?> readAdminFile(String path) async {
  throw UnsupportedError('file-system-unavailable');
}
