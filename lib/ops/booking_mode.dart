// ============================================================================
// §3 Booking Mode ― 「条件を満たしたあと、どう振る舞うか」
//
// ママズケアのスタッフから、産後ケアの予約には
//
//   児の月齢／双子・多胎／訪問場所／自治体利用条件／施設受入状況／スタッフ配置
//
// の確認が要るため、全利用者が即時確定する運用は難しい、という指摘があった。
// これは仕様として正式に取り込む（§2）。
//
// ここで大事なのは「判定をやめる」ことではない。判定はこれまで通り行い、
// その結果を **自動確定に使うか、人の判断材料に使うか** を切り替える（§7）。
// そうしておけば、条件の精度が上がった Service だけを後から INSTANT へ
// 移せる。コード修正は要らない（§0 設定変更のたびにコード修正を必要としない）。
//
// このファイルは Pure Function だけを置く（§28）。
// Flutter も State も UI も import しない。
// ============================================================================

/// Service / ServicePlan ごとの予約成立のしかた（§3）。
///
/// コードに固定せず、管理画面から変更する（§43）。
enum BookingMode {
  /// 条件を満たせば利用者自身で即時確定。
  /// 想定：母乳外来、将来自動化できた標準産後ケア。
  instant,

  /// 利用者は「予約希望」を送る。スタッフ確認後に確定。
  /// 初期段階の産後ケアは原則これ（§4）。
  requestApproval,

  /// 利用者自身では確定できず、スタッフが登録する。
  /// 特殊ケース・完全手動運用向け。
  adminOnly,
}

extension BookingModeX on BookingMode {
  /// 永続化・監査ログ用の安定した文字列（enum の順番に依存させない）。
  String get code => switch (this) {
    BookingMode.instant => 'INSTANT',
    BookingMode.requestApproval => 'REQUEST_APPROVAL',
    BookingMode.adminOnly => 'ADMIN_ONLY',
  };

  static BookingMode fromCode(String code) => switch (code) {
    'INSTANT' => BookingMode.instant,
    'REQUEST_APPROVAL' => BookingMode.requestApproval,
    'ADMIN_ONLY' => BookingMode.adminOnly,
    _ => BookingMode.requestApproval, // 不明値は安全側（人が見る）へ倒す
  };

  /// 管理者向けの名前。運用の意味が分かる言葉にする。
  String get adminLabel => switch (this) {
    BookingMode.instant => 'そのまま予約確定',
    BookingMode.requestApproval => '予約希望 → スタッフ確認',
    BookingMode.adminOnly => 'スタッフが登録',
  };

  String get adminDescription => switch (this) {
    BookingMode.instant => '条件を満たしていれば、ご家族の操作だけで確定します。母乳外来などに向きます。',
    BookingMode.requestApproval =>
      'ご家族は「予約希望」を送ります。判定結果を見てスタッフが確定します。産後ケアの初期運用はこちらです。',
    BookingMode.adminOnly => 'ご家族の画面からは確定できません。特殊なご事情のある方の手動運用に使います。',
  };

  /// §5 ご家族に見せるボタン文言。
  ///
  /// 「予約する」と書いてしまうと確定したと誤解される。ここは絶対に混ぜない。
  String get familyCta => switch (this) {
    BookingMode.instant => 'この日時で予約する',
    BookingMode.requestApproval => 'この内容で申し込む',
    BookingMode.adminOnly => '相談を申し込む',
  };

  /// §5 送信後にご家族へ出す説明。
  String get familyAfterSubmit => switch (this) {
    BookingMode.instant => 'ご予約が確定しました。当日お待ちしています。',
    BookingMode.requestApproval =>
      '予約希望を受け付けました。\nスタッフが利用条件と受入状況を確認後、予約確定をご案内します。',
    BookingMode.adminOnly => 'ご相談を受け付けました。担当者から日程のご相談のご連絡をします。',
  };

  /// ご家族が自分の操作で確定させられるか。
  bool get familyCanConfirm => this == BookingMode.instant;

  /// スタッフの確認を必ず通すか。
  bool get needsStaffReview => this != BookingMode.instant;
}

/// 予約の行き先（§45 最終動作は bookingMode で変える）。
enum BookingOutcome {
  /// 条件を満たし、そのまま確定してよい。
  confirm,

  /// 条件は満たすが、スタッフの確認を通す（予約希望として受け付ける）。
  request,

  /// 条件に不明・不足があるので、確認が必要。
  review,

  /// ご家族の操作では成立させない。
  staffOnly,
}

/// 判定結果と bookingMode から、予約の行き先を決める（§45）。
///
/// 引数はプリミティブだけにしてある。Booking や Engine を持ち込むと
/// この関数が業務ロジックの置き場になってしまい、テストしづらくなる。
///
/// * [mode]        Service に設定された予約モード
/// * [conditionsOk] ルールエンジンが「割当可能」と判断したか
/// * [hasUnknowns]  要確認（月齢・多胎・自治体回数など）が残っているか
BookingOutcome resolveOutcome({
  required BookingMode mode,
  required bool conditionsOk,
  required bool hasUnknowns,
}) {
  // ADMIN_ONLY は条件に関係なく、ご家族の操作では成立させない。
  if (mode == BookingMode.adminOnly) return BookingOutcome.staffOnly;

  // 要確認が残っているなら、モードに関係なく人が見る。
  // ここを「INSTANT だから確定」にしてしまうと、
  // 自動化が現場の判断を飛び越える（§0）。
  if (hasUnknowns || !conditionsOk) return BookingOutcome.review;

  return mode.familyCanConfirm
      ? BookingOutcome.confirm
      : BookingOutcome.request;
}
