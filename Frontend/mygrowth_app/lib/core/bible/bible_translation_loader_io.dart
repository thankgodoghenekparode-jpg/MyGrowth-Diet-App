import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

Future<String> loadBibleTranslation({
  required String id,
  required String file,
  required String baseUrl,
}) async {
  final supportDirectory = await getApplicationSupportDirectory();
  final bibleDirectory = Directory(
    '${supportDirectory.path}${Platform.pathSeparator}bibles',
  );
  final cachedFile = File(
    '${bibleDirectory.path}${Platform.pathSeparator}$file',
  );

  if (await cachedFile.exists()) {
    return cachedFile.readAsString();
  }

  final response = await http
      .get(Uri.parse('$baseUrl/$file'))
      .timeout(const Duration(seconds: 30));
  if (response.statusCode != 200) {
    throw StateError('Could not download $id Bible translation.');
  }

  await bibleDirectory.create(recursive: true);
  await cachedFile.writeAsBytes(response.bodyBytes, flush: true);
  return response.body;
}
