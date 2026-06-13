import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:madaurore/core/constants/app_colors.dart';
import 'package:madaurore/core/utils/member_status_utils.dart';
import 'package:madaurore/core/utils/region_utils.dart';
import 'package:madaurore/data/models/user_model.dart';
import 'package:madaurore/data/models/request_model.dart';
import 'package:madaurore/data/repositories/request_repository.dart';

class StudentListAdminScreen extends StatefulWidget {
  static const routeName = '/admin/student-list';

  const StudentListAdminScreen({super.key});

  @override
  State<StudentListAdminScreen> createState() => _StudentListAdminScreenState();
}

class _StudentListAdminScreenState extends State<StudentListAdminScreen> {
  final RequestRepository _requestRepository = RequestRepository();
  String _searchQuery = '';
  String _filterRegion = 'Toutes';
  String _filterStatus = 'Tous';
  String _filterRequestStatus = 'Toutes demandes';
  List<String> _regions = ['Toutes'];
  final List<String> _memberStatuses = [
    'Tous',
    'Nouveau Membre',
    'Ancien Membre',
    'Non classé',
  ];
  final List<String> _requestStatuses = [
    'Toutes demandes',
    'En attente',
    'Validées admin',
    'Validées conseil',
    'Rejetées',
  ];

  @override
  void initState() {
    super.initState();
    _fetchRegions();
  }

  Future<void> _fetchRegions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('requests')
          .get();
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

  Stream<List<Map<String, dynamic>>> _streamAllStudents() {
    return _requestRepository
        .watchRequests(limit: 200)
        .asyncMap((requests) async {
          final students = <Map<String, dynamic>>[];
          final userIds = <String>{};

          for (final request in requests) {
            if (!userIds.contains(request.userId)) {
              userIds.add(request.userId);
              students.add({
                'request': request,
                'user': null,
                'coordinator': null,
              });
            }
          }

          final userCache = <String, UserModel?>{};
          final coordinatorCache = <String, UserModel?>{};

          for (final student in students) {
            final request = student['request'] as RequestModel;
            if (!userCache.containsKey(request.userId)) {
              userCache[request.userId] = await _fetchUserData(request.userId);
            }
            if (!coordinatorCache.containsKey(request.region)) {
              coordinatorCache[request.region] = await _fetchCoordinatorData(
                request.region,
              );
            }
            student['user'] = userCache[request.userId];
            student['coordinator'] = coordinatorCache[request.region];
          }

          return students;
        })
        .handleError((e) {
          debugPrint('❌ Erreur stream students: $e');
          return <Map<String, dynamic>>[];
        });
  }

  Future<UserModel?> _fetchUserData(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) return UserModel.fromDocument(doc);
    } catch (e) {
      debugPrint('Erreur fetch user: $e');
    }
    return null;
  }

  Future<UserModel?> _fetchCoordinatorData(String region) async {
    try {
      final regions = RegionUtils.queryValues(region);
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'regional_coordinator');
      query = regions.length == 1
          ? query.where('region', isEqualTo: regions.first)
          : query.where('region', whereIn: regions);
      final snapshot = await query.limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        return UserModel.fromDocument(snapshot.docs.first);
      }
    } catch (e) {
      debugPrint('Erreur fetch coordinator: $e');
    }
    return null;
  }

  String _effectiveMemberStatus(RequestModel request, UserModel? user) {
    return MemberStatusUtils.effective(
      request.memberStatus,
      user?.memberStatus,
    );
  }

  bool _matchesRequestStatus(RequestModel request) {
    switch (_filterRequestStatus) {
      case 'En attente':
        return request.isEnAttente;
      case 'Validées admin':
        return request.isApprouveAdmin;
      case 'Validées conseil':
        return request.isApprouveConseil;
      case 'Rejetées':
        return request.isRejete;
      default:
        return true;
    }
  }

  bool _matchesMemberStatus(RequestModel request, UserModel? user) {
    final status = _effectiveMemberStatus(request, user);

    switch (_filterStatus) {
      case 'Nouveau Membre':
        return MemberStatusUtils.isNew(status);
      case 'Ancien Membre':
        return MemberStatusUtils.isOld(status);
      case 'Non classé':
        return MemberStatusUtils.isUnclassified(status);
      default:
        return true;
    }
  }

  List<Map<String, dynamic>> _filterStudents(
    List<Map<String, dynamic>> students,
  ) {
    return students.where((student) {
      final request = student['request'] as RequestModel;
      final user = student['user'] as UserModel?;

      final matchesSearch =
          _searchQuery.isEmpty ||
          (user?.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false) ||
          (user?.email.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false) ||
          request.titre.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesRegion =
          _filterRegion == 'Toutes' ||
          RegionUtils.normalize(request.region) ==
              RegionUtils.normalize(_filterRegion);

      return matchesSearch &&
          matchesRegion &&
          _matchesRequestStatus(request) &&
          _matchesMemberStatus(request, user);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          'Étudiants Parrainés',
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
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _streamAllStudents(),
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

                final allStudents = snapshot.data ?? [];
                final filteredStudents = _filterStudents(allStudents);

                if (filteredStudents.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          allStudents.isEmpty
                              ? 'Aucun étudiant parrainé'
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
                  itemCount: filteredStudents.length,
                  itemBuilder: (context, index) {
                    final student = filteredStudents[index];
                    return _buildStudentCard(
                      student['request'] as RequestModel,
                      student['user'] as UserModel?,
                      student['coordinator'] as UserModel?,
                    );
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
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.background,
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher un étudiant...',
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
          // Filtres par région
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
          Row(
            children: [
              const Icon(
                Icons.fact_check,
                color: AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _requestStatuses.map((status) {
                      final isSelected = status == _filterRequestStatus;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(status),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _filterRequestStatus = status);
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
          // Filtres par statut membre
          Row(
            children: [
              const Icon(
                Icons.people,
                color: AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _memberStatuses.map((status) {
                      final isSelected = status == _filterStatus;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(status),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _filterStatus = status);
                          },
                          backgroundColor: Colors.white,
                          selectedColor: status == 'Non classé'
                              ? Colors.orange.withValues(alpha: 0.5)
                              : AppColors.accent.withValues(alpha: 0.5),
                          checkmarkColor: status == 'Non classé'
                              ? Colors.orange
                              : AppColors.primary,
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

  Widget _buildStudentCard(
    RequestModel request,
    UserModel? user,
    UserModel? coordinator,
  ) {
    final memberStatus = _effectiveMemberStatus(request, user);
    final isNewMember = MemberStatusUtils.isNew(memberStatus);
    final isOldMember = MemberStatusUtils.isOld(memberStatus);
    final memberStatusIcon = isNewMember
        ? Icons.person_add
        : isOldMember
        ? Icons.people
        : Icons.help_outline;
    final memberStatusColor = isNewMember
        ? AppColors.success
        : isOldMember
        ? AppColors.primary
        : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showStudentDetails(request, user, coordinator),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.8),
                  ],
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
                    backgroundColor: AppColors.accent,
                    backgroundImage: user?.photoUrl != null
                        ? NetworkImage(user!.photoUrl!)
                        : null,
                    child: user?.photoUrl == null
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Étudiant',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 14,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              request.region,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Badge statut membre
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: memberStatusColor.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                memberStatusIcon,
                                size: 10,
                                color: memberStatusColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                MemberStatusUtils.shortLabel(memberStatus),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: memberStatusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${request.montantAccorde ?? 0} Ar',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (request.montant != null &&
                            request.montant != request.montantAccorde)
                          Text(
                            '(Dem: ${request.montant} Ar)',
                            style: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 9,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (request.studentBio != null &&
                      request.studentBio!.isNotEmpty) ...[
                    Text(
                      'Bio de l\'étudiant',
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        request.studentBio!,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (coordinator != null) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Coordinateur: ${coordinator.fullName}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        request.titre,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        request.createdAt.toString().split(' ')[0],
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentDetails(
    RequestModel request,
    UserModel? user,
    UserModel? coordinator,
  ) {
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
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.8),
                    ],
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
                      backgroundColor: AppColors.accent,
                      backgroundImage: user?.photoUrl != null
                          ? NetworkImage(user!.photoUrl!)
                          : null,
                      child: user?.photoUrl == null
                          ? const Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user?.fullName ?? 'Étudiant',
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            request.region,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
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
                    _buildInfoRow(
                      'Email',
                      user?.email ?? 'N/A',
                      Icons.email_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      'Montant Accordé',
                      '${request.montantAccorde ?? 0} Ar',
                      Icons.monetization_on_outlined,
                      valueColor: AppColors.success,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      'Statut',
                      request.statut,
                      Icons.info_outline,
                      valueColor: AppColors.pending,
                    ),
                    if (request.studentBio != null &&
                        request.studentBio!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        '📝 Bio de l\'étudiant',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          request.studentBio!,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            height: 1.6,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    if (coordinator != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        '👤 Coordinateur Régional',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppColors.accent,
                                  child: Icon(
                                    Icons.admin_panel_settings,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    coordinator.fullName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.email_outlined,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  coordinator.email,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (request.coordoNotes != null &&
                        request.coordoNotes!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        '📋 Notes du Coordinateur',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.pending.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.pending.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          request.coordoNotes!,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            height: 1.6,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Fermer',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
