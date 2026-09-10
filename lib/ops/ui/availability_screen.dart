import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_nav.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../ops_models.dart';
import '../ops_state.dart';
import 'ops_ui.dart';

/// M-07 OK／NG時間入力（§6.2 / 付録C.8）
///
/// 「カレンダー上で時間帯をタップ／ドラッグして『OK』『NG』を切り替えられる。
///  毎週の基本パターンを登録し、特定日の追加OK／NGで上書きできる。
///  前週コピー、一括登録、終日NG、複数時間帯登録を提供し、
///  スマートフォンで短時間に更新できるようにする。
///  管理者には予約調整に必要な可否だけを共有し、NG理由や私的予定の内容は表示しない。」
class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

/// 塗るモード
enum _PaintMode { ok, ng, erase }

extension _PaintModeX on _PaintMode {
  String get label => switch (this) {
    _PaintMode.ok => 'OK（受けられる）',
    _PaintMode.ng => 'NG（受けられない）',
    _PaintMode.erase => '消す',
  };
  String get shortLabel => switch (this) {
    _PaintMode.ok => 'OK',
    _PaintMode.ng => 'NG',
    _PaintMode.erase => '消す',
  };
  Color get color => switch (this) {
    _PaintMode.ok => const Color(0xFF6FB57E),
    _PaintMode.ng => const Color(0xFFE08A8A),
    _PaintMode.erase => AppColors.warmGray,
  };
  IconData get icon => switch (this) {
    _PaintMode.ok => Icons.check_circle_outline_rounded,
    _PaintMode.ng => Icons.do_not_disturb_on_outlined,
    _PaintMode.erase => Icons.cleaning_services_outlined,
  };
}

/// 30分刻みのグリッド。1日=48スロットだが、表示は 6:00〜22:00（32スロット）に絞る。
const int _slotMin = 30;
const int _gridStartMin = 6 * 60;
const int _gridEndMin = 22 * 60;
const int _slotCount = (_gridEndMin - _gridStartMin) ~/ _slotMin; // 32

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  late DateTime _weekStart;
  _PaintMode _mode = _PaintMode.ok;

  /// 編集中の週のスロット状態。key = 'yyyy-mm-dd', value = 48スロット中の表示分
  final Map<String, List<AvailKind?>> _draft = {};

  /// ドラッグ中の情報
  bool _dragging = false;
  String? _dragDayKey;
  int? _dragAnchor;
  int? _dragCurrent;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = dayOf(now).subtract(Duration(days: now.weekday - 1));
  }

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<DateTime> get _days =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  // ---------------------------------------------------------------------------
  // 実効状態 → ドラフト読み込み
  // ---------------------------------------------------------------------------
  void _loadDraft(OpsState ops) {
    _draft.clear();
    for (final d in _days) {
      _draft[_key(d)] = _slotsFor(ops, d);
    }
  }

  List<AvailKind?> _slotsFor(OpsState ops, DateTime day) {
    final out = List<AvailKind?>.filled(_slotCount, null);
    final ranges = ops.effectiveAvailability(ops.currentStaffId, day);
    // OKを先に塗り、NGで上書き（NG > OK）
    for (final r in ranges.where((r) => r.kind == AvailKind.ok)) {
      _fill(out, r.startMin, r.endMin, AvailKind.ok);
    }
    for (final r in ranges.where((r) => r.kind == AvailKind.ng)) {
      _fill(out, r.startMin, r.endMin, AvailKind.ng);
    }
    return out;
  }

  void _fill(
    List<AvailKind?> slots,
    int startMin,
    int endMin,
    AvailKind? kind,
  ) {
    final from = ((startMin - _gridStartMin) / _slotMin).floor();
    final to = ((endMin - _gridStartMin) / _slotMin).ceil();
    for (var i = from; i < to; i++) {
      if (i >= 0 && i < _slotCount) slots[i] = kind;
    }
  }

  List<AvailKind?> _slotsWithDragPreview(String dayKey) {
    final base = List<AvailKind?>.from(_draft[dayKey] ?? []);
    if (!_dragging || _dragDayKey != dayKey) return base;
    final a = _dragAnchor!;
    final b = _dragCurrent!;
    final lo = (a < b ? a : b).clamp(0, base.length - 1);
    final hi = (a < b ? b : a).clamp(0, base.length - 1);

    if (_mode == _PaintMode.erase) {
      for (var i = lo; i <= hi; i++) {
        base[i] = null;
      }
      return base;
    }

    // 指を離したときの結果（塗る／取り消す）を、なぞっている間に見せる。
    final want = _mode == _PaintMode.ok ? AvailKind.ok : AvailKind.ng;
    var allSame = true;
    for (var i = lo; i <= hi; i++) {
      if (base[i] != want) {
        allSame = false;
        break;
      }
    }
    for (var i = lo; i <= hi; i++) {
      base[i] = allSame ? null : want;
    }
    return base;
  }

  // ---------------------------------------------------------------------------
  // 保存
  // ---------------------------------------------------------------------------
  void _commitDay(OpsState ops, String dayKey, DateTime day) {
    final slots = _draft[dayKey]!;
    final ranges = <StaffAvailability>[];
    var i = 0;
    while (i < slots.length) {
      final kind = slots[i];
      if (kind == null) {
        i++;
        continue;
      }
      var j = i;
      while (j + 1 < slots.length && slots[j + 1] == kind) {
        j++;
      }
      ranges.add(
        StaffAvailability(
          id: 'tmp',
          staffId: ops.currentStaffId,
          date: day,
          startMin: _gridStartMin + i * _slotMin,
          endMin: _gridStartMin + (j + 1) * _slotMin,
          kind: kind,
          updatedAt: DateTime.now(),
        ),
      );
      i = j + 1;
    }
    ops.replaceDay(staffId: ops.currentStaffId, date: day, ranges: ranges);
  }

  void _saveAll(OpsState ops) {
    for (final d in _days) {
      _commitDay(ops, _key(d), d);
    }
    setState(() => _dirty = false);
    showWarmToast(
      context,
      'この週の可否を保存しました',
      icon: Icons.check_rounded,
      color: const Color(0xFF6FB57E),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    if (_draft.isEmpty) _loadDraft(ops);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppTopBar(
        title: 'OK／NG時間',
        subtitle: '登録した時間だけに、予約が入ります',
        actions: [
          IconButton(
            tooltip: '基本パターン',
            icon: const Icon(Icons.repeat_rounded, color: AppColors.mauve),
            onPressed: () => _openWeeklyPattern(ops),
          ),
          IconButton(
            tooltip: 'まとめて登録',
            icon: const Icon(
              Icons.dashboard_customize_outlined,
              color: AppColors.mauve,
            ),
            onPressed: () => _openBulk(ops),
          ),
        ],
      ),
      body: Column(
        children: [
          _weekBar(ops),
          _modeBar(),
          _undoBar(),
          Expanded(child: _grid(ops)),
        ],
      ),
      bottomNavigationBar: PrimaryBar(
        label: _dirty ? 'この週を保存する' : '保存済み',
        icon: _dirty ? Icons.save_rounded : Icons.check_rounded,
        onTap: _dirty ? () => _saveAll(ops) : null,
        secondaryLabel: '前週をコピー',
        onSecondary: () => _copyPrev(ops),
        note:
            'NGを取り消すには、①「NG」のままNGの上をなぞる（もう一度で取り消し）②「消す」を選んでなぞる ③日付をタップして「NGだけを取り消す」。どれでも消せます。',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 週ナビ
  // ---------------------------------------------------------------------------
  Widget _weekBar(OpsState ops) {
    final end = _weekStart.add(const Duration(days: 6));
    final okMin = _days.fold<int>(
      0,
      (s, d) =>
          s +
          (_draft[_key(d)] ?? []).where((k) => k == AvailKind.ok).length *
              _slotMin,
    );
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          _navBtn(Icons.chevron_left_rounded, () => _shiftWeek(ops, -7)),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${_weekStart.month}/${_weekStart.day} 〜 ${end.month}/${end.day}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '受けられる時間 合計 ${(okMin / 60).toStringAsFixed(1)}時間',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          _navBtn(Icons.chevron_right_rounded, () => _shiftWeek(ops, 7)),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) => Pressable(
    onTap: onTap,
    radius: BorderRadius.circular(24),
    child: Container(
      width: kMinTap,
      height: kMinTap,
      alignment: Alignment.center,
      child: Icon(icon, color: AppColors.mauve, size: 26),
    ),
  );

  void _shiftWeek(OpsState ops, int days) {
    if (_dirty) {
      showWarmDialog(
        context,
        icon: Icons.save_outlined,
        title: '保存していない変更があります',
        message: 'この週の変更を保存してから移動しますか。',
        color: AppColors.softYellow,
        primaryLabel: '保存して移動',
        onPrimary: () {
          _saveAll(ops);
          setState(() {
            _weekStart = _weekStart.add(Duration(days: days));
            _draft.clear();
          });
        },
        secondaryLabel: '保存せず移動',
        onSecondary: () => setState(() {
          _weekStart = _weekStart.add(Duration(days: days));
          _dirty = false;
          _draft.clear();
        }),
      );
      return;
    }
    setState(() {
      _weekStart = _weekStart.add(Duration(days: days));
      _draft.clear();
    });
  }

  // ---------------------------------------------------------------------------
  // モード切替
  // ---------------------------------------------------------------------------
  Widget _modeBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          for (final m in _PaintMode.values) ...[
            Expanded(
              child: Semantics(
                selected: _mode == m,
                button: true,
                label: '${m.label}を塗るモード',
                child: Pressable(
                  onTap: () => setState(() => _mode = m),
                  radius: BorderRadius.circular(AppRadius.md),
                  child: AnimatedContainer(
                    duration: AppMotion.quick,
                    curve: AppMotion.gentle,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _mode == m
                          ? m.color.withValues(alpha: 0.16)
                          : AppColors.cream,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: _mode == m ? m.color : AppColors.line,
                        width: _mode == m ? 1.6 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          m.icon,
                          size: 17,
                          color: _mode == m ? m.color : AppColors.textMuted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          m.shortLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _mode == m ? m.color : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (m != _PaintMode.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  /// NGは「いつでも取り消せる」ことを、画面上に常に見える形で保証する導線。
  /// 塗り操作が分からなくなっても、ここから必ず元に戻せる。
  Widget _undoBar() {
    final ngSlots = _days.fold<int>(
      0,
      (s, d) =>
          s + (_draft[_key(d)] ?? []).where((k) => k == AvailKind.ng).length,
    );
    final hasNg = ngSlots > 0;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          Icon(
            hasNg
                ? Icons.do_not_disturb_on_outlined
                : Icons.check_circle_outline_rounded,
            size: 15,
            color: hasNg ? const Color(0xFFD97A7A) : AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              hasNg
                  ? 'この週のNG ${(ngSlots * _slotMin / 60).toStringAsFixed(1)}時間'
                  : 'この週にNGはありません',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'この週のNGをすべて取り消す',
            child: Pressable(
              radius: BorderRadius.circular(30),
              onTap: hasNg ? _clearWeekNg : null,
              child: Opacity(
                opacity: hasNg ? 1 : 0.4,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 34),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.cardPink,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xFFD97A7A).withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.undo_rounded,
                        size: 15,
                        color: Color(0xFFD97A7A),
                      ),
                      SizedBox(width: 5),
                      Text(
                        'NGを取り消す',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD97A7A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 週まるごとのNGを取り消す（OKはそのまま残す）。
  void _clearWeekNg() {
    showWarmDialog(
      context,
      icon: Icons.undo_rounded,
      title: 'この週のNGを取り消しますか',
      message: '受けられない時間の登録だけを消します。OKの時間はそのまま残ります。',
      color: const Color(0xFFE08A8A),
      primaryLabel: '取り消す',
      onPrimary: () {
        setState(() {
          for (final d in _days) {
            final s = _draft[_key(d)];
            if (s == null) continue;
            for (var i = 0; i < s.length; i++) {
              if (s[i] == AvailKind.ng) s[i] = null;
            }
          }
          _dirty = true;
        });
        showWarmToast(
          context,
          'NGを取り消しました。「この週を保存する」で確定します',
          icon: Icons.undo_rounded,
          color: AppColors.lavender,
        );
      },
      secondaryLabel: 'やめる',
    );
  }

  // ---------------------------------------------------------------------------
  // グリッド本体（タップ／ドラッグ塗り）
  // ---------------------------------------------------------------------------
  Widget _grid(OpsState ops) {
    const timeColW = 44.0;
    return LayoutBuilder(
      builder: (context, box) {
        final dayW = (box.maxWidth - timeColW) / 7;
        const rowH = 26.0;
        return SingleChildScrollView(
          // なぞっている間はスクロールを止める（塗り・消しを取りこぼさない）
          physics: _dragging ? const NeverScrollableScrollPhysics() : null,
          child: Column(
            children: [
              // ヘッダ
              Container(
                color: AppColors.surface,
                child: Row(
                  children: [
                    const SizedBox(width: timeColW),
                    for (final d in _days)
                      SizedBox(width: dayW, child: _dayHeader(ops, d, dayW)),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.line),
              // 時間×曜日
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 時刻列
                    SizedBox(
                      width: timeColW,
                      child: Column(
                        children: [
                          for (var i = 0; i < _slotCount; i++)
                            SizedBox(
                              height: rowH,
                              child: (i % 2 == 0)
                                  ? Align(
                                      alignment: Alignment.topRight,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 6,
                                          top: 1,
                                        ),
                                        child: Text(
                                          hhmm(_gridStartMin + i * _slotMin),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    ),
                    // 日ごとの列
                    for (final d in _days) _dayColumn(ops, d, dayW, rowH),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dayHeader(OpsState ops, DateTime d, double w) {
    final isToday = dayOf(d) == dayOf(DateTime.now());
    final isPast = dayOf(d).isBefore(dayOf(DateTime.now()));
    final load = ops.loadMinutes(ops.currentStaffId, d);
    final cap = ops.currentStaff.dailyMaxMin;
    final overridden = ops.isDayOverridden(ops.currentStaffId, d);
    return Pressable(
      onTap: isPast ? null : () => _dayMenu(ops, d),
      radius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isToday ? AppColors.cardPink : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: AppColors.line.withValues(alpha: 0.6),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          children: [
            Text(
              weekdayLabel(d.weekday),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: d.weekday == 7
                    ? const Color(0xFFE08A8A)
                    : d.weekday == 6
                    ? const Color(0xFF8AA9E0)
                    : AppColors.textMuted,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${d.day}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isPast ? AppColors.textMuted : AppColors.textDark,
                  ),
                ),
                // 個別設定の日（毎週パターンを適用していない）目印
                if (overridden && !isPast) ...[
                  const SizedBox(width: 2),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.lavender,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            if (load > 0)
              Container(
                width: w * 0.6,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (load / cap).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: load > cap
                          ? const Color(0xFFE08A8A)
                          : AppColors.blushPinkDeep,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 3),
          ],
        ),
      ),
    );
  }

  Widget _dayColumn(OpsState ops, DateTime d, double w, double rowH) {
    final key = _key(d);
    final isPast = dayOf(d).isBefore(dayOf(DateTime.now()));
    final slots = _slotsWithDragPreview(key);
    final bookings = ops.bookings
        .where(
          (b) =>
              b.staffId == ops.currentStaffId &&
              dayOf(b.at) == dayOf(d) &&
              b.state.isActive,
        )
        .toList();

    int idxFromY(double y) => (y / rowH).floor().clamp(0, _slotCount - 1);

    // ジェスチャの取り合い（gesture arena）に参加しない Listener を使う。
    //
    // GestureDetector だと、外側の縦スクロールや親のジェスチャに
    // 「なぞる」「タップ」を奪われることがあり、
    // その結果「NGの斜線を押しても消えない」状態が起きていた。
    // Listener は生のポインタイベントを必ず受け取るため、
    // 一度入れたNGを確実に消せる／塗り替えられる。
    return SizedBox(
      width: w,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: isPast
            ? null
            : (ev) {
                final i = idxFromY(ev.localPosition.dy);
                setState(() {
                  _dragging = true;
                  _dragDayKey = key;
                  _dragAnchor = i;
                  _dragCurrent = i;
                });
              },
        onPointerMove: isPast
            ? null
            : (ev) {
                if (!_dragging || _dragDayKey != key) return;
                final i = idxFromY(ev.localPosition.dy);
                if (i != _dragCurrent) setState(() => _dragCurrent = i);
              },
        onPointerUp: isPast
            ? null
            : (_) {
                if (!_dragging || _dragDayKey != key) return;
                final a = _dragAnchor!;
                final b = _dragCurrent!;
                setState(() {
                  _dragging = false;
                  _dragDayKey = null;
                });
                _applyRange(key, a < b ? a : b, a < b ? b : a);
              },
        onPointerCancel: isPast
            ? null
            : (_) {
                if (!_dragging || _dragDayKey != key) return;
                final a = _dragAnchor!;
                final b = _dragCurrent!;
                setState(() {
                  _dragging = false;
                  _dragDayKey = null;
                });
                _applyRange(key, a < b ? a : b, a < b ? b : a);
              },
        child: Stack(
          children: [
            Column(
              children: [
                for (var i = 0; i < _slotCount; i++)
                  _cell(slots[i], rowH, i, isPast),
              ],
            ),
            // 確定予約のオーバーレイ（塗り替え不可の可視化）
            for (final b in bookings) _bookingOverlay(ops, b, w, rowH),
          ],
        ),
      ),
    );
  }

  Widget _cell(AvailKind? kind, double rowH, int i, bool isPast) {
    final hourLine = i % 2 == 0;
    Color bg;
    if (isPast) {
      bg = AppColors.cream.withValues(alpha: 0.5);
    } else if (kind == AvailKind.ok) {
      bg = const Color(0xFF6FB57E).withValues(alpha: 0.22);
    } else if (kind == AvailKind.ng) {
      bg = const Color(0xFFE08A8A).withValues(alpha: 0.26);
    } else {
      bg = Colors.white;
    }
    return Container(
      height: rowH,
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(
            color: hourLine
                ? AppColors.line
                : AppColors.line.withValues(alpha: 0.4),
            width: hourLine ? 0.8 : 0.4,
          ),
          left: BorderSide(
            color: AppColors.line.withValues(alpha: 0.6),
            width: 0.5,
          ),
        ),
      ),
      child: kind == AvailKind.ng
          ? CustomPaint(painter: _HatchPainter())
          : null,
    );
  }

  Widget _bookingOverlay(OpsState ops, OpsBooking b, double w, double rowH) {
    final startIdx = (minOfDay(b.at) - _gridStartMin) / _slotMin;
    final spanIdx = b.durationMin / _slotMin;
    if (startIdx + spanIdx <= 0 || startIdx >= _slotCount) {
      return const SizedBox.shrink();
    }
    final top = startIdx.clamp(0, _slotCount.toDouble()) * rowH;
    final height =
        (spanIdx.clamp(0.5, _slotCount - startIdx)).toDouble() * rowH;
    return Positioned(
      top: top,
      left: 2,
      width: w - 4,
      height: height,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.blushPinkDeep.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.all(3),
          child: Text(
            ops.serviceById(b.serviceId).name.characters.take(6).toString(),
            style: const TextStyle(
              fontSize: 8.5,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 3,
            overflow: TextOverflow.clip,
          ),
        ),
      ),
    );
  }

  /// なぞり／タップの結果を反映する。
  ///
  /// 【重要】NGは「入れた操作」でそのまま「取り消せる」ようにする。
  /// 以前は、なぞった範囲を常に上書きしていたため、
  /// NGモードでNGの上をなぞっても NG のまま＝消せない状態だった。
  /// ここでは、なぞった範囲がすでに全部そのモードの色なら「消す」に反転させる。
  /// （タップ1コマでも、長いなぞりでも、同じ直感で動く）
  void _applyRange(String key, int from, int to) {
    setState(() {
      final slots = _draft[key]!;
      final lo = from.clamp(0, slots.length - 1);
      final hi = to.clamp(0, slots.length - 1);

      if (_mode == _PaintMode.erase) {
        for (var i = lo; i <= hi; i++) {
          slots[i] = null;
        }
        _dirty = true;
        return;
      }

      final want = _mode == _PaintMode.ok ? AvailKind.ok : AvailKind.ng;

      // なぞった範囲がすでにすべて「そのモードの色」なら、取り消し（トグル）。
      var allSame = true;
      for (var i = lo; i <= hi; i++) {
        if (slots[i] != want) {
          allSame = false;
          break;
        }
      }

      for (var i = lo; i <= hi; i++) {
        slots[i] = allSame ? null : want;
      }
      _dirty = true;
    });
  }

  // ---------------------------------------------------------------------------
  // 日ごとのメニュー（終日NG／終日OK／消す）
  // ---------------------------------------------------------------------------
  void _dayMenu(OpsState ops, DateTime d) {
    final key = _key(d);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${d.month}月${d.day}日（${weekdayLabel(d.weekday)}）',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'この日をまとめて設定できます。',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            ChoiceTile(
              title: '終日NG（お休み）',
              subtitle: '一日ぜんぶ、予約が入らないようにします',
              icon: Icons.do_not_disturb_on_outlined,
              color: const Color(0xFFE08A8A),
              selected: false,
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _draft[key] = List<AvailKind?>.filled(
                    _slotCount,
                    AvailKind.ng,
                  );
                  _dirty = true;
                });
              },
            ),
            const SizedBox(height: 8),
            ChoiceTile(
              title: '9:00〜17:00をOKにする',
              subtitle: 'よく使う時間帯をすぐに登録します',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF6FB57E),
              selected: false,
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  final s = List<AvailKind?>.filled(_slotCount, null);
                  _fill(s, 9 * 60, 17 * 60, AvailKind.ok);
                  _draft[key] = s;
                  _dirty = true;
                });
              },
            ),
            const SizedBox(height: 8),
            ChoiceTile(
              title: 'NGだけを取り消す',
              subtitle: '受けられない時間の登録を消します（OKはそのまま）',
              icon: Icons.do_not_disturb_off_outlined,
              color: const Color(0xFFE08A8A),
              selected: false,
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  final s = _draft[key]!;
                  for (var i = 0; i < s.length; i++) {
                    if (s[i] == AvailKind.ng) s[i] = null;
                  }
                  _dirty = true;
                });
                showWarmToast(
                  context,
                  'NGを取り消しました。「保存する」で確定します',
                  icon: Icons.undo_rounded,
                  color: AppColors.lavender,
                );
              },
            ),
            const SizedBox(height: 8),
            ChoiceTile(
              title: 'この日の登録を消す',
              subtitle: '空欄の時間は予約が入りません',
              icon: Icons.cleaning_services_outlined,
              color: AppColors.warmGray,
              selected: false,
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _draft[key] = List<AvailKind?>.filled(_slotCount, null);
                  _dirty = true;
                });
              },
            ),
            if (ops.isDayOverridden(ops.currentStaffId, d)) ...[
              const SizedBox(height: 8),
              ChoiceTile(
                title: '毎週の基本パターンに戻す',
                subtitle: 'この日だけの個別設定をやめます',
                icon: Icons.repeat_rounded,
                color: AppColors.lavender,
                selected: false,
                onTap: () {
                  Navigator.pop(context);
                  _restorePattern(ops, d);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// その日の個別設定を解除して、毎週の基本パターンに戻す。
  void _restorePattern(OpsState ops, DateTime d) {
    ops.restoreWeeklyPatternFor(staffId: ops.currentStaffId, date: d);
    setState(() {
      _draft.clear();
      _dirty = false;
    });
    showWarmToast(
      context,
      '${d.month}/${d.day} を基本パターンに戻しました',
      icon: Icons.repeat_rounded,
      color: AppColors.lavender,
    );
  }

  void _copyPrev(OpsState ops) {
    if (_dirty) _saveAll(ops);
    final n = ops.copyPreviousWeek(
      staffId: ops.currentStaffId,
      weekStart: _weekStart,
    );
    setState(() => _draft.clear());
    showWarmToast(
      context,
      n > 0 ? '前の週から$n件コピーしました' : '前の週に登録がありませんでした',
      icon: n > 0 ? Icons.content_copy_rounded : Icons.info_outline_rounded,
      color: n > 0 ? const Color(0xFF6FB57E) : AppColors.softYellow,
    );
  }

  // ---------------------------------------------------------------------------
  // 毎週の基本パターン
  // ---------------------------------------------------------------------------
  void _openWeeklyPattern(OpsState ops) {
    Navigator.push(
      context,
      warmRoute(const _WeeklyPatternScreen()),
    ).then((_) => setState(() => _draft.clear()));
  }

  // ---------------------------------------------------------------------------
  // 一括登録
  // ---------------------------------------------------------------------------
  void _openBulk(OpsState ops) {
    final selected = <DateTime>{};
    var start = 9 * 60;
    var end = 17 * 60;
    var kind = AvailKind.ok;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'まとめて登録',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '日にちを選んで、同じ時間帯を一度に登録します。',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '日にち（今週から4週間）',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBody,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < 28; i++)
                        _bulkDayChip(
                          _weekStart.add(Duration(days: i)),
                          selected,
                          set,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final w in [1, 2, 3, 4, 5, 6, 7])
                        Pressable(
                          radius: BorderRadius.circular(14),
                          onTap: () => set(() {
                            for (var i = 0; i < 28; i++) {
                              final d = _weekStart.add(Duration(days: i));
                              if (d.weekday == w) {
                                if (selected.contains(d)) {
                                  selected.remove(d);
                                } else {
                                  selected.add(d);
                                }
                              }
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cardLavender,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              '毎${OpsState.weekdayName(w)}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.lavender,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '区分',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBody,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final k in AvailKind.values) ...[
                        Expanded(
                          child: ChoiceTile(
                            title: k.label,
                            selected: kind == k,
                            color: k == AvailKind.ok
                                ? const Color(0xFF6FB57E)
                                : const Color(0xFFE08A8A),
                            onTap: () => set(() => kind = k),
                          ),
                        ),
                        if (k != AvailKind.values.last)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  _timePickRow('はじまり', start, (v) => set(() => start = v)),
                  const SizedBox(height: 8),
                  _timePickRow('おわり', end, (v) => set(() => end = v)),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.blushPinkDeep,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      onPressed: selected.isEmpty || end <= start
                          ? null
                          : () {
                              ops.bulkSet(
                                staffId: ops.currentStaffId,
                                dates: selected.toList(),
                                startMin: start,
                                endMin: end,
                                kind: kind,
                              );
                              Navigator.pop(ctx);
                              setState(() {
                                _draft.clear();
                                _dirty = false;
                              });
                              showWarmToast(
                                context,
                                '${selected.length}日分を登録しました',
                                icon: Icons.check_rounded,
                                color: const Color(0xFF6FB57E),
                              );
                            },
                      child: Text(
                        selected.isEmpty
                            ? '日にちを選んでください'
                            : '${selected.length}日に登録する',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _bulkDayChip(
    DateTime d,
    Set<DateTime> selected,
    void Function(VoidCallback) set,
  ) {
    final sel = selected.contains(d);
    final past = dayOf(d).isBefore(dayOf(DateTime.now()));
    return Pressable(
      radius: BorderRadius.circular(10),
      onTap: past
          ? null
          : () => set(() {
              if (sel) {
                selected.remove(d);
              } else {
                selected.add(d);
              }
            }),
      child: Container(
        width: 40,
        height: 44,
        decoration: BoxDecoration(
          color: past
              ? AppColors.cream
              : sel
              ? AppColors.blushPinkDeep
              : AppColors.cardCream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel ? AppColors.blushPinkDeep : AppColors.line,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekdayLabel(d.weekday),
              style: TextStyle(
                fontSize: 9,
                color: sel ? Colors.white70 : AppColors.textMuted,
              ),
            ),
            Text(
              '${d.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: past
                    ? AppColors.textMuted
                    : sel
                    ? Colors.white
                    : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timePickRow(String label, int value, ValueChanged<int> onChange) {
    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textBody,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var m = _gridStartMin; m <= _gridEndMin; m += 60)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Pressable(
                      radius: BorderRadius.circular(10),
                      onTap: () => onChange(m),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: value == m
                              ? AppColors.mauve
                              : AppColors.cardCream,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          hhmm(m),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: value == m
                                ? Colors.white
                                : AppColors.textBody,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// NG時間のハッチング（色覚特性に依存しない識別 / WCAG 1.4.1）
class _HatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFE08A8A).withValues(alpha: 0.5)
      ..strokeWidth = 0.9;
    for (var x = -size.height; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -----------------------------------------------------------------------------
// 毎週の基本パターン
// -----------------------------------------------------------------------------
class _WeeklyPatternScreen extends StatelessWidget {
  const _WeeklyPatternScreen();

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final mine =
        ops.availability
            .where((a) => a.staffId == ops.currentStaffId && a.isRecurring)
            .toList()
          ..sort(
            (a, b) => a.weekday! == b.weekday!
                ? a.startMin.compareTo(b.startMin)
                : a.weekday!.compareTo(b.weekday!),
          );

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: const AppTopBar(title: '毎週の基本パターン', subtitle: 'くり返す時間をまとめて登録'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: warmList([
          const InfoNote(
            title: '毎週くり返す時間だけを登録します',
            text:
                '登録した時間の「✕」を押すと、その1件だけを取り消せます。特定の日だけ変えたいときは、カレンダー画面でその日を上書きできます。NGはいつでもOKより優先されます。',
            icon: Icons.repeat_rounded,
            color: AppColors.lavender,
          ),
          const SizedBox(height: 16),
          for (var w = 1; w <= 7; w++) ...[
            _dayRow(
              context,
              ops,
              w,
              mine.where((a) => a.weekday == w).toList(),
            ),
            const SizedBox(height: 10),
          ],
        ]),
      ),
    );
  }

  Widget _dayRow(
    BuildContext context,
    OpsState ops,
    int w,
    List<StaffAvailability> ranges,
  ) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.cardLavender,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  OpsState.weekdayName(w),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ranges.isEmpty
                    ? const Text(
                        '登録なし（予約は入りません）',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final r in ranges)
                            _removableChip(context, ops, r),
                        ],
                      ),
              ),
              if (ranges.isNotEmpty)
                Pressable(
                  radius: BorderRadius.circular(20),
                  onTap: () => ops.clearWeeklyPattern(
                    staffId: ops.currentStaffId,
                    weekday: w,
                  ),
                  child: const SizedBox(
                    width: kMinTap,
                    height: kMinTap,
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _addBtn(
                  context,
                  'OKを追加',
                  const Color(0xFF6FB57E),
                  () => _pick(context, ops, w, AvailKind.ok),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _addBtn(
                  context,
                  'NGを追加',
                  const Color(0xFFE08A8A),
                  () => _pick(context, ops, w, AvailKind.ng),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 1件ずつ取り消せるチップ。OKだけ・NGだけを個別に消せる。
  Widget _removableChip(
    BuildContext context,
    OpsState ops,
    StaffAvailability r,
  ) {
    final isOk = r.kind == AvailKind.ok;
    final fg = isOk ? const Color(0xFF6FB57E) : const Color(0xFFD97A7A);
    final bg = isOk ? AppColors.cardSage : AppColors.cardPink;
    final text = '${r.kind.label} ${hhmm(r.startMin)}-${hhmm(r.endMin)}';
    return Semantics(
      button: true,
      label: '$text を取り消す',
      child: Tooltip(
        message: '$text を取り消す',
        child: Pressable(
          radius: BorderRadius.circular(30),
          onTap: () {
            ops.removeAvailabilityById(r.id);
            showWarmToast(
              context,
              '$text を取り消しました',
              icon: Icons.undo_rounded,
              color: fg,
            );
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 34),
            padding: const EdgeInsets.only(left: 12, right: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, size: 13, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _addBtn(
    BuildContext context,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Pressable(
      radius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }

  void _pick(BuildContext context, OpsState ops, int w, AvailKind kind) {
    var start = 9 * 60;
    var end = 17 * 60;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '毎${OpsState.weekdayName(w)}の${kind.label}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                _row('はじまり', start, (v) => set(() => start = v)),
                const SizedBox(height: 10),
                _row('おわり', end, (v) => set(() => end = v)),
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.blushPinkDeep,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    onPressed: end <= start
                        ? null
                        : () {
                            ops.setWeeklyPattern(
                              staffId: ops.currentStaffId,
                              weekday: w,
                              startMin: start,
                              endMin: end,
                              kind: kind,
                            );
                            Navigator.pop(ctx);
                          },
                    child: const Text(
                      '登録する',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(String label, int value, ValueChanged<int> onChange) {
    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textBody,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var m = 6 * 60; m <= 22 * 60; m += 60)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Pressable(
                      radius: BorderRadius.circular(10),
                      onTap: () => onChange(m),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: value == m
                              ? AppColors.mauve
                              : AppColors.cardCream,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          hhmm(m),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: value == m
                                ? Colors.white
                                : AppColors.textBody,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
