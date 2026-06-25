export type AppMode = 'landing' | 'midwife' | 'mama';

export type MidwifeTab =
  | 'dashboard'
  | 'calendar'
  | 'patients'
  | 'chart'
  | 'analytics'
  | 'inbox'
  | 'shift'
  | 'settings';

export type MamaTab = 'home' | 'book' | 'intake' | 'photos' | 'chat' | 'visits';

export interface Patient {
  id: string;
  name: string;
  furigana: string;
  babyName: string;
  birthday: string; // ISO
  delivery: '自然分娩' | '帝王切開' | '無痛分娩' | 'その他';
  phone: string;
  lineId?: string;
  riskFlags: ('breast' | 'mental' | 'weight' | 'sleep')[];
  avatar: string; // emoji
  lastVisit?: string;
  notes?: string;
  // 乳房ケア軸の追加項目
  allergy?: string;
  feedingStyle?: '完母' | '混合' | '完ミ';
}

export type AppointmentType =
  | '産後ケア'
  | '乳房ケア'
  | '母乳相談'
  | '沐浴指導'
  | '初回相談';

export interface Appointment {
  id: string;
  patientId: string;
  start: string; // ISO
  durationMin: number; // 30 / 60 / 90 など、1時間枠をそのまま扱える
  type: AppointmentType;
  status: '予約済' | '確定' | '完了' | 'キャンセル';
  notes?: string;
  // 予約と問診のセット化
  intakeId?: string;
  // チャネル
  channel?: 'app' | 'line' | 'phone' | 'stores';
}

export interface IntakeForm {
  id: string;
  patientId: string;
  appointmentId: string;
  submittedAt?: string;
  // 基本情報 (ママズケア現行運用の9項目を踏襲)
  motherName: string;
  babyName: string;
  babyBirthday: string;
  phone: string;
  allergy: string;
  optionRequested: string[]; // 沐浴 / おやつ / 写真撮影 / 整体 など
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

// ───────── シフト管理 ─────────
// 1日を30分単位の slot で管理。1時間枠は2 slot 連続で表現するが
// 予約は durationMin で 60 / 90 など自由に取れるため、Stores の
// 「30分おきにシフト2分割」のような不自然さがない。
export interface ShiftSlot {
  id: string;
  date: string; // YYYY-MM-DD
  // 0 = 00:00, 1 = 00:30, ... 17 = 08:30, 18 = 09:00 ... 34 = 17:00
  slotIndex: number;
  capacity: number; // 通常 1 (同時受け入れ人数)
  staff?: string;
  closed?: boolean; // 受付停止
}

export interface LineNotification {
  id: string;
  at: string;
  channel: 'official-line' | 'staff-line-works' | 'sms';
  to: string; // 「公式LINE」「スタッフLINE WORKS」
  message: string;
  triggeredBy: string; // 「予約作成」「キャンセル」など
}

export interface AppConfig {
  // 6月末暫定対応モード
  comingSoon: boolean;
  storesFallbackUrl: string;
  // ホームページ / SNS リンク
  homepageUrl: string;
  instagramUrl: string;
  // 公式LINE連携
  lineLinked: boolean;
  lineDisplayName: string;
  // 予約枠の基本パラメタ
  openHour: number; // 9
  closeHour: number; // 17
}
