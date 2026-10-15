/// Owner request 2026-10-15: phone numbers, emails and web links inside an
/// event's text become tappable. This finds them; the widget layer turns
/// each into a tap action.
enum TextLinkKind { phone, email, url }

class TextLink {
  const TextLink({
    required this.kind,
    required this.start,
    required this.end,
    required this.text,
  });

  final TextLinkKind kind;

  /// Offsets into the searched string, [start] inclusive, [end] exclusive.
  final int start;
  final int end;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is TextLink &&
      other.kind == kind &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(kind, start, end);

  @override
  String toString() => 'TextLink($kind, "$text")';
}

final RegExp _email = RegExp(r'[A-Za-z0-9][\w.+-]*@[\w-]+(\.[\w-]+)+');
final RegExp _url = RegExp(r'(https?://|www\.)[^\s<>"]+', caseSensitive: false);

/// A phone number: optional +, then digits with optional dashes, spaces,
/// dots or parentheses between them. Checked for 9 to 15 digits below, so
/// a time, a date or a price is not taken for a number.
final RegExp _phone = RegExp(r'\+?\(?\d[\d\-\s.()]{6,}\d');

/// Trailing punctuation that belongs to the sentence, not the link.
final RegExp _trailing = RegExp(r'[.,;:!?)\]]+$');

/// Every phone number, email and web link in [text], in order and never
/// overlapping (an email or link wins over digits inside it).
List<TextLink> findTextLinks(String text) {
  final List<TextLink> found = <TextLink>[];
  bool overlaps(int start, int end) =>
      found.any((TextLink l) => start < l.end && end > l.start);

  for (final RegExpMatch m in _url.allMatches(text)) {
    final String raw = m.group(0)!;
    final String trimmed = raw.replaceFirst(_trailing, '');
    found.add(
      TextLink(
        kind: TextLinkKind.url,
        start: m.start,
        end: m.start + trimmed.length,
        text: trimmed,
      ),
    );
  }
  for (final RegExpMatch m in _email.allMatches(text)) {
    if (!overlaps(m.start, m.end)) {
      found.add(
        TextLink(
          kind: TextLinkKind.email,
          start: m.start,
          end: m.end,
          text: m.group(0)!,
        ),
      );
    }
  }
  for (final RegExpMatch m in _phone.allMatches(text)) {
    String raw = m.group(0)!;
    int start = m.start;
    // An opening parenthesis is only kept when it is closed inside.
    if (raw.startsWith('(') && !raw.contains(')')) {
      raw = raw.substring(1);
      start += 1;
    }
    final String trimmed = raw.replaceFirst(_trailing, '').trimRight();
    final int digits = trimmed.replaceAll(RegExp(r'\D'), '').length;
    final int end = start + trimmed.length;
    if (digits >= 9 && digits <= 15 && !overlaps(start, end)) {
      found.add(
        TextLink(
          kind: TextLinkKind.phone,
          start: start,
          end: end,
          text: trimmed,
        ),
      );
    }
  }
  found.sort((TextLink a, TextLink b) => a.start.compareTo(b.start));
  return found;
}

/// The number as dialable digits, keeping a leading +.
String dialableNumber(String phone) {
  final String digits = phone.replaceAll(RegExp(r'\D'), '');
  return phone.trimLeft().startsWith('+') ? '+$digits' : digits;
}

/// The number in international form without + for a wa.me link. A local
/// Israeli number (leading 0) gets the 972 country code.
String whatsAppNumber(String phone) {
  final String dial = dialableNumber(phone);
  if (dial.startsWith('+')) {
    return dial.substring(1);
  }
  if (dial.startsWith('00')) {
    return dial.substring(2);
  }
  if (dial.startsWith('0')) {
    return '972${dial.substring(1)}';
  }
  return dial;
}
