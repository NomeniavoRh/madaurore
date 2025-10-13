import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../data/models/validation_request_model.dart';
import '../data/models/request_model.dart';
import 'package:intl/intl.dart';

class DocumentService {
  DocumentService._();
  static final DocumentService instance = DocumentService._();

  Future<String> generateValidationDocument(List<ValidationRequestModel> items) async {
    final pdf = pw.Document();
    final fmt = DateFormat.yMd().add_jm();

    pdf.addPage(
      pw.MultiPage(
        build: (context) {
          return [
            pw.Header(level: 0, child: pw.Text('Validation Requests')),
            pw.ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final it = items[index];
                return pw.Container(
                  margin: const pw.EdgeInsets.symmetric(vertical: 6),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Email: ${it.email}'),
                      pw.Text('Region: ${it.region}'),
                      pw.Text('Statut: ${it.statut}'),
                      pw.Text('Created: ${fmt.format(it.createdAt)}'),
                      pw.SizedBox(height: 6),
                    ],
                  ),
                );
              },
            ),
          ];
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/validation_requests_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  Future<String> generateRequestDocument(List<RequestModel> items) async {
    final pdf = pw.Document();
    final fmt = DateFormat.yMd().add_jm();

    pdf.addPage(
      pw.MultiPage(
        build: (context) {
          return [
            pw.Header(level: 0, child: pw.Text('Requests')),
            pw.ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final it = items[index];
                return pw.Container(
                  margin: const pw.EdgeInsets.symmetric(vertical: 6),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Titre: ${it.titre}'),
                      pw.Text('Statut: ${it.statut}'),
                      pw.Text('region: ${it.region}'),
                      pw.Text('Created: ${fmt.format(it.createdAt)}'),
                      if (it.justificationUrl != null) pw.Text('Justif: ${it.justificationUrl}'),
                      pw.SizedBox(height: 6),
                    ],
                  ),
                );
              },
            ),
          ];
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/requests_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }
}
