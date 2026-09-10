import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/facility.dart';
import '../services/app_state.dart';
import '../services/care_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/app_nav.dart';

/// 助産師モード：予約管理・問診確認・SOAPカルテ・報酬計算・請求書
class MidwifeScreen extends StatefulWidget {
  const MidwifeScreen({super.key});

  @override
  State<MidwifeScreen> createState() => _MidwifeScreenState();
}

class _MidwifeScreenState extends State<MidwifeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('助産師モード'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.mauve,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.mauve,
          indicatorWeight: 2.6,
          labelStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: '今日の予約'),
            Tab(text: '問診票'),
            Tab(text: 'カルテ'),
            Tab(text: '報酬・請求'),
          ],
        ),
        actions: const [HomeButton(), SizedBox(width: 8)],
      ),
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _tab,
          children: const [
            _ScheduleTab(),
            _IntakeTab(),
            _RecordTab(),
            _RevenueTab(),
          ],
        ),
      ),
    );
  }
}

// ==================== 予約管理 ====================
class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab();

  @override
  Widget build(BuildContext context) {
    final care = context.watch<CareState>();
    final state = context.watch<AppState>();
    final upcoming = care.upcomingBookings;
    final pending = upcoming.where((b) => b.status == '調整中').toList();
    final esc = care.escalations.where((e) => e.status != '完了').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        _kpiRow(care),
        const SizedBox(height: 18),
        if (esc.isNotEmpty) ...[
          const SectionTitle('AIからのエスカレーション', subtitle: '優先的に確認が必要なご相談です'),
          const SizedBox(height: 12),
          for (final e in esc) ...[
            _escTile(context, e, state.motherName),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
        ],
        if (pending.isNotEmpty) ...[
          const SectionTitle('承認待ち（訪問ケア）', subtitle: '移動時間を確認して確定します'),
          const SizedBox(height: 12),
          for (final b in pending) ...[
            _pendingTile(context, b, state.motherName),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
        ],
        const SectionTitle('これからの予約'),
        const SizedBox(height: 12),
        if (upcoming.isEmpty)
          _emptyBox('予約はまだありません')
        else
          for (final b in upcoming) ...[
            _bookingTile(context, b, state.motherName),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardSage,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: const [
              Icon(
                Icons.calendar_month_outlined,
                size: 19,
                color: Color(0xFF6FB57E),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Googleカレンダー・LINE WORKS と連携すると、施設のスケジュールに自動反映され、二重入力がなくなります。',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textBody,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kpiRow(CareState care) {
    return Row(
      children: [
        Expanded(
          child: _kpi(
            '今月の件数',
            '${care.monthlyCases}',
            '件',
            AppColors.cardPink,
            AppColors.blushPinkDeep,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _kpi(
            '今月の報酬',
            '¥${_man(care.monthlyRevenue)}',
            '',
            AppColors.cardSage,
            const Color(0xFF6FB57E),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _kpi(
            '未対応相談',
            '${care.escalations.where((e) => e.status != '完了').length}',
            '件',
            AppColors.cardCream,
            AppColors.mauve,
          ),
        ),
      ],
    );
  }

  Widget _kpi(String label, String value, String unit, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            '$value$unit',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _escTile(BuildContext context, Escalation e, String motherName) {
    final high = e.severity == 'high';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: high ? const Color(0xFFFDEBEE) : AppColors.cardCream,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: high ? const Color(0xFFE07C93) : AppColors.mauve,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  high ? '優先' : '通常',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$motherName さん',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                DateFormat('M/d HH:mm').format(e.time),
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            e.reason,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            e.detail,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textBody,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              _smallBtn('対応中にする', () {
                context.read<CareState>().updateEscalation(e.id, '対応中');
              }),
              const SizedBox(width: 8),
              _smallBtn('完了', () {
                context.read<CareState>().updateEscalation(e.id, '完了');
              }, primary: true),
              const Spacer(),
              Text(
                e.status,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallBtn(String label, VoidCallback onTap, {bool primary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: primary ? AppColors.mauve : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primary ? AppColors.mauve : AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: primary ? Colors.white : AppColors.textBody,
          ),
        ),
      ),
    );
  }

  Widget _pendingTile(BuildContext context, Booking b, String motherName) {
    final df = DateFormat('M月d日(E) HH:mm', 'ja');
    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: b.kind.color.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(b.kind.icon, size: 19, color: AppColors.mauve),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$motherName さん・${b.kind.label}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      df.format(b.dateTime),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const TagChip(
                '調整中',
                color: AppColors.cardCream,
                textColor: AppColors.mauve,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: () =>
                        context.read<CareState>().cancelBooking(b.id),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'お断りする',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () =>
                        context.read<CareState>().approveBooking(b.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mauve,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'この日程で確定',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bookingTile(BuildContext context, Booking b, String motherName) {
    final df = DateFormat('M月d日(E) HH:mm', 'ja');
    return SoftCard(
      color: Colors.white,
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _SoapSheet(booking: b, motherName: motherName),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: b.kind.color.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(b.kind.icon, size: 20, color: AppColors.mauve),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$motherName さん',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${df.format(b.dateTime)}・${b.kind.label}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TagChip(
                b.intakeDone ? '問診済' : '問診未',
                color: b.intakeDone ? AppColors.cardSage : AppColors.cardCream,
                textColor: b.intakeDone
                    ? const Color(0xFF6FB57E)
                    : AppColors.mauve,
              ),
              const SizedBox(height: 5),
              const Text(
                'カルテを書く',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.blushPinkDeep,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _emptyBox(String msg) => Container(
    padding: const EdgeInsets.all(20),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Text(
      msg,
      style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
    ),
  );

  static String _man(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
}

// ==================== 問診票確認 ====================
class _IntakeTab extends StatelessWidget {
  const _IntakeTab();

  @override
  Widget build(BuildContext context) {
    final care = context.watch<CareState>();
    final state = context.watch<AppState>();
    final list = care.intakes;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        const Text(
          '母親が提出した問診票を、ケアの前に確認できます。EPDS 9点以上は自動でフラグが立ちます。',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textBody,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 18),
        if (list.isEmpty)
          _ScheduleTab._emptyBox('提出された問診票はまだありません')
        else
          for (final f in list) ...[
            _intakeCard(context, f, state.motherName),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _intakeCard(BuildContext context, IntakeForm f, String motherName) {
    final flagged = (f.epdsScore ?? 0) >= 9;
    return SoftCard(
      color: Colors.white,
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _IntakeDetailSheet(form: f, motherName: motherName),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: flagged ? const Color(0xFFFDEBEE) : AppColors.cardPink,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  f.kind.icon,
                  size: 19,
                  color: flagged
                      ? const Color(0xFFE07C93)
                      : AppColors.blushPinkDeep,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$motherName さん・${f.kind.label}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('M月d日 HH:mm 提出', 'ja').format(f.submittedAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (f.epdsScore != null)
                TagChip(
                  'EPDS ${f.epdsScore}',
                  color: flagged ? const Color(0xFFFDEBEE) : AppColors.cardSage,
                  textColor: flagged
                      ? const Color(0xFFE07C93)
                      : const Color(0xFF6FB57E),
                ),
            ],
          ),
          if (flagged) ...[
            const SizedBox(height: 11),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFFDEBEE),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.flag_rounded,
                    size: 16,
                    color: Color(0xFFE07C93),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      CareState.epdsJudgement(f.epdsScore!),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textBody,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                f.signed ? Icons.verified_rounded : Icons.pending_outlined,
                size: 14,
                color: f.signed ? const Color(0xFF6FB57E) : AppColors.textMuted,
              ),
              const SizedBox(width: 5),
              Text(
                f.signed ? '電子同意 取得済み' : '電子同意 未取得',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              Text(
                '${f.answers.length}項目の回答',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IntakeDetailSheet extends StatelessWidget {
  final IntakeForm form;
  final String motherName;
  const _IntakeDetailSheet({required this.form, required this.motherName});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${form.kind.label}｜$motherName さん',
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('yyyy年M月d日 HH:mm 提出', 'ja').format(form.submittedAt),
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: form.answers.entries
                  .map(
                    (e) => Container(
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.key,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            e.value,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== カルテ ====================
class _RecordTab extends StatelessWidget {
  const _RecordTab();

  @override
  Widget build(BuildContext context) {
    final care = context.watch<CareState>();
    final list = care.careRecords;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        const Text(
          '産後ケア特化のSOAPテンプレートで記録します。母乳ケア所見の欄に、乳房の状態や搾乳量を残せます。',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textBody,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) =>
                  _SoapSheet(motherName: context.read<AppState>().motherName),
            ),
            icon: const Icon(Icons.edit_note_rounded, size: 20),
            label: const Text(
              '新しいカルテを作成',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mauve,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const SectionTitle('カルテ一覧'),
        const SizedBox(height: 12),
        if (list.isEmpty)
          _ScheduleTab._emptyBox('カルテはまだありません')
        else
          for (final r in list) ...[_recordCard(r), const SizedBox(height: 12)],
      ],
    );
  }

  Widget _recordCard(CareRecord r) {
    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: r.kind.color.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(r.kind.icon, size: 18, color: AppColors.mauve),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.motherName} さん・${r.kind.label}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${DateFormat('yyyy年M月d日', 'ja').format(r.date)}｜${r.recorder}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _soap('S', '主観的情報', r.subjective, AppColors.cardPink),
          _soap('O', '客観的情報', r.objective, AppColors.cardLavender),
          _soap('A', 'アセスメント', r.assessment, AppColors.cardCream),
          _soap('P', 'ケア計画', r.plan, AppColors.cardSage),
          if (r.breastNote != null && r.breastNote!.isNotEmpty)
            _soap('B', '母乳ケア所見', r.breastNote!, const Color(0xFFFDF0F4)),
        ],
      ),
    );
  }

  Widget _soap(String tag, String label, String body, Color bg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(
              tag,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.mauve,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.65,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoapSheet extends StatefulWidget {
  final Booking? booking;
  final String motherName;
  const _SoapSheet({this.booking, required this.motherName});

  @override
  State<_SoapSheet> createState() => _SoapSheetState();
}

class _SoapSheetState extends State<_SoapSheet> {
  final _s = TextEditingController();
  final _o = TextEditingController();
  final _a = TextEditingController();
  final _p = TextEditingController();
  final _b = TextEditingController();
  late PlanKind _kind = widget.booking?.kind ?? PlanKind.breastClinic;

  @override
  void dispose() {
    _s.dispose();
    _o.dispose();
    _a.dispose();
    _p.dispose();
    _b.dispose();
    super.dispose();
  }

  /// AIカルテ支援：問診票とアプリの記録から下書きを生成
  void _aiDraft() {
    final care = context.read<CareState>();
    final v = care.latestVital;
    final intake = care.intakes.isEmpty ? null : care.intakes.first;
    final bc = care.breastChecks.isEmpty ? null : care.breastChecks.first;

    _s.text = intake != null
        ? '問診票より：${intake.answers.entries.take(3).map((e) => '${e.key}=${e.value}').join('、')}。'
              '${bc != null ? '乳房の自覚症状：${bc.symptoms.join('・')}（痛み${bc.painLevel}/5）。' : ''}'
        : '主訴：夜間授乳による疲労感。授乳時の痛み。';
    _o.text = v != null
        ? '体温${v.temperature?.toStringAsFixed(1) ?? '－'}℃、血圧${v.systolic ?? '－'}/${v.diastolic ?? '－'}mmHg、心拍${v.pulse ?? '－'}bpm。'
              '本日の授乳${care.todayFeedCount}回／${care.todayFeedMinutes}分、搾乳${care.todayPumpMl}ml。'
        : '一般状態良好。';
    _a.text = bc?.risk == 'high'
        ? '乳腺炎への移行リスクあり。早期の乳房ケアと授乳姿勢の修正が必要。'
        : '産後の疲労蓄積。授乳手技はおおむね良好。継続的な休息確保が課題。';
    _p.text =
        '授乳姿勢（脇抱き）を指導。授乳前の温罨法・授乳後の冷却を説明。'
        '通所ケアで休息時間の確保を提案。1週間後に経過確認。'
        '38℃以上の発熱・硬結の悪化時は当日受診を案内。';
    _b.text = bc != null
        ? '乳房所見：${bc.symptoms.join('・')}。痛み${bc.painLevel}/5。搾乳量 本日計${care.todayPumpMl}ml。'
        : '乳房所見：硬結なし。乳頭に亀裂なし。';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'カルテ作成｜${widget.motherName} さん',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _aiDraft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.blushPinkDeep, AppColors.lavender],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                      SizedBox(width: 5),
                      Text(
                        'AI下書き',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: PlanKind.values.map((k) {
                    final sel = _kind == k;
                    return GestureDetector(
                      onTap: () => setState(() => _kind = k),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.mauve : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: sel ? AppColors.mauve : AppColors.line,
                          ),
                        ),
                        child: Text(
                          k.label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : AppColors.textBody,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                _field('S', '主観的情報（ご本人の訴え）', _s),
                _field('O', '客観的情報（観察・測定）', _o),
                _field('A', 'アセスメント', _a),
                _field('P', 'ケア計画', _p),
                _field('B', '母乳ケア所見（任意）', _b),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _s.text.trim().isEmpty
                  ? null
                  : () {
                      context.read<CareState>().createCareRecord(
                        motherName: widget.motherName,
                        facilityName:
                            widget.booking?.facilityName ?? 'ママズケア 助産院',
                        kind: _kind,
                        subjective: _s.text.trim(),
                        objective: _o.text.trim(),
                        assessment: _a.text.trim(),
                        plan: _p.text.trim(),
                        breastNote: _b.text.trim().isEmpty
                            ? null
                            : _b.text.trim(),
                        recorder: '助産師 南田 みなみ',
                      );
                      Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mauve,
                disabledBackgroundColor: AppColors.line,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                'カルテを保存して母親に共有',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String tag, String label, TextEditingController c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.cardPink,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.blushPinkDeep,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textBody,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: c,
            minLines: 2,
            maxLines: 6,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 12.5, height: 1.6),
            decoration: const InputDecoration(
              hintText: '入力してください',
              hintStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 報酬・請求 ====================
class _RevenueTab extends StatelessWidget {
  const _RevenueTab();

  @override
  Widget build(BuildContext context) {
    final care = context.watch<CareState>();
    final counts = care.monthlyCaseCount;
    final month = DateFormat('yyyy年M月', 'ja').format(DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        SoftCard(
          color: Colors.white,
          shadow: AppShadows.soft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$month の報酬（自動計算）',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '¥${_comma(care.monthlyRevenue)}',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blushPinkDeep,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '/ ${care.monthlyCases}件',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: AppColors.line),
              for (final e in counts.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    children: [
                      Icon(e.key.icon, size: 15, color: AppColors.mauve),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.key.label,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '¥${_comma(CareState.municipalUnitPrice[e.key] ?? 0)} × ${e.value}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '¥${_comma((CareState.municipalUnitPrice[e.key] ?? 0) * e.value)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionTitle('請求書', subtitle: '自治体・自費ごとにPDFを自動生成します'),
        const SizedBox(height: 12),
        for (final inv in care.invoices) ...[
          _invoiceTile(context, inv),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardLavender,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: const [
              Icon(
                Icons.account_balance_outlined,
                size: 19,
                color: AppColors.lavender,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '自治体の産後ケア事業の利用申請・回数管理・実績報告をデジタル化します。将来的にPMH（電子母子手帳）連携にも対応予定です。',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textBody,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _invoiceTile(BuildContext context, Invoice inv) {
    final (color, bg) = switch (inv.status) {
      '入金済' => (const Color(0xFF6FB57E), AppColors.cardSage),
      '請求済' => (AppColors.mauve, AppColors.cardCream),
      _ => (AppColors.blushPinkDeep, AppColors.cardPink),
    };
    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inv.payer,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${inv.month.replaceAll('-', '年')}月分・${inv.cases}件',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '¥${_comma(inv.amount)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TagChip(inv.status, color: bg, textColor: color),
                ],
              ),
            ],
          ),
          if (inv.status == '未請求') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.read<CareState>().updateInvoice(inv.id, '請求済');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('請求書PDFを生成し、メール送信しました')),
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                label: const Text(
                  '請求書PDFを生成して送信',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mauve,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _comma(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
}
