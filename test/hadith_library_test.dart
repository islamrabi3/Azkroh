import 'package:azkroh_app/features/core/services/hadith_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('full-text search finds hadiths by any part of the text', () async {
    final lib = HadithLibrary();
    final sw = Stopwatch()..start();
    final r1 = await lib.search('إنما الأعمال بالنيات');
    // ignore: avoid_print
    print('load+search ${sw.elapsedMilliseconds}ms, total=${r1.total}, first=${r1.items.first.source}');
    expect(r1.total, greaterThan(0));
    expect(r1.items.first.source, 'صحيح البخاري');

    sw.reset();
    final r2 = await lib.search('انت سالم ما سكت');
    // ignore: avoid_print
    print('query2 ${sw.elapsedMilliseconds}ms total=${r2.total} ${r2.items.isNotEmpty ? r2.items.first.source : ''}');

    final r3 = await lib.search('الصبر', onlySahih: true);
    // ignore: avoid_print
    print('sabr sahih total=${r3.total}');
    expect(r3.items.every((h) => (h.grade ?? '').contains('صحيح')), true);
  });
}
