import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../data/scripts_repository.dart';

class ImportCsvDialog extends ConsumerStatefulWidget {
  const ImportCsvDialog({super.key});

  @override
  ConsumerState<ImportCsvDialog> createState() => _ImportCsvDialogState();
}

class _ImportCsvDialogState extends ConsumerState<ImportCsvDialog> {
  bool _isImporting = false;
  String _statusMessage = 'CSVファイル（タイトル, 本文, タグ）を選択してください。';

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

      final notifier = ref.read(scriptsListProvider.notifier);

      for (var row in rows) {
        if (row.length >= 2) {
          final title = row[0].toString().trim();
          final content = row[1].toString().trim();
          
          List<String> tags = [];
          if (row.length >= 3) {
            final tagsString = row[2].toString();
            tags = tagsString
                .split(RegExp(r'[,\s]+'))
                .where((e) => e.isNotEmpty)
                .toList();
          }

          DateTime? targetDate;
          if (row.length >= 4) {
            final dateStr = row[3].toString().trim();
            if (dateStr.isNotEmpty) {
              final normalized = dateStr.replaceAll('/', '-');
              targetDate = DateTime.tryParse(normalized);
            }
          }
          
          if (title.isNotEmpty && content.isNotEmpty) {
            await notifier.addScript(
              title: title,
              content: content,
              tags: tags,
              targetDate: targetDate,
            );
            importedCount++;
          }
        }
      }

      setState(() {
        _statusMessage = '$importedCount 件のテキストをインポートしました！';
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
