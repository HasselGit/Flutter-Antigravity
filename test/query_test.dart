import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('fetch viajes', () async {
    await Supabase.initialize(
      url: 'https://suwcqdlxnmfcvmlnzizl.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTEwNTkwMzYsImV4cCI6MjAyNjYzNTAzNn0.tuV6fT5Tq964nZ4j9L-Y46D2M-t-A57y448uE98bL2E',
      localStorage: const EmptyLocalStorage(),
    );
    
    try {
      var query = Supabase.instance.client
          .from('viajes')
          .select('*, paradas(*, parada_items(*))');
      
      final data = await query;
      print('SUCCESS. Data length: ${data.length}');
      if (data.length > 0) {
        print(data[0]);
      }
    } catch (e) {
      print('ERROR IN QUERY: $e');
    }
  });
}
