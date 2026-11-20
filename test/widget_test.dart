import 'package:azkroh_app/features/presentation/screens/homescreen.dart'
    show arNum;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('arNum converts western digits to Arabic-Indic', () {
    expect(arNum(121), '١٢١');
    expect(arNum('04:57'), '٠٤:٥٧');
  });
}
