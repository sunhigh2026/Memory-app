import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../data/scripts_repository.dart';
import '../../subjects/data/subjects_repository.dart';

class ImportCsvDialog extends ConsumerStatefulWidget {
  const ImportCsvDialog({super.key});

  @override
  ConsumerState<ImportCsvDialog> createState() => _ImportCsvDialogState();
}

class _ImportCsvDialogState extends ConsumerState<ImportCsvDialog> {
  bool _isImporting = false;
  bool _isImported = false;
  String _statusMessage = 'CSVファイルを選択してください。\n'
      '（タイトル, 本文, タグ, 本番日, 通し番号, ランク）または\n'
      '（通し番号, タイトル, 本文, タグ, 本番日, ランク）の形式に対応しています。';

  Future<void> _importCsv() async {
    setState(() {
      _isImporting = true;
      _statusMessage = 'ファイルを選択中...';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any, // クラウドやAndroid SAFでCSVがグレーアウトする問題を防ぐためanyを使用
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
      final ext = file.extension?.toLowerCase() ?? '';
      // 拡張子チェックを緩和（警告を出力しつつ処理を継続）
      if (ext != 'csv' && !file.name.toLowerCase().endsWith('.csv')) {
        debugPrint('警告: 選択されたファイルの拡張子が.csvではありません (${file.name})。解析を試みます。');
      }

      setState(() {
        _statusMessage = 'ファイルを読み込み中...';
      });

      List<int> bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        final ioFile = File(file.path!);
        if (await ioFile.exists()) {
          bytes = await ioFile.readAsBytes();
        } else {
          throw Exception('ファイルが見つかりません。ローカルの保存フォルダーから再度お試しください。');
        }
      } else {
        throw Exception('ファイルを読み込めませんでした。ローカルに一度ダウンロードして保存してから再度お試しください。');
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
      
      // 1列目が通し番号の形式であるかを自動判定
      bool hasLeadingSortOrder = false;
      int scanCount = 0;
      int sortOrderScore = 0;
      for (var row in rows) {
        if (row.isEmpty) continue;
        if (row.length < 3) continue; // 2列以下の場合は判定不可
        
        final col0 = row[0].toString().trim();
        final col1 = row[1].toString().trim();
        final col2 = row[2].toString().trim();
        
        // 1列目が空でなく、半角英数字と一部の記号のみで、長さが10文字以下
        final isCol0LookLikeId = col0.isNotEmpty && 
            RegExp(r'^[a-zA-Z0-9\-_./]+$').hasMatch(col0) && 
            col0.length <= 10;
            
        // 3列目（本文と想定）が2列目（タイトルと想定）より明らかに長く、かつ10文字以上
        final isCol2MuchLonger = col2.length > col1.length * 1.5 && col2.length >= 10;
        
        if (isCol0LookLikeId && isCol2MuchLonger) {
          sortOrderScore++;
        } else {
          sortOrderScore--;
        }
        
        scanCount++;
        if (scanCount >= 5) break;
      }
      
      if (scanCount > 0 && sortOrderScore > 0) {
        hasLeadingSortOrder = true;
        debugPrint('CSVの1列目を通し番号（sortOrder）として認識しました。');
      } else {
        debugPrint('CSVの1列目をタイトルとして認識しました（従来のフォーマット）。');
      }

      int importedCount = 0;
      final notifier = ref.read(scriptsListProvider.notifier);

      for (var row in rows) {
        if (row.isEmpty) continue;

        String title = '';
        String content = '';
        List<String> tags = [];
        DateTime? targetDate;
        int sortOrder = 0;
        String rank = 'B';

        if (hasLeadingSortOrder) {
          // 通し番号あり：[0]:通し番号, [1]:タイトル, [2]:本文, [3]:タグ, [4]:ターゲット日, [5]:ランク
          if (row.length >= 3) {
            final sortStr = row[0].toString().trim();
            final cleanSortStr = sortStr.replaceAll(RegExp(r'\D'), '');
            sortOrder = int.tryParse(cleanSortStr) ?? 0;

            title = row[1].toString().trim();
            content = row[2].toString().trim();

            if (row.length >= 4) {
              final tagsString = row[3].toString();
              tags = tagsString
                  .split(RegExp(r'[,\s]+'))
                  .where((e) => e.isNotEmpty)
                  .toList();
            }

            if (row.length >= 5) {
              final dateStr = row[4].toString().trim();
              if (dateStr.isNotEmpty) {
                final normalized = dateStr.replaceAll('/', '-');
                targetDate = DateTime.tryParse(normalized);
              }
            }

            if (row.length >= 6) {
              final rankStr = row[5].toString().trim();
              if (['特A', 'S', 'A', 'B', 'C'].contains(rankStr)) {
                rank = rankStr == '特A' ? 'S' : rankStr;
              } else if (rankStr.toUpperCase() == 'S') {
                rank = 'S';
              } else if (rankStr.toUpperCase() == 'A') {
                rank = 'A';
              } else if (rankStr.toUpperCase() == 'B') {
                rank = 'B';
              } else if (rankStr.toUpperCase() == 'C') {
                rank = 'C';
              }
            }
          }
        } else {
          // 通し番号なし（従来通り）：[0]:タイトル, [1]:本文, [2]:タグ, [3]:ターゲット日, [4]:通し番号, [5]:ランク
          if (row.length >= 2) {
            title = row[0].toString().trim();
            content = row[1].toString().trim();

            if (row.length >= 3) {
              final tagsString = row[2].toString();
              tags = tagsString
                  .split(RegExp(r'[,\s]+'))
                  .where((e) => e.isNotEmpty)
                  .toList();
            }

            if (row.length >= 4) {
              final dateStr = row[3].toString().trim();
              if (dateStr.isNotEmpty) {
                final normalized = dateStr.replaceAll('/', '-');
                targetDate = DateTime.tryParse(normalized);
              }
            }

            if (row.length >= 5) {
              final sortStr = row[4].toString().trim();
              final cleanSortStr = sortStr.replaceAll(RegExp(r'\D'), '');
              sortOrder = int.tryParse(cleanSortStr) ?? 0;
            }

            if (row.length >= 6) {
              final rankStr = row[5].toString().trim();
              if (['特A', 'S', 'A', 'B', 'C'].contains(rankStr)) {
                rank = rankStr == '特A' ? 'S' : rankStr;
              } else if (rankStr.toUpperCase() == 'S') {
                rank = 'S';
              } else if (rankStr.toUpperCase() == 'A') {
                rank = 'A';
              } else if (rankStr.toUpperCase() == 'B') {
                rank = 'B';
              } else if (rankStr.toUpperCase() == 'C') {
                rank = 'C';
              }
            }
          }
        }

        if (title.isNotEmpty && content.isNotEmpty) {
          await notifier.addScript(
            title: title,
            content: content,
            tags: tags,
            targetDate: targetDate,
            sortOrder: sortOrder,
            rank: rank,
          );
          importedCount++;
        }
      }

      setState(() {
        _statusMessage = '$importedCount 件のテキストをインポートしました！';
        _isImporting = false;
        _isImported = true;
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
    final currentSubject = ref.watch(currentSubjectProvider);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.file_upload, size: 22),
          const SizedBox(width: 8),
          const Text('CSVをインポート'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school, size: 16, color: Colors.blue),
                const SizedBox(width: 6),
                Text(
                  'インポート先: ${currentSubject.name}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(_statusMessage),
          const SizedBox(height: 16),
          if (_isImporting) const Center(child: CircularProgressIndicator()),
        ],
      ),
      actions: [
        if (!_isImporting)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_isImported ? 'OK' : '閉じる'),
          ),
        if (!_isImporting && !_isImported)
          ElevatedButton(
            onPressed: _importCsv,
            child: const Text('ファイルを選択'),
          ),
      ],
    );
  }
}
