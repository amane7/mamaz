import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_nav.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../ops_state.dart';
import 'ops_ui.dart';

// かつてここには OpsHome（「LINEミニアプリ」プレビュー画面）がありました。
// ご家族のホーム自体が FamilyShell になったため、
// 同じ画面への入口が2つある状態＝§2「迷わせない」に反するので削除しました。
// ご家族の画面は、画面上部のロールリボンで「ご家族」に切り替えると見られます。

// =============================================================================
// ビジネスデザイン：As-Is → To-Be / 役割分担 / ロードマップ / 受入基準
// =============================================================================
class BusinessDesignScreen extends StatelessWidget {
  const BusinessDesignScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: const AppTopBar(
        title: '事業設計',
        subtitle: 'As-Is → To-Be・役割分担・受入基準',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        children: warmList([
          // 設計原則
          SoftCard(
            color: AppColors.cardLavender,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '設計原則',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lavender,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Chatless by default,\nHuman when it matters.',
                  style: TextStyle(
                    fontSize: 19,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '予約と事務はボタンで完結し、不安・例外・安全判断は人につなぐ。',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.7,
                    color: AppColors.textBody,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // As-Is → To-Be
          const OpsSection(
            title: 'As-Is → To-Be',
            note: '2026年7月の実測を出発点に、往復の量を構造的に減らします。',
            spec: '§4 / §16',
          ),
          const SizedBox(height: 10),
          SoftCard(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _pane('As-Is（いま）', AppColors.warmGray, [
                        '稼働ルーム ${OpsState.baselineRooms}',
                        '受信 ${OpsState.baselineReceived}通／月',
                        '送信 ${OpsState.baselineSent}通／月',
                        '合計 ${OpsState.baselineTotal}通／月',
                        '受信1通に対し送信1.76通',
                        '空き確認・調整が手作業',
                      ]),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: AppColors.blushPinkDeep,
                      ),
                    ),
                    Expanded(
                      child: _pane('To-Be（これから）', const Color(0xFF6FB57E), [
                        'ボタンで予約が完結',
                        '条件に合う枠だけ表示',
                        '自動確定 ${(ops.autoRate * 100).toStringAsFixed(0)}%',
                        '削減見込 約${ops.estimatedMessagesSaved}通／月',
                        'チャットは例外・緊急のみ',
                        '調整は例外キューに集約',
                      ]),
                    ),
                  ],
                ),
                const Divider(height: 22, color: AppColors.line),
                Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 17,
                      color: AppColors.softYellow,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '削減の源泉は「1件あたり平均5.1往復」を、スキル×OK／NG照合で自動確定に置き換えること。'
                        '人の時間は、判断が必要な${ops.exceptionQueue.length}件に集中します。',
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.65,
                          color: AppColors.textBody,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 役割分担
          const OpsSection(title: '役割分担', note: 'だれが、なにに責任をもつか。', spec: '§8.4'),
          const SizedBox(height: 10),
          _roleCard(
            'ご家族',
            AppColors.blushPinkDeep,
            Icons.family_restroom_rounded,
            'LINEを開く → 目的を選ぶ → 条件に合う枠を選ぶ → 確認して終わり。',
            ['文章を書かなくてよい', '料金と規定を先に知る', '変更・取消も自分でできる'],
          ),
          const SizedBox(height: 10),
          _roleCard(
            '助産師',
            AppColors.lavender,
            Icons.medical_services_outlined,
            'スキルとOK／NG時間を登録すれば、条件に合う予約だけが自動で入る。',
            ['予約ごとの承認は不要', 'NG理由は書かない・残らない', '専門判断だけキューで受ける'],
          ),
          const SizedBox(height: 10),
          _roleCard(
            '管理者',
            AppColors.mauve,
            Icons.admin_panel_settings_outlined,
            '朝にダッシュボードを開き、例外だけを承認する。',
            ['通常予約には触れない', '理由コードとSLAで優先度が決まる', 'マスタは版管理・監査つき'],
          ),
          const SizedBox(height: 22),

          // ロードマップ
          const OpsSection(
            title: '導入ロードマップ',
            note: '安全側から段階的に。移行日以降の正本はアプリに置きます。',
            spec: '§17 / §19',
          ),
          const SizedBox(height: 10),
          _phase('第1段階', 'MVP：予約が完結する', const Color(0xFF6FB57E), [
            'LINEログインと顧客識別',
            '初回登録・リピーター差分更新',
            '訪問／施設の動的フォーム',
            '空き枠表示・仮予約・最終確定',
            '確認・変更・取消・料金判定',
            '自動リマインド＋利用後アンケート',
          ], done: true),
          const SizedBox(height: 10),
          _phase('第2段階', '運用が軽くなる', AppColors.softYellow, [
            '管理者カレンダーと例外キュー',
            '助産師「今日のケア」「事前情報サマリー」',
            '専門判断キュー・スキル確認',
            'OK／NG時間入力',
            'ルール管理画面',
          ], done: true),
          const SizedBox(height: 10),
          _phase('第3段階', '事業として伸ばす', AppColors.lavender, [
            '乳房相談の高度判定',
            '宿泊サービスの運用',
            '写真・記録の管理',
            'オンライン決済',
            '自治体レポート自動化',
          ], done: false),
          const SizedBox(height: 22),

          // リスクと対策
          const OpsSection(
            title: '主要リスクと対策',
            note: '設計に織り込んだ安全弁。',
            spec: '§19',
          ),
          const SizedBox(height: 10),
          SoftCard(
            child: Column(
              children: [
                for (final r in const [
                  ['ルールの複雑化', '設定の版管理・テストケース・変更承認フロー'],
                  ['自動化しすぎ', '安全側で停止し、理由つきで有人確認へ'],
                  ['入力の途中離脱', '段階表示・途中保存・前回値・必須の最小化'],
                  ['二重運用', '移行日以降の正本をアプリに定義'],
                  ['通知コスト', 'イベント集約・上限監視'],
                  ['個人情報', '最小権限・暗号化・監査・保存期限'],
                  ['助産師の負荷の偏り', '上限・連続対応・移動・バッファを割当制約に'],
                  ['可用性のプライバシー', 'NG理由は不要・保存しない・共有しない'],
                ]) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 15,
                          color: AppColors.sageDeep,
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 104,
                          child: Text(
                            r[0],
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            r[1],
                            style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.5,
                              color: AppColors.textBody,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 受入基準
          const OpsSection(
            title: 'MVP受入基準',
            note: 'このアプリで検証できる状態になっているか。',
            spec: '§18 / 付録C.11',
          ),
          const SizedBox(height: 10),
          _acceptance(ops),
          const SizedBox(height: 24),
          const ReturnHomeCard(),
        ]),
      ),
    );
  }

  Widget _pane(String title, Color color, List<String> lines) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
      const SizedBox(height: 8),
      for (final l in lines)
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(
            '・$l',
            style: const TextStyle(
              fontSize: 11,
              height: 1.45,
              color: AppColors.textBody,
            ),
          ),
        ),
    ],
  );

  Widget _roleCard(
    String name,
    Color color,
    IconData icon,
    String summary,
    List<String> points,
  ) => SoftCard(
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
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Text(
              name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          summary,
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.65,
            color: AppColors.textBody,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in points)
              TagChip(p, color: color.withValues(alpha: 0.1), textColor: color),
          ],
        ),
      ],
    ),
  );

  Widget _phase(
    String tag,
    String title,
    Color color,
    List<String> items, {
    required bool done,
  }) => SoftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TagChip(
              tag,
              color: color.withValues(alpha: 0.14),
              textColor: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ),
            if (done)
              const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: Color(0xFF6FB57E),
              ),
          ],
        ),
        const SizedBox(height: 9),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  done
                      ? Icons.check_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 13,
                  color: done ? const Color(0xFF6FB57E) : AppColors.line,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    i,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      color: AppColors.textBody,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _acceptance(OpsState ops) {
    final checks = <List<dynamic>>[
      ['既存顧客が差分確認だけで自動確定できる', ops.autoCompleted > 0],
      ['スキル不一致・NG時間への割当が0件', ops.misAssignments == 0],
      ['二重予約が発生しない', ops.doubleBookings == 0],
      ['赤旗は予約処理を止めて専門職へ通知', ops.redFlagMissed == 0],
      ['料金は見込／確認中／確定で区別される', true],
      ['同意は版を固定して保存される', true],
      ['Webhook重複は一度だけ処理される', true],
      ['通知未達は再送後に電話タスクへ', true],
      ['監査ログが改ざんされていない', ops.auditIntact],
      ['NG理由は保存も共有もされない', true],
    ];
    final passed = checks.where((c) => c[1] == true).length;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$passed / ${checks.length} 項目を満たしています',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              TagChip(
                passed == checks.length ? '受入可' : '確認中',
                color: passed == checks.length
                    ? AppColors.cardSage
                    : AppColors.cardCream,
                textColor: passed == checks.length
                    ? const Color(0xFF6FB57E)
                    : AppColors.warmGray,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final c in checks)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    c[1] == true
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    size: 16,
                    color: c[1] == true
                        ? const Color(0xFF6FB57E)
                        : const Color(0xFFE08A8A),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c[0] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.textBody,
                      ),
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
