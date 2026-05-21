export type LogType = 'feeding' | 'sleep' | 'diaper' | 'mood' | 'note';

export interface LogEntry {
  id: string;
  type: LogType;
  at: number; // timestamp
  // feeding
  side?: 'left' | 'right' | 'bottle';
  amountMl?: number;
  durationMin?: number;
  // sleep
  sleepStart?: number;
  sleepEnd?: number;
  // diaper
  diaper?: 'pee' | 'poop' | 'both';
  // mood / note
  mood?: 1 | 2 | 3 | 4 | 5;
  note?: string;
}

export interface MamaCheck {
  id: string;
  at: number;
  sleepHours: number;
  moodScore: number; // 1-10
  bodyPainScore: number; // 1-10
  stressScore: number; // 1-10
  hasHelp: boolean;
  notes?: string;
}

export interface BabyProfile {
  name: string;
  birthday: string; // ISO
  gender: 'boy' | 'girl' | 'unknown';
  avatar: string; // emoji
}

export interface MamaProfile {
  name: string;
  deliveryDate: string;
  deliveryType: '自然分娩' | '帝王切開' | '無痛分娩' | 'その他';
  partnerName?: string;
  avatar: string;
}

export interface ChatMessage {
  id: string;
  role: 'user' | 'mami';
  text: string;
  at: number;
}

export type ScreenId =
  | 'home'
  | 'log'
  | 'mami'
  | 'mama'
  | 'future'
  | 'community';

export interface AppState {
  baby: BabyProfile;
  mama: MamaProfile;
  logs: LogEntry[];
  mamaChecks: MamaCheck[];
  chat: ChatMessage[];
  onboarded: boolean;
}
