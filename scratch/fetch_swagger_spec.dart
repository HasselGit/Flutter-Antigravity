import 'dart:convert';
import 'dart:io';

void main() async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse('https://suwcqdlxnmfcvmlnzizl.supabase.co/rest/v1/'));
    request.headers.add('apikey', 'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo');
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    print('Raw response body: $responseBody');
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
