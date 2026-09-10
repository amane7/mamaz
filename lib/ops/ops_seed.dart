// ============================================================================
// v2.1 運用マスタ・サンプルデータ（Phase 0 業務設計・データ定義の成果物に相当）
// 個人情報は含めない匿名テストデータ（§13.2）
// ============================================================================

import 'package:flutter/material.dart';
import 'ops_models.dart';

// ---------------------------------------------------------------------------
// 自治体制度マスタ（要件再定義 2026-09：5自治体）
//
// 料金・対象条件・申請方法をコードに直接書かず「有効期間付きルール」として
// 持つ。管理画面から更新でき、版が上がる。公式URL・最終確認日・確認担当を
// 必ず併記する（年度改定の見落とし防止）。
//
// 数値の出典は各自治体公式ページ（2026-09 時点で確認）。要確認事項は
// seedOpenIssues に残し、確認完了まで安全側（前日まで／未確認表示）で判定する。
// ---------------------------------------------------------------------------
final DateTime _fy2026Start = DateTime(2026, 4, 1);
final DateTime _fy2026End = DateTime(2027, 3, 31);
final DateTime _verified = DateTime(2026, 9, 1);

final List<MunicipalityProgram> seedMunicipalities = [
  // 名古屋市 ―― 事業所調整型。妊娠32週から電子申請→2〜3週で決定通知・利用券。
  // 通所2,360円／訪問1,560円。3類型合算7日。5か月以上・多胎児も受入可（ママズケア）。
  MunicipalityProgram(
    id: 'mun_nagoya',
    name: '名古屋市',
    version: 4,
    effectiveFrom: DateTime(2025, 10, 1),
    effectiveTo: _fy2026End,
    lastVerifiedAt: _verified,
    verifiedBy: '運営（南田）',
    sourceUrl: 'https://www.city.nagoya.jp/kodomo/ninshin/1008971/1008978.html',
    sourceRevision: '2025-10-01 利用要件・料金見直し版',
    residencyRequirement: '名古屋市に住民登録のある産後1年未満の母子',
    applicationWindow: '妊娠32週から申請可。決定通知・利用券まで2〜3週間',
    applicationLeadDays: 21,
    applicationMethod: '電子申請（名古屋市電子申請サービス）',
    applicationContact: 'お住まいの区の保健センター',
    scheduling: SchedulingAuthority.provider,
    requiresApproval: true,
    requiresDecisionNotice: true,
    requiresVoucher: true,
    requiresProgramNumber: true,
    maxUseCount: 7,
    useCountRule: '宿泊・通所・訪問の3類型合算で7日まで',
    countsOtherFacilities: true,
    maxChildAgeDays: 364,
    serviceEligibility: const [
      ServiceEligibility(
        service: ProgramServiceType.dayCare,
        maxAgeDaysSingle: 364,
        note: '1歳の誕生日前日まで（FAQ・手引き基準。当日までの表現は要確認）',
      ),
      ServiceEligibility(
        service: ProgramServiceType.outreach,
        maxAgeDaysSingle: 364,
      ),
    ],
    multipleBirthNote: 'ママズケアは5か月以上・多胎児も受入可。利用券は1枚で可、多胎加算なし（訪問）',
    feeRules: const [
      FeeRule(
        service: ProgramServiceType.dayCare,
        taxClass: TaxClass.exempt,
        yen: 0,
        label: '非課税',
      ),
      FeeRule(
        service: ProgramServiceType.dayCare,
        taxClass: TaxClass.welfare,
        yen: 0,
        label: '生活保護',
      ),
      FeeRule(service: ProgramServiceType.dayCare, yen: 2360, label: '通所'),
      FeeRule(
        service: ProgramServiceType.outreach,
        taxClass: TaxClass.exempt,
        yen: 0,
        label: '非課税',
      ),
      FeeRule(
        service: ProgramServiceType.outreach,
        taxClass: TaxClass.welfare,
        yen: 0,
        label: '生活保護',
      ),
      FeeRule(service: ProgramServiceType.outreach, yen: 1560, label: '訪問'),
    ],
    cancelRule: const MunicipalCancelRule(
      verified: true,
      feeYen: 0,
      note: '自治体側の規定なし。事業所規定（版管理）を適用',
    ),
    selfPaySwitchNote: '利用券未取得・7日超過・1歳到達後は自費でのご利用をご案内',
    requiredDocs: const ['母子健康手帳', '利用決定通知書', '利用券'],
    bookingEnabled: true,
  ),

  // 尾張旭市 ―― 事前申込みが必要。まず市のこども家庭センターへ。
  // 単胎は産後1年未満、双子・三つ子は産後7か月未満。
  // 課税世帯 1〜5日目：通所1,250／訪問500、6日目以降：3,750／3,000。
  MunicipalityProgram(
    id: 'mun_owariasahi',
    name: '尾張旭市',
    version: 2,
    effectiveFrom: _fy2026Start,
    effectiveTo: _fy2026End,
    lastVerifiedAt: _verified,
    verifiedBy: '運営（南田）',
    sourceUrl: 'https://www.city.owariasahi.lg.jp/',
    sourceRevision: '令和8年度版',
    residencyRequirement: '尾張旭市に住民登録のある母子',
    applicationWindow: '利用前に事前申込み。まず市へ問い合わせ',
    applicationLeadDays: 7,
    applicationMethod: '窓口・電話（要事前相談）',
    applicationContact: '尾張旭市こども家庭センター',
    scheduling: SchedulingAuthority.shared,
    requiresApproval: true,
    requiresDecisionNotice: true,
    requiresProgramNumber: false,
    maxUseCount: 7,
    useCountRule: '通所・訪問合算。6日目以降は料金が上がる',
    countsOtherFacilities: true,
    maxChildAgeDays: 364,
    serviceEligibility: const [
      ServiceEligibility(
        service: ProgramServiceType.dayCare,
        maxAgeDaysSingle: 364,
        maxAgeDaysMultiple: 213,
        note: '単胎：産後1年未満／双子・三つ子：産後7か月未満',
      ),
      ServiceEligibility(
        service: ProgramServiceType.outreach,
        maxAgeDaysSingle: 364,
        maxAgeDaysMultiple: 213,
      ),
    ],
    multipleBirthNote: '双子・三つ子は産後7か月未満が対象',
    feeRules: const [
      FeeRule(
        service: ProgramServiceType.dayCare,
        taxClass: TaxClass.exempt,
        yen: 0,
      ),
      FeeRule(
        service: ProgramServiceType.dayCare,
        taxClass: TaxClass.welfare,
        yen: 0,
      ),
      FeeRule(
        service: ProgramServiceType.dayCare,
        taxClass: TaxClass.taxable,
        fromUse: 1,
        toUse: 5,
        yen: 1250,
      ),
      FeeRule(
        service: ProgramServiceType.dayCare,
        taxClass: TaxClass.taxable,
        fromUse: 6,
        yen: 3750,
      ),
      FeeRule(
        service: ProgramServiceType.outreach,
        taxClass: TaxClass.exempt,
        yen: 0,
      ),
      FeeRule(
        service: ProgramServiceType.outreach,
        taxClass: TaxClass.welfare,
        yen: 0,
      ),
      FeeRule(
        service: ProgramServiceType.outreach,
        taxClass: TaxClass.taxable,
        fromUse: 1,
        toUse: 5,
        yen: 500,
      ),
      FeeRule(
        service: ProgramServiceType.outreach,
        taxClass: TaxClass.taxable,
        fromUse: 6,
        yen: 3000,
      ),
    ],
    cancelRule: const MunicipalCancelRule(
      verified: false,
      note: 'キャンセル料と予約確定主体が公開ページだけでは判断できない',
    ),
    selfPaySwitchNote: '対象月齢超過・回数超過は自費案内',
    requiredDocs: const ['母子健康手帳', '利用承認通知'],
    bookingEnabled: false, // 制度案内のみ（MVP は名古屋市から）
  ),

  // 長久手市 ―― 利用日の1週間前までに申請→承認通知・クーポン→市または事業者から日程連絡。
  // 通所：クーポン利用1,000円／未利用3,500円。前日17時以降キャンセル1,650円。
  MunicipalityProgram(
    id: 'mun_nagakute',
    name: '長久手市',
    version: 3,
    effectiveFrom: _fy2026Start,
    effectiveTo: _fy2026End,
    lastVerifiedAt: DateTime(2026, 8, 17),
    verifiedBy: '運営（南田）',
    sourceUrl:
        'https://www.city.nagakute.lg.jp/soshiki/kodomobu/kodomokateika/1/boshihoken/21513.html',
    sourceRevision: '2026-08-17 更新版（Excel出典欄の4/2更新は差し替え要）',
    residencyRequirement: '長久手市に住民登録のある母子',
    applicationWindow: '利用日の1週間前まで（土日祝を除く）。承認通知・クーポン発行に1週間程度',
    applicationLeadDays: 7,
    applicationMethod: '窓口・電子申請',
    applicationContact: '子ども家庭課 母子保健係',
    scheduling: SchedulingAuthority.shared,
    requiresApproval: true,
    requiresDecisionNotice: true,
    requiresCoupon: true,
    requiresProgramNumber: false,
    maxUseCount: 7,
    useCountRule: 'クーポン枚数まで1,000円。未利用は3,500円',
    countsOtherFacilities: false,
    maxChildAgeDays: 364,
    serviceEligibility: const [
      ServiceEligibility(
        service: ProgramServiceType.dayCare,
        maxAgeDaysSingle: 364,
        note: 'ママズケアは通所型のみ受託',
      ),
    ],
    feeRules: const [
      FeeRule(
        service: ProgramServiceType.dayCare,
        taxClass: TaxClass.exempt,
        yen: 0,
      ),
      FeeRule(
        service: ProgramServiceType.dayCare,
        taxClass: TaxClass.welfare,
        yen: 0,
      ),
      FeeRule(
        service: ProgramServiceType.dayCare,
        couponUsed: true,
        yen: 1000,
        label: 'クーポン利用',
      ),
      FeeRule(
        service: ProgramServiceType.dayCare,
        couponUsed: false,
        yen: 3500,
        label: 'クーポン未利用',
      ),
    ],
    cancelRule: const MunicipalCancelRule(
      verified: true,
      deadlineHourDayBefore: 17,
      feeYen: 1650,
      note: '前日17時以降のキャンセルは1,650円',
    ),
    selfPaySwitchNote: 'クーポンが無い場合は3,500円（制度内の未利用料金）。対象外は自費',
    requiredDocs: const ['母子健康手帳', '利用承認通知書', 'クーポン券'],
    bookingEnabled: false,
  ),

  // 瀬戸市 ―― 電子・書面申請→市と施設が日程調整→市から利用者へ連絡。
  // 通所 1〜5日目1,500円／6〜7日目4,000円。双子 1,800円／4,300円。訪問2回まで無料。
  MunicipalityProgram(
    id: 'mun_seto',
    name: '瀬戸市',
    version: 3,
    effectiveFrom: _fy2026Start,
    effectiveTo: _fy2026End,
    lastVerifiedAt: DateTime(2026, 6, 1),
    verifiedBy: '運営（南田）',
    sourceUrl:
        'https://www.city.seto.aichi.jp/docs/2023/08/14/008533685/008533685.html',
    sourceRevision: '2026-06-01 更新版',
    residencyRequirement: '瀬戸市に住民登録のある母子',
    applicationWindow: '利用前に申請。市と施設が日程調整後、市から連絡',
    applicationLeadDays: 7,
    applicationMethod: '電子申請・書面',
    applicationContact: '瀬戸市 こども家庭センター',
    scheduling: SchedulingAuthority.municipality,
    requiresApproval: true,
    requiresDecisionNotice: true,
    requiresProgramNumber: false,
    maxUseCount: 7,
    useCountRule: '通所7日まで（他施設利用分を含む）。訪問は2回まで無料',
    countsOtherFacilities: true,
    maxChildAgeDays: 364,
    serviceEligibility: const [
      ServiceEligibility(
        service: ProgramServiceType.dayCare,
        maxAgeDaysSingle: 364,
      ),
      ServiceEligibility(
        service: ProgramServiceType.outreach,
        maxAgeDaysSingle: 364,
      ),
    ],
    multipleBirthNote: '双子は通所料金が別段階（1,800円／4,300円）',
    feeRules: const [
      FeeRule(
        service: ProgramServiceType.dayCare,
        taxClass: TaxClass.exempt,
        yen: 0,
      ),
      FeeRule(
        service: ProgramServiceType.dayCare,
        taxClass: TaxClass.welfare,
        yen: 0,
      ),
      FeeRule(
        service: ProgramServiceType.dayCare,
        plurality: 2,
        fromUse: 1,
        toUse: 5,
        yen: 1800,
        label: '双子',
      ),
      FeeRule(
        service: ProgramServiceType.dayCare,
        plurality: 2,
        fromUse: 6,
        toUse: 7,
        yen: 4300,
        label: '双子',
      ),
      FeeRule(
        service: ProgramServiceType.dayCare,
        fromUse: 1,
        toUse: 5,
        yen: 1500,
      ),
      FeeRule(
        service: ProgramServiceType.dayCare,
        fromUse: 6,
        toUse: 7,
        yen: 4000,
      ),
      FeeRule(
        service: ProgramServiceType.outreach,
        fromUse: 1,
        toUse: 2,
        yen: 0,
        label: '2回まで無料',
      ),
    ],
    cancelRule: const MunicipalCancelRule(
      verified: false,
      note: '市のキャンセル規定を確認中',
    ),
    selfPaySwitchNote: '通所8日目以降・訪問3回目以降は自費案内',
    requiredDocs: const ['母子健康手帳', '利用決定通知書'],
    bookingEnabled: false,
  ),

  // 小牧市 ―― 申請→保健師・助産師による確認→市と施設が調整。原則、利用希望日の6日前まで。
  // 課税世帯：デイケア2,000円／アウトリーチ1,000円。3類型合算7日。
  MunicipalityProgram(
    id: 'mun_komaki',
    name: '小牧市',
    version: 2,
    effectiveFrom: _fy2026Start,
    effectiveTo: _fy2026End,
    lastVerifiedAt: _verified,
    verifiedBy: '運営（南田）',
    sourceUrl: 'https://www.city.komaki.lg.jp/',
    sourceRevision: '令和8年度版',
    residencyRequirement: '小牧市に住民登録のある母子',
    applicationWindow: '原則、利用希望日の6日前まで。保健師・助産師による確認あり',
    applicationLeadDays: 6,
    applicationMethod: '窓口・電子申請',
    applicationContact: '小牧市 こども家庭センター',
    scheduling: SchedulingAuthority.municipality,
    requiresApproval: true,
    requiresDecisionNotice: true,
    requiresProgramNumber: false,
    maxUseCount: 7,
    useCountRule: '宿泊・通所・訪問の3類型合算で7日まで',
    countsOtherFacilities: true,
    maxChildAgeDays: 364,
    serviceEligibility: const [
      ServiceEligibility(
        service: ProgramServiceType.dayCare,
        maxAgeDaysSingle: 364,
        note: 'ママズケア固有の対象月齢は追加確認',
      ),
      ServiceEligibility(
        service: ProgramServiceType.outreach,
        maxAgeDaysSingle: 364,
      ),
    ],
    feeRules: const [
      FeeRule(
        service: ProgramServiceType.dayCare,
        taxClass: TaxClass.exempt,
        yen: 0,
      ),
      FeeRule(
        service: ProgramServiceType.dayCare,
        taxClass: TaxClass.welfare,
        yen: 0,
      ),
      FeeRule(
        service: ProgramServiceType.dayCare,
        taxClass: TaxClass.taxable,
        yen: 2000,
      ),
      FeeRule(
        service: ProgramServiceType.outreach,
        taxClass: TaxClass.exempt,
        yen: 0,
      ),
      FeeRule(
        service: ProgramServiceType.outreach,
        taxClass: TaxClass.welfare,
        yen: 0,
      ),
      FeeRule(
        service: ProgramServiceType.outreach,
        taxClass: TaxClass.taxable,
        yen: 1000,
      ),
    ],
    cancelRule: const MunicipalCancelRule(
      verified: false,
      note: 'ママズケア固有のキャンセル料・請求運用を追加確認',
    ),
    selfPaySwitchNote: '行政審査前の予約確定は不可。対象外は自費案内',
    requiredDocs: const ['母子健康手帳', '利用決定通知書'],
    bookingEnabled: false,
  ),
];

// ---------------------------------------------------------------------------
// 現時点で残っている要確認事項・次回南田さんに確認すべきこと（データとして持つ）
// ---------------------------------------------------------------------------
List<OpenIssue> seedOpenIssues() => [
  OpenIssue(
    id: 'iss_nagoya_birthday',
    municipalityId: 'mun_nagoya',
    title: '利用期限「1歳の誕生日前日まで」か「当日まで」か',
    detail: '公式FAQ・事業者手引きは前日まで、公式ページの事業者向け注意は当日まで。確認完了までは前日までで判定する。',
    owner: '運営',
  ),
  OpenIssue(
    id: 'iss_owariasahi_cancel',
    municipalityId: 'mun_owariasahi',
    title: 'キャンセル料と予約確定主体',
    detail: '公開ページだけでは判断できない。市へ確認。',
    owner: '運営',
  ),
  OpenIssue(
    id: 'iss_komaki_detail',
    municipalityId: 'mun_komaki',
    title: 'ママズケア固有の対象月齢・キャンセル料・請求運用',
    detail: '市の委託条件と実務を追加確認。',
    owner: '運営',
  ),
  OpenIssue(
    id: 'iss_nagakute_source',
    municipalityId: 'mun_nagakute',
    title: '出典の更新日を差し替え',
    detail: '公式ページは2026-08-17更新。添付Excel出典欄の「4月2日更新」は更新が必要。',
    owner: '運営',
  ),
  OpenIssue(
    id: 'q01',
    title: '初期リリースは名古屋市だけか、5自治体すべてか',
    detail: '推奨：5自治体の制度案内に対応し、予約機能は名古屋市から。',
    owner: '南田さん',
  ),
  OpenIssue(
    id: 'q02',
    title: '自治体ごとの現在の実務（電話・LINE・STORES・市役所からの連絡の順番）',
    detail: '誰がどの順番で行っているか。',
    owner: '南田さん',
  ),
  OpenIssue(
    id: 'q03',
    title: '利用前に確認している書類',
    detail: '決定通知・利用券・クーポンのどこを確認・記録しているか。',
    owner: '南田さん',
  ),
  OpenIssue(
    id: 'q04',
    title: '他施設での利用回数の確認方法',
    detail: '特に瀬戸市の6回目以降の料金計算に必要。',
    owner: '南田さん',
  ),
  OpenIssue(
    id: 'q05',
    title: '多胎児の実際の受入条件',
    detail: '必要な助産師数、対応月齢、通所・訪問時間、同時受入人数。',
    owner: '南田さん',
  ),
  OpenIssue(
    id: 'q06',
    title: '即時確定できない予約の扱い',
    detail: '仮予約の保持時間、承認者、利用者への回答期限。',
    owner: '南田さん',
  ),
  OpenIssue(
    id: 'q07',
    title: '自治体制度外の自費サービスへの切替',
    detail: '対象外、回数超過、利用券未取得の場合に案内するか。',
    owner: '南田さん',
  ),
  OpenIssue(
    id: 'q08',
    title: 'キャンセル料の徴収方法',
    detail: 'STORES決済、現地支払、振込、未払い管理のどれか。',
    owner: '南田さん',
  ),
  OpenIssue(
    id: 'q09',
    title: '自治体請求・実績報告の現在の作業',
    detail: '月次報告、利用券回収、請求書作成のどこまでMAMOAで支援するか。',
    owner: '南田さん',
  ),
  OpenIssue(
    id: 'q10',
    title: '自治体マスタの更新責任者',
    detail: '年度改定を誰が確認し、誰が公開承認するか。',
    owner: '南田さん',
  ),
];

// ---------------------------------------------------------------------------
// キャンセル規定（付録C.5：固定実装せず版番号＋適用開始日で管理）
// ---------------------------------------------------------------------------
final List<CancelPolicy> seedCancelPolicies = [
  CancelPolicy(
    id: 'cp_standard',
    name: '通常キャンセル規定',
    version: 4,
    effectiveFrom: DateTime(2026, 4, 1),
    changeDeadlineHours: 55, // 2日前17時相当
    tiers: const [
      CancelTier('2日前17時まで', 55, 0),
      CancelTier('前日17時まで', 31, 5000),
      CancelTier('前日17時以降', 0, 10000),
    ],
    fullText: '''
【通常キャンセル規定 v4】
1. ご利用日の2日前17時までのお取消しは、キャンセル料はかかりません。
2. 前日17時までのお取消しは、5,000円をご負担いただきます。
3. 前日17時以降・当日のお取消しは、10,000円をご負担いただきます。
4. ご利用時間の変更は、2日前17時まで承ります。
5. 体調不良・お子さまの急な発熱など、やむを得ない事情の場合はご相談ください。
   状況に応じて減免を検討いたします。
6. 本規定は予約確定時点の版が適用され、以後の改定が過去のご予約に影響することはありません。
''',
  ),
  CancelPolicy(
    id: 'cp_day2h',
    name: '通所2時間キャンセル規定',
    version: 4,
    effectiveFrom: DateTime(2026, 4, 1),
    changeDeadlineHours: 55,
    tiers: const [
      CancelTier('2日前17時まで', 55, 0),
      CancelTier('前日17時まで', 31, 3400),
      CancelTier('前日17時以降', 0, 6800),
    ],
    fullText: '''
【通所2時間キャンセル規定 v4】
1. ご利用日の2日前17時までのお取消しは無料です。
2. 前日17時までのお取消しは3,400円。
3. 前日17時以降・当日のお取消しは6,800円。
4. ご利用時間の変更は2日前17時まで承ります。
5. 本規定は予約確定時点の版が適用されます。
''',
  ),
];

// ---------------------------------------------------------------------------
// 利用規約（版管理・要点＋全文）
// ---------------------------------------------------------------------------
final List<TermsDoc> seedTerms = [
  TermsDoc(
    id: 'terms_care',
    title: '産後ケアサービス利用規約',
    version: 5,
    revisedAt: DateTime(2026, 6, 1),
    keyPoints: const [
      'ケアの内容は、助産師がお母さまとお子さまの状態を見ながら一緒に決めていきます。',
      '医療行為（診断・治療・処方）は行いません。必要なときは医療機関をご案内します。',
      'お預かりした健康情報は、ケアの提供と安全確認のためだけに使用します。',
      '記録は5年間保管し、ご本人のご請求で開示・訂正・削除を承ります。',
      'キャンセル規定は予約確定時点の版が適用されます。',
      'ご利用中に撮影した写真は、ご同意のない限り第三者へ提供しません。',
    ],
    fullText: '''
第1条（目的）
本規約は、ママズケアが提供する産後ケアサービス（訪問・通所・宿泊・母乳外来）の
ご利用条件を定めるものです。

第2条（サービスの内容と限界）
1. 本サービスは、助産師による産後の心身のケア、授乳・育児に関する相談支援を行います。
2. 本サービスは医療行為（診断・治療・投薬）を行いません。
3. 助産師が医療機関の受診が望ましいと判断した場合は、速やかにご案内します。
4. 緊急性が疑われる場合は、救急要請を含む適切な対応を優先します。

第3条（お預かりする情報）
1. 母子の氏名・生年月日・連絡先・住所、健康状態、相談内容をお預かりします。
2. 健康に関する情報は「要配慮個人情報」として、通常より厳格に取り扱います。
3. 利用目的は、ケアの提供、安全確認、自治体への実績報告（法令に基づく範囲）に限ります。
4. ご本人の同意なく第三者へ提供しません。委託先には同等の安全管理を義務付けます。

第4条（保存期間と開示）
1. ケア記録は最終利用日から5年間保管します。
2. ご本人のご請求により、開示・訂正・利用停止・削除に対応します。

第5条（予約・変更・キャンセル）
1. 予約は所定の手続きにより確定します。
2. 変更・キャンセルは、予約確定時点のキャンセル規定の版に従います。
3. やむを得ない事情の場合は、減免を個別に検討します。

第6条（安全上のお願い）
1. 発熱、強い痛み、出血など気になる症状がある場合は、事前にお知らせください。
2. 感染症の疑いがある場合は、ご利用日程の調整をご相談ください。

第7条（規約の改定）
1. 本規約を改定する場合、適用開始日と版番号を明示します。
2. 改定は、既に確定したご予約の条件を変更しません。
''',
  ),
  TermsDoc(
    id: 'terms_privacy',
    title: '個人情報の取扱いについて',
    version: 3,
    revisedAt: DateTime(2026, 6, 1),
    keyPoints: const [
      '健康に関する情報は「要配慮個人情報」として厳格に管理します。',
      '閲覧できるのは、担当する助産師と必要最小限の職員だけです。',
      '誰がいつ見たかは、すべて監査ログに記録されます。',
      'ご本人のご請求で、開示・訂正・削除に対応します。',
    ],
    fullText: '''
1. 取得する情報
   母子の氏名、ふりがな、生年月日、電話番号、住所、緊急連絡先、
   健康状態、授乳状況、相談内容、自治体の利用番号。

2. 利用目的
   (1) 産後ケアサービスの提供および安全確認
   (2) 予約・変更・キャンセルのご連絡
   (3) 自治体制度に基づく利用実績の報告
   (4) サービス品質の改善（個人が特定されない形での集計）

3. 要配慮個人情報の取扱い
   健康に関する情報は、担当案件に限定した最小権限で管理します。
   システム管理者は原則として健康内容を閲覧しません。
   アクセスはすべて追記専用の監査ログに記録されます。

4. 保存期間
   ケア記録は最終利用日から5年間。それ以降は安全に削除します。

5. 第三者提供・委託
   ご本人の同意または法令に基づく場合を除き、第三者へ提供しません。
   委託先には同等の安全管理措置を契約で義務付けます。

6. ご本人の権利
   開示、訂正、追加、削除、利用停止のご請求に対応します。
''',
  ),
];

// ---------------------------------------------------------------------------
// サービス定義（版管理・必要スキル・所要時間・移動・バッファ）
// ---------------------------------------------------------------------------
final List<ServiceDef> seedServices = [
  ServiceDef(
    id: 'svc_visit3',
    name: '訪問ケア（3時間）',
    kind: ServiceKind.visit,
    durationMin: 180,
    requiredSkills: const {'助産師免許', '訪問対応'},
    maxChildAgeDays: 365,
    bathEligible: true,
    travelMin: 30,
    bufferMin: 15,
    priceYen: 12000,
    cancelPolicyId: 'cp_standard',
    version: 3,
    effectiveFrom: DateTime(2026, 4, 1),
    planGroupId: 'plan_visit',
    planLabel: 'ゆっくり3時間',
    // §4 産後ケアは月齢・多胎・訪問場所・自治体条件・受入状況の
    // 確認が要るため、初期運用はスタッフ確認型にする。
    // 条件の精度が上がれば管理画面から INSTANT へ変えられる（§3）。
    bookingMode: BookingMode.requestApproval,
    startIntervalMinutes: 30,
    description: 'ご自宅・ご実家に助産師がうかがい、休養・授乳相談・沐浴をお手伝いします。',
    needTags: ['休みたい', '授乳を相談したい', '沐浴を手伝ってほしい', '外出がむずかしい'],
  ),
  ServiceDef(
    id: 'svc_visit2',
    name: '訪問ケア（2時間）',
    kind: ServiceKind.visit,
    durationMin: 120,
    requiredSkills: const {'助産師免許', '訪問対応'},
    maxChildAgeDays: 365,
    travelMin: 30,
    bufferMin: 15,
    priceYen: 8500,
    cancelPolicyId: 'cp_standard',
    version: 3,
    effectiveFrom: DateTime(2026, 4, 1),
    planGroupId: 'plan_visit',
    planLabel: 'コンパクト2時間',
    // §4 産後ケアは月齢・多胎・訪問場所・自治体条件・受入状況の
    // 確認が要るため、初期運用はスタッフ確認型にする。
    // 条件の精度が上がれば管理画面から INSTANT へ変えられる（§3）。
    bookingMode: BookingMode.requestApproval,
    startIntervalMinutes: 30,
    description: '短時間で授乳・体調のご相談に集中したい方へ。',
    needTags: ['授乳を相談したい', '体の回復が気になる', '外出がむずかしい'],
  ),
  ServiceDef(
    id: 'svc_day4',
    name: '通所ケア（4時間・食事付き）',
    kind: ServiceKind.dayStay,
    durationMin: 240,
    requiredSkills: const {'助産師免許'},
    maxChildAgeDays: 365,
    mealEligible: true,
    bathEligible: true,
    bufferMin: 20,
    priceYen: 14000,
    cancelPolicyId: 'cp_standard',
    version: 3,
    effectiveFrom: DateTime(2026, 4, 1),
    planGroupId: 'plan_day',
    planLabel: '1日ゆったり（食事つき）',
    // §4 産後ケアは月齢・多胎・訪問場所・自治体条件・受入状況の
    // 確認が要るため、初期運用はスタッフ確認型にする。
    // 条件の精度が上がれば管理画面から INSTANT へ変えられる（§3）。
    bookingMode: BookingMode.requestApproval,
    startIntervalMinutes: 30,
    requiredResourceKinds: {ResourceKind.room},
    description: 'ケアルームでゆっくりお過ごしいただきます。お食事とお昼寝の時間つき。',
    needTags: ['休みたい', 'ひとりで眠りたい', '食事をとりたい', '沐浴を手伝ってほしい'],
  ),
  ServiceDef(
    id: 'svc_day2',
    name: '通所ケア（2時間）',
    kind: ServiceKind.dayStay,
    durationMin: 120,
    requiredSkills: const {'助産師免許'},
    maxChildAgeDays: 365,
    bufferMin: 20,
    priceYen: 7000,
    cancelPolicyId: 'cp_day2h',
    version: 3,
    effectiveFrom: DateTime(2026, 4, 1),
    planGroupId: 'plan_day',
    planLabel: '半日2時間',
    // §4 産後ケアは月齢・多胎・訪問場所・自治体条件・受入状況の
    // 確認が要るため、初期運用はスタッフ確認型にする。
    // 条件の精度が上がれば管理画面から INSTANT へ変えられる（§3）。
    bookingMode: BookingMode.requestApproval,
    startIntervalMinutes: 30,
    description: '短時間の通所。お話とケアだけを、ぎゅっと。',
    needTags: ['話をきいてほしい', '授乳を相談したい'],
  ),
  ServiceDef(
    id: 'svc_breast',
    name: '母乳外来（60分）',
    kind: ServiceKind.breastClinic,
    durationMin: 60,
    requiredSkills: const {'助産師免許', '母乳ケア'},
    maxChildAgeDays: 365,
    bufferMin: 15,
    priceYen: 5500,
    cancelPolicyId: 'cp_day2h',
    version: 3,
    effectiveFrom: DateTime(2026, 4, 1),
    planGroupId: 'plan_breast',
    planLabel: '60分',
    // §4 母乳外来は条件が単純なので即時確定でよい。
    // §12 所要60分でも開始は30分刻み（09:00/09:30/10:00…）。
    bookingMode: BookingMode.instant,
    startIntervalMinutes: 30,
    description: '乳房の張り・痛み・しこり、母乳量のご相談。専門の助産師が担当します。',
    needTags: ['授乳を相談したい', '乳房が痛い', '卒乳を考えている'],
  ),
  ServiceDef(
    id: 'svc_stay',
    name: '宿泊ケア（1泊2日）',
    kind: ServiceKind.stay,
    durationMin: 1440,
    requiredSkills: const {'助産師免許', '宿泊対応'},
    maxChildAgeDays: 180,
    mealEligible: true,
    bathEligible: true,
    bufferMin: 30,
    priceYen: 32000,
    cancelPolicyId: 'cp_standard',
    version: 3,
    effectiveFrom: DateTime(2026, 4, 1),
    planGroupId: 'plan_stay',
    planLabel: '1泊2日',
    // §4 産後ケアは月齢・多胎・訪問場所・自治体条件・受入状況の
    // 確認が要るため、初期運用はスタッフ確認型にする。
    // 条件の精度が上がれば管理画面から INSTANT へ変えられる（§3）。
    bookingMode: BookingMode.requestApproval,
    startIntervalMinutes: 30,
    requiredResourceKinds: {ResourceKind.room},
    description: '夜間もお預かりし、まとまった睡眠をとっていただきます。',
    needTags: ['休みたい', 'ひとりで眠りたい', '夜がつらい'],
  ),
];

// ---------------------------------------------------------------------------
// 施設
// ---------------------------------------------------------------------------
const List<OpsFacility> seedOpsFacilities = [
  OpsFacility(
    id: 'fac_sakura',
    name: 'ママズケア 名古屋院',
    area: 'area_sakura',
    rooms: 4,
    concurrentCapacity: 3,
    mealCutoffHours: 48,
    access: '地下鉄 徒歩6分／駐車場3台',
    serviceKinds: {
      ServiceKind.dayStay,
      ServiceKind.visit,
      ServiceKind.stay,
      ServiceKind.breastClinic,
    },
    maxChildAgeDays: 364,
    acceptsMultiples: true,
    multipleStaffRequired: 2,
    visitAreas: {'area_sakura', 'area_midori'},
    siblingAllowed: true,
    familyAllowed: true,
    parkingSpaces: 3,
    pickupAvailable: false,
    bringItems: ['母子健康手帳', '利用券・決定通知', 'おむつ・着替え', '授乳用品'],
    paymentMethods: ['現地（現金・PayPay）', 'STORES決済'],
    paidOptions: ['骨盤ケア', 'ベビーマッサージ', 'お食事追加'],
  ),
  OpsFacility(
    id: 'fac_midori',
    name: 'ママズケア 長久手院',
    area: 'area_midori',
    rooms: 2,
    concurrentCapacity: 2,
    mealCutoffHours: 48,
    access: 'リニモ 徒歩3分／駐車場2台',
    serviceKinds: {
      ServiceKind.dayStay,
      ServiceKind.stay,
      ServiceKind.breastClinic,
    },
    maxChildAgeDays: 364,
    acceptsMultiples: true,
    multipleStaffRequired: 2,
    visitAreas: {'area_midori', 'area_hinata'},
    siblingAllowed: false,
    familyAllowed: true,
    parkingSpaces: 2,
    pickupAvailable: false,
    bringItems: ['母子健康手帳', 'クーポン券', 'おむつ・着替え'],
    paymentMethods: ['現地（現金）', 'STORES決済'],
    paidOptions: ['お食事追加'],
  ),
];

// ---------------------------------------------------------------------------
// スタッフ（スキル・対応サービス・エリア・上限）
// ---------------------------------------------------------------------------
const List<OpsStaff> seedStaff = [
  OpsStaff(
    id: 'st_sato',
    name: '佐藤 みどり',
    skills: {'助産師免許', '母乳ケア', '訪問対応', '宿泊対応', 'メンタルケア'},
    services: {
      ServiceKind.visit,
      ServiceKind.dayStay,
      ServiceKind.stay,
      ServiceKind.breastClinic,
    },
    areas: {'area_sakura', 'area_midori'},
    facilityIds: {'fac_sakura', 'fac_midori'},
    bufferMin: 15,
    dailyMaxMin: 420,
    consecutiveMax: 3,
    color: Color(0xFFF49BB8),
  ),
  OpsStaff(
    id: 'st_tanaka',
    name: '田中 あゆみ',
    skills: {'助産師免許', '母乳ケア', '訪問対応'},
    services: {
      ServiceKind.visit,
      ServiceKind.dayStay,
      ServiceKind.breastClinic,
    },
    areas: {'area_sakura'},
    facilityIds: {'fac_sakura'},
    bufferMin: 20,
    dailyMaxMin: 360,
    consecutiveMax: 2,
    color: Color(0xFFC9BEE6),
  ),
  OpsStaff(
    id: 'st_kimura',
    name: '木村 のぞみ',
    skills: {'助産師免許', '訪問対応', 'メンタルケア'},
    services: {ServiceKind.visit, ServiceKind.dayStay},
    areas: {'area_midori', 'area_hinata'},
    facilityIds: {'fac_midori'},
    bufferMin: 15,
    dailyMaxMin: 420,
    consecutiveMax: 3,
    color: Color(0xFFB7D0B5),
  ),
  OpsStaff(
    id: 'st_ono',
    name: '小野 かおる',
    skills: {'助産師免許', '母乳ケア', '宿泊対応'},
    services: {ServiceKind.dayStay, ServiceKind.stay, ServiceKind.breastClinic},
    areas: {'area_sakura'},
    facilityIds: {'fac_sakura'},
    bufferMin: 15,
    dailyMaxMin: 480,
    consecutiveMax: 4,
    color: Color(0xFFF6E2A8),
  ),
];

// ---------------------------------------------------------------------------
// 赤旗ルール（E-01：診断せず、定義済み質問のみ）
// ---------------------------------------------------------------------------
const List<RedFlagRule> seedRedFlags = [
  RedFlagRule(
    key: 'fever',
    question: '38.0℃以上の熱がありますか',
    hint: 'お母さま・お子さまのどちらでも',
    reasonCode: 'RF-FEVER',
    urgent: true,
  ),
  RedFlagRule(
    key: 'breast_pain',
    question: '乳房の強い痛み・赤み・しこりがありますか',
    hint: '触ると熱い、ズキズキするなど',
    reasonCode: 'RF-BREAST',
    urgent: true,
  ),
  RedFlagRule(
    key: 'bleeding',
    question: '出血が増えている、または止まりませんか',
    hint: '大きな血のかたまりが出るなど',
    reasonCode: 'RF-BLEED',
    urgent: true,
  ),
  RedFlagRule(
    key: 'infection',
    question: 'ご家族に感染症の疑いがありますか',
    hint: 'インフルエンザ・胃腸炎など',
    reasonCode: 'RF-INFECT',
  ),
  RedFlagRule(
    key: 'baby_weight',
    question: '赤ちゃんの体重が増えていないと感じますか',
    hint: '母乳やミルクの量が心配なとき',
    reasonCode: 'RF-WEIGHT',
  ),
  RedFlagRule(
    key: 'mood',
    question: '気持ちが落ち込んで、つらい時間が続いていますか',
    hint: 'ひとりで抱えなくて大丈夫です',
    reasonCode: 'RF-MOOD',
    urgent: true,
  ),
];

// ---------------------------------------------------------------------------
// ニーズ（C-05：目的から候補提示）
// ---------------------------------------------------------------------------
class NeedTag {
  final String label;
  final String hint;
  final IconData icon;
  const NeedTag(this.label, this.hint, this.icon);
}

const List<NeedTag> seedNeeds = [
  NeedTag('休みたい', 'すこしでも横になりたい', Icons.bedtime_outlined),
  NeedTag('ひとりで眠りたい', 'まとまった睡眠をとりたい', Icons.hotel_outlined),
  NeedTag('授乳を相談したい', '出方・量・くわえ方など', Icons.water_drop_outlined),
  NeedTag('乳房が痛い', '張り・しこり・痛みがある', Icons.healing_outlined),
  NeedTag('卒乳を考えている', '進め方を相談したい', Icons.spa_outlined),
  NeedTag('沐浴を手伝ってほしい', 'まだ少し不安がある', Icons.bathtub_outlined),
  NeedTag('体の回復が気になる', '傷・血圧・悪露など', Icons.monitor_heart_outlined),
  NeedTag('話をきいてほしい', 'まとまらなくても大丈夫', Icons.chat_bubble_outline_rounded),
  NeedTag('夜がつらい', '夜間の対応がしんどい', Icons.nightlight_outlined),
  NeedTag('食事をとりたい', '温かいごはんを食べたい', Icons.restaurant_outlined),
  NeedTag('外出がむずかしい', '来所が難しい状況', Icons.home_outlined),
];

// ---------------------------------------------------------------------------
// サンプル顧客（匿名テストデータ）
// ---------------------------------------------------------------------------
OpsCustomer seedCustomer() {
  final now = DateTime.now();
  return OpsCustomer(
    id: 'cus_001',
    lineUserId: 'U_sample_line_id',
    nameKanji: '山田 さくら',
    nameKana: 'ヤマダ サクラ',
    birth: DateTime(1994, 5, 12),
    phone: '09012345678',
    emergencyContact: '090-8888-7777（夫）',
    children: [
      OpsChild(
        id: 'ch_001',
        name: '山田 そら',
        kana: 'ヤマダ ソラ',
        birth: now.subtract(const Duration(days: 22)),
        birthOrder: 1,
      ),
    ],
    address: const OpsAddress(
      postal: '464-0000',
      city: '名古屋市千種区',
      line1: '桜台2-14-3',
      building: 'さくらレジデンス',
      room: '502',
      parkingOnSite: true,
      areaCode: 'area_sakura',
    ),
    municipalityId: 'mun_nagoya',
    programNumber: 'NG-2026-0481',
    usedCount: 2,
    isReturning: true,
    // 名古屋市：電子申請済み → 決定通知・利用券を受領し、スタッフが確認済み
    application: MunicipalApplication(
      status: ApplicationStatus.approved,
      voucherNumber: 'NG-2026-0481',
      appliedAt: DateTime(now.year, now.month - 2, 10),
      approvedAt: DateTime(now.year, now.month - 1, 2),
      decisionNoticeChecked: true,
      voucherChecked: true,
      taxClass: TaxClass.taxable,
      otherFacilityUses: 0,
    ),
  );
}

// ---------------------------------------------------------------------------
// 初期OK／NG時間（助産師が登録済みの状態を再現）
// ---------------------------------------------------------------------------
List<StaffAvailability> seedAvailability() {
  final now = DateTime.now();
  final out = <StaffAvailability>[];
  var n = 0;
  String id() => 'av_${n++}';

  // 毎週の基本パターン
  void weekly(String staffId, List<int> days, int s, int e, AvailKind k) {
    for (final d in days) {
      out.add(
        StaffAvailability(
          id: id(),
          staffId: staffId,
          weekday: d,
          startMin: s,
          endMin: e,
          kind: k,
          updatedAt: now,
        ),
      );
    }
  }

  // 佐藤：月〜金 9:00-17:00 OK、水曜午後NG（私的都合・理由は保存しない）
  weekly('st_sato', [1, 2, 3, 4, 5], 540, 1020, AvailKind.ok);
  weekly('st_sato', [3], 780, 1020, AvailKind.ng);
  // 田中：火・木・土 10:00-16:00 OK
  weekly('st_tanaka', [2, 4, 6], 600, 960, AvailKind.ok);
  // 木村：月〜土 9:30-18:00 OK、金曜終日NG
  weekly('st_kimura', [1, 2, 3, 4, 6], 570, 1080, AvailKind.ok);
  weekly('st_kimura', [5], 0, 1440, AvailKind.ng);
  // 小野：月〜日 8:00-20:00 OK、日曜NG
  weekly('st_ono', [1, 2, 3, 4, 5, 6], 480, 1200, AvailKind.ok);
  weekly('st_ono', [7], 0, 1440, AvailKind.ng);

  // 特定日の追加NG（例：3日後の午前）
  out.add(
    StaffAvailability(
      id: id(),
      staffId: 'st_sato',
      date: dayOf(now).add(const Duration(days: 3)),
      startMin: 540,
      endMin: 720,
      kind: AvailKind.ng,
      updatedAt: now,
    ),
  );
  return out;
}

List<StaffBlock> seedBlocks() {
  final now = DateTime.now();
  return [
    StaffBlock(
      id: 'bl_1',
      staffId: 'st_tanaka',
      date: dayOf(now).add(const Duration(days: 5)),
      startMin: 600,
      endMin: 840,
      reason: '院内研修',
    ),
  ];
}

// ---------------------------------------------------------------------------
// §11 / §24 Skill マスタ
//
// スキルはコードに固定しない。管理者が追加・改廃できる「候補データ」として
// 持ち、助産師には MidwifeSkill で紐づける。
// ---------------------------------------------------------------------------
const List<SkillDef> seedSkills = [
  SkillDef(
    id: '助産師免許',
    name: '助産師免許',
    description: 'すべてのケアの前提となる国家資格',
    certificationRequired: true,
  ),
  SkillDef(
    id: '母乳ケア',
    name: '母乳ケア',
    description: '授乳姿勢・乳房ケア・卒乳の相談に対応できる',
    certificationRequired: true,
  ),
  SkillDef(id: '訪問対応', name: '訪問対応', description: 'ご自宅へ伺うケアに対応できる'),
  SkillDef(id: '宿泊対応', name: '宿泊対応', description: '夜間を含む宿泊ケアに対応できる'),
  SkillDef(
    id: 'メンタルケア',
    name: 'こころのケア',
    description: '産後のこころの相談に対応できる',
    certificationRequired: true,
  ),
  SkillDef(id: '多胎児対応', name: '多胎児対応', description: 'ふたご・みつごのケアに対応できる'),
];

/// 助産師 ⇄ スキルの紐づけ（OpsStaff.skills と整合させる）
final List<MidwifeSkill> seedMidwifeSkills = [
  for (final s in seedStaff)
    for (final k in s.skills) MidwifeSkill(staffId: s.id, skillId: k, level: 2),
];

// ---------------------------------------------------------------------------
// §16 自治体マスタ（事業要件 MunicipalityProgram とは別エンティティ）
// ---------------------------------------------------------------------------
const List<Municipality> seedMunicipalityMasters = [
  Municipality(
    id: 'city_nagoya',
    name: '名古屋市',
    prefecture: '愛知県',
    programIds: ['mun_nagoya'],
  ),
  Municipality(
    id: 'city_owariasahi',
    name: '尾張旭市',
    prefecture: '愛知県',
    programIds: ['mun_owariasahi'],
  ),
  Municipality(
    id: 'city_nagakute',
    name: '長久手市',
    prefecture: '愛知県',
    programIds: ['mun_nagakute'],
  ),
  Municipality(
    id: 'city_seto',
    name: '瀬戸市',
    prefecture: '愛知県',
    programIds: ['mun_seto'],
  ),
  Municipality(
    id: 'city_komaki',
    name: '小牧市',
    prefecture: '愛知県',
    programIds: ['mun_komaki'],
  ),
];

// ---------------------------------------------------------------------------
// §15 Resource（部屋・ベッド・座席・設備）
//
// 「助産師は空いているが部屋が無い」を正しく判定するための在庫。
// OpsFacility.rooms / concurrentCapacity と整合させる。
// ---------------------------------------------------------------------------
const List<OpsResource> seedResources = [
  // さくら院：個室2・デイルーム座席2・沐浴設備1
  OpsResource(
    id: 'res_sakura_r1',
    facilityId: 'fac_sakura',
    name: '個室A（さくら）',
    kind: ResourceKind.room,
    serviceKinds: {ServiceKind.stay, ServiceKind.dayStay},
    overnightCapable: true,
  ),
  OpsResource(
    id: 'res_sakura_r2',
    facilityId: 'fac_sakura',
    name: '個室B（さくら）',
    kind: ResourceKind.room,
    serviceKinds: {ServiceKind.stay, ServiceKind.dayStay},
    overnightCapable: true,
  ),
  OpsResource(
    id: 'res_sakura_seat',
    facilityId: 'fac_sakura',
    name: 'デイルーム座席（さくら）',
    kind: ResourceKind.seat,
    capacity: 2,
    serviceKinds: {
      ServiceKind.dayStay,
      ServiceKind.stay,
      ServiceKind.breastClinic,
    },
  ),
  OpsResource(
    id: 'res_sakura_bath',
    facilityId: 'fac_sakura',
    name: '沐浴設備（さくら）',
    kind: ResourceKind.bath,
    serviceKinds: {ServiceKind.dayStay, ServiceKind.stay},
  ),
  // みどり院：個室1・座席1
  OpsResource(
    id: 'res_midori_r1',
    facilityId: 'fac_midori',
    name: '個室A（みどり）',
    kind: ResourceKind.room,
    serviceKinds: {ServiceKind.stay, ServiceKind.dayStay},
    overnightCapable: true,
  ),
  OpsResource(
    id: 'res_midori_seat',
    facilityId: 'fac_midori',
    name: '相談ルーム（みどり）',
    kind: ResourceKind.seat,
    serviceKinds: {ServiceKind.breastClinic, ServiceKind.dayStay},
  ),
];
