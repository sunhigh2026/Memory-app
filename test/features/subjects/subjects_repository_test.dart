import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:memorization_app/models/script.dart';
import 'package:memorization_app/models/cloze_word.dart';
import 'package:memorization_app/models/practice_session.dart';
import 'package:memorization_app/models/tts_dictionary_entry.dart';
import 'package:memorization_app/models/allowed_pair.dart';
import 'package:memorization_app/models/subject.dart';
import 'package:memorization_app/features/subjects/data/subjects_repository.dart';
import 'package:memorization_app/features/scripts/data/scripts_repository.dart';

void main() {
  late Directory tempDir;
  late SubjectsRepository subjectsRepo;
  late ScriptsRepository scriptsRepo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('subject_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ScriptAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ClozeWordAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(PracticeSessionAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(TtsDictionaryEntryAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(AllowedPairAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(SubjectAdapter());

    await Hive.openBox<Subject>('subjects');
    await Hive.openBox<Script>('scripts');
    await Hive.openBox('app_settings');

    subjectsRepo = SubjectsRepository();
    scriptsRepo = ScriptsRepository();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SubjectsRepository Tests', () {
    test('初期状態ではデフォルト科目「一般」が自動作成されること', () {
      final list = subjectsRepo.getAll();
      expect(list.length, 1);
      expect(list.first.id, SubjectsRepository.defaultSubjectId);
      expect(list.first.name, SubjectsRepository.defaultSubjectName);

      final currentId = subjectsRepo.getCurrentSubjectId();
      expect(currentId, SubjectsRepository.defaultSubjectId);
    });

    test('新規科目の作成と名前変更、切り替えができること', () async {
      final newSubject = await subjectsRepo.add('行政書士 憲法');
      expect(newSubject.name, '行政書士 憲法');

      final list = subjectsRepo.getAll();
      expect(list.length, 2);

      // 新規作成後は自動で現在選択中になる
      expect(subjectsRepo.getCurrentSubjectId(), newSubject.id);

      // 名前変更
      newSubject.name = '行政書士 憲法（改定）';
      await subjectsRepo.update(newSubject);

      final updated = subjectsRepo.getById(newSubject.id);
      expect(updated?.name, '行政書士 憲法（改定）');

      // 切り替え
      await subjectsRepo.setCurrentSubjectId(SubjectsRepository.defaultSubjectId);
      expect(subjectsRepo.getCurrentSubjectId(), SubjectsRepository.defaultSubjectId);
    });

    test('最後の1つの科目は削除できないこと', () async {
      final success = await subjectsRepo.delete(SubjectsRepository.defaultSubjectId);
      expect(success, false);
      expect(subjectsRepo.getAll().length, 1);
    });

    test('科目を削除すると、現在選択中の科目だった場合は別科目に自動切り替えされること', () async {
      final sub2 = await subjectsRepo.add('英語');
      expect(subjectsRepo.getCurrentSubjectId(), sub2.id);

      final success = await subjectsRepo.delete(sub2.id);
      expect(success, true);
      expect(subjectsRepo.getAll().length, 1);
      expect(subjectsRepo.getCurrentSubjectId(), SubjectsRepository.defaultSubjectId);
    });
  });

  group('ScriptsRepository Subject Filter Tests', () {
    test('科目ごとにカードが分離して取得されること', () async {
      final sub1 = subjectsRepo.getAll().first;
      final sub2 = await subjectsRepo.add('英語');

      // sub1 にカード追加
      await scriptsRepo.add(
        title: '憲法第1条',
        content: '天皇は日本国の象徴であり',
        tags: ['憲法'],
        subjectId: sub1.id,
      );

      // sub2 にカード追加
      await scriptsRepo.add(
        title: 'Apple',
        content: 'Apple is a fruit',
        tags: ['英単語'],
        subjectId: sub2.id,
      );

      final sub1Scripts = scriptsRepo.getAll(subjectId: sub1.id);
      final sub2Scripts = scriptsRepo.getAll(subjectId: sub2.id);

      expect(sub1Scripts.length, 1);
      expect(sub1Scripts.first.title, '憲法第1条');

      expect(sub2Scripts.length, 1);
      expect(sub2Scripts.first.title, 'Apple');
    });

    test('指定科目のカードのみを一括削除できること', () async {
      final sub1 = subjectsRepo.getAll().first;
      final sub2 = await subjectsRepo.add('英語');

      await scriptsRepo.add(title: 'A', content: 'content A', tags: [], subjectId: sub1.id);
      await scriptsRepo.add(title: 'B', content: 'content B', tags: [], subjectId: sub2.id);

      await scriptsRepo.deleteBySubjectId(sub2.id);

      expect(scriptsRepo.getAll(subjectId: sub1.id).length, 1);
      expect(scriptsRepo.getAll(subjectId: sub2.id).length, 0);
    });

    test('subjectIdが空の既存カードが自動マイグレーションされること', () async {
      final box = Hive.box<Script>('scripts');
      final legacyScript = Script(
        id: 'legacy_1',
        title: '旧データ',
        content: '本文',
        subjectId: '', // 空
      );
      await box.put(legacyScript.id, legacyScript);

      // getAll を呼び出すと自動マイグレーションが走る
      final all = scriptsRepo.getAll();
      expect(all.first.subjectId, SubjectsRepository.defaultSubjectId);
    });
  });
}
