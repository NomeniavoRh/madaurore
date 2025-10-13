import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:madaurore/services/firestore_service.dart';
import 'package:madaurore/data/repositories/app_auth_provider.dart';
import 'package:madaurore/core/utils/validators.dart';
import 'package:madaurore/core/constants/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RequestSubmitScreen extends StatefulWidget {
  const RequestSubmitScreen({super.key});

  @override
  RequestSubmitScreenState createState() => RequestSubmitScreenState();
}

class RequestSubmitScreenState extends State<RequestSubmitScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  String _reason = 'Medical';
  String _region = 'Antananarivo';
  bool _loading = false;
  File? _pdfFile;

  static const List<String> reasons = ['Medical', 'Family', 'Other'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AppAuthProvider>(context, listen: false);
      if (auth.userModel?.role != 'student' || auth.userModel?.status != 'approved') {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      setState(() {
        _pdfFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _pdfFile == null) return;
    setState(() => _loading = true);
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final uid = auth.user?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur non connecté')),
        );
      }
      setState(() => _loading = false);
      return;
    }

    try {
      await FirestoreService.instance.addRequest(
        titre: _titleController.text.trim(),
        reason: _reason,
        userId: uid,
        region: auth.userModel?.region ?? _region,
        localisation: '',
        pdfFile: _pdfFile!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande soumise')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const sizedBox = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          'Soumettre une demande',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Titre',
                  labelStyle: GoogleFonts.poppins(color: AppColors.primary),
                  border: const OutlineInputBorder(),
                ),
                validator: validateTitle,
              ),
              sizedBox,
              DropdownButtonFormField<String>(
                initialValue: _reason,
                items: reasons
                    .map((reason) => DropdownMenuItem(
                          value: reason,
                          child: Text(reason, style: GoogleFonts.poppins()),
                        ))
                    .toList(),
                decoration: InputDecoration(
                  labelText: 'Raison',
                  labelStyle: GoogleFonts.poppins(color: AppColors.primary),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _reason = v!),
              ),
              sizedBox,
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('regions').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  final regions = snapshot.data!.docs.map((doc) => doc['name'] as String).toList();
                  return _buildRegionDropdown(regions);
                },
              ),
              sizedBox,
              ElevatedButton(
                onPressed: _pickPdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.background,
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Choisir un PDF (max 10MB)',
                  style: GoogleFonts.poppins(color: AppColors.primary),
                ),
              ),
              if (_pdfFile != null) Text('Fichier sélectionné : ${_pdfFile!.path.split('/').last}'),
              sizedBox,
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _loading ? 'Patientez...' : 'Soumettre',
                  style: GoogleFonts.poppins(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegionDropdown(List<String> regions) {
    return DropdownButtonFormField<String>(
      initialValue: _region,
      items: regions
          .map((region) => DropdownMenuItem(
                value: region,
                child: Text(region, style: GoogleFonts.poppins()),
              ))
          .toList(),
      decoration: InputDecoration(
        labelText: 'Région',
        labelStyle: GoogleFonts.poppins(color: AppColors.primary),
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) => setState(() => _region = v!),
    );
  }
}