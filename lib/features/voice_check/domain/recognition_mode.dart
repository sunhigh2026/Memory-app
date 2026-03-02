enum RecognitionMode {
  /// 即時中断モード - 無音検出で自動停止
  immediate,
  /// 全文暗唱後採点モード - ユーザーが手動で停止するまで蓄積
  fullRecitation,
}
