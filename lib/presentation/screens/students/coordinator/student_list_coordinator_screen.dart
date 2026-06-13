import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:madaurore/core/constants/app_colors.dart';
import 'package:madaurore/core/utils/member_status_utils.dart';
import 'package:madaurore/data/repositories/app_auth_provider.dart';
import 'package:madaurore/data/repositories/request_repository.dart';
import 'package:madaurore/data/models/user_model.dart';
import 'package:madaurore/data/models/request_model.dart';

class StudentListCoordinatorScreen extends StatefulWidget {
  static const routeName = '/coordinator/student-list';

  const StudentListCoordinatorScreen({super.key});

  @override
  State<StudentListCoordinatorScreen> createState() =>
      _StudentListCoordinatorScreenState();
}

class _StudentListCoordinatorScreenState
    extends State<StudentListCoordinatorScreen> {
  final RequestRepository _requestRepository = RequestRepository();
  String _searchQuery = '';
  String _filterStatus = 'Tous';
  String _filterRequestStatus = 'Toutes demandes';
  final List<String> _statuses = [
    'Tous',
    'Nouveau Membre',
    'Ancien Membre',
    'Non classé',
  ];
  final List<String> _requestStatuses = [
    'Toutes demandes',
    'À traiter',
    'Validées admin',
    'Validées conseil',
    'Rejetées',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context);
    final userRegion = auth.userModel?.region;

    if (userRegion == null) {
      return const Scaffold(body: Center(child: Text('Région non trouvée')));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          'Étudiants de $userRegion',
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
              stream: _streamRegionalStudents(userRegion),
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
                              ? 'Aucun étudiant dans votre région'
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

  Stream<List<Map<String, dynamic>>> _streamRegionalStudents(String region) {
    return _requestRepository
        .getRequestsByRegionStream(region, limit: 200)
        .asyncMap((requests) async {
          final students = <Map<String, dynamic>>[];
          final userIds = <String>{};

          for (final request in requests) {
            if (!userIds.contains(request.userId)) {
              userIds.add(request.userId);
              students.add({'request': request, 'user': null});
            }
          }

          final userCache = <String, UserModel?>{};

          for (final student in students) {
            final request = student['request'] as RequestModel;
            if (!userCache.containsKey(request.userId)) {
              userCache[request.userId] = await _fetchUserData(request.userId);
            }
            student['user'] = userCache[request.userId];
          }

          return students;
        })
        .handleError((e) {
          debugPrint('❌ Erreur stream regional students: $e');
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

  /// ✅ MODIFIER LA BIO DE L'ÉTUDIANT (PAR COORDO)
  void _showEditBioDialog(RequestModel request) async {
    final bioController = TextEditingController(text: request.studentBio ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier la bio de l\'étudiant'),
        content: TextField(
          controller: bioController,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Bio de l\'étudiant...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (confirmed == true && bioController.text.trim().isNotEmpty) {
      await _updateStudentBio(request.id, bioController.text.trim());
    }
  }

  Future<void> _updateStudentBio(String requestId, String newBio) async {
    try {
      final auth = Provider.of<AppAuthProvider>(context, listen: false);
      final coordoId = auth.user?.uid;

      await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .update({
            'studentBio': newBio,
            'bioModifiedBy': coordoId,
            'bioModifiedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Bio modifiée avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Erreur: $e')));
      }
    }
  }

  /// ✅ CLASSER COMME NOUVEAU/ANCIEN MEMBRE
  void _showClasserMembreDialog(RequestModel request) async {
    final selectedStatus = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          request.isNouveauMembre
              ? Icons.edit
              : request.isAncienMembre
              ? Icons.edit
              : Icons.person_add_alt_1,
          size: 48,
          color: request.memberStatus == null
              ? Colors.orange
              : AppColors.primary,
        ),
        title: Text(
          'Classer l\'étudiant',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'En tant que coordinateur régional, vous devez classer cet étudiant :',
              style: GoogleFonts.poppins(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.person_add, color: AppColors.success),
                    title: Text(
                      'Nouveau Membre',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Première demande de parrainage',
                      style: GoogleFonts.poppins(fontSize: 11),
                    ),
                    selected: request.isNouveauMembre,
                    selectedTileColor: AppColors.success.withValues(alpha: 0.1),
                    onTap: () => Navigator.pop(context, 'nouveau_membre'),
                  ),
                  ListTile(
                    leading: Icon(Icons.people, color: AppColors.primary),
                    title: Text(
                      'Ancien Membre',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Déjà parrainé précédemment',
                      style: GoogleFonts.poppins(fontSize: 11),
                    ),
                    selected: request.isAncienMembre,
                    selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
                    onTap: () => Navigator.pop(context, 'ancien_membre'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '📌 Cette information aide le Conseil Administratif dans ses décisions',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Annuler', style: GoogleFonts.poppins()),
          ),
          if (request.memberStatus != null)
            TextButton(
              onPressed: () => Navigator.pop(context, 'clear'),
              child: Text(
                'Réinitialiser',
                style: GoogleFonts.poppins(color: Colors.orange),
              ),
            ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );

    if (selectedStatus != null) {
      if (selectedStatus == 'clear') {
        await _clearMemberStatus(request.id);
      } else {
        await _updateMemberStatus(request.id, selectedStatus);
      }
    }
  }

  Future<void> _updateMemberStatus(
    String requestId,
    String memberStatus,
  ) async {
    try {
      final auth = Provider.of<AppAuthProvider>(context, listen: false);
      final coordoId = auth.user?.uid;
      final normalizedStatus =
          MemberStatusUtils.normalize(memberStatus) ??
          MemberStatusUtils.unclassified;
      final firestore = FirebaseFirestore.instance;
      final requestRef = firestore.collection('requests').doc(requestId);
      final requestSnapshot = await requestRef.get();
      final userId = requestSnapshot.data()?['userId'] as String?;
      final batch = firestore.batch();

      batch.update(requestRef, {
        'memberStatus': normalizedStatus,
        'coordoNotesAt': FieldValue.serverTimestamp(),
        'coordoNotesBy': coordoId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (userId != null && userId.trim().isNotEmpty) {
        batch.update(firestore.collection('users').doc(userId), {
          'memberStatus': normalizedStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              MemberStatusUtils.isNew(normalizedStatus)
                  ? '✅ Étudiant classé comme NOUVEAU MEMBRE'
                  : '✅ Étudiant classé comme ANCIEN MEMBRE',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Erreur: $e')));
      }
    }
  }

  Future<void> _clearMemberStatus(String requestId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final requestRef = firestore.collection('requests').doc(requestId);
      final requestSnapshot = await requestRef.get();
      final userId = requestSnapshot.data()?['userId'] as String?;
      final batch = firestore.batch();

      batch.update(requestRef, {
        'memberStatus': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (userId != null && userId.trim().isNotEmpty) {
        batch.update(firestore.collection('users').doc(userId), {
          'memberStatus': MemberStatusUtils.unclassified,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🔄 Statut membre réinitialisé')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Erreur: $e')));
      }
    }
  }

  String _effectiveMemberStatus(RequestModel request, UserModel? user) {
    return MemberStatusUtils.effective(
      request.memberStatus,
      user?.memberStatus,
    );
  }

  bool _matchesRequestStatus(RequestModel request) {
    switch (_filterRequestStatus) {
      case 'À traiter':
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

      return matchesSearch &&
          _matchesRequestStatus(request) &&
          _matchesMemberStatus(request, user);
    }).toList();
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
          Row(
            children: [
              const Icon(Icons.fact_check, color: AppColors.textSecondary),
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
          Row(
            children: [
              const Icon(Icons.filter_list, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statuses.map((status) {
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

  Widget _buildStudentCard(RequestModel request, UserModel? user) {
    final isApproved = request.statut == 'approved_council';
    final isPending = request.isEnAttente;
    final isRejected = request.isRejete;

    String statusText;

    if (isApproved) {
      statusText = 'Approuvé';
    } else if (isRejected) {
      statusText = 'Rejeté';
    } else if (isPending) {
      statusText = 'En attente';
    } else {
      statusText = request.statut;
    }

    final memberStatus = _effectiveMemberStatus(request, user);
    final memberStatusIcon = MemberStatusUtils.isNew(memberStatus)
        ? Icons.person_add
        : MemberStatusUtils.isOld(memberStatus)
        ? Icons.people
        : Icons.help_outline;
    final memberStatusLabel = MemberStatusUtils.label(memberStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showStudentDetails(request, user),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isApproved
                      ? [
                          AppColors.success,
                          AppColors.success.withValues(alpha: 0.8),
                        ]
                      : isPending
                      ? [
                          AppColors.pending,
                          AppColors.pending.withValues(alpha: 0.8),
                        ]
                      : [
                          AppColors.error,
                          AppColors.error.withValues(alpha: 0.8),
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
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
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
                            Icon(
                              memberStatusIcon,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              memberStatusLabel,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
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
                      statusText,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
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
                      '📝 Bio de l\'étudiant',
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
                  if (request.coordoNotes != null &&
                      request.coordoNotes!.isNotEmpty) ...[
                    Text(
                      '📋 Mes notes',
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
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        request.coordoNotes!,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // ✅ BOUTON CLASSER NOUVEAU/ANCIEN MEMBRE
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '📌 Statut membre :',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      if (request.isNouveauMembre)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.success,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 12,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Nouveau',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (request.isAncienMembre)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primary,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                size: 12,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Ancien',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.help_outline,
                                size: 12,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'À classer',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ✅ BOUTON ACTION RAPIDE - CLASSER MEMBRE
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showClasserMembreDialog(request),
                      icon: Icon(
                        request.isNouveauMembre
                            ? Icons.edit
                            : request.isAncienMembre
                            ? Icons.edit
                            : Icons.person_add_alt_1,
                        size: 18,
                      ),
                      label: Text(
                        request.isNouveauMembre
                            ? 'Modifier le statut'
                            : request.isAncienMembre
                            ? 'Modifier le statut'
                            : '🔔 Classer comme membre (Action requise)',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: request.memberStatus == null
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: request.memberStatus == null
                            ? Colors.orange
                            : AppColors.primary,
                        side: BorderSide(
                          color: request.memberStatus == null
                              ? Colors.orange
                              : AppColors.primary,
                          width: request.memberStatus == null ? 2 : 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          request.titre,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (request.montant != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${request.montant} Ar',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
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

  void _showStudentDetails(RequestModel request, UserModel? user) {
    final memberStatus = _effectiveMemberStatus(request, user);
    final memberStatusIcon = MemberStatusUtils.isNew(memberStatus)
        ? Icons.person_add
        : MemberStatusUtils.isOld(memberStatus)
        ? Icons.people
        : Icons.help_outline;
    final memberStatusLabel = MemberStatusUtils.label(memberStatus);

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
                    colors: request.isApprouveConseil
                        ? [
                            AppColors.success,
                            AppColors.success.withValues(alpha: 0.8),
                          ]
                        : request.isEnAttente
                        ? [
                            AppColors.pending,
                            AppColors.pending.withValues(alpha: 0.8),
                          ]
                        : [
                            AppColors.error,
                            AppColors.error.withValues(alpha: 0.8),
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
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
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
                          Icon(memberStatusIcon, size: 16, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            memberStatusLabel,
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
                      'Statut',
                      request.statut,
                      Icons.info_outline,
                      valueColor: request.isApprouveConseil
                          ? AppColors.success
                          : request.isEnAttente
                          ? AppColors.pending
                          : AppColors.error,
                    ),
                    if (request.montant != null) ...[
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        'Montant Demandé',
                        '${request.montant} Ar',
                        Icons.monetization_on_outlined,
                      ),
                    ],
                    if (request.montantAccorde != null) ...[
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        'Montant Accordé',
                        '${request.montantAccorde} Ar',
                        Icons.monetization_on,
                        valueColor: AppColors.success,
                      ),
                    ],
                    if (request.studentBio != null &&
                        request.studentBio!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '📝 Bio de l\'étudiant',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _showEditBioDialog(request);
                            },
                            icon: const Icon(
                              Icons.edit,
                              color: AppColors.primary,
                            ),
                            tooltip: 'Modifier la bio',
                          ),
                        ],
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
                    if (request.coordoNotes != null &&
                        request.coordoNotes!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        '📋 Mes notes (Coordinateur)',
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
                            Text(
                              request.coordoNotes!,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                height: 1.6,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (request.coordoNotesBy != null) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Par: ${request.coordoNotesBy}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (request.reason != null &&
                        request.reason!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        '❌ Raison du rejet',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          request.reason!,
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
