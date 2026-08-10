export type AppMode = 'landing' | 'midwife' | 'mama' | 'admin';
export type MidwifeTab = 'dashboard' | 'bookings' | 'availability' | 'patients' | 'chart' | 'care' | 'billing' | 'municipality' | 'settings';
export type MamaTab = 'home' | 'book' | 'manage' | 'intake' | 'guide' | 'survey' | 'consult' | 'ai' | 'health' | 'care' | 'visits';
export type AdminTab = 'dashboard' | 'queues' | 'calendar' | 'customers' | 'staff' | 'rules' | 'notifications' | 'reports' | 'audit';

export type WorkflowStatus = 'DRAFT' | 'SUBMITTED' | 'NEEDS_REVIEW' | 'SLOT_HELD' | 'CONFIRMED' | 'IN_SERVICE' | 'COMPLETED' | 'CANCELLED' | 'NO_SHOW';
export type AppointmentStatus = '下書き' | '申込' | '要確認' | '仮押さえ' | '予約済' | '確定' | '利用中' | '完了' | 'キャンセル' | '無断キャンセル';
export type TaskQueue = '専門判断' | '予約例外' | '事前確認' | '顧客回答待ち' | '管理者作業待ち';
export type TaskStatus = '未対応' | '対応中' | '保留' | '完了';
export type TaskPriority = '通常' | '優先' | '緊急';
export type DeliveryStatus = 'queued' | 'sent' | 'delivered' | 'failed' | 'retrying';

export interface Patient {
  id: string; name: string; furigana: string; babyName: string; birthday: string;
  delivery: '自然分娩' | '帝王切開' | '無痛分娩' | 'その他'; phone: string; lineId?: string;
  riskFlags: ('breast' | 'mental' | 'weight' | 'sleep' | 'bloodPressure')[];
  avatar: string; lastVisit?: string; notes?: string; allergy?: string;
  feedingStyle?: '完母' | '混合' | '完ミ'; address?: string; municipality?: string;
  postpartumCondition?: string; emergencyContact?: string; profileCompleted?: boolean;
  municipalityEligibilityId?: string; parkingNote?: string; dietaryRestrictions?: string;
  updatedAt?: string;
}

export type AppointmentType = '通所ケア' | '宿泊ケア' | '訪問ケア' | '母乳外来' | 'オンライン相談' | '産後ケア' | '乳房ケア' | '母乳相談' | '沐浴指導' | '初回相談';
export interface Appointment {
  id: string; patientId: string; facilityId?: string; planId?: string; start: string;
  durationMin: number; nights?: number; type: AppointmentType; status: AppointmentStatus;
  workflowStatus?: WorkflowStatus; notes?: string; intakeId?: string;
  channel?: 'app' | 'line' | 'phone' | 'stores'; approvalMode?: 'auto' | 'manual';
  reminderSent?: boolean; holdExpiresAt?: string; assignedMidwifeId?: string;
  termsVersion?: string; termsSnapshot?: string; cancellationPolicyVersion?: string;
  serviceStartedAt?: string; serviceCompletedAt?: string; updatedAt?: string;
}

export interface IntakeForm {
  id: string; patientId: string; appointmentId: string; submittedAt?: string;
  motherName: string; babyName: string; babyBirthday: string; phone: string; allergy: string;
  optionRequested: string[]; sleepHours: number; moodScore: number; bodyPain: number;
  bleeding: 'なし' | '少量' | '中等量' | '多量';
  breastCondition: '良好' | '張り' | '痛み' | 'しこり' | '乳腺炎疑い';
  babyWeightG: number; feedingPerDay: number; diaperPerDay: number;
  babyMood: '機嫌よし' | 'ぐずり多め' | '泣き止まない'; concerns: string;
  consultTopics: string[]; formType?: '初回問診' | '産後経過' | '母乳ケア' | '緊急時';
  epdsScore?: number; consentSignature?: string; draftSavedAt?: string;
  addressConfirmed?: boolean; allergyConfirmed?: boolean; parkingRequired?: boolean;
  mealRequired?: boolean; municipalityEligibilityConfirmed?: boolean;
}

export interface OperationalTask {
  id: string; appointmentId?: string; patientId: string; queue: TaskQueue; reasonCode: string;
  title: string; detail: string; priority: TaskPriority; status: TaskStatus; createdAt: string;
  dueAt: string; assignedRole: 'midwife' | 'admin'; assignedTo?: string; updatedAt?: string;
  resolutionNote?: string;
}
export interface BookingChange {
  id: string; appointmentId: string; changedAt: string; actor: string;
  type: '日時変更' | 'プラン変更' | '問診更新' | 'キャンセル' | '状態変更';
  before: string; after: string; reasonCode?: string;
}
export interface PostCareSurvey {
  id: string; appointmentId: string; patientId: string; submittedAt: string;
  satisfaction: number; rested: number; feltSafe: number; comment?: string;
  wantsRebook: boolean; followupRequested: boolean;
}

export interface ChartEntry {
  id: string; patientId: string; appointmentId?: string; facilityId?: string; at: string;
  midwife: string; subjective: string; objective: string; assessment: string; plan: string;
  babyWeightG?: number; motherBP?: string; breastNote?: string; breastObservation?: string;
  aiInsights?: string[]; sharedWith?: string[];
}
export interface PhotoEntry { id: string; patientId: string; at: string; category: '乳房' | '便' | '発疹' | '体重計' | '傷跡' | '母乳量' | 'その他'; caption: string; emoji: string; dataUrl?: string; }
export interface ChatMessage { id: string; roomId: string; from: 'mama' | 'midwife' | 'system'; text: string; at: string; urgent?: boolean; }
export interface ShiftSlot { id: string; date: string; slotIndex: number; capacity: number; staff?: string; closed?: boolean; facilityId?: string; bufferMin?: number; }
export type AvailabilityKind = 'OK' | 'NG';
export interface MidwifeAvailability {
  id: string; midwifeId: string; kind: AvailabilityKind; start: string; end: string;
  reason?: string; reasonVisibility: 'private'; recurrence?: 'none' | 'weekly'; source: 'midwife' | 'admin' | 'migration';
  createdBy: string; createdAt: string; updatedAt: string;
}
export type SlotExclusionCode = 'SKILL_MISMATCH' | 'NO_EXPLICIT_OK' | 'NG_CONFLICT' | 'BOOKING_CONFLICT' | 'BUFFER_SHORTAGE' | 'TRAVEL_SHORTAGE' | 'DAILY_LIMIT' | 'CONSECUTIVE_LIMIT' | 'AREA_MISMATCH' | 'FACILITY_MISMATCH';
export interface SlotCandidate {
  midwifeId: string; eligible: boolean; score: number; rank?: number;
  exclusionCodes: SlotExclusionCode[]; reasons: string[];
  scoreBreakdown: { loadBalance: number; travelEfficiency: number; continuity: number };
}
export interface GeneratedBookingSlot {
  start: string; end: string; available: boolean; candidates: SlotCandidate[];
  selectedMidwifeId?: string; publicReason: string;
}
export interface LineNotification {
  id: string; at: string; channel: 'official-line' | 'staff-line-works' | 'sms' | 'push';
  to: string; message: string; triggeredBy: string; deliveryStatus?: DeliveryStatus;
  webhookEventId?: string; deliveredAt?: string; retryCount?: number; errorMessage?: string;
  serviceMessage?: boolean;
}
export interface AppConfig {
  comingSoon: boolean; storesFallbackUrl: string; homepageUrl: string; instagramUrl: string;
  lineLinked: boolean; lineDisplayName: string; openHour: number; closeHour: number;
  linePcFallbackUrl?: string; monthlyMessageLimit?: number; monthlyMessageUsed?: number;
  termsVersion?: string; cancellationPolicyVersion?: string;
}

export interface MidwifeProfile {
  id: string; name: string; facilityId: string; qualifications: string[]; specialties: string[];
  skills?: string[]; supportedServices?: AppointmentType[]; workHours: string; area: string; status: 'online' | 'offline'; travelOrigin?: string;
  visitAreas?: string[]; bufferMin?: number; dailyLimit?: number; consecutiveLimit?: number;
}
export interface Facility {
  id: string; name: string; address: string; area: string; phone: string; distanceKm: number;
  rating: number; reviewCount: number; description: string; services: AppointmentType[];
  amenities: string[]; openHours: string; imageTone: 'pink' | 'sage' | 'lavender';
  autoApprove: boolean; latitude: number; longitude: number; roomCount?: number;
  dailyCapacity?: number; mealCapacity?: number;
}
export interface BookingPlan { id: string; facilityId: string; type: AppointmentType; name: string; durationMin: number; nights?: number; description: string; minimumBabyAgeDays?: number; requiresQualification?: string; }
export interface MunicipalityCoupon { id: string; patientId: string; municipality: string; label: string; remainingUses: number; expiresAt: string; eligibilityId?: string; }

export interface AIConsultation { id: string; patientId: string; at: string; category: '母乳育児' | '育児' | '自分の体調' | 'メンタル' | 'その他'; question: string; answer: string; confidence: number; sources: string[]; escalationId?: string; }
export interface Escalation { id: string; consultationId?: string; patientId: string; createdAt: string; reason: string; severity: '注意' | '緊急'; status: '未対応' | '対応中' | '完了'; assignedMidwifeId?: string; }
export interface EPDSResult { id: string; patientId: string; at: string; answers: number[]; score: number; selfHarmAnswer: number; risk: '低' | '要フォロー' | '緊急'; }

export type HealthMetricType = '収縮期血圧' | '拡張期血圧' | '心拍' | '睡眠' | '活動量' | '体温' | '体重';
export interface HealthMetric { id: string; patientId: string; at: string; type: HealthMetricType; value: number; unit: string; source: 'manual' | 'Withings' | 'Apple Health' | 'Fitbit' | 'Oura'; abnormal?: boolean; }
export interface WearableConnection { id: string; patientId: string; provider: 'Withings' | 'Apple Health' | 'Fitbit' | 'Oura'; connected: boolean; lastSync?: string; }
export interface BreastfeedingRecord { id: string; patientId: string; at: string; side: '左' | '右' | '両側' | '搾乳'; durationMin: number; amountMl?: number; memo?: string; }

export interface UsageBatch { id: string; facilityId: string; municipality?: string; period: string; appointmentIds: string[]; status: '集計中' | '確定済'; confirmedAt?: string; }
export interface MunicipalityReport { id: string; municipality: string; period: string; usageCount: number; uniqueUsers: number; status: '作成中' | '提出済'; }
export interface ConsentSignature { id: string; patientId: string; appointmentId?: string; type: string; signedName: string; signedAt: string; version: string; snapshot?: string; }
export interface AuditLog { id: string; at: string; actor: string; role: 'mother' | 'midwife' | 'admin'; action: string; target: string; reasonCode?: string; immutable?: boolean; }
