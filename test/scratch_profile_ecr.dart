import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:academic_system/services/ecr_parser_service.dart';
import 'package:academic_system/services/ecr_mapping_engine.dart';

void main() {
  test('profile ECR import stages', () async {
    final file = File('Grade 7/Computer 7.xlsx');
    final bytes = await file.readAsBytes();
    print('File size: ${(bytes.length / 1024).toStringAsFixed(0)} KB');

    final sw = Stopwatch()..start();
    final archive = ZipDecoder().decodeBytes(bytes);
    print('zip decode: ${sw.elapsedMilliseconds} ms (${archive.files.length} entries)');
    for (final f in archive.files) {
      if (f.size > 200000) print('  big entry: ${f.name} ${(f.size / 1024).toStringAsFixed(0)} KB');
    }

    sw
      ..reset()
      ..start();
    final excel = Excel.decodeBytes(Uint8List.fromList(bytes));
    print('Excel.decodeBytes: ${sw.elapsedMilliseconds} ms');
    for (final k in excel.tables.keys) {
      final t = excel.tables[k]!;
      print('  sheet "$k": ${t.maxRows} rows x ${t.maxColumns} cols');
    }

    final parser = EcrParserService();
    sw
      ..reset()
      ..start();
    final res = parser.parseFileSync(bytes, 'Computer 7.xlsx', gradingPeriod: '1st Term');
    print('parseFileSync total: ${sw.elapsedMilliseconds} ms');

    sw
      ..reset()
      ..start();
    EcrMappingEngine().autoDetectMappings(
      headers: res.headers,
      previewRows: res.dataRows.take(10).toList(),
      rowHpsMap: res.rowHpsMap,
    );
    print('autoDetectMappings: ${sw.elapsedMilliseconds} ms');
  }, timeout: const Timeout(Duration(minutes: 3)));
}

