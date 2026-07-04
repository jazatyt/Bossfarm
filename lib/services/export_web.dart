import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';

Future<void> saveFile(List<int> bytes, String fileName, dynamic context) async {
  final content = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  final url = html.Url.createObjectUrlFromBlob(content);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
  html.Url.revokeObjectUrl(url);

  if (context is BuildContext) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('เริ่มดาวน์โหลดไฟล์: $fileName'))
    );
  }
}
