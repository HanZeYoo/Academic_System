import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Delete all scores', () async {
    final client = SupabaseClient(
      'https://vslqselpnkpghtpnxryg.supabase.co',
      'sb_publishable_qAfWW1fw67Xb85gAtWyBZg_sKB-ISaW',
    );
    print('Deleting all scores from Supabase...');
    final res = await client.from('scores').delete().neq('student_id', '__non_existent__').select();
    print('Successfully deleted ${res.length} scores from Supabase.');
  });
}
