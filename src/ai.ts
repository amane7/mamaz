import type { AIConsultation, ChartEntry, IntakeForm, Patient } from './types';
export type Severity='info'|'warn'|'urgent';
export interface AiInsight{severity:Severity;message:string;source:string;}

export function calculateEPDS(answers:number[]){const score=answers.reduce((a,b)=>a+b,0);return{score,selfHarm:answers[9]>0,risk:answers[9]>0?'緊急':score>=9?'要フォロー':'低'} as const;}
export function analyzeIntake(intake:IntakeForm,_patient:Patient,pastCharts:ChartEntry[]):AiInsight[]{const x:AiInsight[]=[];if((intake.epdsScore??0)>=9||intake.moodScore<=4)x.push({severity:'urgent',message:`気分とEPDSを継続確認してください（EPDS ${intake.epdsScore??'未実施'}点）。`,source:'EPDS・産後経過問診'});if(intake.sleepHours<=4)x.push({severity:'warn',message:`睡眠${intake.sleepHours}時間。家族支援と休息計画を確認してください。`,source:'睡眠記録'});if(['しこり','乳腺炎疑い'].includes(intake.breastCondition))x.push({severity:'warn',message:`乳房状態「${intake.breastCondition}」。発熱・発赤と既往を確認してください${pastCharts.some(c=>c.breastNote)?'（乳房ケア既往あり）':''}。`,source:'母乳ケア問診'});if(intake.bleeding==='多量')x.push({severity:'urgent',message:'多量出血の申告。医療機関への連絡を優先してください。',source:'緊急時問診'});return x;}
export function suggestSOAP(intake:IntakeForm|undefined,patient:Patient){if(!intake)return{S:'',O:`${patient.name}さん`,A:'',P:''};return{S:`睡眠${intake.sleepHours}時間、気分${intake.moodScore}/10。${intake.concerns}`,O:`乳房：${intake.breastCondition}、出血：${intake.bleeding}。${patient.babyName}ちゃん ${intake.babyWeightG}g、授乳${intake.feedingPerDay}回。`,A:`${intake.sleepHours<=4?'休息不足。':''}${intake.breastCondition!=='良好'?'乳房ケア継続が必要。':''}${(intake.epdsScore??0)>=9?'EPDS要フォロー。':''}`||'経過良好。',P:`${intake.consultTopics.join('・')||'産後経過'}を中心にケア。セルフケア説明と次回フォローを行う。`};}

const urgentRules=[
 {pattern:/死にたい|消えたい|自分を傷|自殺|生きていたくない/,reason:'自傷念慮に関する言葉',answer:'今、とてもつらい状態をひとりで抱えているのですね。あなたの安全が最優先です。ひとりにならず、身近な方に声をかけてください。助産師へただちにつなぎます。差し迫った危険がある場合は119へ連絡してください。'},
 {pattern:/大量.*出血|出血.*止まら|ナプキン.*1時間|血の塊/,reason:'大量出血の可能性',answer:'出血について緊急の確認が必要です。1時間にナプキン1枚以上が必要、ふらつき、息苦しさがある場合は、すぐに産科または119へ連絡してください。同時に助産師へつなぎます。'},
 {pattern:/39度|40度|高熱|38[\.．]?[0-9]?度|発熱.*しこり/,reason:'高熱・乳腺炎などの可能性',answer:'38℃以上の発熱は早めの確認が必要です。乳房の赤み・しこり、悪寒の有無を確認し、医療機関へ相談してください。助産師へつなぎます。'},
 {pattern:/血圧.*1[4-9][0-9]|1[4-9][0-9].*血圧|頭痛.*目が|目がちかちか/,reason:'産後高血圧の可能性',answer:'産後の高血圧は早めの対応が必要です。血圧を安静にして再測定し、140/90mmHg以上、強い頭痛や見え方の異常がある場合は医療機関へ連絡してください。助産師にも共有します。'}
];
export function answerConsultation(question:string,category:AIConsultation['category']){for(const r of urgentRules)if(r.pattern.test(question))return{answer:r.answer,confidence:.98,sources:['MAMOA緊急時対応基準 2026','こども家庭庁 産後ケア安全指針'],escalate:true,urgent:true,reason:r.reason};
 if(/乳房|母乳|授乳|乳首|しこり|張り|ラッチ|飲まない/.test(question)||category==='母乳育児')return{answer:'おつらいですね。まず、赤ちゃんの口が乳輪まで深く含めているか、鼻とあごが乳房に触れる姿勢かを確認してみましょう。痛みが続く、赤み・発熱・強いしこりがある場合は、無理に揉まず助産師の母乳ケアをご利用ください。',confidence:.89,sources:['MAMOA母乳ケアガイド「深いラッチ」','助産師監修FAQ「乳房の張り」'],escalate:false,urgent:false};
 if(/眠れ|睡眠|つらい|不安|涙|落ち込/.test(question)||category==='メンタル')return{answer:'話してくれてありがとうございます。まとまって眠れない時期は、短い休息でも確保することが大切です。今日、赤ちゃんを任せられる方はいますか？ 気分の落ち込みが続く場合はEPDSチェックも一緒に行えます。',confidence:.82,sources:['MAMOA産後メンタルケアガイド','EPDS運用手順'],escalate:false,urgent:false};
 if(/赤ちゃん|泣|便|おむつ|体重/.test(question)||category==='育児')return{answer:'赤ちゃんの様子を一緒に整理しましょう。月齢、授乳回数、おしっこの回数、機嫌、体温を教えてください。哺乳できない、ぐったり、3か月未満で38℃以上の場合は医療機関へ相談してください。',confidence:.78,sources:['MAMOA育児観察ガイド','乳児の受診目安'],escalate:false,urgent:false};
 return{answer:'ご相談ありがとうございます。安全にお答えするため、いつから・どのくらい・ほかに気になる症状があるかを教えてください。判断が難しい場合は人間の助産師へおつなぎできます。',confidence:.58,sources:['MAMOA相談トリアージ標準'],escalate:true,urgent:false,reason:'AIの回答信頼度が基準未満'};
}
export function triageMessage(text:string){const r=answerConsultation(text,'その他');return{urgent:r.urgent,reason:r.reason,suggestedReply:r.answer,confidence:r.confidence};}
