import type {
  Patient,
  Appointment,
  IntakeForm,
  ChartEntry,
  PhotoEntry,
  ChatMessage,
} from './types';

const today = new Date();
const iso = (d: Date) => d.toISOString();
const addDays = (n: number) => {
  const d = new Date(today);
  d.setDate(d.getDate() + n);
  return d;
};
const setHM = (d: Date, h: number, m: number) => {
  const x = new Date(d);
  x.setHours(h, m, 0, 0);
  return x;
};

export const seedPatients: Patient[] = [
  {
    id: 'p1',
    name: '佐藤 みなみ',
    furigana: 'さとう みなみ',
    babyName: 'はる',
    birthday: iso(addDays(-42)),
    delivery: '自然分娩',
    phone: '090-1234-5678',
    riskFlags: ['mental'],
    avatar: '🌷',
    lastVisit: iso(addDays(-7)),
    notes: '初産。夜間授乳でお疲れ気味。EPDS要チェック。',
  },
  {
    id: 'p2',
    name: '田中 ゆかり',
    furigana: 'たなか ゆかり',
    babyName: 'そら',
    birthday: iso(addDays(-21)),
    delivery: '帝王切開',
    phone: '090-2345-6789',
    riskFlags: ['breast', 'weight'],
    avatar: '🌸',
    lastVisit: iso(addDays(-3)),
    notes: '右乳房に張り。体重増加やや少なめ。混合栄養。',
  },
  {
    id: 'p3',
    name: '鈴木 さやか',
    furigana: 'すずき さやか',
    babyName: 'あおい',
    birthday: iso(addDays(-90)),
    delivery: '無痛分娩',
    phone: '090-3456-7890',
    riskFlags: [],
    avatar: '🌼',
    lastVisit: iso(addDays(-30)),
    notes: '経産婦・上のお子さんあり。育児経験豊富。',
  },
  {
    id: 'p4',
    name: '高橋 ありさ',
    furigana: 'たかはし ありさ',
    babyName: 'りく',
    birthday: iso(addDays(-14)),
    delivery: '自然分娩',
    phone: '090-4567-8901',
    riskFlags: ['breast', 'sleep'],
    avatar: '🍀',
    notes: '初回利用。乳頭亀裂あり、痛み強い。',
  },
  {
    id: 'p5',
    name: '伊藤 のぞみ',
    furigana: 'いとう のぞみ',
    babyName: 'ひな',
    birthday: iso(addDays(-150)),
    delivery: '自然分娩',
    phone: '090-5678-9012',
    riskFlags: [],
    avatar: '🌻',
    lastVisit: iso(addDays(-14)),
    notes: '離乳食開始相談。',
  },
];

export const seedAppointments: Appointment[] = [
  {
    id: 'a1',
    patientId: 'p1',
    start: iso(setHM(today, 9, 30)),
    durationMin: 60,
    type: '産後ケア',
    status: '確定',
  },
  {
    id: 'a2',
    patientId: 'p2',
    start: iso(setHM(today, 11, 0)),
    durationMin: 45,
    type: '乳房ケア',
    status: '確定',
  },
  {
    id: 'a3',
    patientId: 'p4',
    start: iso(setHM(today, 14, 0)),
    durationMin: 60,
    type: '初回相談',
    status: '確定',
  },
  {
    id: 'a4',
    patientId: 'p3',
    start: iso(setHM(today, 15, 30)),
    durationMin: 30,
    type: '母乳相談',
    status: '予約済',
  },
  {
    id: 'a5',
    patientId: 'p2',
    start: iso(setHM(addDays(2), 10, 0)),
    durationMin: 45,
    type: '乳房ケア',
    status: '予約済',
  },
  {
    id: 'a6',
    patientId: 'p5',
    start: iso(setHM(addDays(1), 13, 30)),
    durationMin: 45,
    type: '産後ケア',
    status: '予約済',
  },
  {
    id: 'a7',
    patientId: 'p1',
    start: iso(setHM(addDays(7), 9, 30)),
    durationMin: 60,
    type: '産後ケア',
    status: '予約済',
  },
];

export const seedIntakes: IntakeForm[] = [
  {
    id: 'i1',
    patientId: 'p1',
    appointmentId: 'a1',
    submittedAt: iso(addDays(-1)),
    sleepHours: 4,
    moodScore: 4,
    bodyPain: 3,
    bleeding: '少量',
    breastCondition: '張り',
    babyWeightG: 4200,
    feedingPerDay: 9,
    diaperPerDay: 7,
    babyMood: 'ぐずり多め',
    concerns:
      '夜中ほとんど寝られず、自分が母親として大丈夫なのか不安になる時間が増えました。',
    consultTopics: ['夜泣き', 'メンタル', '母乳量'],
  },
  {
    id: 'i2',
    patientId: 'p2',
    appointmentId: 'a2',
    submittedAt: iso(addDays(-1)),
    sleepHours: 5.5,
    moodScore: 7,
    bodyPain: 5,
    bleeding: 'なし',
    breastCondition: 'しこり',
    babyWeightG: 3200,
    feedingPerDay: 8,
    diaperPerDay: 6,
    babyMood: '機嫌よし',
    concerns: '右胸の外側にしこりがあり、授乳の時痛い。',
    consultTopics: ['乳腺ケア', '体重'],
  },
];

export const seedCharts: ChartEntry[] = [
  {
    id: 'c1',
    patientId: 'p1',
    at: iso(addDays(-7)),
    midwife: '助産師 田村',
    subjective: '睡眠不足、涙もろい。ミルクの追加に罪悪感。',
    objective: '体重:51.2kg / BP:108/68 / 子宮復古良好',
    assessment: 'マタニティブルーズの遷延傾向。EPDS 11点で要観察。',
    plan: '次回EPDS再検、夜間ミルク導入を肯定的に伝達。家族の協力依頼。',
    motherBP: '108/68',
    babyWeightG: 4050,
    aiInsights: [
      'EPDS 11点：産婦人科紹介の閾値に近い。次回必ず再評価を推奨。',
      '夜間睡眠4h未満が継続。パートナーシフト導入を提案。',
    ],
  },
  {
    id: 'c2',
    patientId: 'p2',
    at: iso(addDays(-3)),
    midwife: '助産師 渡辺',
    subjective: '右乳房の外側上部に張りと痛み。',
    objective: '右C領域にしこり 2cm、発赤なし。体温36.7℃。',
    assessment: '乳腺うっ滞。乳腺炎には至らず。',
    plan: '授乳姿勢の変更、冷罨法、次回48h後フォロー。',
    breastNote: '右C領域 うっ滞',
    aiInsights: [
      '過去のしこり再発リスク中。授乳姿勢の動画コンテンツを送付済み。',
    ],
  },
];

export const seedPhotos: PhotoEntry[] = [
  {
    id: 'ph1',
    patientId: 'p2',
    at: iso(addDays(-2)),
    category: '乳房',
    caption: '右胸外側、しこりがある場所',
    emoji: '🫧',
  },
  {
    id: 'ph2',
    patientId: 'p1',
    at: iso(addDays(-1)),
    category: '便',
    caption: '緑色っぽい、心配です',
    emoji: '💩',
  },
  {
    id: 'ph3',
    patientId: 'p4',
    at: iso(addDays(-1)),
    category: '発疹',
    caption: '顔の頬に赤いぶつぶつ',
    emoji: '🌹',
  },
  {
    id: 'ph4',
    patientId: 'p2',
    at: iso(addDays(-5)),
    category: '体重計',
    caption: '3.18kg',
    emoji: '⚖️',
  },
];

export const seedChats: ChatMessage[] = [
  {
    id: 'm1',
    roomId: 'p1',
    from: 'mama',
    text: '夜中3時、また寝てくれません…どうしたら良いですか😢',
    at: iso(new Date(today.getTime() - 1000 * 60 * 60 * 6)),
    urgent: true,
  },
  {
    id: 'm2',
    roomId: 'p1',
    from: 'midwife',
    text: 'みなみさん、お疲れさまです。今は無理に寝かしつけず、一度抱っこで気分転換してみてくださいね。明日のケアでもゆっくりお話しましょう🌸',
    at: iso(new Date(today.getTime() - 1000 * 60 * 60 * 5)),
  },
  {
    id: 'm3',
    roomId: 'p2',
    from: 'mama',
    text: '今日のしこり、少し小さくなった気がします！',
    at: iso(new Date(today.getTime() - 1000 * 60 * 30)),
  },
  {
    id: 'm4',
    roomId: 'p4',
    from: 'mama',
    text: '授乳の時の痛みが強くて、続けるのが辛いです。',
    at: iso(new Date(today.getTime() - 1000 * 60 * 90)),
    urgent: true,
  },
];
