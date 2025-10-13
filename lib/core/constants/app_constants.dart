class AppConstants {
  static const List<String> regions = [
    'Antananarivo',
    'Antsirabe',
    'Fianarantsoa',
    'Tuléar',
  ];

  static const List<String> roles = ['admin', 'coordinator', 'student'];

  static const List<String> statuses = ['pending', 'approved', 'rejected'];

  static const Map<String, String> roleTitles = {
    'admin': 'Administrateur',
    'coordinator': 'Coordinateur',
    'student': 'Étudiant',
  };

  static const Map<String, String> statusMessages = {
    'pending': 'En attente',
    'approved': 'Approuvé',
    'rejected': 'Rejeté',
  };
}
