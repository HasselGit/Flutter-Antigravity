import 'package:supabase/supabase.dart';

void main() async {
  print('--- CHECKING SUPABASE SCHEMA ---');
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('Checking profiles table...');
    final data = await client.from('profiles').select().limit(1);
    if (data is List && data.isNotEmpty) {
      print('Profiles column keys: ${data[0].keys.toList()}');
      print('First profile data: $data');
    } else {
      print('Profiles table is empty or data format unexpected: $data');
    }
  } catch (e) {
    print('Error checking profiles: $e');
  }

  try {
    print('\nChecking auth users (via public profiles email match)...');
    // We can't access auth.users directly via anon key, 
    // but we can check if there are users with standard auth by trying to sign in with a known bad password
    // but better check if there's an 'id' that looks like a UUID in profiles.
  } catch (_) {}
}
