class RegionUtils {
  static const String toliara = 'Toliara';

  static String normalize(String? value) {
    final cleaned = (value ?? '').trim();
    if (cleaned.isEmpty) return 'Antananarivo';

    final lower = cleaned.toLowerCase();
    if (lower == 'tulear' || lower == 'tuléar' || lower == 'toliara') {
      return toliara;
    }

    return cleaned;
  }

  static List<String> queryValues(String? value) {
    final normalized = normalize(value);
    if (normalized == toliara) {
      return const [toliara, 'Tuléar', 'Tulear'];
    }
    return [normalized];
  }
}
