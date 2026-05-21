import type { ChartEntry, IntakeForm, Patient } from './types';

// AI予測機能（ルールベース・LLMに差し替え可能な構造）
// "Manary"のコア訴求である「助産院監修のAI予測機能」を担う

export interface AiInsight {
  level: 'info' | 'warn' | 'urgent';
  icon: string;
  title: string;
  detail: string;
  source: string; // 推論の根拠
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
      level: 'urgent',
      icon: '🧠',
      title: '産後うつ・睡眠不足の高リスク',
      detail: `気分スコア${intake.moodScore}/10、睡眠${intake.sleepHours}h。EPDS実施を強く推奨します。${
        intake.concerns.includes('不安') || intake.concerns.includes('泣')
          ? '問診票にも不安・涙に関する記述あり。'
          : ''
      }`,
      source: '気分≤4 または 睡眠≤4h ルール',
    });
  }

  // 乳房系
  if (intake.breastCondition === 'しこり' || intake.breastCondition === '乳腺炎疑い') {
    insights.push({
      level: 'warn',
      icon: '🫧',
      title: '乳腺うっ滞〜乳腺炎の警戒',
      detail: `自覚: ${intake.breastCondition}。発熱・発赤の確認、授乳姿勢の見直しを準備。${
        pastCharts.some((c) => c.breastNote)
          ? '既往あり：再発リスク中。冷罨法と排乳指導を継続を。'
          : ''
      }`,
      source: '問診票の乳房コンディション項目',
    });
  }

  // 体重・発育
  const ageDays = Math.max(
    0,
    Math.floor((Date.now() - new Date(patient.birthday).getTime()) / 86400000),
  );
  // 平均増加: 0-3ヶ月は25-30g/日、3-6ヶ月は15-20g/日
  const expected = ageDays < 90 ? 3000 + ageDays * 28 : 5500 + (ageDays - 90) * 17;
  if (intake.babyWeightG && intake.babyWeightG < expected * 0.9) {
    insights.push({
      level: 'warn',
      icon: '⚖️',
      title: '体重増加が緩やか',
      detail: `生後${ageDays}日で${intake.babyWeightG}g。同月齢平均比 約${Math.round(
        (intake.babyWeightG / expected) * 100,
      )}%。授乳回数・哺乳量の評価をおすすめします。`,
      source: '月齢別体重曲線との比較',
    });
  }

  // 授乳回数
  if (intake.feedingPerDay < 7 && ageDays < 60) {
    insights.push({
      level: 'info',
      icon: '🍼',
      title: '授乳回数がやや少なめ',
      detail: `1日${intake.feedingPerDay}回。新生児〜生後2ヶ月は8回以上が目安。脱水兆候の確認を。`,
      source: '月齢別授乳回数の目安',
    });
  }

  // 出血
  if (intake.bleeding === '多量') {
    insights.push({
      level: 'urgent',
      icon: '🩸',
      title: '産後出血の警戒',
      detail: '多量の出血は産科受診の対象。バイタル測定と医療機関連携を。',
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
      level: 'info',
      icon: '🌸',
      title: '心身ともに良好',
      detail: '現在の生活リズムを継続。次回フォローは2週間後で問題なさそう。',
      source: '高スコアの組み合わせ',
    });
  }

  return insights;
}

// SOAP 自動下書き
export function suggestSOAP(
  intake: IntakeForm | undefined,
  patient: Patient,
): { subjective: string; objective: string; assessment: string; plan: string } {
  if (!intake) {
    return {
      subjective: '',
      objective: `${patient.name}さん 生後${Math.floor(
        (Date.now() - new Date(patient.birthday).getTime()) / 86400000,
      )}日`,
      assessment: '',
      plan: '',
    };
  }
  return {
    subjective: `睡眠約${intake.sleepHours}h／気分${intake.moodScore}/10。心配ごと：${intake.concerns}`,
    objective: `${patient.babyName}ちゃん ${intake.babyWeightG}g／授乳${intake.feedingPerDay}回・おむつ${intake.diaperPerDay}回／乳房:${intake.breastCondition}／出血:${intake.bleeding}`,
    assessment: `${
      intake.moodScore <= 5 ? 'マタニティブルー遷延の懸念。' : ''
    }${intake.breastCondition !== '良好' ? '乳房ケア継続必要。' : ''}${
      intake.babyMood === '泣き止まない' ? '黄昏泣き／コリックの可能性。' : ''
    }`,
    plan: `相談トピック「${intake.consultTopics.join('・')}」を中心にケア。次回は1〜2週間後を提案。`,
  };
}

// SOSメッセージのトリアージ
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
        'お話してくれてありがとうございます。今とても辛い状況だと思います。すぐにお電話で繋がりたいです。私の方からお電話してもよろしいですか？',
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
