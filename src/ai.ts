import type { ChartEntry, IntakeForm, Patient } from './types';

// AI予測機能（ルールベース・LLMに差し替え可能な構造）

export type Severity = 'info' | 'warn' | 'urgent';

export interface AiInsight {
  severity: Severity;
  message: string;
  source: string;
}

export function analyzeIntake(
  intake: IntakeForm,
  patient: Patient,
  pastCharts: ChartEntry[],
): AiInsight[] {
  const insights: AiInsight[] = [];

  // メンタル系
  if (intake.moodScore <= 4 || intake.sleepHours <= 4) {
    insights.push({
      severity: 'urgent',
      message: `🧠 気分${intake.moodScore}/10・睡眠${intake.sleepHours}h。EPDS実施を強く推奨。${
        intake.concerns.includes('不安') || intake.concerns.includes('泣')
          ? '問診に不安・涙の記述あり。'
          : ''
      }`,
      source: '気分≤4 または 睡眠≤4h',
    });
  }

  // 乳房系
  if (
    intake.breastCondition === 'しこり' ||
    intake.breastCondition === '乳腺炎疑い'
  ) {
    insights.push({
      severity: 'warn',
      message: `🫧 乳房状態「${intake.breastCondition}」。発熱・発赤の確認と授乳姿勢見直しを。${
        pastCharts.some((c) => c.breastNote)
          ? '既往あり：再発リスク。冷罨法・排乳指導を継続。'
          : ''
      }`,
      source: '乳房コンディション',
    });
  }

  // 体重・発育
  const ageDays = Math.max(
    0,
    Math.floor((Date.now() - new Date(patient.birthday).getTime()) / 86400000),
  );
  const expected = ageDays < 90 ? 3000 + ageDays * 28 : 5500 + (ageDays - 90) * 17;
  if (intake.babyWeightG && intake.babyWeightG < expected * 0.9) {
    insights.push({
      severity: 'warn',
      message: `⚖️ 生後${ageDays}日 ${intake.babyWeightG}g (平均比 ${Math.round((intake.babyWeightG / expected) * 100)}%)。授乳回数・哺乳量の評価を。`,
      source: '月齢別体重曲線',
    });
  }

  // 授乳回数
  if (intake.feedingPerDay < 7 && ageDays < 60) {
    insights.push({
      severity: 'info',
      message: `🍼 1日${intake.feedingPerDay}回。新生児〜2ヶ月は8回以上が目安。脱水兆候確認を。`,
      source: '月齢別授乳目安',
    });
  }

  // 出血
  if (intake.bleeding === '多量') {
    insights.push({
      severity: 'urgent',
      message: '🩸 多量の出血。バイタル測定・産科連携を。',
      source: '出血量「多量」',
    });
  }

  // ポジティブ
  if (
    intake.moodScore >= 8 &&
    intake.sleepHours >= 6 &&
    intake.breastCondition === '良好'
  ) {
    insights.push({
      severity: 'info',
      message: '🌸 心身ともに良好。次回フォローは2週間後で問題なし。',
      source: '高スコア組合せ',
    });
  }

  return insights;
}

// SOAP 自動下書き (S/O/A/P key)
export function suggestSOAP(
  intake: IntakeForm | undefined,
  patient: Patient,
): { S: string; O: string; A: string; P: string } {
  const ageDays = Math.floor(
    (Date.now() - new Date(patient.birthday).getTime()) / 86400000,
  );
  if (!intake) {
    return {
      S: '',
      O: `${patient.name}さん 生後${ageDays}日`,
      A: '',
      P: '',
    };
  }
  return {
    S: `睡眠約${intake.sleepHours}h／気分${intake.moodScore}/10。心配ごと：${intake.concerns || '特になし'}`,
    O: `${patient.babyName}ちゃん ${intake.babyWeightG}g／授乳${intake.feedingPerDay}回・おむつ${intake.diaperPerDay}回／乳房:${intake.breastCondition}／出血:${intake.bleeding}`,
    A: [
      intake.moodScore <= 5 ? 'マタニティブルー遷延の懸念。' : '',
      intake.breastCondition !== '良好' ? '乳房ケア継続必要。' : '',
      intake.babyMood === '泣き止まない' ? '黄昏泣き／コリックの可能性。' : '',
    ]
      .filter(Boolean)
      .join(' ') || '特記事項なし。',
    P: `相談トピック「${intake.consultTopics.join('・') || '一般'}」を中心にケア。次回1〜2週間後を提案。`,
  };
}

// SOS メッセージのトリアージ
export function triageMessage(text: string): {
  urgent: boolean;
  reason?: string;
  suggestedReply: string;
} {
  if (/出血|血が|多量|止まら/.test(text)) {
    return {
      urgent: true,
      reason: '出血関連ワード検知',
      suggestedReply:
        '出血の状態を詳しく教えていただけますか？ナプキンが何枚/時間で交換が必要ですか？多い場合はすぐに産婦人科にご連絡ください。',
    };
  }
  if (/死にたい|消えたい|自分を傷|もう無理/.test(text)) {
    return {
      urgent: true,
      reason: '自傷リスク検知',
      suggestedReply:
        'お話してくれてありがとうございます。今とても辛い状況だと思います。すぐにお電話で繋がりたいです。',
    };
  }
  if (/熱|発熱|39|40度|ぐったり/.test(text)) {
    return {
      urgent: true,
      reason: '発熱・全身症状',
      suggestedReply:
        '体温と全身の様子（哺乳の有無、機嫌など）を教えてください。3ヶ月未満で38℃以上は受診対象です。',
    };
  }
  if (/痛|しこり|張り/.test(text)) {
    return {
      urgent: false,
      reason: '乳房症状',
      suggestedReply:
        'お辛いですね。痛みの場所と授乳との関係を教えてください。冷却と授乳姿勢の見直しで対応してみましょう。',
    };
  }
  return {
    urgent: false,
    suggestedReply: 'お知らせありがとうございます。詳しくお話を伺いますね🌸',
  };
}
