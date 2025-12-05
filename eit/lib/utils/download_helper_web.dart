// Web implementation using dart:html
import 'dart:convert';
import 'dart:html' as html;

Future<void> downloadCSV(String csvData, String fileName) async {
  final bytes = utf8.encode(csvData);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
