import 'package:azkroh_app/features/core/services/hadith_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses Dorar result html', () {
    const html =
        '<div class="hadith" style="text-align:justify;">1 - إنما الأعمال بالنيات</div>'
        '<div class="hadith-info"><span class="info-subtitle">الراوي:</span> عمر بن الخطاب '
        '<span class="info-subtitle">المحدث:</span> البخاري '
        '<span class="info-subtitle">المصدر:</span> صحيح البخاري '
        '<span class="info-subtitle">الصفحة أو الرقم:</span> 1 <br> '
        '<span class="info-subtitle">خلاصة حكم المحدث:</span> <span>[صحيح]</span></div><hr>'
        '<div class="hadith">2 - حديث آخر</div>'
        '<div class="hadith-info"><span class="info-subtitle">الراوي:</span> أبو هريرة '
        '<span class="info-subtitle">خلاصة حكم المحدث:</span> <span>ضعيف</span></div>';
    final r = HadithService.parseDorarHtml(html);
    expect(r.length, 2);
    expect(r[0].text, 'إنما الأعمال بالنيات');
    expect(r[0].narrator, 'عمر بن الخطاب');
    expect(r[0].muhaddith, 'البخاري');
    expect(r[0].source, 'صحيح البخاري');
    expect(r[0].number, '1');
    expect(r[0].grade, '[صحيح]');
    expect(r[0].isSahih, true);
    expect(r[1].isSahih, false);
  });
}
