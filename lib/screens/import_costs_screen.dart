import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/migration_service.dart';

class ImportCostsScreen extends StatefulWidget {
  const ImportCostsScreen({super.key});

  @override
  State<ImportCostsScreen> createState() => _ImportCostsScreenState();
}

class _ImportCostsScreenState extends State<ImportCostsScreen> {
  String status = 'Seleccione un archivo CSV o Excel (.csv, .xlsx)';
  bool processing = false;

  Future<void> _pickAndImport() async {
    setState(() { processing = true; status = 'Seleccionando archivo...'; });

    try {
      if (kIsWeb) {
        // FilePicker supports web
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.custom,
          allowedExtensions: ['csv', 'xlsx', 'xls'],
        );
        if (result == null || result.files.isEmpty) return;
        final fileBytes = result.files.first.bytes;
        final name = result.files.first.name;
        final tmp = await File('${Directory.systemTemp.path}/${name}').writeAsBytes(fileBytes!);
        final res = await MigrationService.migrateProductCostsFromFile(tmp.path);
        setState(() { status = 'Importado: updated=${res['updated']}, skipped=${res['skipped']}'; });
      } else {
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.custom,
          allowedExtensions: ['csv', 'xlsx', 'xls'],
        );
        if (result == null || result.files.isEmpty) return;
        final path = result.files.single.path!;
        final res = await MigrationService.migrateProductCostsFromFile(path);
        setState(() { status = 'Importado: updated=${res['updated']}, skipped=${res['skipped']}'; });
      }
    } catch (e) {
      setState(() { status = 'Error: $e'; });
    } finally {
      setState(() => processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar costos')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: processing ? null : _pickAndImport,
              icon: const Icon(Icons.upload_file),
              label: Text(processing ? 'Procesando...' : 'Subir CSV/Excel'),
            ),
            const SizedBox(height: 8),
            const Text('Formato esperado: id,name,cost  (id opcional - se buscará por id o por name)'),
          ],
        ),
      ),
    );
  }
}
