import 'dart:io';

/// Reads a local file from disk for upload. Returns null when the path does
/// not point at a readable file.
Future<AdminFilePayload?> readAdminFile(String path) async {
  final file = File(path.trim());
  if (!await file.exists()) return null;
  final bytes = await file.readAsBytes();
  final name = path
      .trim()
      .split(RegExp(r'[\\/]'))
      .where((part) => part.isNotEmpty)
      .last;
  return AdminFilePayload(
    bytes: bytes,
    filename: name,
    contentType: _contentTypeFor(name),
  );
}

/// Best-effort MIME lookup from the file extension.
String? _contentTypeFor(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot < 0) return null;
  switch (filename.substring(dot + 1).toLowerCase()) {
    case 'pdf':
      return 'application/pdf';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'txt':
      return 'text/plain';
    case 'mp3':
      return 'audio/mpeg';
    case 'm4a':
      return 'audio/mp4';
    case 'wav':
      return 'audio/wav';
    case 'mp4':
      return 'video/mp4';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    default:
      return null;
  }
}

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
