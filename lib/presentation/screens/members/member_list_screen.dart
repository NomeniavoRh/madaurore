import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:madaurore/core/constants/app_colors.dart';
import 'package:madaurore/core/utils/region_utils.dart';
import 'package:madaurore/data/repositories/app_auth_provider.dart';
import 'package:madaurore/data/models/user_model.dart';

class MemberListScreen extends StatefulWidget {
  static const routeName = '/admin/member-list';

  const MemberListScreen({super.key});

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  String _searchQuery = '';
  String _filterRegion = 'Toutes';
  String _filterRole =
      'student'; // Par défaut, afficher seulement les étudiants
  List<String> _regions = ['Toutes'];
  final List<String> _roles = [
    'Tous',
    'student',
    'regional_coordinator',
    'Conseil_Administratif',
    'admin',
  ];

  @override
  void initState() {
    super.initState();
    _fetchRegions();
  }

  Future<void> _fetchRegions() async {
    try {
      final auth = Provider.of<AppAuthProvider>(context, listen: false);
      final currentRole = auth.userModel?.role;
      final currentRegion = auth.userModel?.region;

      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('users')
          .where('status', isEqualTo: 'approved');

      if (currentRole == 'regional_coordinator' && currentRegion != null) {
        final regions = RegionUtils.queryValues(currentRegion);
        query = regions.length == 1
            ? query.where('region', isEqualTo: regions.first)
            : query.where('region', whereIn: regions);
      }

      final snapshot = await query.get();
      final regions = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return RegionUtils.normalize(data['region'] as String?);
          })
          .where((r) => r.isNotEmpty)
          .toSet()
          .toList();
      regions.sort();
      if (!mounted) return;
      setState(() {
        _regions = ['Toutes', ...regions];
      });
    } catch (e) {
      debugPrint('Erreur fetch regions: $e');
      if (mounted) {
        setState(() {
          _regions = ['Toutes'];
        });
      }
    }
  }

  Stream<List<UserModel>> _streamMembers() {
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final currentRole = auth.userModel?.role;
    final currentRegion = auth.userModel?.region;

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        .where('status', isEqualTo: 'approved');

    if (currentRole == 'regional_coordinator' && currentRegion != null) {
      final regions = RegionUtils.queryValues(currentRegion);
      query = regions.length == 1
          ? query.where('region', isEqualTo: regions.first)
          : query.where('region', whereIn: regions);
    }

    query = query.orderBy('fullName', descending: false);

    return query
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                try {
                  return UserModel.fromDocument(doc);
                } catch (e) {
                  debugPrint('❌ Erreur parse user: $e');
                  return null;
                }
              })
              .where((u) => u != null)
              .cast<UserModel>()
              .toList();
        })
        .handleError((e) {
          debugPrint('❌ Erreur stream members: $e');
          return <UserModel>[];
        });
  }

  List<UserModel> _filterMembers(List<UserModel> members) {
    return members.where((user) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          user.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.email.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesRegion =
          _filterRegion == 'Toutes' ||
          RegionUtils.normalize(user.region) ==
              RegionUtils.normalize(_filterRegion);

      final matchesRole = _filterRole == 'Tous' || user.role == _filterRole;

      return matchesSearch && matchesRegion && matchesRole;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context);
    final currentRole = auth.userModel?.role;
    final userRegion = auth.userModel?.region;

    // Vérifier les permissions
    if (currentRole != 'admin' &&
        currentRole != 'regional_coordinator' &&
        currentRole != 'Conseil_Administratif') {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          title: const Text('Accès refusé'),
        ),
        body: const Center(child: Text('Vous n\'avez pas accès à cette page')),
      );
    }

    // Pour les coordo, forcer le filtre sur leur région et étudiants seulement
    if (currentRole == 'regional_coordinator') {
      _filterRegion = userRegion ?? 'Toutes';
      _filterRole = 'student'; // Uniquement les étudiants
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          currentRole == 'regional_coordinator'
              ? 'Étudiants de $userRegion'
              : _filterRegion == 'Toutes'
              ? 'Membres Inscrits'
              : 'Étudiants de $_filterRegion',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _streamMembers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Erreur de chargement',
                          style: GoogleFonts.poppins(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final allMembers = snapshot.data ?? [];
                final filteredMembers = _filterMembers(allMembers);

                if (filteredMembers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          allMembers.isEmpty
                              ? 'Aucun membre inscrit'
                              : 'Aucun résultat trouvé',
                          style: GoogleFonts.poppins(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredMembers.length,
                  itemBuilder: (context, index) {
                    final member = filteredMembers[index];
                    return _buildMemberCard(member);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    final auth = Provider.of<AppAuthProvider>(context);
    final currentRole = auth.userModel?.role;
    final isCoordinator = currentRole == 'regional_coordinator';

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.background,
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: isCoordinator
                  ? 'Rechercher un étudiant...'
                  : 'Rechercher un membre...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 12),
          // Filtres par région (caché pour les coordo)
          if (!isCoordinator) ...[
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _regions.map((region) {
                        final isSelected = region == _filterRegion;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(region),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() => _filterRegion = region);
                            },
                            backgroundColor: Colors.white,
                            selectedColor: AppColors.accent.withValues(
                              alpha: 0.5,
                            ),
                            checkmarkColor: AppColors.primary,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          // Filtres par rôle (caché pour les coordo)
          if (!isCoordinator)
            Row(
              children: [
                const Icon(
                  Icons.badge,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _roles.map((role) {
                        final isSelected = role == _filterRole;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(_getRoleLabel(role)),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() => _filterRole = role);
                            },
                            backgroundColor: Colors.white,
                            selectedColor: AppColors.accent.withValues(
                              alpha: 0.5,
                            ),
                            checkmarkColor: AppColors.primary,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(UserModel member) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showMemberDetails(member),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _getRoleGradient(member.role),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    backgroundImage: member.photoUrl != null
                        ? NetworkImage(member.photoUrl!)
                        : null,
                    child: member.photoUrl == null
                        ? Icon(
                            _getRoleIcon(member.role),
                            color: Colors.white,
                            size: 30,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.fullName,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          member.email,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              member.region,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getRoleLabel(member.role),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Inscrit le ${_formatDate(member.createdAt)}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    member.memberStatus == 'nouveau_membre' ||
                            member.memberStatus == 'new_member'
                        ? Icons.person_add
                        : member.memberStatus == 'ancien_membre' ||
                              member.memberStatus == 'existing_member'
                        ? Icons.people
                        : Icons.help_outline,
                    size: 16,
                    color:
                        member.memberStatus == 'nouveau_membre' ||
                            member.memberStatus == 'new_member'
                        ? AppColors.success
                        : member.memberStatus == 'ancien_membre' ||
                              member.memberStatus == 'existing_member'
                        ? AppColors.primary
                        : Colors.orange,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMemberDetails(UserModel member) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _getRoleGradient(member.role),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      backgroundImage: member.photoUrl != null
                          ? NetworkImage(member.photoUrl!)
                          : null,
                      child: member.photoUrl == null
                          ? Icon(
                              _getRoleIcon(member.role),
                              size: 50,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      member.fullName,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getRoleLabel(member.role),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Email', member.email, Icons.email_outlined),
                    const SizedBox(height: 16),
                    _buildInfoRow('Région', member.region, Icons.location_on),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      'Date d\'inscription',
                      _formatDate(member.createdAt),
                      Icons.calendar_today,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      'Statut Membre',
                      member.memberStatus == 'nouveau_membre' ||
                              member.memberStatus == 'new_member'
                          ? 'Nouveau Membre'
                          : member.memberStatus == 'ancien_membre' ||
                                member.memberStatus == 'existing_member'
                          ? 'Ancien Membre'
                          : 'Non classé',
                      member.memberStatus == 'nouveau_membre' ||
                              member.memberStatus == 'new_member'
                          ? Icons.person_add
                          : member.memberStatus == 'ancien_membre' ||
                                member.memberStatus == 'existing_member'
                          ? Icons.people
                          : Icons.help_outline,
                      valueColor:
                          member.memberStatus == 'nouveau_membre' ||
                              member.memberStatus == 'new_member'
                          ? AppColors.success
                          : member.memberStatus == 'ancien_membre' ||
                                member.memberStatus == 'existing_member'
                          ? AppColors.primary
                          : Colors.orange,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'student':
        return 'Étudiant';
      case 'regional_coordinator':
        return 'Coordo Régional';
      case 'Conseil_Administratif':
        return 'Conseil Admin';
      case 'admin':
        return 'Administrateur';
      default:
        return role;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'student':
        return Icons.school;
      case 'regional_coordinator':
        return Icons.admin_panel_settings;
      case 'Conseil_Administratif':
        return Icons.gavel;
      case 'admin':
        return Icons.security;
      default:
        return Icons.person;
    }
  }

  List<Color> _getRoleGradient(String role) {
    switch (role) {
      case 'student':
        return [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)];
      case 'regional_coordinator':
        return [AppColors.accent, AppColors.accent.withValues(alpha: 0.8)];
      case 'Conseil_Administratif':
        return [AppColors.success, AppColors.success.withValues(alpha: 0.8)];
      case 'admin':
        return [Colors.purple, Colors.purple.withValues(alpha: 0.8)];
      default:
        return [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)];
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
