export type AppMode = 'landing' | 'midwife' | 'mama';

export type MidwifeTab =
  | 'dashboard'
  | 'calendar'
  | 'patients'
  | 'chart'
  | 'analytics'
  | 'inbox';

export type MamaTab = 'home' | 'intake' | 'photos' | 'chat' | 'visits';

export interface Patient {
  id: string;
  name: string;
  furigana: string;
  babyName: string;
  birthday: string; // ISO
  delivery: '自然分娩' | '帝王切開' | '無痛分娩' | 'その他';
  phone: string;
  riskFlags: ('breast' | 'mental' | 'weight' | 'sleep')[];
  avatar: string; // emoji
  lastVisit?: string;
  notes?: string;
}

export interface Appointment {
  id: string;
  patientId: string;
  start: string; // ISO
  durationMin: number;
  type: '産後ケア' | '乳房ケア' | '母乳相談' | '沐浴指導' | '初回相談';
  status: '予約済' | '確定' | '完了' | 'キャンセル';
  notes?: string;
}

export interface IntakeForm {
  id: string;
  patientId: string;
  appointmentId: string;
  submittedAt?: string;
  // 産後体調
  sleepHours: number;
  moodScore: number; // 1-10
  bodyPain: number;
  bleeding: 'なし' | '少量' | '中等量' | '多量';
  breastCondition: '良好' | '張り' | '痛み' | 'しこり' | '乳腺炎疑い';
  // 赤ちゃん
  babyWeightG: number;
  feedingPerDay: number;
  diaperPerDay: number;
  babyMood: '機嫌よし' | 'ぐずり多め' | '泣き止まない';
  // 心配ごと
  concerns: string;
  consultTopics: string[];
}

export interface ChartEntry {
  id: string;
  patientId: string;
  appointmentId?: string;
  at: string; // ISO
  midwife: string;
  // SOAP
  subjective: string;
  objective: string;
  assessment: string;
  plan: string;
  // 計測
  babyWeightG?: number;
  motherBP?: string;
  breastNote?: string;
  // AI
  aiInsights?: string[];
}

export interface PhotoEntry {
  id: string;
  patientId: string;
  at: string;
  category: '乳房' | '便' | '発疹' | '体重計' | 'その他';
  caption: string;
  // 実画像は持たず、絵文字代替
  emoji: string;
}

export interface ChatMessage {
  id: string;
  roomId: string; // patientId
  from: 'mama' | 'midwife' | 'system';
  text: string;
  at: string;
  urgent?: boolean;
}
