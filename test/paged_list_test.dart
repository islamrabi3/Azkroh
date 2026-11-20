import 'package:azkroh_app/features/core/widgets/paged_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('searchKey keeps letters and drops diacritics', () {
    expect(searchKey('مُحَمَّد صدّيق'), 'محمدصديق');
    expect(searchKey('أحمد'), 'احمد');
  });

  testWidgets('PagedSliverList builds one page at a time', (tester) async {
    final items = List.generate(200, (i) => i);
    final built = <int>{};
    await tester.pumpWidget(MaterialApp(
      home: CustomScrollView(slivers: [
        PagedSliverList<int>(
          items: items,
          pageSize: 20,
          itemBuilder: (_, v, __) {
            built.add(v);
            return SizedBox(height: 50, child: Text('$v'));
          },
        ),
      ]),
    ));
    expect(built.length, lessThanOrEqualTo(20));

    // Scroll to the bottom repeatedly: pages are appended.
    for (int i = 0; i < 4; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
    }
    expect(built.length, greaterThan(20));
    expect(built.length, lessThan(200));
  });
}
