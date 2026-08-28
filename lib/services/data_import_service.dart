import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

class DataImportService {
  Future<List<Map<String, dynamic>>> parseFile(File file) async {
    String extension = file.path.split('.').last.toLowerCase();
    if (extension == 'csv') {
      return await parseCsvFile(file);
    } else if (extension == 'xlsx' || extension == 'ods') {
      return await parseSpreadsheetFile(file, extension);
    } else {
      throw Exception('Formato non supportato: $extension');
    }
  }

  Future<List<Map<String, dynamic>>> parseSpreadsheetFile(File file, String extension) async {
    var bytes = await file.readAsBytes();
    
    SpreadsheetDecoder decoder;
    try {
      decoder = SpreadsheetDecoder.decodeBytes(bytes, update: false);
    } catch (e) {
      throw Exception('Errore durante la decodifica del file $extension: $e');
    }

    List<Map<String, dynamic>> results = [];
    
    // Leggi dal primo foglio disponibile
    String? sheetName = decoder.tables.keys.firstOrNull;
    if (sheetName != null) {
      var table = decoder.tables[sheetName]!;
      if (table.rows.isNotEmpty) {
        var headerRow = table.rows.first;
        List<String> headers = headerRow.map((e) => e?.toString().trim() ?? '').toList();
        
        for (int i = 1; i < table.rows.length; i++) {
          var row = table.rows[i];
          // Skip empty rows
          if (row.every((element) => element == null || element.toString().trim().isEmpty)) {
            continue;
          }

          Map<String, dynamic> rowData = {};
          for (int j = 0; j < headers.length; j++) {
            if (j < row.length && row[j] != null) {
              rowData[headers[j]] = row[j]?.toString().trim() ?? '';
            } else {
              rowData[headers[j]] = '';
            }
          }
          results.add(rowData);
        }
      }
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> parseCsvFile(File file) async {
    String contents = '';
    try {
      contents = await file.readAsString(encoding: utf8);
    } catch (e) {
      contents = await file.readAsString(encoding: latin1);
    }

    String firstLine = contents.split('\n').first;
    String delimiter = firstLine.contains(';') ? ';' : ',';

    List<List<dynamic>> rowsAsListOfValues = CsvDecoder(fieldDelimiter: delimiter).convert(contents);

    if (rowsAsListOfValues.isEmpty) return [];

    List<Map<String, dynamic>> results = [];
    var headers = rowsAsListOfValues.first.map((e) => e.toString().trim()).toList();

    for (int i = 1; i < rowsAsListOfValues.length; i++) {
      var row = rowsAsListOfValues[i];
      if (row.isEmpty || row.every((element) => element.toString().trim().isEmpty)) continue;

      Map<String, dynamic> rowData = {};
      for (int j = 0; j < headers.length; j++) {
        if (j < row.length) {
          rowData[headers[j]] = row[j].toString().trim();
        } else {
          rowData[headers[j]] = '';
        }
      }
      results.add(rowData);
    }
    
    return results;
  }
}
