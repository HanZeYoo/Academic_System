import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';

void main() {
  print('=== RE-RUNNING CLEAN ECR SCRUBBER ===');

  final xlsxSource = File(r'C:\Users\Acer\Downloads\Documents\GRADE-1_1ST-QUARTER-.xlsx');
  final xlsxTarget = File('test/fixtures/anonymized_deped_grade1.xlsx');

  if (xlsxSource.existsSync()) {
    final bytes = xlsxSource.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    final newArchive = Archive();

    for (final file in archive.files) {
      if (!file.isFile) {
        newArchive.addFile(file);
        continue;
      }

      final name = file.name;
      List<int> content = file.content as List<int>;

      // Scrub metadata properties
      if (name.startsWith('docProps/')) {
        var xml = utf8.decode(content);
        xml = xml.replaceAll(RegExp(r'<dc:creator>[^<]*</dc:creator>'), '<dc:creator>DepEd Teacher</dc:creator>');
        xml = xml.replaceAll(RegExp(r'<cp:lastModifiedBy>[^<]*</cp:lastModifiedBy>'), '<cp:lastModifiedBy>DepEd Teacher</cp:lastModifiedBy>');
        content = utf8.encode(xml);
      }
      // Scrub sheet XMLs if any 12-digit numbers appear
      else if (name.startsWith('xl/worksheets/')) {
        var xml = utf8.decode(content);
        // Scrub any 12-digit numbers in sheet cells
        xml = xml.replaceAllMapped(RegExp(r'\b[0-9]{12}\b'), (m) => '100000000001');
        content = utf8.encode(xml);
      }

      newArchive.addFile(ArchiveFile(name, content.length, content));
    }

    final outBytes = ZipEncoder().encode(newArchive);
    if (outBytes != null) {
      xlsxTarget.writeAsBytesSync(outBytes);
      print('Wrote clean anonymized XLSX: ${xlsxTarget.path} (${xlsxTarget.lengthSync()} bytes)');
    }
  }

  // 2. Scrub CSV file
  final csvSource = File(r'C:\Users\Acer\Downloads\Documents\MAPEH,EPP,TLE-DO NOT DELETE,MAPEH,EPP,TLE-FIRST QUARTER,MAPEH,EPP,TLE-FOURTH QUARTER\MAPEH,EPP,TLE-FIRST QUARTER.csv');
  final csvTarget = File('test/fixtures/anonymized_mapeh_q1.csv');

  if (csvSource.existsSync()) {
    final lines = csvSource.readAsLinesSync();
    final scrubbedLines = <String>[];
    int studentCount = 1;
    int lrnCount = 100000000001;

    for (final line in lines) {
      var scrubbed = line;
      scrubbed = scrubbed.replaceAllMapped(RegExp(r'\b[0-9]{12}\b'), (m) => '${lrnCount++}');

      if (scrubbed.toUpperCase().contains('SCHOOL NAME') || scrubbed.toUpperCase().contains('TEACHER:')) {
        scrubbed = scrubbed.replaceAll(RegExp(r':\s*[^,]+'), ': Anonymized');
      }

      final match = RegExp(r'^(\d+),("[^"]+"|[A-Za-z\s,\.]+),(.*)$').firstMatch(scrubbed);
      if (match != null) {
        final num = match.group(1);
        final rest = match.group(3);
        scrubbed = '$num,"SYNTHETIC LEARNER ${studentCount++}",$rest';
      }

      scrubbedLines.add(scrubbed);
    }

    csvTarget.writeAsStringSync(scrubbedLines.join('\n'));
    print('Wrote clean anonymized CSV: ${csvTarget.path} (${csvTarget.lengthSync()} bytes)');
  }

  print('=== RE-SCRUBBING COMPLETE ===');
}
