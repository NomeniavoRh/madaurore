import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:madaurore/services/firestore_service.dart';
import 'package:madaurore/data/repositories/app_auth_provider.dart';
import 'package:madaurore/core/utils/validators.dart';
import 'package:madaurore/core/constants/app_colors.dart';

class RequestSubmitScreen extends StatefulWidget {
  const RequestSubmitScreen({super.key});

  @override
  RequestSubmitScreenState createState() => RequestSubmitScreenState();
}

class RequestSubmitScreenState extends State<RequestSubmitScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  String _reason = 'Medical';
  final String _region = 'Antananarivo';
  bool _loading = false;
  PlatformFile? _pdfFile;

  static const List<String> reasons = ['Medical', 'Family', 'Other'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AppAuthProvider>(context, listen: false);
      if (auth.userModel?.role != 'student' ||
          auth.userModel?.status != 'approved') {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null) {
      setState(() {
        _pdfFile = result.files.single;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pdfFile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Veuillez choisir un PDF')));
      return;
    }

    final montant = _parseAmount(_amountController.text);
    if (montant == null || montant <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Montant demandé invalide')));
      return;
    }

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
        localisation: _locationController.text.trim(),
        montant: montant,
        pdfFile: _pdfFile!,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Demande soumise')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  double? _parseAmount(String value) {
    final normalized = value.replaceAll(' ', '').replaceAll(',', '.').trim();
    return double.tryParse(normalized);
  }

  @override
  Widget build(BuildContext context) {
    const sizedBox = SizedBox(height: 12);
    final auth = Provider.of<AppAuthProvider>(context);
    final profileRegion = auth.userModel?.region ?? _region;

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
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
                  TextFormField(
                    controller: _amountController,
                    decoration: InputDecoration(
                      labelText: 'Montant demandé (Ar)',
                      labelStyle: GoogleFonts.poppins(color: AppColors.primary),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final amount = _parseAmount(value ?? '');
                      if (amount == null || amount <= 0) {
                        return 'Montant requis';
                      }
                      return null;
                    },
                  ),
                  sizedBox,
                  DropdownButtonFormField<String>(
                    initialValue: _reason,
                    items: reasons
                        .map(
                          (reason) => DropdownMenuItem(
                            value: reason,
                            child: Text(reason, style: GoogleFonts.poppins()),
                          ),
                        )
                        .toList(),
                    decoration: InputDecoration(
                      labelText: 'Raison',
                      labelStyle: GoogleFonts.poppins(color: AppColors.primary),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _reason = v!),
                  ),
                  sizedBox,
                  TextFormField(
                    initialValue: profileRegion,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Région',
                      labelStyle: GoogleFonts.poppins(color: AppColors.primary),
                      border: const OutlineInputBorder(),
                      helperText: 'La région vient de votre profil',
                    ),
                  ),
                  sizedBox,
                  TextFormField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      labelText: 'Localisation (optionnel)',
                      labelStyle: GoogleFonts.poppins(color: AppColors.primary),
                      border: const OutlineInputBorder(),
                    ),
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
                  if (_pdfFile != null)
                    Text('Fichier sélectionné : ${_pdfFile!.name}'),
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
        ),
      ),
    );
  }
}
