/// §37-42 スタッフ権限の付与モデル
///
/// スタッフからの指摘はこうだった。
/// «利用者が誤って「助産師」を選ぶことでスタッフ画面へ入れてはいけない。
///   これはセキュリティ上の要件です。»
///
/// 従来のこのアプリは、入口で立場を選んだらそのまま助産師画面に入れた。
/// デモとしては便利だったが、実運用では他のご家族の氏名・住所・
/// 問診内容・カルテが見えてしまう。取り返しがつかない種類の事故なので、
/// 「自己申告では絶対に付与されない」という形に作り替える。
///
/// 設計方針:
///   - 立場（希望）と 権限（実際に見えるもの）を別の概念として分ける
///   - 権限が付くのは «招待コード» か «管理者承認» を通ったときだけ
///   - 申請中（PENDING）は、ご家族としての画面しか見えない
///   - いつでも「利用者として戻る」ができる（§40。永久確定しない）
///
/// このファイルは Flutter に依存しない。UI から切り離しておくことで、
/// 画面を作り替えても権限判定が一緒に壊れることを防ぐ（§42）。
library;

/// 権限の種類。「立場」ではなく「見てよい範囲」を表す。
enum StaffRoleKind { midwife, admin }

extension StaffRoleKindX on StaffRoleKind {
  String get code => this == StaffRoleKind.midwife ? 'MIDWIFE' : 'ADMIN';

  String get label => this == StaffRoleKind.midwife ? '助産師' : '管理者';
}

/// 権限申請の状態（§39）。
enum StaffAccessStatus {
  /// 申請していない（＝ご家族としてのみ利用できる）
  none,

  /// 申請済み・管理者の承認待ち
  pending,

  /// 承認済み。スタッフ画面を見てよい
  approved,

  /// 却下。理由を添えて戻す
  rejected,

  /// いったん付与したが取り消した（退職・異動など）
  revoked,
}

extension StaffAccessStatusX on StaffAccessStatus {
  String get code => switch (this) {
    StaffAccessStatus.none => 'NONE',
    StaffAccessStatus.pending => 'PENDING',
    StaffAccessStatus.approved => 'APPROVED',
    StaffAccessStatus.rejected => 'REJECTED',
    StaffAccessStatus.revoked => 'REVOKED',
  };

  String get label => switch (this) {
    StaffAccessStatus.none => '未申請',
    StaffAccessStatus.pending => '承認待ち',
    StaffAccessStatus.approved => '承認済み',
    StaffAccessStatus.rejected => '承認されませんでした',
    StaffAccessStatus.revoked => '権限を取り消し済み',
  };

  /// この状態でスタッフ画面を開いてよいか。
  ///
  /// approved 以外はすべて false。判定を1か所にしておかないと、
  /// 画面が増えたときに «ここだけ抜けていた» が起きる。
  bool get grantsAccess => this == StaffAccessStatus.approved;
}

/// §38 招待コード。管理者が発行し、スタッフ本人が入力する。
///
/// «招待» を実体として持たせる理由は、あとから
/// «誰がいつ誰を招いたのか» を必ず答えられるようにするため。
/// 権限が増える操作は、必ず出どころを残す。
class StaffInvitation {
  final String id;

  /// 入力してもらうコード。表示のしかたは UI 側の責務。
  final String code;

  /// このコードで付与される権限。
  final StaffRoleKind grants;

  /// 発行者（監査用）。
  final String issuedBy;
  final DateTime issuedAt;

  /// 期限。過ぎたコードは通さない。
  final DateTime? expiresAt;

  /// 使える回数。個人宛なら 1。研修で一斉に配るなら複数。
  final int maxUses;
  int uses;

  /// 招待した相手の想定名（照合用のメモ。必須ではない）
  final String? invitedName;

  /// 発行後に取り消した場合。
  bool revoked;

  StaffInvitation({
    required this.id,
    required this.code,
    required this.grants,
    required this.issuedBy,
    required this.issuedAt,
    this.expiresAt,
    this.maxUses = 1,
    this.uses = 0,
    this.invitedName,
    this.revoked = false,
  });

  bool get expired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get exhausted => uses >= maxUses;

  /// 今このコードを使えるか。
  bool get usable => !revoked && !expired && !exhausted;

  /// 使えない理由。ご本人に見せる言葉で返す。
  ///
  /// «無効なコードです» だけだと、入力ミスなのか期限切れなのか
  /// 分からず、結局スタッフに電話することになる。それでは意味がない。
  String? get unusableReason {
    if (revoked) return 'この招待コードは取り消されています。管理者にご確認ください。';
    if (expired) return 'この招待コードは有効期限が切れています。管理者に再発行をご依頼ください。';
    if (exhausted) return 'この招待コードは、すでに使用されています。';
    return null;
  }
}

/// §38/§41 権限の付与記録。1人につき1件を最新状態として持つ。
class StaffAccessGrant {
  final String id;

  /// 誰に対する権限か。デモでは端末利用者を表す固定IDでよい。
  final String subjectId;

  /// 本人が申告した名前（照合用）。
  String subjectName;

  /// 希望している権限。
  StaffRoleKind requested;

  StaffAccessStatus status;

  /// 招待コード経由なら、その招待ID。管理者承認なら null。
  String? invitationId;

  /// 対応する助産師マスタのID（承認時に紐づける）。
  String? staffId;

  /// 申請理由・却下理由など。
  String? note;

  final DateTime requestedAt;
  DateTime? decidedAt;
  String? decidedBy;

  StaffAccessGrant({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.requested,
    this.status = StaffAccessStatus.pending,
    this.invitationId,
    this.staffId,
    this.note,
    required this.requestedAt,
    this.decidedAt,
    this.decidedBy,
  });

  bool get grantsAccess => status.grantsAccess;
}

/// 申請を受け付けたときの結果。
///
/// «通った/通らない» の二値ではなく «承認待ちになった» を
/// 独立した結果として持つ。ここを二値にすると、
/// 待ち状態のご本人に何を表示すべきか決められなくなる。
enum StaffAccessOutcome {
  /// 即時に権限が付いた（有効な招待コード）
  granted,

  /// 申請を受け付けた。管理者の承認待ち
  pending,

  /// 受け付けられなかった（コード不正・期限切れなど）
  rejected,
}

/// 申請の判定結果と、ご本人に見せる言葉。
class StaffAccessDecision {
  final StaffAccessOutcome outcome;
  final String message;
  final StaffRoleKind? granted;
  final String? invitationId;

  const StaffAccessDecision({
    required this.outcome,
    required this.message,
    this.granted,
    this.invitationId,
  });

  bool get isGranted => outcome == StaffAccessOutcome.granted;
}

/// §38/§39 招待コードを判定する純粋関数。
///
/// 状態を持たないので、テストで全分岐を固定できる。
/// コードが空（＝コードを持っていない）場合は、拒否ではなく
/// «管理者承認の申請» に回す。現場では «先に働き始めて、
/// コードは後からもらう» が普通に起きるので、道を閉じない（§39）。
StaffAccessDecision evaluateStaffAccess({
  required String enteredCode,
  required StaffRoleKind requested,
  required List<StaffInvitation> invitations,
}) {
  final code = enteredCode.trim();

  if (code.isEmpty) {
    return const StaffAccessDecision(
      outcome: StaffAccessOutcome.pending,
      message:
          'スタッフとしてのご利用には、招待または管理者の承認が必要です。\n'
          '承認の申請をお預かりしました。管理者が確認しますので、'
          'それまでは利用者としてお使いいただけます。',
    );
  }

  // 大文字小文字・全角半角の差で弾かない。入力させる以上は寄せる。
  final normalized = _normalize(code);
  final hit = invitations.where((i) => _normalize(i.code) == normalized);

  if (hit.isEmpty) {
    return const StaffAccessDecision(
      outcome: StaffAccessOutcome.rejected,
      message:
          'この招待コードは確認できませんでした。\n'
          'お手元のコードをもう一度ご確認いただくか、管理者の承認申請をお選びください。',
    );
  }

  final inv = hit.first;
  if (!inv.usable) {
    return StaffAccessDecision(
      outcome: StaffAccessOutcome.rejected,
      message: inv.unusableReason!,
    );
  }

  // 招待は «付与される権限» を持っている。本人の希望より招待が優先。
  // 助産師として招いた人が、自己申告で管理者になれてはいけない。
  if (inv.grants != requested) {
    return StaffAccessDecision(
      outcome: StaffAccessOutcome.rejected,
      message:
          'この招待コードは「${inv.grants.label}」としての招待です。\n'
          '「${requested.label}」としてのご利用をご希望の場合は、管理者にご相談ください。',
      granted: inv.grants,
      invitationId: inv.id,
    );
  }

  return StaffAccessDecision(
    outcome: StaffAccessOutcome.granted,
    message: '${inv.grants.label}としてのご利用を確認しました。',
    granted: inv.grants,
    invitationId: inv.id,
  );
}

/// §42 «この権限で、この画面を見てよいか» を判定する唯一の関数。
///
/// 画面側に if を散らさない。散らすと必ずどこかが抜ける。
///
/// [grant] が null は «申請すらしていない» 状態。
bool canAccessStaffArea(StaffAccessGrant? grant, StaffRoleKind area) {
  if (grant == null) return false;
  if (!grant.grantsAccess) return false;
  // 助産師権限で管理者画面は見られない。管理者は助産師画面も見てよい
  // （現場で助産師の予定を確認しないと調整できないため）。
  if (area == StaffRoleKind.midwife) return true;
  return grant.requested == StaffRoleKind.admin;
}

String _normalize(String s) {
  final buf = StringBuffer();
  for (final r in s.trim().toUpperCase().runes) {
    // 全角英数を半角に寄せる
    if (r >= 0xFF21 && r <= 0xFF3A) {
      buf.writeCharCode(r - 0xFF21 + 0x41);
    } else if (r >= 0xFF10 && r <= 0xFF19) {
      buf.writeCharCode(r - 0xFF10 + 0x30);
    } else if (r == 0x20 || r == 0x3000 || r == 0x2D) {
      // 空白とハイフンは無視（"MW-2026-01" と "mw202601" を同じ扱いに）
      continue;
    } else {
      buf.writeCharCode(r);
    }
  }
  return buf.toString();
}
