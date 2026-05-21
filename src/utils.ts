import type { LogEntry, MamaCheck } from './types';

export function daysSince(iso: string) {
  const d = new Date(iso).getTime();
  return Math.max(0, Math.floor((Date.now() - d) / (1000 * 60 * 60 * 24)));
}

export function formatTime(at: number) {
  const d = new Date(at);
  const today = new Date();
  const sameDay =
    d.getFullYear() === today.getFullYear() &&
    d.getMonth() === today.getMonth() &&
    d.getDate() === today.getDate();
  const yesterday = new Date(today);
  yesterday.setDate(today.getDate() - 1);
  const isYesterday =
    d.getFullYear() === yesterday.getFullYear() &&
    d.getMonth() === yesterday.getMonth() &&
    d.getDate() === yesterday.getDate();
  const hh = d.getHours().toString().padStart(2, '0');
  const mm = d.getMinutes().toString().padStart(2, '0');
  if (sameDay) return `今日 ${hh}:${mm}`;
  if (isYesterday) return `昨日 ${hh}:${mm}`;
  return `${d.getMonth() + 1}/${d.getDate()} ${hh}:${mm}`;
}

export function timeAgo(at: number) {
  const diff = Date.now() - at;
  const m = Math.floor(diff / 60000);
  if (m < 1) return 'たった今';
  if (m < 60) return `${m}分前`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}時間${m % 60}分前`;
  return `${Math.floor(h / 24)}日前`;
}

export function sumFeedingLast24h(logs: LogEntry[]) {
  const since = Date.now() - 24 * 60 * 60 * 1000;
  return logs
    .filter((l) => l.type === 'feeding' && l.at >= since)
    .reduce(
      (acc, l) => ({
        count: acc.count + 1,
        ml: acc.ml + (l.amountMl ?? 0),
        min: acc.min + (l.durationMin ?? 0),
      }),
      { count: 0, ml: 0, min: 0 },
    );
}

export function sumSleepLast24h(logs: LogEntry[]) {
  const since = Date.now() - 24 * 60 * 60 * 1000;
  return logs
    .filter((l) => l.type === 'sleep' && l.at >= since)
    .reduce((acc, l) => {
      const s = l.sleepStart ?? l.at;
      const e = l.sleepEnd ?? l.at;
      return acc + Math.max(0, e - s);
    }, 0);
}

export function sumDiaperLast24h(logs: LogEntry[]) {
  const since = Date.now() - 24 * 60 * 60 * 1000;
  return logs.filter((l) => l.type === 'diaper' && l.at >= since).length;
}

// 次の授乳予測: 過去5回の平均間隔から算出
export function predictNextFeeding(logs: LogEntry[]): { at: number; intervalMin: number } | null {
  const feeds = logs
    .filter((l) => l.type === 'feeding')
    .sort((a, b) => b.at - a.at)
    .slice(0, 6);
  if (feeds.length < 2) return null;
  const intervals: number[] = [];
  for (let i = 0; i < feeds.length - 1; i++) {
    intervals.push(feeds[i].at - feeds[i + 1].at);
  }
  const avg = intervals.reduce((a, b) => a + b, 0) / intervals.length;
  return {
    at: feeds[0].at + avg,
    intervalMin: Math.round(avg / 60000),
  };
}

// ママのコンディションスコア（0-100）。直近のチェックと睡眠から算出。
export function mamaWellnessScore(checks: MamaCheck[], logs: LogEntry[]): number {
  const latest = checks[0];
  const sleepMs = sumSleepLast24h(logs);
  let score = 60;
  if (latest) {
    score += (latest.moodScore - 5) * 4;
    score -= (latest.stressScore - 5) * 3;
    score -= (latest.bodyPainScore - 5) * 2;
    if (latest.hasHelp) score += 5;
  }
  // 睡眠ボーナス（最大15点）
  score += Math.min(15, (sleepMs / (1000 * 60 * 60)) * 2);
  return Math.max(0, Math.min(100, Math.round(score)));
}

// 泣き声解析シミュレーション（本物のAI処理の代わり）
export const CRY_CATEGORIES = [
  { id: 'hungry', label: 'お腹がすいた', emoji: '🍼', advice: '前回の授乳から時間が経っていそう。授乳または白湯をどうぞ。' },
  { id: 'sleepy', label: '眠い', emoji: '😴', advice: '抱っこして寝かしつけ。背中をトントン、ホワイトノイズが◎。' },
  { id: 'diaper', label: 'おむつが不快', emoji: '💧', advice: 'まずはおむつチェック。皮膚のかぶれにも注意。' },
  { id: 'discomfort', label: '暑い・寒い・かゆい', emoji: '🌡️', advice: '室温24〜26℃が目安。服装やタグの当たりも確認。' },
  { id: 'wantcuddle', label: '抱っこしてほしい', emoji: '🤱', advice: '不安・甘え。ぎゅっと抱きしめてあげてください。' },
] as const;

export function analyzeCrySim(seed: number) {
  // 簡単な疑似スコア
  const scores = CRY_CATEGORIES.map((c, i) => ({
    ...c,
    score: Math.round(((Math.sin(seed + i * 1.7) + 1) / 2) * 100),
  })).sort((a, b) => b.score - a.score);
  const total = scores.reduce((a, b) => a + b.score, 0);
  return scores.map((s) => ({ ...s, percent: Math.round((s.score / total) * 100) }));
}

// EPDS簡易版（産後うつスクリーニング）
export const EPDS_QUESTIONS = [
  '物事の面白い面に笑うことができた',
  '物事を楽しみにして待つことができた',
  '物事がうまくいかなかったとき、自分を責めた',
  'はっきりとした理由もなく不安になったり心配したりした',
  'はっきりとした理由もなく恐怖を感じた',
  'することがたくさんあって大変だった',
  '不幸せなので眠りにくかった',
  '悲しくて惨めだった',
  '不幸せなので泣いていた',
  '自分自身を傷つけたいという考えが浮かんだ',
];

// 育児TIPSライブラリ（月齢別）
export function tipsForAge(days: number): string[] {
  if (days < 30) {
    return [
      '新生児期は3時間ごとの授乳が目安。脱水と黄疸に注意。',
      'うつぶせ寝はNG。仰向けで、顔まわりにぬいぐるみを置かないで。',
      'ママの体は子宮復古中。1日20分でも横になる時間を意識して。',
      'お風呂はベビーバス。へその緒が乾くまで沐浴で。',
    ];
  }
  if (days < 90) {
    return [
      '首がすわり始める時期。腹ばい遊びを1日5分から。',
      '昼夜の区別がつき始める。朝の光、夜の暗さで生活リズムを。',
      '黄昏泣き（コリック）が増える時期。15分抱っこで落ち着きます。',
      'ママはホルモン変動が激しい時期。涙もろくて当然です。',
    ];
  }
  if (days < 180) {
    return [
      '寝返り注意。ベッド周りの安全確認を。',
      '生活リズムが整い、夜まとめて寝る子も。離乳食準備期。',
      '人見知りが始まる子も。ママ・パパとの愛着形成は順調な証拠。',
      '産後6ヶ月健診、骨盤底筋ケアの再評価を。',
    ];
  }
  return [
    '離乳食が進む時期。アレルギーは新食材1日1種で。',
    'ハイハイ・つかまり立ちの始まり。家庭内安全対策を。',
    '夜泣きが復活する子も。寝室環境を見直してみて。',
    'ママも社会復帰を考える時期。一人時間を意識的に。',
  ];
}
