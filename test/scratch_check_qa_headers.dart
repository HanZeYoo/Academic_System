import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:academic_system/services/ecr_parser_service.dart';
import 'package:academic_system/services/ecr_mapping_engine.dart';
import 'package:academic_system/models/ecr_mapping_model.dart';

void main() {
  test('Check Computer 7.xlsx mappings with old template', () async {
    final parser = EcrParserService();
    final engine = EcrMappingEngine();
    final bytes = await File('Grade 7/Computer 7.xlsx').readAsBytes();
    final res = parser.parseFileSync(bytes, 'Computer 7.xlsx');

    final oldTemplate = {
      'E X A M I N A T I O N S - Summative Test1': 'QA',
      'E X A M I N A T I O N S - Summative Test2': 'QA',
      'E X A M I N A T I O N S - Quarterly Exam': 'QA',
    };

    final mappingsWithTemplate = engine.autoDetectMappings(
      headers: res.headers,
      previewRows: res.dataRows,
      rowHpsMap: res.rowHpsMap,
      savedTemplate: EcrMappingTemplate(
        teacherId: 'teacher@school.edu',
        subjectId: 'COMP7',
        mappingJson: oldTemplate,
      ),
    );

    print('Mappings with OLD template:');
    print('[49]: ${mappingsWithTemplate[49].target.label}');
    print('[50]: ${mappingsWithTemplate[50].target.label}');
    print('[51]: ${mappingsWithTemplate[51].target.label}');
  });
}

