import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

Future<void> saveFile(List<int> bytes, String fileName, dynamic context) async {
  final directory = await getApplicationDocumentsDirectory();
  final String filePath = "${directory.path}/$fileName";
  final file = File(filePath);
  await file.writeAsBytes(bytes);

  if (context is BuildContext) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('บันทึกไฟล์เรียบร้อยที่: $fileName'))
    );
  }
}
