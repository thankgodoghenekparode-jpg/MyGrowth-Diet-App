import 'package:http/http.dart' as http;

Future<String> loadBibleTranslation({
  required String id,
  required String file,
  required String baseUrl,
}) async {
  final response = await http
      .get(Uri.parse('$baseUrl/$file'))
      .timeout(const Duration(seconds: 30));
  if (response.statusCode != 200) {
    throw StateError('Could not download $id Bible translation.');
  }
  return response.body;
}
