import type { Patient, Appointment, IntakeForm, ChartEntry, PhotoEntry, ChatMessage, ShiftSlot, MidwifeAvailability, LineNotification, AppConfig, Facility, MidwifeProfile, BookingPlan, MunicipalityCoupon, AIConsultation, Escalation, EPDSResult, HealthMetric, WearableConnection, BreastfeedingRecord, UsageBatch, MunicipalityReport, ConsentSignature, AuditLog, OperationalTask, BookingChange, PostCareSurvey } from './types';

const today = new Date();
const iso = (d: Date) => d.toISOString();
const addDays = (n: number) => { const d = new Date(today); d.setDate(d.getDate() + n); return d; };
const setHM = (d: Date, h: number, m = 0) => { const x = new Date(d); x.setHours(h, m, 0, 0); return x; };
const ymd = (d: Date) => `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;

export const seedPatients: Patient[] = [
 { id:'p1', name:'佐藤 みなみ', furigana:'さとう みなみ', babyName:'はる', birthday:iso(addDays(-42)), delivery:'自然分娩', phone:'090-1234-5678', lineId:'U91f-mamoa-minami', riskFlags:['mental'], avatar:'み', lastVisit:iso(addDays(-7)), notes:'初産。夜間授乳でお疲れ気味。EPDS要フォロー。', allergy:'なし', feedingStyle:'混合', address:'東京都世田谷区太子堂2-10-4', municipality:'世田谷区', postpartumCondition:'産後6週・経過良好', emergencyContact:'090-1111-2222', profileCompleted:true, municipalityEligibilityId:'SET-2026-00482', parkingNote:'近隣コインパーキングを利用', dietaryRestrictions:'なし', updatedAt:iso(addDays(-1)) },
 { id:'p2', name:'田中 ゆかり', furigana:'たなか ゆかり', babyName:'そら', birthday:iso(addDays(-21)), delivery:'帝王切開', phone:'090-2345-6789', riskFlags:['breast','weight'], avatar:'ゆ', notes:'右乳房に張り。体重増加やや少なめ。', allergy:'卵', feedingStyle:'混合', municipality:'目黒区', profileCompleted:true },
 { id:'p3', name:'高橋 ありさ', furigana:'たかはし ありさ', babyName:'りく', birthday:iso(addDays(-14)), delivery:'自然分娩', phone:'090-4567-8901', riskFlags:['breast','sleep','bloodPressure'], avatar:'あ', notes:'乳頭亀裂あり。妊娠高血圧既往。', allergy:'なし', feedingStyle:'完母', municipality:'渋谷区', profileCompleted:true }
];

export const seedFacilities: Facility[] = [
 { id:'f1', name:'ママズケア 三軒茶屋', address:'東京都世田谷区太子堂2-8-3', area:'世田谷', phone:'03-1234-5678', distanceKm:1.2, rating:4.8, reviewCount:126, description:'母乳ケアと、ほっと休める産後ケアに強い助産院です。', services:['通所ケア','宿泊ケア','母乳外来','オンライン相談'], amenities:['個室','沐浴室','駐車場','授乳室'], openHours:'9:00–17:00', imageTone:'pink', autoApprove:true, latitude:35.643, longitude:139.67 },
 { id:'f2', name:'木もれび助産院', address:'東京都目黒区中根1-5-2', area:'目黒', phone:'03-2222-5678', distanceKm:3.6, rating:4.6, reviewCount:84, description:'訪問ケアと宿泊ケア。家族みんなが安心できる場所です。', services:['通所ケア','宿泊ケア','訪問ケア','母乳外来'], amenities:['個室','家族室','食事','駅近'], openHours:'8:30–18:00', imageTone:'sage', autoApprove:false, latitude:35.618, longitude:139.676 },
 { id:'f3', name:'よりそい母乳ケア室', address:'東京都渋谷区代々木4-12-6', area:'渋谷', phone:'03-3333-5678', distanceKm:5.1, rating:4.9, reviewCount:203, description:'IBCLC助産師による母乳・乳房ケア専門施設です。', services:['訪問ケア','母乳外来','オンライン相談'], amenities:['駅近','オンライン','ベビーカー可'], openHours:'10:00–19:00', imageTone:'lavender', autoApprove:true, latitude:35.681, longitude:139.692 }
];
export const seedMidwives: MidwifeProfile[] = [
 { id:'mw1', name:'田村 南田', facilityId:'f1', qualifications:['助産師','看護師'], specialties:['母乳ケア','産後メンタル'], skills:['母乳ケア','訪問対応','宿泊対応'], supportedServices:['通所ケア','宿泊ケア','訪問ケア','母乳外来','オンライン相談'], workHours:'平日 9:00–17:00', area:'世田谷区', status:'online', travelOrigin:'三軒茶屋駅', visitAreas:['世田谷区','目黒区'], bufferMin:30, dailyLimit:6, consecutiveLimit:3 },
 { id:'mw2', name:'渡辺 香織', facilityId:'f2', qualifications:['助産師','IBCLC'], specialties:['訪問ケア','乳房ケア'], skills:['母乳ケア','訪問対応','宿泊対応'], supportedServices:['通所ケア','宿泊ケア','訪問ケア','母乳外来','オンライン相談'], workHours:'月・水・金', area:'目黒区', status:'online', travelOrigin:'都立大学駅', visitAreas:['目黒区','渋谷区'], bufferMin:45, dailyLimit:5, consecutiveLimit:2 },
 { id:'mw3', name:'小林 ひかり', facilityId:'f3', qualifications:['助産師','IBCLC'], specialties:['母乳ケア','オンライン相談'], skills:['母乳ケア'], supportedServices:['母乳外来','オンライン相談'], workHours:'火〜土 10:00–19:00', area:'渋谷区', status:'online', travelOrigin:'代々木駅', visitAreas:['渋谷区'], bufferMin:30, dailyLimit:5, consecutiveLimit:3 }
];
export const seedPlans: BookingPlan[] = [
 { id:'pl1', facilityId:'f1', type:'通所ケア', name:'通所ゆったり3時間', durationMin:180, description:'休息・育児相談・昼食付き' },
 { id:'pl2', facilityId:'f1', type:'宿泊ケア', name:'宿泊安心1泊', durationMin:1200, nights:1, description:'10:00チェックイン、翌8:00チェックアウト' },
 { id:'pl3', facilityId:'f1', type:'母乳外来', name:'母乳ケア60分', durationMin:60, description:'乳房観察・授乳姿勢・セルフケア' },
 { id:'pl4', facilityId:'f2', type:'訪問ケア', name:'ご自宅訪問2時間', durationMin:120, description:'ご自宅で休息と育児相談' },
 { id:'pl5', facilityId:'f2', type:'宿泊ケア', name:'家族で宿泊1泊', durationMin:1200, nights:1, description:'家族室・夕朝食付き' },
 { id:'pl6', facilityId:'f3', type:'母乳外来', name:'専門母乳ケア90分', durationMin:90, description:'IBCLCによる専門ケア' },
 { id:'pl7', facilityId:'f3', type:'オンライン相談', name:'オンライン相談30分', durationMin:30, description:'自宅から助産師へ相談' }
];

export const seedAppointments: Appointment[] = [
 { id:'a1', patientId:'p1', facilityId:'f1', planId:'pl1', start:iso(setHM(addDays(2),10)), durationMin:180, type:'通所ケア', status:'確定', workflowStatus:'CONFIRMED', channel:'line', intakeId:'i1', approvalMode:'auto', assignedMidwifeId:'mw1', termsVersion:'terms-2026.08', termsSnapshot:'産後ケア利用規約 2026年8月版', cancellationPolicyVersion:'cancel-2026.08', updatedAt:iso(addDays(-1)) },
 { id:'a2', patientId:'p2', facilityId:'f1', planId:'pl3', start:iso(setHM(today,11)), durationMin:60, type:'母乳外来', status:'確定', workflowStatus:'CONFIRMED', channel:'line', intakeId:'i2', approvalMode:'auto', assignedMidwifeId:'mw1', termsVersion:'terms-2026.08', cancellationPolicyVersion:'cancel-2026.08' },
 { id:'a3', patientId:'p3', facilityId:'f2', planId:'pl4', start:iso(setHM(addDays(1),14)), durationMin:120, type:'訪問ケア', status:'要確認', workflowStatus:'NEEDS_REVIEW', channel:'line', approvalMode:'manual', assignedMidwifeId:'mw2', termsVersion:'terms-2026.08', cancellationPolicyVersion:'cancel-2026.08' },
 { id:'a4', patientId:'p1', facilityId:'f1', planId:'pl3', start:iso(setHM(addDays(-7),9,30)), durationMin:60, type:'母乳外来', status:'完了', workflowStatus:'COMPLETED', channel:'app', assignedMidwifeId:'mw1', serviceStartedAt:iso(setHM(addDays(-7),9,32)), serviceCompletedAt:iso(setHM(addDays(-7),10,28)), termsVersion:'terms-2026.07' }
];
export const seedIntakes: IntakeForm[] = [
 { id:'i1', patientId:'p1', appointmentId:'a1', submittedAt:iso(addDays(-1)), motherName:'佐藤 みなみ', babyName:'はる', babyBirthday:iso(addDays(-42)), phone:'090-1234-5678', allergy:'なし', optionRequested:['沐浴'], sleepHours:4, moodScore:5, bodyPain:2, bleeding:'少量', breastCondition:'張り', babyWeightG:4300, feedingPerDay:8, diaperPerDay:7, babyMood:'ぐずり多め', concerns:'夜の授乳と気分の落ち込みが心配です。', consultTopics:['睡眠不足','母乳'], formType:'産後経過', epdsScore:8, consentSignature:'佐藤 みなみ' },
 { id:'i2', patientId:'p2', appointmentId:'a2', submittedAt:iso(addDays(-1)), motherName:'田中 ゆかり', babyName:'そら', babyBirthday:iso(addDays(-21)), phone:'090-2345-6789', allergy:'卵', optionRequested:[], sleepHours:5.5, moodScore:7, bodyPain:5, bleeding:'なし', breastCondition:'しこり', babyWeightG:3200, feedingPerDay:8, diaperPerDay:6, babyMood:'機嫌よし', concerns:'右胸の外側にしこりと痛みがあります。', consultTopics:['乳腺ケア'], formType:'母乳ケア', consentSignature:'田中 ゆかり' }
];
export const seedCharts: ChartEntry[] = [
 { id:'c1', patientId:'p1', appointmentId:'a4', facilityId:'f1', at:iso(addDays(-7)), midwife:'田村 南田', subjective:'夜間授乳で睡眠不足。母乳量への不安あり。', objective:'BP 108/68、体温36.6℃。乳房軽度緊満。', assessment:'疲労蓄積。EPDS継続評価が必要。', plan:'家族との夜間シフトを提案。1週間後フォロー。', motherBP:'108/68', babyWeightG:4200, breastNote:'両側軽度緊満', breastObservation:'発赤なし、しこりなし', aiInsights:['EPDS 8点。次回再評価を提案。'], sharedWith:['ママズケア 三軒茶屋'] }
];
export const seedPhotos: PhotoEntry[] = [{ id:'ph1', patientId:'p2', at:iso(addDays(-2)), category:'乳房', caption:'右胸外側の赤みを記録', emoji:'写真' }];
export const seedChats: ChatMessage[] = [{ id:'m1', roomId:'p1', from:'mama', text:'夜中の授乳がつらくて、ほとんど眠れていません。', at:iso(addDays(-1)), urgent:false },{ id:'m2', roomId:'p1', from:'midwife', text:'お話ししてくれてありがとうございます。今夜の休み方を一緒に考えましょう。', at:iso(addDays(-1)) }];

function buildShifts(): ShiftSlot[] { const out: ShiftSlot[]=[]; for (let i=0;i<21;i++){ const d=addDays(i); for(const f of ['f1','f2','f3']) for(let s=18;s<38;s++) out.push({id:`${f}-${ymd(d)}-${s}`,facilityId:f,date:ymd(d),slotIndex:s,capacity:1,staff:f==='f1'?'田村':'渡辺',closed:d.getDay()===0}); } return out; }
export const seedShifts=buildShifts();
function buildAvailability(): MidwifeAvailability[] {
 const out: MidwifeAvailability[]=[]; const createdAt=iso(addDays(-7));
 for(let i=0;i<28;i++){
  const d=addDays(i); const date=ymd(d); if(d.getDay()===0)continue;
  for(const mw of seedMidwives){
   const startHour=mw.id==='mw3'?9.5:8; const endHour=mw.id==='mw3'?19.5:18;
   out.push({id:`av-ok-${mw.id}-${date}`,midwifeId:mw.id,kind:'OK',start:iso(setHM(d,Math.floor(startHour),(startHour%1)*60)),end:iso(setHM(d,Math.floor(endHour),(endHour%1)*60)),reasonVisibility:'private',recurrence:'weekly',source:'midwife',createdBy:mw.name,createdAt,updatedAt:createdAt});
  }
 }
 const ngDate=addDays(1);
 out.push({id:'av-ng-private-mw1',midwifeId:'mw1',kind:'NG',start:iso(setHM(ngDate,13)),end:iso(setHM(ngDate,15)),reason:'私用',reasonVisibility:'private',recurrence:'none',source:'midwife',createdBy:'田村 南田',createdAt,updatedAt:createdAt});
 out.push({id:'av-ng-admin-mw2',midwifeId:'mw2',kind:'NG',start:iso(setHM(addDays(4),9)),end:iso(setHM(addDays(4),18)),reasonVisibility:'private',recurrence:'none',source:'admin',createdBy:'運営担当',createdAt,updatedAt:createdAt});
 return out;
}
export const seedAvailability=buildAvailability();
export const seedLineNotifications: LineNotification[]=[
 {id:'ln1',at:iso(today),channel:'official-line',to:'佐藤みなみさん',message:'ご予約が確定しました。前日と当日朝にお知らせします。',triggeredBy:'予約確定',deliveryStatus:'delivered',webhookEventId:'wh_01J7MAMOA001',deliveredAt:iso(today),retryCount:0,serviceMessage:true},
 {id:'ln2',at:iso(today),channel:'staff-line-works',to:'田村助産師',message:'専門判断が必要な問診が届きました。EPDS 8点です。',triggeredBy:'問診送信',deliveryStatus:'sent',webhookEventId:'wh_01J7MAMOA002',retryCount:0},
 {id:'ln3',at:iso(addDays(-1)),channel:'official-line',to:'高橋ありささん',message:'訪問先住所の確認をお願いします。',triggeredBy:'顧客回答待ち',deliveryStatus:'failed',webhookEventId:'wh_01J7MAMOA003',retryCount:2,errorMessage:'LINE user blocked'}
];
export const seedConfig: AppConfig={comingSoon:false,storesFallbackUrl:'https://line.me',homepageUrl:'https://mamoa.jp',instagramUrl:'https://instagram.com/mamoa',lineLinked:true,lineDisplayName:'MAMOA公式',openHour:9,closeHour:19,linePcFallbackUrl:'https://app.mamoa.jp/line-pc',monthlyMessageLimit:5000,monthlyMessageUsed:3276,termsVersion:'terms-2026.08',cancellationPolicyVersion:'cancel-2026.08'};

export const seedCoupons: MunicipalityCoupon[]=[{id:'cp1',patientId:'p1',municipality:'世田谷区',label:'産後ケア利用券',remainingUses:4,expiresAt:iso(addDays(180))}];
export const seedAIConsultations: AIConsultation[]=[{id:'ai1',patientId:'p1',at:iso(addDays(-1)),category:'母乳育児',question:'授乳のたびに痛みます。',answer:'痛みが続くときは、深く含ませられているか姿勢を確認してみましょう。発熱や赤み、強いしこりがある場合は助産師へつなぎます。',confidence:0.88,sources:['MAMOA母乳ケアガイド 2.1','助産師監修FAQ「ラッチ」']}];
export const seedEscalations: Escalation[]=[{id:'es1',patientId:'p3',createdAt:iso(today),reason:'血圧 146/94 mmHg を検出',severity:'緊急',status:'未対応',assignedMidwifeId:'mw1'}];
export const seedEPDS: EPDSResult[]=[{id:'ep1',patientId:'p1',at:iso(addDays(-8)),answers:[1,1,0,1,1,1,1,1,1,0],score:8,selfHarmAnswer:0,risk:'低'}];
export const seedHealthMetrics: HealthMetric[]=[
 {id:'h1',patientId:'p1',at:iso(addDays(-4)),type:'収縮期血圧',value:118,unit:'mmHg',source:'Withings'}, {id:'h2',patientId:'p1',at:iso(addDays(-4)),type:'拡張期血圧',value:76,unit:'mmHg',source:'Withings'},
 {id:'h3',patientId:'p1',at:iso(addDays(-3)),type:'睡眠',value:4.2,unit:'時間',source:'Oura'}, {id:'h4',patientId:'p1',at:iso(addDays(-2)),type:'睡眠',value:5.1,unit:'時間',source:'Oura'}, {id:'h5',patientId:'p1',at:iso(addDays(-1)),type:'睡眠',value:5.6,unit:'時間',source:'Oura'},
 {id:'h6',patientId:'p1',at:iso(today),type:'心拍',value:72,unit:'bpm',source:'Apple Health'}, {id:'h7',patientId:'p3',at:iso(today),type:'収縮期血圧',value:146,unit:'mmHg',source:'Withings',abnormal:true}, {id:'h8',patientId:'p3',at:iso(today),type:'拡張期血圧',value:94,unit:'mmHg',source:'Withings',abnormal:true}
];
export const seedWearables: WearableConnection[]=[{id:'w1',patientId:'p1',provider:'Withings',connected:true,lastSync:iso(today)},{id:'w2',patientId:'p1',provider:'Oura',connected:true,lastSync:iso(today)},{id:'w3',patientId:'p1',provider:'Apple Health',connected:true,lastSync:iso(today)}];
export const seedBreastfeeding: BreastfeedingRecord[]=[{id:'b1',patientId:'p1',at:iso(setHM(today,6,20)),side:'両側',durationMin:24,memo:'痛み少し'},{id:'b2',patientId:'p1',at:iso(setHM(today,9,10)),side:'左',durationMin:14},{id:'b3',patientId:'p1',at:iso(setHM(today,12,30)),side:'搾乳',durationMin:18,amountMl:70}];
export const seedUsageBatches: UsageBatch[]=[{id:'usage1',facilityId:'f1',municipality:'世田谷区',period:'2026-08',appointmentIds:['a1'],status:'集計中'}];
export const seedReports: MunicipalityReport[]=[{id:'mr1',municipality:'世田谷区',period:'2026-08',usageCount:18,uniqueUsers:12,status:'作成中'}];
export const seedConsents: ConsentSignature[]=[{id:'co1',patientId:'p1',appointmentId:'a1',type:'産後ケア利用同意',signedName:'佐藤 みなみ',signedAt:iso(addDays(-1)),version:'terms-2026.08',snapshot:'利用日時、キャンセル規定、個人情報の取扱いに同意'}];
export const seedOperationalTasks: OperationalTask[]=[
 {id:'ot1',appointmentId:'a3',patientId:'p3',queue:'予約例外',reasonCode:'VISIT_TRAVEL_BUFFER',title:'訪問移動時間の確認',detail:'前枠からの移動時間が標準バッファ30分を超える可能性があります。',priority:'優先',status:'未対応',createdAt:iso(today),dueAt:iso(setHM(today,16)),assignedRole:'admin',assignedTo:'運営担当'},
 {id:'ot2',appointmentId:'a2',patientId:'p2',queue:'専門判断',reasonCode:'BREAST_RED_FLAG',title:'乳房症状の事前確認',detail:'右乳房のしこりと痛み。発熱・発赤の有無を助産師が確認してください。',priority:'緊急',status:'対応中',createdAt:iso(today),dueAt:iso(setHM(today,10,30)),assignedRole:'midwife',assignedTo:'田村 南田'},
 {id:'ot3',appointmentId:'a1',patientId:'p1',queue:'事前確認',reasonCode:'EPDS_FOLLOWUP',title:'前回との差分を確認',detail:'睡眠は+1.4時間、気分スコアは前回比-1。ケア前に本人へ確認します。',priority:'通常',status:'未対応',createdAt:iso(today),dueAt:iso(setHM(addDays(2),9)),assignedRole:'midwife',assignedTo:'田村 南田'},
 {id:'ot4',appointmentId:'a3',patientId:'p3',queue:'顧客回答待ち',reasonCode:'ADDRESS_CONFIRM',title:'訪問先住所の回答待ち',detail:'建物名と当日の駐車場所をLINEフォームで確認中です。',priority:'通常',status:'保留',createdAt:iso(addDays(-1)),dueAt:iso(setHM(today,18)),assignedRole:'admin'},
 {id:'ot5',patientId:'p2',queue:'管理者作業待ち',reasonCode:'MUNICIPALITY_ELIGIBILITY',title:'自治体利用番号の照合',detail:'目黒区の利用番号と残回数を管理者が確認します。',priority:'優先',status:'未対応',createdAt:iso(today),dueAt:iso(addDays(1)),assignedRole:'admin',assignedTo:'運営担当'}
];
export const seedBookingChanges: BookingChange[]=[{id:'bc1',appointmentId:'a1',changedAt:iso(addDays(-1)),actor:'佐藤 みなみ',type:'問診更新',before:'睡眠 4時間',after:'睡眠 5.4時間',reasonCode:'SELF_UPDATE'}];
export const seedSurveys: PostCareSurvey[]=[{id:'sv1',appointmentId:'a4',patientId:'p1',submittedAt:iso(addDays(-6)),satisfaction:5,rested:4,feltSafe:5,comment:'授乳姿勢を一緒に見てもらえて安心しました。',wantsRebook:true,followupRequested:false}];
export const seedAuditLogs: AuditLog[]=[{id:'au1',at:iso(today),actor:'田村 南田',role:'midwife',action:'カルテ閲覧',target:'佐藤みなみ / c1',immutable:true},{id:'au2',at:iso(today),actor:'佐藤 みなみ',role:'mother',action:'予約確認',target:'a1',immutable:true},{id:'au3',at:iso(today),actor:'MAMOAルールエンジン',role:'admin',action:'例外タスク作成',target:'ot1',reasonCode:'VISIT_TRAVEL_BUFFER',immutable:true}];
