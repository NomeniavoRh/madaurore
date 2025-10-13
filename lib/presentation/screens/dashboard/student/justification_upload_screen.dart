import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:madaurore/services/firestore_service.dart';
import 'package:madaurore/core/constants/app_colors.dart';

class JustificationUploadScreen extends StatefulWidget {
  final String requestId;
  const JustificationUploadScreen({super.key, required this.requestId});

  @override
  // ignore: library_private_types_in_public_api
  _JustificationUploadScreenState createState() =>
      _JustificationUploadScreenState();
}

class _JustificationUploadScreenState extends State<JustificationUploadScreen> {
  bool _loading = false;
  File? _justificationFile;

  Future<void> _pickPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      setState(() {
        _justificationFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _uploadJustification() async {
    if (_justificationFile == null) return;
    setState(() => _loading = true);
    try {
      await FirestoreService.instance.updateRequest(
        widget.requestId,
        'en attente',
        justificationFile: _justificationFile,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Justificatif téléchargé')),
        );
        Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    const sizedBox2 = SizedBox(height: 12);
    const sizedBox = sizedBox2;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          'Télécharger un Justificatif',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
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
            if (_justificationFile != null)
              Text(
                'Fichier sélectionné : ${_justificationFile!.path.split('/').last}',
              ),
            sizedBox,
            ElevatedButton(
              onPressed: _loading ? null : _uploadJustification,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _loading ? 'Patientez...' : 'Télécharger',
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
