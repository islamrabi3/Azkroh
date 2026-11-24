/// Arabic honorific ligatures (﵀ ﵁ ﷺ …) are missing from most fonts and
/// show as unknown-character boxes, so they are spelled out as words.
const _honorifics = {
  '﵀': 'رحمه الله',
  '﵁': 'رضي الله عنه',
  '﵂': 'رضي الله عنها',
  '﵃': 'رضي الله عنهم',
  '﵄': 'رضي الله عنهما',
  '﵅': 'رضي الله عنهن',
  '﵆': 'صلى الله عليه وآله',
  '﵇': 'عليه السلام',
  '﵈': 'عليهم السلام',
  '﵉': 'عليهما السلام',
  '﵊': 'عليه الصلاة والسلام',
  '﵋': 'قدس سره',
  '﵌': 'صلى الله عليه وآله وسلم',
  '﵍': 'عليها السلام',
  '﵎': 'تبارك وتعالى',
  '﵏': 'رحمهم الله',
  'ﷲ': 'الله',
  'ﷺ': 'صلى الله عليه وسلم',
  'ﷻ': 'جل جلاله',
  '﷽': 'بسم الله الرحمن الرحيم',
};

final _honorificRe = RegExp('[\\uFD40-\\uFD4F\\uFDF2\\uFDFA-\\uFDFD]');

/// Replaces honorific ligatures with their words.
String spellHonorifics(String s) {
  if (!_honorificRe.hasMatch(s)) return s;
  return s
      .replaceAllMapped(_honorificRe, (m) => ' ${_honorifics[m[0]] ?? ''} ')
      .replaceAll(RegExp(' {2,}'), ' ')
      .replaceAll(RegExp(r' ([،.؛:)\]»])'), r'$1')
      .trim();
}
