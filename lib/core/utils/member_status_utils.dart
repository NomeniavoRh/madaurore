class MemberStatusUtils {
  static const String newMember = 'nouveau_membre';
  static const String oldMember = 'ancien_membre';
  static const String unclassified = 'non_classe';

  static String? normalize(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;

    final normalized = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]+'), '_')
        .replaceAll('__', '_');

    switch (normalized) {
      case 'nouveau_membre':
      case 'nouveau':
      case 'new_member':
      case 'new':
        return newMember;
      case 'ancien_membre':
      case 'ancien':
      case 'existing_member':
      case 'old_member':
      case 'old':
        return oldMember;
      case 'non_classe':
      case 'non_classé':
      case 'unclassified':
      case 'unknown':
        return unclassified;
      default:
        return raw;
    }
  }

  static String effective(String? requestStatus, String? userStatus) {
    final requestValue = normalize(requestStatus);
    if (requestValue != null) return requestValue;

    return normalize(userStatus) ?? unclassified;
  }

  static bool isNew(String? value) => normalize(value) == newMember;
  static bool isOld(String? value) => normalize(value) == oldMember;
  static bool isUnclassified(String? value) =>
      normalize(value) == null || normalize(value) == unclassified;

  static String label(String? value) {
    switch (normalize(value)) {
      case newMember:
        return 'Nouveau Membre';
      case oldMember:
        return 'Ancien Membre';
      default:
        return 'Non classé';
    }
  }

  static String shortLabel(String? value) {
    switch (normalize(value)) {
      case newMember:
        return 'Nouveau';
      case oldMember:
        return 'Ancien';
      default:
        return 'Non classé';
    }
  }
}
