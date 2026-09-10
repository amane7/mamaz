import 'package:flutter/material.dart';

import '../models/facility.dart';

/// 提携助産院・産後ケア施設のシードデータ（Step1：10〜30施設想定のうち代表6件）
const seedFacilities = <Facility>[
  Facility(
    id: 'f001',
    name: 'ママズケア 助産院',
    area: '東京都 世田谷区',
    address: '東京都世田谷区三軒茶屋1-2-3 ママズケアビル2F',
    tel: '03-1234-5678',
    rating: 4.9,
    reviewCount: 128,
    distanceKm: 1.2,
    kinds: [
      PlanKind.dayCare,
      PlanKind.stay,
      PlanKind.breastClinic,
      PlanKind.online,
      PlanKind.visit,
    ],
    features: ['母乳ケア専門', '自治体委託', '個室あり', '兄弟同伴OK'],
    midwifeName: '助産師 南田 みなみ',
    comment: '母乳・乳房ケアを20年。「がんばりすぎないで」を合言葉に、ママの体と心をまるごとお預かりします。',
    subsidyAvailable: true,
    plans: [
      CarePlan(
        id: 'p001',
        kind: PlanKind.dayCare,
        name: '通所ケア 3時間（休息＋母乳ケア）',
        hours: 3,
        price: 8000,
        subsidy: 5000,
      ),
      CarePlan(
        id: 'p002',
        kind: PlanKind.dayCare,
        name: '通所ケア 6時間（食事・沐浴つき）',
        hours: 6,
        price: 14000,
        subsidy: 8000,
      ),
      CarePlan(
        id: 'p003',
        kind: PlanKind.stay,
        name: '宿泊ケア 1泊2日（個室・3食つき）',
        hours: 0,
        price: 28000,
        subsidy: 18000,
      ),
      CarePlan(
        id: 'p004',
        kind: PlanKind.breastClinic,
        name: '母乳外来 60分（乳房ケア＋授乳指導）',
        hours: 1,
        price: 6000,
        subsidy: 3000,
      ),
      CarePlan(
        id: 'p005',
        kind: PlanKind.online,
        name: 'オンライン相談 30分',
        hours: 0,
        price: 3000,
      ),
      CarePlan(
        id: 'p006',
        kind: PlanKind.visit,
        name: '訪問ケア 2時間（LINEで日程調整）',
        hours: 2,
        price: 12000,
        subsidy: 7000,
      ),
    ],
  ),
  Facility(
    id: 'f002',
    name: 'MOA産後ケアハウス 目黒',
    area: '東京都 目黒区',
    address: '東京都目黒区中目黒4-5-6',
    tel: '03-2345-6789',
    rating: 4.7,
    reviewCount: 86,
    distanceKm: 2.8,
    kinds: [PlanKind.stay, PlanKind.dayCare, PlanKind.online],
    features: ['全室個室', '産後の食事つき', '夜間助産師常駐'],
    midwifeName: '助産師 佐々木 えみ',
    comment: '夜間も助産師が常駐。「ぐっすり眠れた」と言ってもらえる宿泊ケアを大切にしています。',
    subsidyAvailable: true,
    plans: [
      CarePlan(
        id: 'p011',
        kind: PlanKind.stay,
        name: '宿泊ケア 1泊2日（産後ごはんつき）',
        hours: 0,
        price: 32000,
        subsidy: 20000,
      ),
      CarePlan(
        id: 'p012',
        kind: PlanKind.dayCare,
        name: '日帰りケア 4時間',
        hours: 4,
        price: 11000,
        subsidy: 6000,
      ),
      CarePlan(
        id: 'p013',
        kind: PlanKind.online,
        name: 'オンライン相談 30分',
        hours: 0,
        price: 2500,
      ),
    ],
  ),
  Facility(
    id: 'f003',
    name: 'あおぞら母乳外来クリニック',
    area: '東京都 品川区',
    address: '東京都品川区大井町7-8-9',
    tel: '03-3456-7890',
    rating: 4.8,
    reviewCount: 154,
    distanceKm: 3.4,
    kinds: [PlanKind.breastClinic, PlanKind.online],
    features: ['乳腺炎対応', '土日診療', 'IBCLC在籍'],
    midwifeName: '助産師 田中 かおり',
    comment: '乳腺炎・乳頭痛・卒乳のご相談まで。国際認定ラクテーション・コンサルタントが対応します。',
    plans: [
      CarePlan(
        id: 'p021',
        kind: PlanKind.breastClinic,
        name: '母乳外来 初回 60分',
        hours: 1,
        price: 7000,
        subsidy: 3000,
      ),
      CarePlan(
        id: 'p022',
        kind: PlanKind.breastClinic,
        name: '母乳外来 再診 30分',
        hours: 0,
        price: 4500,
        subsidy: 2000,
      ),
      CarePlan(
        id: 'p023',
        kind: PlanKind.online,
        name: 'オンライン母乳相談 30分',
        hours: 0,
        price: 3000,
      ),
    ],
  ),
  Facility(
    id: 'f004',
    name: 'こもれび助産院（訪問専門）',
    area: '東京都 大田区',
    address: '東京都大田区蒲田2-3-4',
    tel: '03-4567-8901',
    rating: 4.6,
    reviewCount: 62,
    distanceKm: 5.1,
    kinds: [PlanKind.visit, PlanKind.online],
    features: ['訪問専門', '双子対応', '沐浴指導'],
    midwifeName: '助産師 井上 ゆき',
    comment: 'ご自宅にうかがい、いつもの環境のままケアします。お部屋の片付けは不要です。',
    subsidyAvailable: true,
    plans: [
      CarePlan(
        id: 'p031',
        kind: PlanKind.visit,
        name: '訪問ケア 2時間',
        hours: 2,
        price: 13000,
        subsidy: 8000,
      ),
      CarePlan(
        id: 'p032',
        kind: PlanKind.visit,
        name: '訪問ケア 3時間（沐浴・授乳指導つき）',
        hours: 3,
        price: 17000,
        subsidy: 10000,
      ),
      CarePlan(
        id: 'p033',
        kind: PlanKind.online,
        name: 'オンライン相談 30分',
        hours: 0,
        price: 2500,
      ),
    ],
  ),
  Facility(
    id: 'f005',
    name: 'かがやき産後ケアセンター',
    area: '神奈川県 川崎市',
    address: '神奈川県川崎市中原区小杉町1-1-1',
    tel: '044-123-4567',
    rating: 4.5,
    reviewCount: 97,
    distanceKm: 8.6,
    kinds: [PlanKind.dayCare, PlanKind.stay, PlanKind.breastClinic],
    features: ['自治体委託', '駅近', '託児あり'],
    midwifeName: '助産師 山口 のぞみ',
    comment: '川崎市の産後ケア事業対応。上のお子さんの託児もご相談ください。',
    subsidyAvailable: true,
    plans: [
      CarePlan(
        id: 'p041',
        kind: PlanKind.dayCare,
        name: '通所ケア 5時間',
        hours: 5,
        price: 12000,
        subsidy: 9000,
      ),
      CarePlan(
        id: 'p042',
        kind: PlanKind.stay,
        name: '宿泊ケア 1泊2日',
        hours: 0,
        price: 26000,
        subsidy: 19000,
      ),
      CarePlan(
        id: 'p043',
        kind: PlanKind.breastClinic,
        name: '母乳外来 45分',
        hours: 1,
        price: 5500,
        subsidy: 2500,
      ),
    ],
  ),
  Facility(
    id: 'f006',
    name: 'ゆりかご助産院 オンライン',
    area: 'オンライン（全国対応）',
    address: 'オンライン専門（ビデオ通話）',
    tel: '0120-000-000',
    rating: 4.7,
    reviewCount: 210,
    distanceKm: 0,
    kinds: [PlanKind.online, PlanKind.breastClinic],
    features: ['全国対応', '夜間20時まで', '当日予約OK'],
    midwifeName: '助産師 チーム MOA',
    comment: '遠方の方も、深夜の不安も。画面越しでも助産師の知恵はきちんと届きます。',
    plans: [
      CarePlan(
        id: 'p051',
        kind: PlanKind.online,
        name: 'オンライン相談 30分',
        hours: 0,
        price: 2800,
      ),
      CarePlan(
        id: 'p052',
        kind: PlanKind.online,
        name: 'オンライン相談 60分（じっくり）',
        hours: 1,
        price: 5000,
      ),
      CarePlan(
        id: 'p053',
        kind: PlanKind.breastClinic,
        name: 'オンライン母乳相談 40分',
        hours: 1,
        price: 3800,
      ),
    ],
  ),
];

/// おすすめ記事
const seedArticles = <Article>[
  Article(
    id: 'a001',
    title: '母乳育児のコツ・深く含ませる「ラッチオン」',
    category: '母乳・授乳',
    readMin: '4分',
    body: '''授乳の痛みの多くは「浅飲み」から起こります。赤ちゃんの口が大きく開いたタイミングで、乳輪までしっかり含ませましょう。

【チェックポイント】
・赤ちゃんの唇が外向きにめくれている
・あごが乳房に触れている
・耳・肩・腰が一直線
・飲むリズムに合わせてこめかみが動く

痛みが続く、白斑ができる、しこりが取れないときは、我慢せず母乳外来へ。MAMOAの「予約」から母乳外来を予約できます。''',
    color: Color(0xFFFDEEF2),
    icon: Icons.water_drop_outlined,
  ),
  Article(
    id: 'a002',
    title: '産後うつのサインと対処法（EPDSの使い方）',
    category: 'こころのケア',
    readMin: '5分',
    body: '''産後は女性ホルモンが急激に変化し、誰にでも気分の落ち込みが起こりえます。「がんばりが足りない」わけでは決してありません。

【受診をおすすめするサイン】
・2週間以上、気分の落ち込みが続く
・眠れない／食欲がない
・赤ちゃんをかわいく思えない
・自分を傷つけたい気持ちが浮かぶ

MAMOAではEPDS（エジンバラ産後うつ病自己評価票）を使って、こころの状態を数値で見られます。9点以上のときは、そのまま助産師へおつなぎします。ひとりで抱えないでください。''',
    color: Color(0xFFF1ECF8),
    icon: Icons.favorite_border_rounded,
  ),
  Article(
    id: 'a003',
    title: '産後の血圧に注意 — 産後子癇前症を見逃さない',
    category: 'からだのケア',
    readMin: '3分',
    body: '''産後6週間までは、血圧が上がる「産後子癇前症」に注意が必要です。分娩後にはじめて発症することもあります。

【すぐ相談したい数値・症状】
・血圧 140/90 mmHg 以上
・強い頭痛、目のちらつき
・みぞおちの痛み、急な浮腫

MAMOAの「健康管理」に血圧を記録すると、基準を超えた時点で助産師へアラートが飛びます。血圧計をお持ちの方は1日1回の測定をおすすめします。''',
    color: Color(0xFFFFF4EC),
    icon: Icons.monitor_heart_outlined,
  ),
  Article(
    id: 'a004',
    title: '夜間授乳を少し楽にする3つの工夫',
    category: '睡眠・休息',
    readMin: '3分',
    body: '''① 「置き場所」をまとめる
おむつ・ガーゼ・水分を手の届く1カ所へ。夜中に立ち上がる回数が減ります。

② 明かりは暖色の間接照明
強い光は赤ちゃんもママも覚醒させます。

③ 日中の20分仮眠
夜まとめて眠れない時期は、細切れでも合計睡眠を確保。赤ちゃんと一緒に横になるだけでも回復します。

つらい日が続くときは、通所・宿泊ケアで「眠る」ことを目的に頼ってください。それは立派なケアの使い方です。''',
    color: Color(0xFFEEF4ED),
    icon: Icons.nightlight_round,
  ),
  Article(
    id: 'a005',
    title: '自治体の産後ケア事業を使いこなす',
    category: '制度・お金',
    readMin: '4分',
    body: '''多くの自治体では、産後ケア（通所・宿泊・訪問）の利用料が助成されます。自己負担が1/3程度になることも珍しくありません。

【一般的な流れ】
1. 自治体に利用申請（産前でも可）
2. 利用可能回数の決定（例：通所4回・宿泊7日）
3. 施設を予約して利用
4. 助成後の自己負担分のみお支払い

MAMOAでは自治体クーポン対応の施設に「自治体助成対象」バッジが付き、助成後の金額が予約画面に表示されます。回数の残りもアプリで管理できます。''',
    color: Color(0xFFFDEEF2),
    icon: Icons.confirmation_number_outlined,
  ),
];

/// 対応ウェアラブル
List<WearableDevice> seedDevices() => [
  WearableDevice(
    id: 'd1',
    name: 'Withings BPM Connect',
    vendor: 'Withings',
    icon: Icons.monitor_heart_outlined,
    metrics: ['血圧', '心拍'],
    connected: true,
  ),
  WearableDevice(
    id: 'd2',
    name: 'Apple Watch',
    vendor: 'Apple HealthKit',
    icon: Icons.watch_outlined,
    metrics: ['心拍', '睡眠', '活動量'],
    connected: true,
  ),
  WearableDevice(
    id: 'd3',
    name: 'Fitbit Inspire',
    vendor: 'Fitbit',
    icon: Icons.fitness_center_outlined,
    metrics: ['睡眠', '歩数'],
  ),
  WearableDevice(
    id: 'd4',
    name: 'Oura Ring',
    vendor: 'Oura',
    icon: Icons.circle_outlined,
    metrics: ['睡眠', '体温'],
  ),
  WearableDevice(
    id: 'd5',
    name: 'Medela 搾乳器',
    vendor: 'Medela',
    icon: Icons.water_drop_outlined,
    metrics: ['搾乳量'],
  ),
];
