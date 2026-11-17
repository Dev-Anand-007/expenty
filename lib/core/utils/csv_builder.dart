/// Minimal CSV serialisation (RFC 4180 style) used by the export flows.
///
/// Fields containing a comma, quote or line break are quoted, and inner
/// quotes are doubled. Rows are joined with CRLF so Excel and Sheets
/// parse the files without tweaking import settings.
class CsvBuilder {
  CsvBuilder._();

  static String escape(String field) {
    final needsQuotes = field.contains(',') ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r');
    if (!needsQuotes) return field;
    return '"${field.replaceAll('"', '""')}"';
  }

  static String build(List<String> headers, List<List<String>> rows) {
    final lines = [
      headers.map(escape).join(','),
      for (final row in rows) row.map(escape).join(','),
    ];
    return lines.join('\r\n');
  }
}
