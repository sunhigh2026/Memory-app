import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../../tts/data/tts_dictionary_repository.dart';

class ImportTtsCsvDialog extends ConsumerStatefulWidget {
  const ImportTtsCsvDialog({super.key});

  @override
  ConsumerState<ImportTtsCsvDialog> createState() => _ImportTtsCsvDialogState();
}

class _ImportTtsCsvDialogState extends ConsumerState<ImportTtsCsvDialog> {
  bool _isImporting = false;
  String _statusMessage = 'CSVファイル（原文, 読み）を選択してください。';

  Future<void> _importCsv() async {
    setState(() {
      _isImporting = true;
      _statusMessage = 'ファイルを選択中...';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null) {
        setState(() {
          _isImporting = false;
          _statusMessage = 'キャンセルされました。';
        });
        return;
      }

      final file = result.files.single;
      setState(() {
        _statusMessage = 'ファイルを読み込み中...';
      });

      List<int> bytes;
      if (file.path != null) {
        final ioFile = File(file.path!);
        bytes = await ioFile.readAsBytes();
      } else if (file.bytes != null) {
        bytes = file.bytes!;
      } else {
        throw Exception('ファイルを読み込めませんでした。ローカルに保存してから再度お試しください。');
      }

      String csvString;
      try {
        csvString = Utf8Decoder(allowMalformed: false).convert(bytes);
      } on FormatException {
        throw const FormatException(
          '文字コードエラー: ファイルがUTF-8で保存されていない可能性があります。\n\n'
          'ExcelでCSVを作成した場合は、保存時のファイルの種類で「CSV UTF-8 (コンマ区切り)(*.csv)」を選択して保存してください。'
        );
      }

      setState(() {
        _statusMessage = 'CSVを解析中...';
      });

      final rows = const CsvToListConverter().convert(csvString);
      int importedCount = 0;

      final notifier = ref.read(ttsDictionaryListProvider.notifier);

      for (var row in rows) {
        if (row.length >= 2) {
          final original = row[0].toString().trim();
          final reading = row[1].toString().trim();
          
          if (original.isNotEmpty && reading.isNotEmpty) {
            notifier.add(original, reading);
            importedCount++;
          }
        }
      }

      setState(() {
        _statusMessage = '$importedCount 件の辞書エントリをインポートしました！';
        _isImporting = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = e is FormatException ? e.message : 'エラーが発生しました: $e';
        _isImporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('CSVをインポート'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_statusMessage),
          const SizedBox(height: 16),
          if (_isImporting) const CircularProgressIndicator(),
        ],
      ),
      actions: [
        if (!_isImporting)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        if (!_isImporting)
          ElevatedButton(
            onPressed: _importCsv,
            child: const Text('ファイルを選択'),
          ),
      ],
    );
  }
}
