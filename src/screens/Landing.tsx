import { useState } from 'react';
import type { AppMode, AppConfig } from '../types';
import { MAMOA, MAMOA_MESSAGES } from '../mamoa';

interface Props {
  onEnter: (mode: AppMode) => void;
  config?: AppConfig;
  onUpdateConfig?: (patch: Partial<AppConfig>) => void;
}

export function Landing({ onEnter, config, onUpdateConfig }: Props) {
  if (config?.comingSoon) {
    return <ComingSoonPage config={config} onEnter={onEnter} />;
  }
  return (
    <div className="min-h-screen relative">
      {/* MAMOA 温かいドット背景（うっすら） */}
      <div className="fixed inset-0 mamoa-dot-bg opacity-40 pointer-events-none" />
      <Header config={config} onEnter={onEnter} />
      <Hero onEnter={onEnter} />
      <Marquee />
      <MessageFromMoa />
      <BreastCareSection />
      <FeatureGrid />
      <BookingFlowSection />
      <LineSection config={config} />
      <DashboardPreview />
      <Roadmap />
      <Faq />
      <CtaSection onEnter={onEnter} />
      <Footer config={config} onUpdateConfig={onUpdateConfig} />
    </div>
  );
}

// ════════════════════════════════════════════
// Header
// ════════════════════════════════════════════
function Header({
  config,
  onEnter,
}: {
  config?: AppConfig;
  onEnter: (m: AppMode) => void;
}) {
  return (
    <header
      className="sticky top-0 z-40 backdrop-blur-md"
      style={{
        background: 'rgba(255, 251, 247, 0.85)',
        borderBottom: '1px solid rgba(241, 176, 185, 0.20)',
      }}
    >
      <div className="max-w-7xl mx-auto px-6 h-16 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Logo />
          <div className="leading-tight">
            <div
              className="display font-bold text-lg"
              style={{ color: '#3A2A30', letterSpacing: '0.14em' }}
            >
              MAMOA
            </div>
            <div
              className="text-[10px]"
              style={{ color: '#8E6A73', letterSpacing: '0.2em' }}
            >
              MIDWIFE&nbsp;CARE
            </div>
          </div>
        </div>
        <nav
          className="hidden md:flex items-center gap-7 text-sm"
          style={{ color: '#6E4F58' }}
        >
          <a href="#features" className="hover:text-mamoa-deep transition">機能</a>
          <a href="#booking" className="hover:text-mamoa-deep transition">予約</a>
          <a href="#faq" className="hover:text-mamoa-deep transition">よくある質問</a>
          {config?.homepageUrl && (
            <a
              href={config.homepageUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="hover:text-mamoa-deep transition"
            >
              ホームページ ↗
            </a>
          )}
        </nav>
        <div className="flex items-center gap-2">
          <button
            onClick={() => onEnter('mama')}
            className="btn-ghost text-xs px-4"
          >
            ママの方
          </button>
          <button
            onClick={() => onEnter('admin')}
            className="btn-ghost text-xs px-4 hidden lg:inline-flex"
          >
            運営管理
          </button>
          <button
            onClick={() => onEnter('midwife')}
            className="btn-primary text-xs px-5 py-2.5"
          >
            助産師ログイン
          </button>
        </div>
      </div>
    </header>
  );
}

function LineIcon({ name }: { name: string }) {
  const paths: Record<string, string> = {
    feeding: 'M8 4h8v4a4 4 0 0 1-4 4H9v8H5V8a4 4 0 0 1 3-4Zm1 4v4',
    shield: 'M12 3 5 6v5c0 4.4 2.8 8.1 7 10 4.2-1.9 7-5.6 7-10V6l-7-3Zm-3 9 2 2 4-5',
    guide: 'M5 4h10a4 4 0 0 1 4 4v12H8a3 3 0 0 1-3-3V4Zm3 12h11M9 8h6M9 11h5',
    form: 'M7 3h10v18H7V3Zm3 5h4m-4 4h4m-4 4h3',
    clock: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18Zm0 4v5l3 2',
    message: 'M4 5h16v11H9l-5 4V5Zm4 4h8m-8 3h5',
    chart: 'M6 20V10m6 10V4m6 16v-7',
    photo: 'M4 5h16v14H4V5Zm3 11 4-4 3 3 2-2 4 4M9 9h.01',
    web: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18Zm-9 9h18M12 3c3 3.2 3 14.8 0 18m0-18c-3 3.2-3 14.8 0 18',
  };
  return (
    <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={paths[name] ?? paths.shield} />
    </svg>
  );
}

function Logo() {
  return (
    <div
      className="relative w-10 h-10 flex items-center justify-center overflow-hidden"
      style={{
        background: 'linear-gradient(135deg, #F7C8CE 0%, #F1B0B9 100%)',
        borderRadius: '14px',
        boxShadow: '0 4px 10px -4px rgba(241, 176, 185, 0.55)',
      }}
    >
      {/* MAMOA アイコン風の M シェイプ */}
      <svg viewBox="0 0 32 32" className="w-6 h-6" fill="none">
        <path
          d="M6 26 L6 10 Q6 6 10 6 Q13 6 14 9 L16 14 L18 9 Q19 6 22 6 Q26 6 26 10 L26 26"
          stroke="#FFFFFF"
          strokeWidth="3"
          strokeLinecap="round"
          strokeLinejoin="round"
          fill="none"
        />
      </svg>
    </div>
  );
}

// ════════════════════════════════════════════
// Hero
// ════════════════════════════════════════════
function Hero({ onEnter }: { onEnter: (m: AppMode) => void }) {
  return (
    <section className="relative max-w-7xl mx-auto px-6 pt-20 pb-16 md:pt-24 md:pb-20">
      <div className="grid md:grid-cols-2 gap-12 items-center">
        <div>
          <div className="chip-plasma inline-flex mb-6">
            <span className="dot bg-lavender-300" />
            <span className="text-[11px]" style={{ letterSpacing: '0.2em' }}>
              助産師の手のぬくもりを、24時間そばに
            </span>
          </div>
          <h1
            className="display font-bold leading-[1.35]"
            style={{
              color: '#3A2A30',
              fontSize: 'clamp(2rem, 5vw, 3.25rem)',
              letterSpacing: '0.02em',
            }}
          >
            産後の毎日を、<br />
            <span className="hand-underline">やさしく支える</span>
            パートナー。
          </h1>
          <p
            className="mt-8 text-base md:text-lg"
            style={{ color: '#6E4F58', lineHeight: 1.9 }}
          >
            LINEから予約・問診・変更を、迷わずボタンで完了。
            <br />
            判断が必要なときだけ人へつなぎ、助産師がケアへ集中できる毎日をつくります。
          </p>
          <div className="mt-9 flex flex-wrap gap-3">
            <button className="btn-primary" onClick={() => onEnter('mama')}>
              ママとしてはじめる
            </button>
            <button className="btn-outline" onClick={() => onEnter('midwife')}>
              助産師として試す
            </button>
            <button className="btn-ghost" onClick={() => onEnter('admin')}>
              運営管理を試す
            </button>
          </div>
          <div className="mt-10 grid grid-cols-3 gap-4 max-w-md">
            <Stat label="紙カルテ削減" value="-92%" />
            <Stat label="予約取り時間" value="-78%" />
            <Stat label="ダブルブッキング" value="0件" />
          </div>
        </div>
        <HeroMock onEnter={onEnter} />
      </div>
    </section>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="kpi-num">{value}</div>
      <div
        className="mt-1 text-[10px] font-bold"
        style={{ color: '#8E6A73', letterSpacing: '0.22em' }}
      >
        {label}
      </div>
    </div>
  );
}

function HeroMock({ onEnter }: { onEnter: (m: AppMode) => void }) {
  return (
    <div className="relative">
      {/* 背景のぼかしオーラ */}
      <div
        className="absolute -inset-6 blur-3xl opacity-70 rounded-full pointer-events-none"
        style={{
          background:
            'radial-gradient(circle, rgba(241,176,185,0.35) 0%, rgba(191,169,211,0.20) 40%, transparent 70%)',
        }}
      />
      <div className="relative card-hero">
        {/* MOA キャラクター */}
        <div className="flex items-start gap-4 mb-5">
          <div className="moa-avatar w-16 h-16 shrink-0">
            <img src={MAMOA.moaSmall} alt="MOA" />
          </div>
          <div className="flex-1">
            <div
              className="text-[11px] mb-1 font-medium"
              style={{ color: '#8B72A9', letterSpacing: '0.18em' }}
            >
              MOA からのことば
            </div>
            <div className="bubble-moa">
              <div
                className="display"
                style={{ fontSize: '15px', color: '#4A323B', lineHeight: 1.85 }}
              >
                無理しなくていいよ。<br />
                あなたのペースで大丈夫だよ。
              </div>
            </div>
          </div>
        </div>

        {/* 今日のコンディション */}
        <div
          className="text-xs mb-3 font-semibold"
          style={{ color: '#8E6A73', letterSpacing: '0.14em' }}
        >
          今日のコンディション
        </div>
        <div className="grid grid-cols-3 gap-2 mb-4">
          {[
            { l: '授乳', v: '8回', accent: '#F1B0B9' },
            { l: '睡眠', v: '5.2時間', accent: '#BFA9D3' },
            { l: '気分', v: 'やや不安', accent: '#9ABF8F' },
          ].map((k) => (
            <div
              key={k.l}
              className="p-3 text-center"
              style={{
                background: '#FFFBF7',
                border: '1px solid rgba(142,106,115,0.10)',
                borderRadius: '16px',
              }}
            >
              <div
                className="text-[10px] mb-1.5 font-medium"
                style={{ color: '#8E6A73', letterSpacing: '0.1em' }}
              >
                {k.l}
              </div>
              <div
                className="display font-bold text-lg"
                style={{ color: k.accent }}
              >
                {k.v}
              </div>
            </div>
          ))}
        </div>

        {/* 今日のおすすめ（MOA アバター付きカード） */}
        <div
          className="flex items-center gap-3 p-3 mb-4"
          style={{
            background: 'linear-gradient(180deg, #FFFBF7 0%, #FBEFE8 100%)',
            border: '1px solid rgba(241,176,185,0.25)',
            borderRadius: '16px',
          }}
        >
          <div className="moa-avatar w-10 h-10 shrink-0">
            <img src={MAMOA.moaSmall} alt="MOA" />
          </div>
          <div className="flex-1">
            <div
              className="text-[10px] font-medium"
              style={{ color: '#8B72A9', letterSpacing: '0.1em' }}
            >
              あなたへのおすすめ
            </div>
            <div
              className="display text-sm mt-0.5"
              style={{ color: '#3A2A30' }}
            >
              授乳の痛みをやわらげるポイント
            </div>
          </div>
          <span style={{ color: '#8E6A73' }}>›</span>
        </div>

        <button
          onClick={() => onEnter('mama')}
          className="btn-ghost w-full text-xs"
        >
          MAMA アプリを開く
        </button>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════
// Marquee (静かなブランド言葉)
// ════════════════════════════════════════════
function Marquee() {
  const items = [
    '助産師監修',
    '医学的根拠に基づく情報',
    'プライバシーに配慮',
    '母乳・乳房ケア専門',
    '24時間 いつでも寄り添う',
    '国産・国内ホスティング',
  ];
  return (
    <div
      className="overflow-hidden py-6"
      style={{
        borderTop: '1px solid rgba(241,176,185,0.20)',
        borderBottom: '1px solid rgba(241,176,185,0.20)',
        background: 'rgba(255,251,247,0.6)',
      }}
    >
      <div className="max-w-7xl mx-auto px-6 flex flex-wrap justify-center gap-x-10 gap-y-2 text-sm">
        {items.map((t, i) => (
          <span
            key={i}
            className="inline-flex items-center gap-2"
            style={{ color: '#8E6A73' }}
          >
            <span
              className="inline-block w-1.5 h-1.5 rounded-full"
              style={{ background: '#F1B0B9' }}
            />
            {t}
          </span>
        ))}
      </div>
    </div>
  );
}

// ════════════════════════════════════════════
// MOA からのメッセージセクション (MAMOA らしさ)
// ════════════════════════════════════════════
function MessageFromMoa() {
  return (
    <section className="max-w-4xl mx-auto px-6 py-16">
      <div className="grid md:grid-cols-[240px_1fr] gap-8 items-center">
        <div className="flex justify-center">
          <img
            src={MAMOA.moaLarge}
            alt="MOA と ゆりかご"
            className="w-52 md:w-60 h-auto"
            style={{ filter: 'drop-shadow(0 10px 30px rgba(191,169,211,0.35))' }}
          />
        </div>
        <div>
          <div
            className="text-[11px] mb-3 font-semibold"
            style={{ color: '#8B72A9', letterSpacing: '0.24em' }}
          >
            MOA からのことば
          </div>
          <h2
            className="serif-display text-2xl md:text-3xl"
            style={{ color: '#3A2A30', lineHeight: 1.7 }}
          >
            産後の「わからない」を、<br />
            いっしょに、ゆっくり解いていこう。
          </h2>
          <p
            className="mt-5"
            style={{ color: '#6E4F58', lineHeight: 1.9, fontSize: '15px' }}
          >
            ひとりで抱えないで大丈夫だよ。<br />
            うれしかったことも、ちょっと不安なことも、<br />
            そのままここに置いていってね。
          </p>
        </div>
      </div>
    </section>
  );
}

// ════════════════════════════════════════════
// 差別化: 乳房・母乳ケア
// ════════════════════════════════════════════
function BreastCareSection() {
  return (
    <section className="max-w-7xl mx-auto px-6 py-20">
      <div className="text-center max-w-2xl mx-auto mb-14">
        <span className="chip-pink inline-flex mb-4">母乳・乳房ケア</span>
        <h2
          className="display text-3xl md:text-4xl"
          style={{ color: '#3A2A30', lineHeight: 1.5 }}
        >
          産後の乳房トラブル、<br />
          <span className="hand-underline">どこに相談したらいい？</span> を、解消する。
        </h2>
        <p className="mt-5" style={{ color: '#6E4F58', lineHeight: 1.9 }}>
          ママズケアの強み「母乳・乳房ケア」を軸に、<br className="hidden md:block" />
          相談・記録・ケアまでを 1つに。
        </p>
      </div>
      <div className="grid md:grid-cols-3 gap-5">
        {[
          {
            icon: 'feeding',
            title: '乳房写真タイムライン',
            desc: '張り・しこり・発赤の経過を時系列で。助産師は前回比をワンタップで確認できます。',
            tag: 'Timeline',
          },
          {
            icon: 'shield',
            title: 'AI相談と助産師フォロー',
            desc: '問診から気になる変化を整理し、必要時は助産師へつないで受診の目安を確認できます。',
            tag: 'AI Triage',
          },
          {
            icon: 'guide',
            title: '授乳姿勢ライブラリ',
            desc: 'ママの状態に合わせた動画を自動でご提案。LINE で個別配信もできます。',
            tag: 'Library',
          },
        ].map((f) => (
          <div key={f.title} className="card-glow">
            <div
              className="w-12 h-12 flex items-center justify-center mb-4 text-2xl"
              style={{
                background: 'linear-gradient(135deg, #FBE6EA 0%, #F7C8CE 100%)',
                borderRadius: '16px',
              }}
            >
              <LineIcon name={f.icon} />
            </div>
            <div
              className="text-[10px] mb-1 font-bold"
              style={{ color: '#B85F6A', letterSpacing: '0.24em' }}
            >
              {f.tag.toUpperCase()}
            </div>
            <div
              className="display font-bold text-lg"
              style={{ color: '#3A2A30' }}
            >
              {f.title}
            </div>
            <div
              className="mt-3 text-sm"
              style={{ color: '#6E4F58', lineHeight: 1.9 }}
            >
              {f.desc}
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}

// ════════════════════════════════════════════
// Feature Grid
// ════════════════════════════════════════════
function FeatureGrid() {
  const features = [
    {
      tag: '予約',
      title: '予約 ＝ 問診 セット予約',
      desc: '予約と同時に問診票が届く設計。「事前情報がない」を、なくします。',
      icon: 'form',
    },
    {
      tag: 'シフト',
      title: '1時間枠をそのまま',
      desc: 'Storesの「30分×2」操作は不要。1時間・90分・1日休診をワンクリックで。',
      icon: 'clock',
    },
    {
      tag: 'LINE',
      title: '公式LINE × LINE WORKS',
      desc: '予約・問診・緊急時を自動通知。「予約が入りました」も標準搭載。',
      icon: 'message',
    },
    {
      tag: 'カルテ',
      title: 'SOAPカルテ＋AI下書き',
      desc: '問診から SOAP を自動ドラフト。助産師は確認と微修正だけ。時間が約 1/3 に。',
      icon: 'chart',
    },
    {
      tag: '写真',
      title: '乳房・赤ちゃん写真共有',
      desc: 'LINEで散らかる写真を、カテゴリ別・時系列で構造化保管します。',
      icon: 'photo',
    },
    {
      tag: 'Web',
      title: 'Webアプリ／再インストール不要',
      desc: '同じURLで更新が反映。スマホでも PC でも、ブラウザだけで動きます。',
      icon: 'web',
    },
  ];
  return (
    <section id="features" className="max-w-7xl mx-auto px-6 py-20">
      <div className="text-center mb-14">
        <span className="chip-cyan inline-flex mb-4">MAMOA の機能</span>
        <h2 className="display text-3xl md:text-4xl" style={{ color: '#3A2A30' }}>
          助産院の毎日を、<span className="hand-underline">ひとつのアプリ</span>に
        </h2>
        <p className="mt-4" style={{ color: '#6E4F58', lineHeight: 1.9 }}>
          LINE、Stores、ホームページ、紙の問診票──<br className="hidden md:block" />
          バラバラだった道具を、迷わない 1 つの画面へ。
        </p>
      </div>
      <div className="grid md:grid-cols-3 gap-5">
        {features.map((f) => (
          <div key={f.tag} className="card group transition">
            <div className="flex items-start justify-between mb-4">
              <div
                className="w-12 h-12 flex items-center justify-center text-2xl"
                style={{
                  background: '#FBEFE8',
                  borderRadius: '14px',
                }}
              >
                <LineIcon name={f.icon} />
              </div>
              <div
                className="text-[10px] font-bold"
                style={{ color: '#8E6A73', letterSpacing: '0.22em' }}
              >
                {f.tag}
              </div>
            </div>
            <div
              className="display font-bold text-lg"
              style={{ color: '#3A2A30' }}
            >
              {f.title}
            </div>
            <div
              className="mt-3 text-sm"
              style={{ color: '#6E4F58', lineHeight: 1.9 }}
            >
              {f.desc}
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}

// ════════════════════════════════════════════
// 予約フロー
// ════════════════════════════════════════════
function BookingFlowSection() {
  const steps = [
    {
      n: '01',
      title: 'ママが空き枠を選ぶ',
      desc: '空いている時間だけが選べます。ダブルブッキングは構造的に起きません。',
    },
    {
      n: '02',
      title: '問診票がそのまま続く',
      desc: '名前・赤ちゃん・電話・アレルギー・オプション──9項目を予約と同時に。',
    },
    {
      n: '03',
      title: '公式LINEに自動通知',
      desc: '「予約が入りました」と同時に、助産師の LINE WORKS にも届きます。',
    },
    {
      n: '04',
      title: 'AI が要点を要約',
      desc: 'メンタルや乳房の要注意ポイントを、優しく助産師にお知らせします。',
    },
  ];
  return (
    <section id="booking" className="max-w-7xl mx-auto px-6 py-20">
      <div className="text-center mb-14">
        <span className="chip-plasma inline-flex mb-4">予約 → 問診 → 通知</span>
        <h2 className="display text-3xl md:text-4xl" style={{ color: '#3A2A30' }}>
          予約 → 問診 → 通知 が、<span className="hand-underline">1本の流れ</span>に
        </h2>
      </div>
      <div className="grid md:grid-cols-4 gap-4">
        {steps.map((s, i) => (
          <div key={s.n} className="card relative overflow-hidden">
            <div
              className="display absolute -top-3 -right-2 font-bold pointer-events-none select-none"
              style={{
                fontSize: '76px',
                color: 'rgba(241, 176, 185, 0.22)',
                lineHeight: 1,
              }}
            >
              {s.n}
            </div>
            <div className="relative">
              <div
                className="text-[10px] font-bold mb-2"
                style={{ color: '#B85F6A', letterSpacing: '0.24em' }}
              >
                STEP {s.n}
              </div>
              <div
                className="display font-bold text-lg"
                style={{ color: '#3A2A30' }}
              >
                {s.title}
              </div>
              <div
                className="mt-3 text-sm"
                style={{ color: '#6E4F58', lineHeight: 1.85 }}
              >
                {s.desc}
              </div>
              {i < steps.length - 1 && (
                <div
                  className="absolute top-2 right-0 hidden md:block"
                  style={{ color: 'rgba(241,176,185,0.5)' }}
                >
                  →
                </div>
              )}
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}

// ════════════════════════════════════════════
// LINE 連携
// ════════════════════════════════════════════
function LineSection({ config }: { config?: AppConfig }) {
  return (
    <section className="max-w-7xl mx-auto px-6 py-20">
      <div className="card-hero">
        <div className="grid md:grid-cols-2 gap-10 items-center">
          <div>
            <span className="chip-ok inline-flex mb-4">LINE 連携</span>
            <h2
              className="display text-3xl md:text-4xl"
              style={{ color: '#3A2A30', lineHeight: 1.5 }}
            >
              「予約が入りました」を<br />
              <span className="hand-underline">自動で送信</span>
            </h2>
            <p
              className="mt-5"
              style={{ color: '#6E4F58', lineHeight: 1.9 }}
            >
              {config?.lineLinked ? (
                <>
                  公式LINE <span className="chip-ok text-[10px] ml-1">連携済み</span>{' '}
                  ・ LINE WORKS{' '}
                  <span className="chip-ok text-[10px] ml-1">連携済み</span>
                  <br />
                </>
              ) : (
                <>連携前のお試しモードでも、通知のプレビューを確認できます。<br /></>
              )}
              予約が入った瞬間、公式LINE と スタッフの LINE WORKS に自動で通知が届きます。
              緊急ワードを含むメッセージは、赤いアラートで優先表示。
            </p>
            <div className="mt-6 flex flex-wrap gap-2">
              <span className="chip-cyan">公式LINE</span>
              <span className="chip-cyan">LINE WORKS</span>
              <span className="chip-cyan">SMS (オプション)</span>
            </div>
          </div>
          <div className="space-y-3">
            <LinePreview
              channel="公式LINE"
              text={'予約が入りました\n田中ゆかり様 / 11:00 / 乳房ケア'}
            />
            <LinePreview
              channel="LINE WORKS"
              text={'問診票が届きました\n佐藤みなみ様 / メンタル4 / 睡眠4h → 要確認'}
              warn
            />
            <LinePreview
              channel="公式LINE"
              text={'授乳姿勢の動画をお送りしました\n高橋ありさ様'}
            />
          </div>
        </div>
      </div>
    </section>
  );
}

function LinePreview({
  channel,
  text,
  warn,
}: {
  channel: string;
  text: string;
  warn?: boolean;
}) {
  return (
    <div
      className="p-4"
      style={{
        background: warn
          ? 'linear-gradient(180deg, #FBF3E7 0%, rgba(216,168,90,0.10) 100%)'
          : 'linear-gradient(180deg, #FFFBF7 0%, rgba(247,200,206,0.15) 100%)',
        border: warn
          ? '1px solid rgba(216,168,90,0.40)'
          : '1px solid rgba(241,176,185,0.35)',
        borderRadius: '18px',
        boxShadow: '0 4px 12px -4px rgba(142,106,115,0.10)',
      }}
    >
      <div className="flex items-center justify-between mb-2">
        <span
          className="text-[10px] font-bold"
          style={{ color: '#8E6A73', letterSpacing: '0.16em' }}
        >
          {channel}
        </span>
        <span
          className="text-[10px] font-bold"
          style={{
            color: warn ? '#B78638' : '#5F8156',
            letterSpacing: '0.16em',
          }}
        >
          {warn ? '要 確 認' : '送 信 済 み'}
        </span>
      </div>
      <div
        className="text-sm whitespace-pre-line"
        style={{ color: '#3A2A30', lineHeight: 1.85 }}
      >
        {text}
      </div>
    </div>
  );
}

// ════════════════════════════════════════════
// Dashboard Preview
// ════════════════════════════════════════════
function DashboardPreview() {
  return (
    <section className="max-w-7xl mx-auto px-6 py-20">
      <div className="text-center mb-12">
        <span className="chip-cyan inline-flex mb-4">Dashboard</span>
        <h2 className="display text-3xl md:text-4xl" style={{ color: '#3A2A30' }}>
          紙のカルテと予約ノートを、<span className="hand-underline">ひと目で</span>
        </h2>
      </div>
      <div className="card-hero">
        <div className="grid md:grid-cols-4 gap-3 mb-4">
          {[
            ['本日の予約', '7', '+2'],
            ['問診回収率', '92%', '+8%'],
            ['再来率', '74%', '+3%'],
            ['緊急アラート', '2', 'NEW'],
          ].map(([l, v, s]) => (
            <div key={l} className="card p-4">
              <div
                className="text-[10px] font-bold mb-2"
                style={{ color: '#8E6A73', letterSpacing: '0.22em' }}
              >
                {l}
              </div>
              <div className="kpi-num">{v}</div>
              <div
                className="mt-1 text-[10px] font-bold"
                style={{ color: '#B85F6A', letterSpacing: '0.14em' }}
              >
                {s}
              </div>
            </div>
          ))}
        </div>
        <div className="grid md:grid-cols-3 gap-4">
          <div className="card md:col-span-2">
            <div className="section-title mb-4">
              <span style={{ color: '#F1B0B9' }}>●</span> 本日のスケジュール
            </div>
            <div className="space-y-2">
              {[
                ['09:30', '佐藤 みなみ', '産後ケア (60min)', 'mental'],
                ['11:00', '田中 ゆかり', '乳房ケア (60min)', 'breast'],
                ['13:30', '伊藤 のぞみ', '産後ケア (60min)', null],
                ['14:00', '高橋 ありさ', '初回相談 (60min)', null],
                ['15:30', '鈴木 さやか', '母乳相談 (30min)', null],
              ].map(([t, n, type, risk], i) => (
                <div
                  key={i}
                  className="flex items-center gap-3 px-3 py-2.5"
                  style={{
                    background: '#FFFBF7',
                    border: '1px solid rgba(142,106,115,0.08)',
                    borderRadius: '14px',
                  }}
                >
                  <span
                    className="display w-14 text-sm font-bold"
                    style={{ color: '#B85F6A' }}
                  >
                    {t}
                  </span>
                  <span
                    className="text-sm flex-1"
                    style={{ color: '#3A2A30' }}
                  >
                    {n}
                  </span>
                  <span className="text-xs" style={{ color: '#8E6A73' }}>
                    {type}
                  </span>
                  {risk === 'mental' && (
                    <span className="chip-warn text-[10px]">メンタル</span>
                  )}
                  {risk === 'breast' && (
                    <span className="chip-pink text-[10px]">乳房</span>
                  )}
                </div>
              ))}
            </div>
          </div>
          <div className="card">
            <div className="section-title mb-4">
              <span style={{ color: '#BFA9D3' }}>●</span> AI インサイト
            </div>
            <div className="space-y-2">
              {[
                'みなみ様: EPDS再評価を推奨',
                'ゆかり様: 乳腺うっ滞 経過良好',
                'ありさ様: 乳頭亀裂 強い痛み',
              ].map((t, i) => (
                <div
                  key={i}
                  className="text-xs p-3"
                  style={{
                    background: 'rgba(191,169,211,0.10)',
                    border: '1px solid rgba(191,169,211,0.30)',
                    borderRadius: '12px',
                    color: '#4A323B',
                    lineHeight: 1.75,
                  }}
                >
                  {t}
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

// ════════════════════════════════════════════
// Roadmap
// ════════════════════════════════════════════
function Roadmap() {
  const items = [
    {
      phase: 'Phase 1',
      label: '〜 6月末',
      title: '予約・問診のセット運用',
      status: 'now',
      bullets: [
        'ホームページ公開 → 予約導線を MAMOA に集約',
        '完成までは Stores 予約へフォールバック',
        '「準備中ページ」の暫定公開',
      ],
    },
    {
      phase: 'Phase 2',
      label: '7〜9月',
      title: 'カルテ・LINE 連携・写真共有',
      status: 'next',
      bullets: [
        '公式LINE / LINE WORKS の正式連携',
        '電子カルテ (SOAP + AI下書き)',
        '乳房・赤ちゃん写真の構造化保管',
      ],
    },
    {
      phase: 'Phase 3',
      label: '9月〜',
      title: 'Stores 解約・本格運用',
      status: 'plan',
      bullets: [
        'Stores 年間契約の更新停止',
        '助産院ネットワーク向けマルチテナント',
        '補助金活用・サーバー最適化',
      ],
    },
  ];
  return (
    <section className="max-w-7xl mx-auto px-6 py-20">
      <div className="text-center mb-14">
        <span className="chip-cyan inline-flex mb-4">Roadmap</span>
        <h2 className="display text-3xl md:text-4xl" style={{ color: '#3A2A30' }}>
          段階的に、<span className="hand-underline">確実に</span>移行します
        </h2>
      </div>
      <div className="grid md:grid-cols-3 gap-5">
        {items.map((it) => (
          <div key={it.phase} className="card">
            <div
              className={
                it.status === 'now'
                  ? 'chip-pink inline-flex'
                  : it.status === 'next'
                    ? 'chip-plasma inline-flex'
                    : 'chip inline-flex'
              }
            >
              {it.phase} ・ {it.label}
            </div>
            <div
              className="display font-bold mt-4 text-lg"
              style={{ color: '#3A2A30' }}
            >
              {it.title}
            </div>
            <ul className="mt-4 space-y-2">
              {it.bullets.map((b) => (
                <li
                  key={b}
                  className="text-sm flex items-start gap-2"
                  style={{ color: '#4A323B', lineHeight: 1.75 }}
                >
                  <span style={{ color: '#EFA4B0' }}>◦</span>
                  <span>{b}</span>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
    </section>
  );
}

// ════════════════════════════════════════════
// FAQ
// ════════════════════════════════════════════
function Faq() {
  const items = [
    {
      q: 'Stores予約から移行できますか？',
      a: '9月の更新タイミングに合わせて段階移行できる設計です。それまでは MAMOA → Stores へのフォールバック導線もご用意しています。',
    },
    {
      q: 'スマホアプリのインストールは必要？',
      a: 'いいえ、Webアプリです。同じURLでアップデートが反映されるため、再インストールは不要。スマホ・PC どちらでも動きます。',
    },
    {
      q: '公式LINE通知のフレーズはカスタマイズできますか？',
      a: 'はい。「予約が入りました」など、院ごとの口調・絵文字を設定画面から自由に変更できます。',
    },
    {
      q: '1時間枠を「30分×2」に分けずに登録できますか？',
      a: 'できます。MAMOA は内部的に30分slotで管理しますが、UI上は1時間枠そのものとして扱えます。1日休診もワンクリックです。',
    },
    {
      q: 'データはどこに保存されますか？',
      a: 'デモではブラウザの端末内にのみ保存しています。本番では国内ホスティング(お名前.com系VPSも検討中)を予定しています。',
    },
  ];
  return (
    <section id="faq" className="max-w-3xl mx-auto px-6 py-20">
      <div className="text-center mb-12">
        <span className="chip-cyan inline-flex mb-4">FAQ</span>
        <h2 className="display text-3xl md:text-4xl" style={{ color: '#3A2A30' }}>
          よくあるご質問
        </h2>
      </div>
      <div className="space-y-3">
        {items.map((it, i) => (
          <details key={i} className="card group">
            <summary
              className="cursor-pointer flex items-center justify-between font-medium"
              style={{ color: '#3A2A30' }}
            >
              <span className="flex items-center gap-3">
                <span
                  className="text-[10px] font-bold"
                  style={{ color: '#B85F6A', letterSpacing: '0.16em' }}
                >
                  Q{String(i + 1).padStart(2, '0')}
                </span>
                <span className="display">{it.q}</span>
              </span>
              <span
                className="transition group-open:rotate-45 text-xl"
                style={{ color: '#EFA4B0' }}
              >
                +
              </span>
            </summary>
            <div
              className="mt-4 text-sm"
              style={{ color: '#6E4F58', lineHeight: 1.9 }}
            >
              {it.a}
            </div>
          </details>
        ))}
      </div>
    </section>
  );
}

// ════════════════════════════════════════════
// CTA
// ════════════════════════════════════════════
function CtaSection({ onEnter }: { onEnter: (m: AppMode) => void }) {
  return (
    <section className="max-w-5xl mx-auto px-6 py-20">
      <div className="card-hero text-center relative overflow-hidden">
        {/* 背景の MOA イラスト（うっすら） */}
        <img
          src={MAMOA.moaLarge}
          alt=""
          className="absolute -right-6 -bottom-4 w-40 md:w-48 pointer-events-none select-none"
          style={{ opacity: 0.35 }}
        />
        <div className="relative">
          <h2
            className="serif-display text-3xl md:text-4xl"
            style={{ color: '#3A2A30', lineHeight: 1.6 }}
          >
            {MAMOA_MESSAGES.primary}
          </h2>
          <p
            className="mt-6"
            style={{ color: '#6E4F58', lineHeight: 1.9 }}
          >
            まずはデモで触ってみてください。<br className="md:hidden" />
            データはお手元のブラウザ内だけに保存されます。
          </p>
          <div className="mt-8 flex flex-wrap gap-3 justify-center">
            <button className="btn-primary" onClick={() => onEnter('mama')}>
              ママアプリへ
            </button>
            <button className="btn-outline" onClick={() => onEnter('midwife')}>
              助産師アプリへ
            </button>
            <button className="btn-ghost" onClick={() => onEnter('admin')}>
              運営管理画面へ
            </button>
          </div>
        </div>
      </div>
    </section>
  );
}

// ════════════════════════════════════════════
// Footer
// ════════════════════════════════════════════
function Footer({
  config,
  onUpdateConfig,
}: {
  config?: AppConfig;
  onUpdateConfig?: (patch: Partial<AppConfig>) => void;
}) {
  return (
    <footer
      style={{
        borderTop: '1px solid rgba(241,176,185,0.20)',
        background: 'rgba(255,251,247,0.6)',
      }}
      className="mt-10"
    >
      <div className="max-w-7xl mx-auto px-6 py-12 grid md:grid-cols-4 gap-10 text-sm">
        <div>
          <div className="flex items-center gap-3 mb-4">
            <Logo />
            <span
              className="display font-bold text-lg"
              style={{ color: '#3A2A30', letterSpacing: '0.14em' }}
            >
              MAMOA
            </span>
          </div>
          <p
            className="text-xs"
            style={{ color: '#8E6A73', lineHeight: 1.85 }}
          >
            助産院・産後ケア施設のための
            <br />
            オペレーティングOS。<br />
            母乳・乳房ケアを軸に、ママと助産師をつなぎます。
          </p>
        </div>
        <div>
          <div className="label mb-3">プロダクト</div>
          <ul className="space-y-2.5" style={{ color: '#6E4F58' }}>
            <li>
              <a href="#features" className="hover:text-mamoa-deep">
                機能
              </a>
            </li>
            <li>
              <a href="#booking" className="hover:text-mamoa-deep">
                予約フロー
              </a>
            </li>
            <li>
              <a href="#faq" className="hover:text-mamoa-deep">
                よくあるご質問
              </a>
            </li>
          </ul>
        </div>
        <div>
          <div className="label mb-3">リンク</div>
          <ul className="space-y-2.5" style={{ color: '#6E4F58' }}>
            <li>
              <a
                href={config?.homepageUrl ?? '#'}
                target="_blank"
                rel="noopener noreferrer"
                className="hover:text-mamoa-deep"
              >
                ↗ ホームページ
              </a>
            </li>
            <li>
              <a
                href={config?.instagramUrl ?? '#'}
                target="_blank"
                rel="noopener noreferrer"
                className="hover:text-mamoa-deep"
              >
                ↗ Instagram
              </a>
            </li>
            <li>
              <a
                href={config?.storesFallbackUrl ?? '#'}
                target="_blank"
                rel="noopener noreferrer"
                className="hover:text-mamoa-deep"
              >
                ↗ Stores予約 (旧)
              </a>
            </li>
          </ul>
        </div>
        <div>
          <div className="label mb-3">運用デモ</div>
          <p className="text-xs mb-3" style={{ color: '#8E6A73', lineHeight: 1.75 }}>
            ホームページ公開時に「準備中ページ」表示に切り替えるトグル。
          </p>
          {onUpdateConfig && (
            <button
              onClick={() => onUpdateConfig({ comingSoon: true })}
              className="btn-ghost text-xs"
            >
              準備中ページに切替
            </button>
          )}
          <div className="mamoa-divider my-5" />
          <div
            className="text-[10px]"
            style={{ color: '#8E6A73', lineHeight: 1.8 }}
          >
            {MAMOA_MESSAGES.medicalDisclaimer}
          </div>
          <div
            className="text-[10px] mt-4 font-medium"
            style={{ color: '#B78E96', letterSpacing: '0.14em' }}
          >
            © 2026 MAMOA / made in Japan
          </div>
        </div>
      </div>
    </footer>
  );
}

// ════════════════════════════════════════════
// Coming Soon Page (6月末暫定対応)
// ════════════════════════════════════════════
function ComingSoonPage({
  config,
  onEnter,
}: {
  config: AppConfig;
  onEnter: (m: AppMode) => void;
}) {
  const [adminOpen, setAdminOpen] = useState(false);
  return (
    <div className="min-h-screen relative flex items-center justify-center px-6 py-16">
      <div className="fixed inset-0 mamoa-dot-bg opacity-40 pointer-events-none" />

      <div className="relative max-w-2xl w-full text-center">
        {/* MOA キャラクター */}
        <div className="flex justify-center mb-8">
          <img
            src={MAMOA.moaLarge}
            alt="MOA と ゆりかご"
            className="w-52 md:w-60 h-auto animate-breathe"
            style={{
              filter: 'drop-shadow(0 10px 30px rgba(191,169,211,0.40))',
            }}
          />
        </div>

        <div className="chip-plasma inline-flex mb-6">
          <span className="dot" style={{ background: '#BFA9D3' }} />
          <span className="text-[11px]" style={{ letterSpacing: '0.2em' }}>
            準備中
          </span>
        </div>
        <h1
          className="serif-display text-4xl md:text-5xl"
          style={{ color: '#3A2A30', lineHeight: 1.6 }}
        >
          いま、ゆっくり<br />
          <span className="hand-underline">おめかし中</span>です
        </h1>
        <p
          className="mt-6"
          style={{ color: '#6E4F58', lineHeight: 2 }}
        >
          ママズケアの新しい予約システムは、現在準備中です。<br />
          ご予約はお手数ですが、現在運用中の予約サイトをご利用ください。
        </p>

        <a
          href={config.storesFallbackUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="btn-primary mt-8 inline-flex"
        >
          現在の予約サイト (Stores) へ
        </a>

        <div className="mt-14 grid md:grid-cols-3 gap-3 text-sm">
          {[
            ['🌐 ホームページ', config.homepageUrl],
            ['📷 Instagram', config.instagramUrl],
            ['💬 公式LINE', '#'],
          ].map(([label, url]) => (
            <a
              key={label}
              href={url}
              target="_blank"
              rel="noopener noreferrer"
              className="card hover:shadow-warm-3 transition"
              style={{ display: 'block' }}
            >
              <div className="display" style={{ color: '#3A2A30' }}>
                {label}
              </div>
            </a>
          ))}
        </div>

        <div
          className="mt-14 text-[11px] font-medium"
          style={{ color: '#8E6A73', letterSpacing: '0.24em' }}
        >
          正式ローンチ予定 ・ 2026 Q3
        </div>

        <button
          onClick={() => setAdminOpen(true)}
          className="mt-6 text-[10px] transition"
          style={{ color: '#B78E96', letterSpacing: '0.24em' }}
        >
          [ STAFF ACCESS ]
        </button>

        {adminOpen && (
          <div className="mt-6 card-glow inline-flex flex-col gap-2 items-stretch text-left">
            <div
              className="text-xs"
              style={{ color: '#6E4F58', lineHeight: 1.75 }}
            >
              スタッフ・開発者は通常のアプリにアクセスできます。
            </div>
            <button
              onClick={() => onEnter('midwife')}
              className="btn-ghost text-xs"
            >
              助産師アプリへ
            </button>
            <button
              onClick={() => onEnter('mama')}
              className="btn-ghost text-xs"
            >
              ママアプリへ
            </button>
            <button
              onClick={() => onEnter('admin')}
              className="btn-ghost text-xs"
            >
              運営管理画面へ
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
