/// Platform-conditional file reading used by the admin Materials uploader.
///
/// On native platforms (`dart:io` available) a local file path is read into
/// bytes. On the web there is no filesystem, so [readAdminFile] throws an
/// [UnsupportedError] and the UI falls back to an external link + a toast.
library;

export 'admin_file_reader_stub.dart'
    if (dart.library.io) 'admin_file_reader_io.dart';
