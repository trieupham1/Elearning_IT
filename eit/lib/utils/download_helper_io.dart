// Mobile/Desktop implementation using path_provider and share_plus
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadCSV(String csvData, String fileName) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsString(csvData);

  await Share.shareXFiles(
    [XFile(file.path)],
    subject: 'CSV Export',
  );
}
