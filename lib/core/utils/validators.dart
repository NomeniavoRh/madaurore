String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Email requis';
  }
  final email = value.trim();
  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  if (!emailRegex.hasMatch(email)) {
    return 'Email invalide';
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Mot de passe requis';
  }
  if (value.length < 6) {
    return 'Doit contenir au moins 6 caractères';
  }
  return null;
}

String? validateFullName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Nom complet requis';
  }
  if (value.trim().split(' ').length < 2) {
    return 'Entrez le nom et le prénom';
  }
  return null;
}

String? validateTitle(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Titre requis';
  }
  if (value.trim().length < 3) {
    return 'Titre trop court';
  }
  return null;
}
