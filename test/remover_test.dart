import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Delete old scores', () async {
    await Supabase.initialize(
      url: 'https://vslqselpnkpghtpnxryg.supabase.co',
      anonKey: 'sb_publishable_qAfWW1fw67Xb85gAtWyBZg_sKB-ISaW',
    );
    final supabase = Supabase.instance.client;
    print('Deleting old dummy scores...');
    final res = await supabase.from('scores').delete().inFilter('category', ['Quiz', 'Assignment', 'Activity', 'Project', 'Exam']).select();
    print('Deleted ${res.length} old scores.');
  });
}
