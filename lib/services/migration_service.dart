import 'dart:io';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'db_service.dart';
import 'export_service.dart';

class MigrationService {
  /// Migrates product cost values from a CSV or Excel file.
  ///
  /// Accepted formats:
  /// - CSV with columns: id,name,cost (id optional - if present match by id, otherwise match by name case-insensitive)
  /// - XLSX with a sheet containing the same columns in the first row.
  ///
  /// By default does NOT create new products. It will update existing products matched by id or name.
  /// Returns a map with counts: { 'updated': int, 'created': int, 'skipped': int }
  static Future<Map<String, int>> migrateProductCostsFromFile(String path) async {
    final lower = path.toLowerCase();
    if (lower.endsWith('.csv')) {
      return migrateFromCsv(path);
    } else if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
      return migrateFromExcel(path);
    } else {
      throw Exception('Unsupported file format: $path');
    }
  }

  static Future<Map<String, int>> migrateFromCsv(String path) async {
    final file = File(path);
    if (!await file.exists()) throw Exception('CSV file not found: $path');

    final content = await file.readAsString();
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(content);

    return _processRows(rows.map((r) => r.map((c) => c?.toString() ?? '').toList()).toList());
  }

  static Future<Map<String, int>> migrateFromExcel(String path) async {
    final bytes = await File(path).readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) throw Exception('Excel file contains no sheets');

    // Use the first sheet
    final sheetName = excel.tables.keys.first;
    final table = excel.tables[sheetName]!;

    final rows = table.rows.map((r) => r.map((c) => c?.value?.toString() ?? '').toList()).toList();
    return _processRows(rows);
  }

  static Future<Map<String, int>> _processRows(List<List<String>> rows) async {
    if (rows.isEmpty) return {'updated': 0, 'created': 0, 'skipped': 0};

    // Normalize header: find indices of id,name,cost
    final header = rows.first.map((c) => c.toString().toLowerCase().trim()).toList();
    int idIdx = header.indexOf('id');
    int nameIdx = header.indexOf('name');
    int costIdx = header.indexOf('cost');

    // If there's no header names, attempt common positions
    if (nameIdx == -1 && header.length >= 2) nameIdx = 0;
    if (costIdx == -1 && header.length >= 2) costIdx = 1;

    int updated = 0;
    int created = 0;
    int skipped = 0;

    // Read existing products once
    final products = await DBService.getProducts();

    // Build name -> index map for quick lookup (case-insensitive)
    final nameToIndex = <String, int>{};
    for (var p in products) {
      final id = (p['id'] is int) ? p['id'] as int : int.tryParse('${p['id']}') ?? -1;
      final name = (p['name'] ?? '').toString().toLowerCase();
      if (name.isNotEmpty) nameToIndex[name] = id;
    }

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((c) => c.trim().isEmpty)) continue;

      String name = '';
      double cost = 0.0;
      int? id;

      if (idIdx >= 0 && idIdx < row.length) {
        id = int.tryParse(row[idIdx].trim());
      }

      if (nameIdx >= 0 && nameIdx < row.length) {
        name = row[nameIdx].trim();
      }

      if (costIdx >= 0 && costIdx < row.length) {
        cost = double.tryParse(row[costIdx].trim().replaceAll(',', '.')) ?? 0.0;
      } else if (row.length >= 2) {
        // fallback: if only two columns assume name,cost
        name = name.isEmpty ? row[0].trim() : name;
        cost = double.tryParse(row[1].trim().replaceAll(',', '.')) ?? 0.0;
      }

      if ((id == null || id < 0) && name.isEmpty) {
        skipped++;
        continue;
      }

      bool didUpdate = false;
      if (id != null) {
        // try match by id
        final productsById = products.where((p) {
          final pid = (p['id'] is int) ? p['id'] as int : int.tryParse('${p['id']}') ?? -1;
          return pid == id;
        }).toList();
        if (productsById.isNotEmpty) {
          final pid = id;
          final current = productsById.first;
          final updatedMap = {
            ...current,
            'cost': cost,
          };
          await DBService.updateProduct(pid, updatedMap);
          updated++;
          didUpdate = true;
        }
      }

      if (!didUpdate && name.isNotEmpty) {
        final lookup = name.toLowerCase();
        if (nameToIndex.containsKey(lookup)) {
          final pid = nameToIndex[lookup]!;
          final raw = products.firstWhere((p) {
            final pid2 = (p['id'] is int) ? p['id'] as int : int.tryParse('${p['id']}') ?? -1;
            return pid2 == pid;
          });
          final updatedMap = {
            ...raw,
            'cost': cost,
          };
          await DBService.updateProduct(pid, updatedMap);
          updated++;
          didUpdate = true;
        }
      }

      if (!didUpdate) {
        // By default we do not create new products; count as skipped
        skipped++;
      }
    }

    return {'updated': updated, 'created': created, 'skipped': skipped};
  }
}
