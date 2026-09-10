// ============================================================================
// 家族向け 予約ウィザード（付録C.3 の9画面 / C-05〜C-09 / §9 UX要件）
// UX: 一画面ひとテーマ・進捗表示・途中保存・戻っても消えない・その場でやさしく説明
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_nav.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../matching_engine.dart';
import '../ops_models.dart';
import '../ops_seed.dart';
import '../ops_state.dart';
import 'ops_ui.dart';
import 'booking_detail_screen.dart';
import 'municipality_guide_screen.dart';

/// 用件（画面1）
enum BookingPurpose { newBooking, repeat, change, cancel, waitlist, consult }

class BookingWizardScreen extends StatefulWidget {
  final BookingPurpose purpose;

  /// §7 母乳外来など、入口でプランが決まっている場合に先に選んでおく。
  final ServiceKind? presetKind;

  const BookingWizardScreen({
    super.key,
    this.purpose = BookingPurpose.newBooking,
    this.presetKind,
  });

  @override
  State<BookingWizardScreen> createState() => _BookingWizardScreenState();
}

class _BookingWizardScreenState extends State<BookingWizardScreen> {
  // 7ステップ（9画面のうち「用件選択」は入口、「予約完了」は結果画面）
  static const _titles = [
    'ご本人の確認',
    'お子さまと自治体',
    '今いちばん、してほしいこと',
    'ご利用の条件',
    '体調の確認',
    '空いている時間',
    '最終確認',
  ];

  int _step = 0;

  // --- 入力状態（戻っても消えない）---
  late OpsChild _child;
  final Set<String> _needs = {};
  ServiceDef? _service;
  String? _facilityId;
  final Map<String, dynamic> _intake = {
    'bath': false,
    'meal': false,
    'allergy': '',
    'parking': 'あり',
    'companion': false,
    'freeText': '',
    'wantHuman': false,
  };
  SlotCandidate? _slot;

  /// 要件再定義：制度利用か自費か。対象外・未申請のときに自費を選べる。
  FundingType _funding = FundingType.municipal;
  bool _agreedTerms = false;
  bool _agreedPrivacy = false;
  OpsBooking? _held;
  bool _submitting = false;

  final _allergyCtrl = TextEditingController();
  final _freeCtrl = TextEditingController();

  /// §21 「前回と同じ内容で予約」で引き継いだ計画。null なら通常の8ステップ。
  RepeatPlan? _repeat;

  @override
  void initState() {
    super.initState();
    final ops = context.read<OpsState>();
    _child = ops.customer.children.first;
    if (widget.purpose == BookingPurpose.repeat) {
      _applyRepeatPlan(ops);
    } else if (widget.presetKind != null) {
      _applyPresetKind(ops, widget.presetKind!);
    }
  }

  /// §7 入口で用件が確定しているときは、目的選択を飛ばす。
  void _applyPresetKind(OpsState ops, ServiceKind kind) {
    final hit = ops.services.where((s) => s.kind == kind).toList();
    if (hit.isEmpty) return;
    hit.sort((a, b) => a.durationMin.compareTo(b.durationMin));
    final s = hit.first;
    _service = s;
    _needs
      ..clear()
      ..addAll(s.needTags.take(1));
    _step = 3;
  }

  /// 前回内容を丸ごと引き継ぐ。家族の入力は「変わった項目」だけに絞る。
  void _applyRepeatPlan(OpsState ops) {
    final plan = ops.buildRepeatPlan();
    if (plan == null || plan.unavailable) return;

    _repeat = plan;
    _child = plan.child;
    _service = plan.service;
    _facilityId = plan.facilityId;
    _needs
      ..clear()
      ..addAll(plan.needs);
    // 前回の問診内容を引き継ぐ（キーは既存の初期値を壊さないようマージ）
    plan.intake.forEach((k, v) {
      if (_intake.containsKey(k)) _intake[k] = v;
    });
    _allergyCtrl.text = (_intake['allergy'] as String?) ?? '';
    _freeCtrl.text = '';
    // 自由記述は毎回まっさらに（前回の相談内容を引き継ぐと誤解を生む）
    _intake['freeText'] = '';
    _intake['wantHuman'] = false;

    // 引き継げた枠を候補として保持
    final at = plan.proposedAt!;
    final slot = ops.engine.buildSlot(
      service: plan.service,
      at: at,
      facilityId: plan.facilityId,
      areaCode: ops.customer.address.areaCode,
      customerId: ops.customer.id,
    );
    if (slot.bookable) _slot = slot;

    // 確認事項ゼロ かつ 枠が取れた → 最終確認へ直行（§33 3〜5分）
    _step = _repeatEntryStep;
  }

  /// リピート時の開始ステップ。差分が無ければ「空いている時間」から。
  int get _repeatEntryStep {
    final r = _repeat;
    if (r == null) return 0;
    // プラン・利用条件に確認事項があるなら、その画面から始める
    if (r.changes.any((c) => c.field == 'プラン' || c.field == '利用条件')) return 2;
    return 5;
  }

  bool get _isRepeat => _repeat != null;

  @override
  void dispose() {
    _allergyCtrl.dispose();
    _freeCtrl.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // 候補サービス（ニーズ × 月齢 × 自治体で絞り込み）
  // -------------------------------------------------------------------------
  List<ServiceDef> _candidateServices(OpsState ops) {
    final mun = ops.municipalityById(ops.customer.municipalityId);
    final age = _child.ageDays;
    return ops.services.where((s) {
      if (age < s.minChildAgeDays || age > s.maxChildAgeDays) return false;
      if (age > mun.maxChildAgeDays) return false;
      if (_needs.isEmpty) return true;
      return s.needTags.any(_needs.contains);
    }).toList()..sort((a, b) {
      final am = a.needTags.where(_needs.contains).length;
      final bm = b.needTags.where(_needs.contains).length;
      return bm.compareTo(am);
    });
  }

  bool get _canNext {
    switch (_step) {
      case 0:
        return true;
      case 1:
        return true;
      case 2:
        return _needs.isNotEmpty && _service != null;
      case 3:
        if (_service!.kind != ServiceKind.visit && _facilityId == null) {
          return false;
        }
        if (_service!.mealEligible &&
            _intake['meal'] == true &&
            (_intake['allergy'] as String).trim().isEmpty) {
          // アレルギーは「なし」も明示入力を求める（未入力のまま進めない）
          return false;
        }
        return true;
      case 4:
        return true;
      case 5:
        return _slot != null;
      case 6:
        return _agreedTerms && _agreedPrivacy && !_submitting;
      default:
        return false;
    }
  }

  void _next() {
    if (_step == 5) {
      _hold();
      return;
    }
    if (_step == 6) {
      _confirm();
      return;
    }
    setState(() => _step++);
  }

  void _back() {
    // §21 リピートは開始ステップより前に戻らない（前回内容の再入力をさせない）
    final floor = _isRepeat ? _repeatEntryStep : 0;
    if (_step <= floor) {
      Navigator.of(context).pop();
    } else {
      setState(() => _step--);
    }
  }

  // -------------------------------------------------------------------------
  // 仮おさえ → 最終確認
  // -------------------------------------------------------------------------
  void _hold() {
    final ops = context.read<OpsState>();
    _intake['allergy'] = _allergyCtrl.text;
    _intake['freeText'] = _freeCtrl.text;
    final key = 'hold_${_service!.id}_${_slot!.at.millisecondsSinceEpoch}';
    final b = ops.holdSlot(
      service: _service!,
      child: _child,
      at: _slot!.at,
      facilityId: _facilityId,
      intake: Map<String, dynamic>.from(_intake),
      needs: _needs.toList(),
      idempotencyKey: key,
      funding: _funding,
    );
    if (b == null) {
      showWarmDialog(
        context,
        icon: Icons.event_busy_rounded,
        title: 'ちょうど埋まってしまいました',
        message:
            'ほんの少しの差で、別のご家族のご予約が入りました。'
            '近い時間の候補をご用意しますので、もう一度お選びいただけますか。',
        primaryLabel: '別の時間を見る',
        onPrimary: () => setState(() => _slot = null),
      );
      return;
    }
    // §21 リピート由来を記録（KPI集計に使う）
    b.repeatOfBookingId = _repeat?.source.id;
    setState(() {
      _held = b;
      _step = 6;
    });
  }

  Future<void> _confirm() async {
    final ops = context.read<OpsState>();
    final terms = ops.terms.first;
    setState(() => _submitting = true);
    // 二重送信防止（§14 NFR-02）
    await Future<void>.delayed(const Duration(milliseconds: 620));
    if (!mounted) return;
    final ok = ops.confirmBooking(
      _held!,
      consent: ConsentSnapshot(
        termsId: terms.id,
        title: terms.title,
        version: terms.version,
        revisedAt: terms.revisedAt,
        agreedAt: DateTime.now(),
        agreedText: terms.keyPoints.join('／'),
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!ok && _held!.state == BookingState.draft) {
      showWarmDialog(
        context,
        icon: Icons.timer_off_outlined,
        title: 'おさえていた時間が解放されました',
        message:
            'お手続きの途中で少し時間が経ってしまいました。'
            'もう一度、空いている時間からお選びください。',
        primaryLabel: '時間を選び直す',
        onPrimary: () => setState(() {
          _slot = null;
          _step = 5;
        }),
      );
      return;
    }
    Navigator.of(
      context,
    ).pushReplacement(warmRoute(_BookingDoneScreen(booking: _held!)));
  }

  // -------------------------------------------------------------------------
  // build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppTopBar(
        title: 'ご予約',
        subtitle: '${_step + 1} / ${_titles.length}・${_titles[_step]}',
        background: Colors.white,
        onBack: _back,
        confirmLeave: 'ここまでの内容は保存され、いつでも続きから再開できます。',
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
            child: StepProgress(
              current: _step + 1,
              total: _titles.length,
              label: _titles[_step],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
              child: StepFade(
                key: ValueKey(_step),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isRepeat) ...[
                      _repeatBanner(),
                      const SizedBox(height: 18),
                    ],
                    _body(ops),
                  ],
                ),
              ),
            ),
          ),
          _footer(ops),
        ],
      ),
    );
  }

  Widget _body(OpsState ops) {
    return switch (_step) {
      0 => _step1Identity(ops),
      1 => _step2Child(ops),
      2 => _step3Needs(ops),
      3 => _step4Conditions(ops),
      4 => _step5Safety(ops),
      5 => _step6Slots(ops),
      _ => _step7Final(ops),
    };
  }

  // -------------------------------------------------------------------------
  // §21 「前回と同じ内容」の引き継ぎ表示 ＋ 変更項目だけの確認
  // -------------------------------------------------------------------------
  Widget _repeatBanner() {
    final r = _repeat!;
    final clean = r.changes.isEmpty;
    return SoftCard(
      color: clean ? AppColors.cardPink : const Color(0xFFFFF6E5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  clean ? Icons.replay_rounded : Icons.error_outline_rounded,
                  size: 19,
                  color: clean
                      ? AppColors.blushPinkDeep
                      : const Color(0xFFCE8A2E),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clean ? '前回と同じ内容で用意しました' : 'ここだけ、ご確認ください',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      clean
                          ? '変わったところはありません。このまま進められます。'
                          : '${r.changes.length}件だけ変わっています。ほかは前回のままです。',
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: AppColors.textBody,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Colors.white70),

          // 引き継いだ内容（読むだけ・入力不要）
          _repeatRow(Icons.child_care_outlined, 'お子さま', r.child.name),
          _repeatRow(
            Icons.spa_outlined,
            'プラン',
            '${r.service.name}・${r.service.planName}',
          ),
          if (r.proposedAt != null)
            _repeatRow(
              Icons.schedule_rounded,
              '日時',
              '${fmtDate(r.proposedAt!)} ${fmtTime(r.proposedAt!)}'
                  '${r.sameRhythm ? '（前回と同じリズム）' : ''}',
            ),

          // 変わったところだけ
          if (!clean) ...[
            const SizedBox(height: 6),
            for (final c in r.changes) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE8C98F).withValues(alpha: 0.7),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        TagChip(
                          c.field,
                          color: const Color(0xFFCE8A2E),
                          textColor: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c.action,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB0752A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      c.detail,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: AppColors.textBody,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _repeatRow(IconData icon, String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 7),
        SizedBox(
          width: 54,
          child: Text(
            k,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _footer(OpsState ops) {
    // §3/§5 ご家族への言葉は、そのサービスの予約方式で決まる。
    // 画面に文言を直書きすると、管理者が方式を変えたときに嘘になる。
    final mode = _service?.bookingMode ?? BookingMode.requestApproval;
    final needsReview = mode.needsStaffReview;

    final note = switch (_step) {
      _ when _isRepeat && _step == 5 && _slot != null =>
        '前回と同じ時間をご用意しています。別の時間も下から選べます。',
      2 => '選び直しはいつでもできます。迷ったら、いちばん近いものでどうぞ。',
      5 =>
        needsReview
            ? 'ご希望の時間をお選びください。確定はスタッフの確認後にご案内します。'
            : 'ここに出ている時間は、担当できる助産師がいる時間だけです。',
      // §5 確定しない方式で「おさえています」と書くと確定と誤解される。
      6 =>
        needsReview
            ? '送信後、スタッフが利用条件と受入状況を確認します。'
            : (_held?.holdExpiresAt == null
                  ? null
                  : 'この時間は ${fmtTime(_held!.holdExpiresAt!)} までおさえています。'),
      _ => null,
    };
    final mun = ops.municipalityById(ops.customer.municipalityId);
    final cta = mode == BookingMode.adminOnly
        ? mode.familyCta
        : familyCtaFor(
            application: ops.customer.application.status,
            scheduling: mun.scheduling,
            instant: mode == BookingMode.instant,
            selfPay:
                _funding == FundingType.selfPay ||
                (_service?.kind.programType == null),
            requiresApproval: mun.requiresApproval,
          );
    return PrimaryBar(
      label: switch (_step) {
        5 => needsReview ? 'この時間を希望する' : 'この時間でおさえる',
        // 自治体・申請状態で変わる：「自治体へ利用申請する」「利用希望を送る」
        // 「仮予約を申し込む」「この日時で予約する」
        6 => _submitting ? '手続きしています…' : cta,
        _ => 'つぎへ',
      },
      icon: _step == 6 ? Icons.check_rounded : Icons.arrow_forward_rounded,
      onTap: _canNext ? _next : null,
      secondaryLabel: _step == 0 ? null : 'もどる',
      onSecondary: _step == 0 ? null : _back,
      note: note,
    );
  }

  // -------------------------------------------------------------------------
  // 画面2：本人確認（既存顧客は登録情報を表示、初回だけ全項目）
  // -------------------------------------------------------------------------
  Widget _step1Identity(OpsState ops) {
    final c = ops.customer;
    return StaggerColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _lead(
          'こんにちは、${c.nameKanji.split(' ').first}さん',
          'LINEでご本人を確認しました。前回の情報が残っていますので、変わったところだけ直していただければ大丈夫です。',
        ),
        const SizedBox(height: 18),
        SoftCard(
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.cardPink,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      size: 21,
                      color: AppColors.blushPinkDeep,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.nameKanji,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          c.nameKana,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TagChip(
                    c.isReturning ? '2回目以降' : 'はじめて',
                    color: AppColors.cardSage,
                    textColor: const Color(0xFF6FB57E),
                  ),
                ],
              ),
              const Divider(height: 26, color: AppColors.line),
              _kv('お電話', c.maskedPhone, editable: true),
              _kv('ご住所', c.address.short, editable: true),
              _kv('緊急連絡先', c.emergencyContact, editable: true),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const InfoNote(
          icon: Icons.lock_outline_rounded,
          color: AppColors.lavender,
          title: '入力は最小限にしています',
          text:
              'すでにお預かりしている情報は、もう一度うかがいません。'
              'ご住所やお電話が変わったときだけ、直していただければ十分です。',
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // 画面3：対象児・自治体
  // -------------------------------------------------------------------------
  Widget _step2Child(OpsState ops) {
    final c = ops.customer;
    final mun = ops.municipalityById(c.municipalityId);
    final remaining = (mun.maxUseCount - c.usedCount).clamp(0, 99);
    return StaggerColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _lead('どのお子さまのことですか', 'ご登録のお子さまから選んでください。'),
        const SizedBox(height: 16),
        ...c.children.map(
          (ch) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ChoiceTile(
              title: ch.name,
              subtitle:
                  '${ch.ageLabel}・第${ch.birthOrder}子'
                  '${ch.multiple ? '・多胎' : ''}',
              icon: Icons.child_care_rounded,
              selected: _child.id == ch.id,
              onTap: () => setState(() => _child = ch),
              color: AppColors.mauve,
            ),
          ),
        ),
        const SizedBox(height: 20),
        OpsSection(
          title: 'お住まいの自治体',
          note: '自治体によって、対象になる条件・申請の流れ・料金が変わります。',
          spec: 'C-04',
        ),
        SoftCard(
          color: AppColors.cardSage,
          onTap: () => Navigator.push(
            context,
            warmRoute(const MunicipalityGuideScreen()),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.apartment_rounded,
                    size: 19,
                    color: Color(0xFF6FB57E),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      mun.name,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      mun.versionLabel,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 22, color: Colors.white),
              _kv('申請の状態', c.application.status.label),
              _kv(
                '利用券・決定通知',
                c.application.hasVoucher
                    ? (ops.voucherVerifiedForCustomer ? '確認済み' : '登録済み・スタッフ確認中')
                    : '未登録',
              ),
              _kv('のこり回数', 'あと$remaining回（全${mun.maxUseCount}回）'),
              _kv('日程の決め方', mun.scheduling.label),
              _kv('対象月齢', '生後${(mun.maxChildAgeDays / 30.4).floor()}か月まで'),
            ],
          ),
        ),
        // 要件再定義：承認前は制度利用の希望を送れない。自費を選ぶ道は残す。
        if (!c.application.status.canRequest) ...[
          const SizedBox(height: 12),
          InfoNote(
            icon: Icons.account_balance_outlined,
            color: AppColors.softYellow,
            title: c.application.status == ApplicationStatus.notEligible
                ? '自治体事業の対象外です'
                : '自治体への申請が済んでいません',
            text: c.application.status.familyHint,
          ),
        ],
        const SizedBox(height: 16),
        OpsSection(title: 'ご利用のしかた', note: '自治体事業（助成あり）か、自費かをお選びください。'),
        ChoiceTile(
          title: '自治体の産後ケア事業で利用する',
          subtitle: c.application.status.canRequest
              ? '概算は自治体の料金表から出ます'
              : '承認後に利用希望を送れます（いまは確認待ちになります）',
          icon: Icons.account_balance_rounded,
          selected: _funding == FundingType.municipal,
          onTap: () => setState(() => _funding = FundingType.municipal),
          color: AppColors.mauve,
        ),
        const SizedBox(height: 8),
        ChoiceTile(
          title: '自費で利用する',
          subtitle: mun.selfPaySwitchNote.isEmpty
              ? '自治体の条件に関係なくご利用いただけます'
              : mun.selfPaySwitchNote,
          icon: Icons.payments_outlined,
          selected: _funding == FundingType.selfPay,
          onTap: () => setState(() => _funding = FundingType.selfPay),
          color: AppColors.mauve,
        ),
        if (mun.requiredDocs.isNotEmpty &&
            _funding == FundingType.municipal) ...[
          const SizedBox(height: 12),
          InfoNote(
            icon: Icons.folder_outlined,
            color: AppColors.softYellow,
            title: '当日ご用意いただくもの',
            text: mun.requiredDocs.join('／'),
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------------------------
  // 画面4：ニーズ・サービス選択（目的から候補提示）
  // -------------------------------------------------------------------------
  Widget _step3Needs(OpsState ops) {
    final candidates = _candidateServices(ops);
    return StaggerColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _lead('今いちばん、してほしいことは', 'いくつでも選べます。うまく言葉にならなくても、近いものを選んでいただければ大丈夫です。'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: seedNeeds.map((n) {
            final on = _needs.contains(n.label);
            return Pressable(
              onTap: () => setState(() {
                on ? _needs.remove(n.label) : _needs.add(n.label);
                if (_service != null &&
                    !_candidateServices(ops).any((s) => s.id == _service!.id)) {
                  _service = null;
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                constraints: const BoxConstraints(minHeight: 46),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: on ? AppColors.blushPinkDeep : Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: on ? AppColors.blushPinkDeep : AppColors.line,
                  ),
                  boxShadow: on ? null : AppShadows.card,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      n.icon,
                      size: 16,
                      color: on ? Colors.white : AppColors.blushPinkDeep,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      n.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: on ? Colors.white : AppColors.textBody,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 26),
        if (_needs.isEmpty)
          const InfoNote(
            icon: Icons.touch_app_outlined,
            text: 'ひとつ選ぶと、ご希望に合うケアの種類だけが表示されます。',
          )
        else ...[
          OpsSection(
            title: 'ご希望に合うケア',
            note: '選ばれた内容から、${candidates.length}件が対象です。',
            spec: 'C-05',
          ),
          ...candidates.map((s) {
            final matched = s.needTags.where(_needs.contains).toList();
            final est = ops.estimateFeeFor(
              service: s,
              child: _child,
              at: DateTime.now().add(const Duration(days: 7)),
              funding: _funding,
            );
            final net = est.yen;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ChoiceTile(
                title: s.name,
                subtitle:
                    '${s.description}\n${matched.isEmpty ? '' : '▸ ${matched.join('・')} に合います'}',
                icon: s.kind.icon,
                selected: _service?.id == s.id,
                onTap: () => setState(() {
                  _service = s;
                  _facilityId = s.kind == ServiceKind.visit
                      ? null
                      : (_facilityId ?? ops.facilities.first.id);
                  _slot = null;
                  _intake['meal'] = s.mealEligible;
                }),
                color: AppColors.mauve,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      net == null ? '要確認' : '概算 ${yen(net)}',
                      style: TextStyle(
                        fontSize: net == null ? 11 : 13,
                        fontWeight: FontWeight.w900,
                        color: net == null
                            ? AppColors.textMuted
                            : AppColors.mauve,
                      ),
                    ),
                    Text(
                      est.isSelfPay ? '${s.durationLabel}・自費' : s.durationLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
          const InfoNote(
            icon: Icons.info_outline_rounded,
            color: AppColors.lavender,
            text: '表示の金額は自治体の助成をひいた見込です。確定した金額は最終確認でお知らせします。',
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------------------------
  // 画面5：予約前確認（サービス・施設・月齢・時間で条件分岐）
  // -------------------------------------------------------------------------
  Widget _step4Conditions(OpsState ops) {
    final s = _service!;
    final isVisit = s.kind == ServiceKind.visit;
    final ageOkForBath = _child.ageDays <= 120;
    return StaggerColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _lead(
          'ご利用の条件を教えてください',
          '予約に必要なことだけをうかがいます。くわしいご相談内容は、ご予約のあとでゆっくり入力いただけます。',
        ),
        const SizedBox(height: 18),
        if (isVisit) ...[
          OpsSection(title: '訪問先', note: 'ご自宅・ご実家のどちらでも承ります。', spec: 'C-06'),
          SoftCard(
            child: Column(
              children: [
                _kv('ご住所', ops.customer.address.short, editable: true),
                _kv('お部屋', ops.customer.address.room),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OpsSection(title: 'お車を停められますか', note: '助産師は車でうかがいます。'),
          Row(
            children: ['あり', '近くにあり', 'なし'].map((v) {
              final on = _intake['parking'] == v;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceTile(
                    title: v,
                    selected: on,
                    onTap: () => setState(() => _intake['parking'] = v),
                    color: AppColors.mauve,
                    trailing: const SizedBox.shrink(),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_intake['parking'] == 'なし') ...[
            const SizedBox(height: 10),
            const InfoNote(
              icon: Icons.local_parking_outlined,
              color: AppColors.softYellow,
              title: '駐車場所を一緒に考えます',
              text: '近隣の駐車場を担当が確認しますので、ご予約はそのまま進めていただけます。',
            ),
          ],
        ] else ...[
          OpsSection(title: 'ご利用の院', note: '通いやすい院をお選びください。', spec: 'C-08'),
          ...ops.facilities.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ChoiceTile(
                title: f.name,
                subtitle: f.access,
                icon: Icons.location_on_outlined,
                selected: _facilityId == f.id,
                onTap: () => setState(() {
                  _facilityId = f.id;
                  _slot = null;
                }),
                color: AppColors.mauve,
              ),
            ),
          ),
        ],
        if (s.bathEligible && ageOkForBath) ...[
          const SizedBox(height: 18),
          OpsSection(title: '沐浴', note: '生後4か月ごろまでのお子さまが対象です。'),
          _switchTile(
            '沐浴をお手伝いしてほしい',
            'やり方を一緒に確認しながら進めます。',
            Icons.bathtub_outlined,
            _intake['bath'] == true,
            (v) => setState(() => _intake['bath'] = v),
          ),
        ],
        if (s.mealEligible) ...[
          const SizedBox(height: 18),
          OpsSection(
            title: 'お食事',
            note: '${s.durationLabel}のご利用は、お食事をお付けできます。',
          ),
          _switchTile(
            'お食事をつける',
            '温かいごはんを、ゆっくり召し上がってください。',
            Icons.restaurant_outlined,
            _intake['meal'] == true,
            (v) => setState(() => _intake['meal'] = v),
          ),
          if (_intake['meal'] == true) ...[
            const SizedBox(height: 12),
            _textField(
              controller: _allergyCtrl,
              label: 'アレルギー・苦手なもの',
              hint: '例：えび、そば／とくにありません',
              helper: 'ないときも「とくにありません」とご記入ください。安全のため必ず確認しています。',
              onChanged: (v) => setState(() => _intake['allergy'] = v),
            ),
          ],
        ],
        const SizedBox(height: 20),
        InfoNote(
          icon: Icons.schedule_rounded,
          color: AppColors.cardSage,
          title: 'ご利用時間',
          text:
              '${s.name}／${s.durationLabel}'
              '${isVisit ? '（前後に移動の時間をとっています）' : ''}',
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // 画面6：相談・安全確認（赤旗判定・診断はしない）
  // -------------------------------------------------------------------------
  Widget _step5Safety(OpsState ops) {
    final flagged = seedRedFlags.where((r) => _intake[r.key] == true).toList();
    return StaggerColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _lead('気になっていることはありますか', '当てはまるものにチェックしてください。ここでの回答は、担当する助産師だけが見ます。'),
        const SizedBox(height: 16),
        ...seedRedFlags.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: ChoiceTile(
              title: r.question,
              subtitle: r.hint,
              selected: _intake[r.key] == true,
              onTap: () =>
                  setState(() => _intake[r.key] = !(_intake[r.key] == true)),
              color: const Color(0xFFD2705E),
              multi: true,
            ),
          ),
        ),
        if (flagged.isNotEmpty) ...[
          const SizedBox(height: 8),
          FadeSlideIn(
            child: InfoNote(
              icon: Icons.favorite_rounded,
              color: const Color(0xFFD2705E),
              title: 'お知らせいただき、ありがとうございます',
              text:
                  'この内容は、助産師がすぐに確認します。ご予約はそのままお進めいただけますが、'
                  '当日までに担当からご連絡することがあります。\n'
                  'なお、このアプリで診断や治療の判断は行いません。'
                  'いますぐつらいときは、下の「すぐに相談する」からお声がけください。',
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => showWarmDialog(
                context,
                icon: Icons.call_rounded,
                title: 'すぐにお話しできます',
                message:
                    'お電話（0120-000-000／24時間）と、アプリのチャット相談をご用意しています。'
                    'ひとりで抱えず、いつでも呼んでください。',
                primaryLabel: '電話をかける',
                secondaryLabel: 'とじる',
                color: const Color(0xFFD2705E),
              ),
              icon: const Icon(Icons.support_agent_rounded, size: 18),
              label: const Text('すぐに相談する'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD2705E),
                side: const BorderSide(color: Color(0xFFD2705E)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _textField(
          controller: _freeCtrl,
          label: 'そのほか、伝えておきたいこと（任意）',
          hint: 'まとまっていなくて大丈夫です。',
          helper: '長くお書きいただいた場合は、担当が読んでからご連絡します。',
          maxLines: 4,
          onChanged: (v) => setState(() => _intake['freeText'] = v),
        ),
        const SizedBox(height: 14),
        _switchTile(
          '予約の前に、人と話しておきたい',
          '担当からお電話またはメッセージでご連絡します。',
          Icons.record_voice_over_outlined,
          _intake['wantHuman'] == true,
          (v) => setState(() => _intake['wantHuman'] = v),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // 画面7：空き枠選択（割当可能な枠だけ表示）
  // -------------------------------------------------------------------------
  Widget _step6Slots(OpsState ops) {
    final s = _service!;
    final slots = ops.engine.searchSlots(
      service: s,
      from: DateTime.now().add(const Duration(days: 1)),
      days: 14,
      startMinutes: const [540, 600, 660, 780, 840, 900],
      facilityId: _facilityId,
      areaCode: ops.customer.address.areaCode,
      customerId: ops.customer.id,
    );

    // 日付ごとにまとめる
    final byDay = <DateTime, List<SlotCandidate>>{};
    for (final c in slots) {
      byDay.putIfAbsent(dayOf(c.at), () => []).add(c);
    }

    if (byDay.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 20),
          WarmEmptyState(
            icon: Icons.event_busy_rounded,
            title: 'この条件では、空いている時間がありませんでした',
            message:
                '別の日程や、ほかのケアもお選びいただけます。\n'
                '空きが出たらお知らせすることもできます。',
            action: Column(
              children: [
                SizedBox(
                  width: 240,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ops.addToWaitlist(
                        serviceId: s.id,
                        from: DateTime.now().add(const Duration(days: 1)),
                        to: DateTime.now().add(const Duration(days: 21)),
                        weekdays: const [1, 2, 3, 4, 5, 6, 7],
                      );
                      showWarmToast(
                        context,
                        '空きが出たら、いちばん早くお知らせします。',
                        icon: Icons.notifications_active_rounded,
                      );
                    },
                    icon: const Icon(
                      Icons.notifications_active_outlined,
                      size: 18,
                    ),
                    label: const Text('空き待ちに登録する'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blushPinkDeep,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _step = 2),
                  child: const Text('ほかのケアを見る'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return StaggerColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _lead(
          '空いている時間をお選びください',
          'ここに出ているのは、条件に合う助産師が対応できる時間だけです。'
              'お選びいただければ、そのまま確定できます。',
        ),
        const SizedBox(height: 8),
        InfoNote(
          icon: Icons.verified_rounded,
          color: AppColors.cardSage,
          text:
              '${slots.length}件の枠が空いています。'
              '担当のご都合が合わない時間は、はじめから表示していません。',
        ),
        const SizedBox(height: 18),
        ...byDay.entries.take(8).map((e) {
          final day = e.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      fmtDate(day),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardPink,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        relativeDay(day),
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.blushPinkDeep,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: e.value.map((c) {
                    final on = _slot?.at == c.at;
                    return Pressable(
                      onTap: () => setState(() => _slot = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        constraints: const BoxConstraints(
                          minHeight: kMinTap,
                          minWidth: 96,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: on ? AppColors.blushPinkDeep : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: on
                                ? AppColors.blushPinkDeep
                                : AppColors.line,
                          ),
                          boxShadow: on ? null : AppShadows.card,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fmtTime(c.at),
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: on ? Colors.white : AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '担当あり',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: on
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : const Color(0xFF6FB57E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // 画面8：最終確認（料金・キャンセル規定・同意）
  // -------------------------------------------------------------------------
  Widget _step7Final(OpsState ops) {
    final b = _held!;
    final s = ops.serviceById(b.serviceId);
    final policy = ops.policyById(b.cancelPolicyId!);
    final terms = ops.terms.first;
    final privacy = ops.terms[1];
    final mun = ops.municipalityById(ops.customer.municipalityId);
    final flagged = seedRedFlags.where((r) => b.intake[r.key] == true).toList();

    return StaggerColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // §5 方式によって、この画面の意味そのものが変わる。
        // 「確定します」と書いていいのは INSTANT のときだけ。
        _lead(
          '内容をご確認ください',
          s.bookingMode.familyCanConfirm
              ? 'ここで確定すると、担当が決まります。あとからの変更もできます。'
              : 'この内容で予約希望をお送りします。'
                    'スタッフが利用条件と受入状況を確認したうえで、予約確定をご案内します。',
        ),
        const SizedBox(height: 16),
        // §5/§47 確定型でないことを、送信前に必ず一度言う。
        if (s.bookingMode.needsStaffReview) ...[
          InfoNote(
            icon: Icons.pending_actions_outlined,
            color: AppColors.cardLavender,
            title: 'この時点では予約は確定しません',
            text: !b.isSelfPay && mun.scheduling.waitsForMunicipality
                ? '${mun.name}は行政調整型です。利用希望を受け付けたあと、'
                      '市と施設が日程を調整し、市からご連絡があります。'
                : '${s.name}は、お子さまの月齢・多胎のご様子・訪問場所・'
                      '自治体の利用条件・受入状況をスタッフが確認してから確定します。\n'
                      '確認が終わりましたら、アプリからご案内します。',
          ),
          const SizedBox(height: 14),
        ],
        // 確定型でないなら「おさえています」は言わない（誤解のもと）。
        if (b.holdExpiresAt != null && s.bookingMode.familyCanConfirm)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.softYellow.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                BreathingGlow(
                  color: const Color(0xFFC9A227),
                  child: const Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: Color(0xFFC9A227),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'この時間は ${fmtTime(b.holdExpiresAt!)} までおさえています。'
                    'ゆっくりご確認ください。',
                    style: const TextStyle(
                      fontSize: 11.8,
                      color: AppColors.textBody,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.cardPink,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      s.kind.icon,
                      size: 20,
                      color: AppColors.blushPinkDeep,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          fmtDateTime(b.at),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StateBadge(b.state),
                ],
              ),
              const Divider(height: 24, color: AppColors.line),
              _kv('ご利用時間', fmtRange(b.at, b.durationMin)),
              _kv(
                b.kind == ServiceKind.visit ? '訪問先' : 'ご利用の院',
                b.kind == ServiceKind.visit
                    ? ops.customer.address.short
                    : (ops.facilityById(b.facilityId)?.name ?? '—'),
              ),
              _kv('担当', ops.staffById(b.staffId)?.name ?? '確認中'),
              _kv('お子さま', '${_child.name}（${_child.ageLabel}）'),
              if (_needs.isNotEmpty) _kv('ご希望', _needs.join('・')),
              if (b.intake['bath'] == true) _kv('沐浴', 'お手伝いします'),
              if (b.intake['meal'] == true)
                _kv(
                  'お食事',
                  'あり（${(b.intake['allergy'] as String).trim().isEmpty ? '—' : b.intake['allergy']}）',
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OpsSection(title: 'お支払いの概算', spec: 'C-09'),
        SoftCard(
          color: AppColors.cardCream,
          child: Column(
            children: [
              _kv('ご利用のしかた', b.funding.label),
              _kv('根拠', b.feeBasis.isEmpty ? '${s.name} 定価' : b.feeBasis),
              if (!b.isSelfPay)
                _kv(
                  '自治体マスタ',
                  '${mun.name} v${b.municipalityProgramVersion ?? mun.version}',
                ),
              if (b.useIndex != null && !b.isSelfPay)
                _kv('利用回数', '${b.useIndex}回目として概算'),
              const Divider(height: 20, color: Colors.white),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'ご負担の概算',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  FeeChip(yen: b.feeYen, state: b.feeState),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                b.feeState == FeeState.underReview
                    ? 'この条件に当たる料金の取り決めが見つからないため、スタッフが確認します。'
                    : '概算です。最終金額は利用券・自治体の決定・スタッフ確認後に確定します。'
                          '当日のご様子でケアの内容が変わることもあります。',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OpsSection(
          title: 'キャンセルについて',
          note: '${policy.versionLabel}（このご予約に適用される版を保存します）',
          spec: 'C.5',
        ),
        SoftCard(
          child: Column(
            children: [
              ...policy.tiers.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        t.feeYen == 0
                            ? Icons.check_circle_outline_rounded
                            : Icons.info_outline_rounded,
                        size: 15,
                        color: t.feeYen == 0
                            ? const Color(0xFF6FB57E)
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textBody,
                          ),
                        ),
                      ),
                      Text(
                        t.feeYen == 0 ? '無料' : yen(t.feeYen),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: t.feeYen == 0
                              ? const Color(0xFF6FB57E)
                              : AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 18, color: AppColors.line),
              const Text(
                'ご体調やお子さまの急な発熱など、やむを得ないご事情のときはご相談ください。'
                '状況にあわせて減免を検討します。',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textBody,
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),
        if (flagged.isNotEmpty) ...[
          const SizedBox(height: 14),
          InfoNote(
            icon: Icons.medical_information_outlined,
            color: const Color(0xFFD2705E),
            title: '助産師が確認します',
            text:
                '${flagged.map((f) => f.question).join('／')}\n'
                'この内容は担当の助産師に届きます。ご予約は進めていただけます。',
          ),
        ],
        const SizedBox(height: 18),
        OpsSection(title: 'ご同意のお願い', spec: 'C-07'),
        _consentTile(
          terms,
          _agreedTerms,
          (v) => setState(() => _agreedTerms = v),
        ),
        const SizedBox(height: 10),
        _consentTile(
          privacy,
          _agreedPrivacy,
          (v) => setState(() => _agreedPrivacy = v),
        ),
        const SizedBox(height: 14),
        const InfoNote(
          icon: Icons.history_edu_outlined,
          color: AppColors.lavender,
          title: '同意した内容は、このご予約に保存します',
          text:
              'あとから規約が変わっても、今回のご予約の条件は変わりません。'
              'いつでも予約詳細からご確認いただけます。',
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // パーツ
  // -------------------------------------------------------------------------

  Widget _lead(String title, String body) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        body,
        style: const TextStyle(
          fontSize: 12.5,
          color: AppColors.textBody,
          height: 1.75,
        ),
      ),
    ],
  );

  Widget _kv(String k, String v, {bool editable = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            k,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              height: 1.5,
            ),
          ),
        ),
        if (editable)
          Pressable(
            onTap: () => showWarmToast(
              context,
              '変更いただけます。反映は次のご予約からです。',
              icon: Icons.edit_rounded,
            ),
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(
                '直す',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blushPinkDeep,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _switchTile(
    String title,
    String sub,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) => Container(
    constraints: const BoxConstraints(minHeight: kMinTap + 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: value ? AppColors.mauve : AppColors.line),
      boxShadow: AppShadows.card,
    ),
    child: Row(
      children: [
        Icon(icon, size: 19, color: AppColors.mauve),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.mauve,
        ),
      ],
    ),
  );

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? helper,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      const SizedBox(height: 7),
      TextField(
        controller: controller,
        maxLines: maxLines,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13.5, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textMuted,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.blushPinkDeep),
          ),
        ),
      ),
      if (helper != null) ...[
        const SizedBox(height: 6),
        Text(
          helper,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
            height: 1.55,
          ),
        ),
      ],
    ],
  );

  Widget _consentTile(TermsDoc doc, bool value, ValueChanged<bool> onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: value ? const Color(0xFF6FB57E) : AppColors.line,
          width: value ? 1.6 : 1,
        ),
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  doc.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Text(
                doc.versionLabel,
                style: const TextStyle(
                  fontSize: 9.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...doc.keyPoints
              .take(3)
              .map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Icon(
                          Icons.circle,
                          size: 4,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textBody,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 4),
          Pressable(
            onTap: () => _showFullText(doc),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 15,
                    color: AppColors.blushPinkDeep,
                  ),
                  SizedBox(width: 6),
                  Text(
                    '全文を読む',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blushPinkDeep,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 16, color: AppColors.line),
          Pressable(
            onTap: () => onChanged(!value),
            child: Container(
              constraints: const BoxConstraints(minHeight: kMinTap),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Icon(
                    value
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 24,
                    color: value
                        ? const Color(0xFF6FB57E)
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '内容を確認し、同意します',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: value ? AppColors.textDark : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullText(TermsDoc doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            doc.versionLabel,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.line),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    doc.fullText,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textBody,
                      height: 1.9,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ふわりと切り替わるステップ本体
class StepFade extends StatelessWidget {
  final Widget child;
  const StepFade({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      FadeSlideIn(offsetY: 14, duration: AppMotion.normal, child: child);
}

// ---------------------------------------------------------------------------
// 画面9：予約完了
// ---------------------------------------------------------------------------
class _BookingDoneScreen extends StatefulWidget {
  final OpsBooking booking;
  const _BookingDoneScreen({required this.booking});

  @override
  State<_BookingDoneScreen> createState() => _BookingDoneScreenState();
}

class _BookingDoneScreenState extends State<_BookingDoneScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.booking.state == BookingState.confirmed) {
        Celebration.show(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final b = widget.booking;
    final s = ops.serviceById(b.serviceId);
    final confirmed = b.state == BookingState.confirmed;
    // §6/§47 予約希望と予約確定は、色・言葉・記号のすべてで区別する。
    // 状態の言い換えは BookingState 側に集約してある（画面ごとに書かない）。
    final requested =
        b.state == BookingState.requested ||
        b.state == BookingState.municipalCoordination;
    final viaMunicipality = b.state == BookingState.municipalCoordination;
    final munName = ops.programOfBooking(b).name;
    final accentColor = confirmed
        ? const Color(0xFF6FB57E)
        : requested
        ? const Color(0xFF6E93C4) // 確認待ちは「注意」ではなく「お預かり」の色
        : const Color(0xFFC98A1E);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 36, 20, 24),
                child: StaggerColumn(
                  children: [
                    FloatingBob(
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(alpha: 0.15),
                        ),
                        child: Icon(
                          b.state.familyIcon,
                          size: 44,
                          color: accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      // §5 REQUEST_APPROVAL で「確定しました」と書いては絶対にいけない。
                      confirmed
                          ? 'ご予約が確定しました'
                          : viaMunicipality
                          ? '利用希望を受け付けました'
                          : requested
                          ? '仮予約のお申し込みを受け付けました'
                          : 'お申し込みをお預かりしました',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      confirmed
                          ? 'やり取りなしで、担当までお決まりです。\n当日は無理をせず、そのままの状態でお迎えください。'
                          : viaMunicipality
                          ? '$munNameと施設が日程を調整し、\n市からご連絡があります。\n'
                                'MAMOAでは、この時点で予約は確定していません。'
                          : requested
                          ? 'スタッフが利用条件・利用券・受入状況を確認したうえで、\n'
                                '仮予約をご案内します。仮予約が届いたら、\n'
                                'ホーム画面の「予約を確定する」で確定できます。'
                          : 'ご入力の内容を、助産師が確認しています。\nこちらからご連絡しますので、どうぞお待ちください。',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textBody,
                        height: 1.85,
                      ),
                    ),
                    if (!confirmed) ...[
                      const SizedBox(height: 18),
                      // §47 「まだ確定ではない」ことを、色に頼らず文字で言い切る。
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: accentColor,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'この時点では、まだ予約は確定していません',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    SoftCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '予約番号',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      b.code,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              StateBadge(b.state),
                            ],
                          ),
                          const Divider(height: 24, color: AppColors.line),
                          _row('ケア', s.name),
                          _row('日時', fmtDateTime(b.at)),
                          _row('時間', fmtRange(b.at, b.durationMin)),
                          _row(
                            b.kind == ServiceKind.visit ? '訪問先' : '院',
                            b.kind == ServiceKind.visit
                                ? ops.customer.address.short
                                : (ops.facilityById(b.facilityId)?.name ?? '—'),
                          ),
                          _row(
                            '担当',
                            // §5 確定前に担当者名を出すと「決まった」と読まれる。
                            confirmed
                                ? (ops.staffById(b.staffId)?.name ?? '確認中')
                                : '確認中',
                          ),
                          if (b.state.familyHint.isNotEmpty) ...[
                            const Divider(height: 20, color: AppColors.line),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  b.state.familyIcon,
                                  size: 15,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    b.state.familyHint,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      height: 1.55,
                                      color: AppColors.textBody,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (requested) ...[
                      const InfoNote(
                        icon: Icons.pending_actions_outlined,
                        color: AppColors.cardLavender,
                        title: 'これからの流れ',
                        text:
                            '① スタッフが利用条件と受入状況を確認します\n'
                            '② 日程を調整し、予約確定をご案内します\n'
                            '③ 確定後に、事前の問診をご入力いただけます',
                      ),
                      const SizedBox(height: 12),
                    ],
                    const InfoNote(
                      icon: Icons.checkroom_outlined,
                      color: AppColors.cardSage,
                      title: '当日ご用意いただくもの',
                      text:
                          '母子健康手帳／お子さまの着替え／授乳用のもの。\n'
                          'お忘れでも、こちらでご用意できるものがあります。',
                    ),
                    const SizedBox(height: 12),
                    const InfoNote(
                      icon: Icons.edit_calendar_outlined,
                      color: AppColors.lavender,
                      title: '変更・お取消しもアプリから',
                      text:
                          'お電話や、やり取りは必要ありません。'
                          '2日前17時までなら、無料で変更いただけます。',
                    ),
                  ],
                ),
              ),
            ),
            PrimaryBar(
              label: 'メニューにもどる',
              icon: Icons.grid_view_rounded,
              onTap: () => goHome(context),
              secondaryLabel: '詳細を見る',
              onSecondary: () => Navigator.of(
                context,
              ).push(warmRoute(BookingDetailScreen(bookingId: b.id))),
              note: confirmed ? '詳しいご相談内容は、あとからゆっくり入力いただけます。' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 62,
          child: Text(
            k,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}
