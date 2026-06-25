import { useState } from 'react';
import type { AppMode, AppConfig } from '../types';

interface Props {
  onEnter: (mode: AppMode) => void;
  config?: AppConfig;
  onUpdateConfig?: (patch: Partial<AppConfig>) => void;
}

export function Landing({ onEnter, config, onUpdateConfig }: Props) {
  // 準備中モード
  if (config?.comingSoon) {
    return <ComingSoonPage config={config} onEnter={onEnter} />;
  }
  return (
    <div className="min-h-screen relative overflow-hidden">
      {/* 背景グリッド */}
      <div className="fixed inset-0 tech-bg opacity-40 pointer-events-none animate-grid-move" />
      <div className="fixed inset-0 pointer-events-none bg-gradient-to-b from-transparent via-transparent to-ink-950" />

      <Header config={config} onEnter={onEnter} />
      <Hero onEnter={onEnter} />
      <Marquee />
      <BreastCareSection />
      <FeatureGrid />
      <BookingFlowSection />
      <LineSection config={config} />
      <DashboardPreview />
      <PricingSection />
      <Roadmap />
      <Faq />
      <CtaSection onEnter={onEnter} />
      <Footer
        config={config}
        onUpdateConfig={onUpdateConfig}
      />
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
    <header className="sticky top-0 z-40 backdrop-blur-xl bg-ink-950/60 border-b border-white/5">
      <div className="max-w-7xl mx-auto px-5 h-14 flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <Logo />
          <div className="leading-tight">
            <div className="display font-bold text-ink-50">
              Manary<span className="text-cyber-400">+</span>
            </div>
            <div className="text-[10px] text-ink-400 mono tracking-wider">
              MIDWIFE OS
            </div>
          </div>
        </div>
        <nav className="hidden md:flex items-center gap-6 text-sm text-ink-300">
          <a href="#features" className="hover:text-cyber-400 transition">機能</a>
          <a href="#booking" className="hover:text-cyber-400 transition">予約</a>
          <a href="#pricing" className="hover:text-cyber-400 transition">料金</a>
          <a href="#faq" className="hover:text-cyber-400 transition">FAQ</a>
          {config?.homepageUrl && (
            <a
              href={config.homepageUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="hover:text-cyber-400 transition"
            >
              ホームページ ↗
            </a>
          )}
        </nav>
        <div className="flex items-center gap-2">
          <button onClick={() => onEnter('mama')} className="btn-ghost text-xs">
            ママ
          </button>
          <button onClick={() => onEnter('midwife')} className="btn-primary text-xs px-4 py-2">
            助産師ログイン
          </button>
        </div>
      </div>
    </header>
  );
}

function Logo() {
  return (
    <div className="relative w-9 h-9 rounded-lg bg-cyber-grad flex items-center justify-center shadow-neon-cyan">
      <svg viewBox="0 0 24 24" className="w-5 h-5 text-white">
        <path
          d="M12 2L4 7v6c0 5 3.5 8.5 8 9 4.5-.5 8-4 8-9V7l-8-5z"
          fill="currentColor"
          opacity="0.9"
        />
        <circle cx="12" cy="11" r="2.5" fill="#0c1124" />
      </svg>
    </div>
  );
}

// ════════════════════════════════════════════
// Hero
// ════════════════════════════════════════════
function Hero({ onEnter }: { onEnter: (m: AppMode) => void }) {
  return (
    <section className="relative max-w-7xl mx-auto px-5 pt-16 pb-24">
      <div className="grid md:grid-cols-2 gap-12 items-center">
        <div>
          <div className="inline-flex items-center gap-2 chip-cyan mb-6">
            <span className="dot bg-cyber-400 animate-pulse-glow" />
            <span className="mono text-[11px]">v2.0 / MIDWIFE-OS</span>
          </div>
          <h1 className="display text-5xl md:text-6xl font-bold leading-[1.05] text-ink-50">
            助産師の<span className="holo">第六感</span>を、<br />
            データに翻訳する。
          </h1>
          <p className="mt-6 text-ink-300 text-lg leading-relaxed">
            予約・問診・カルテ・LINE通知。すべてを <span className="text-cyber-400 font-semibold">ひとつの未来型OS</span> に統合し、
            助産師が「ケア」だけに集中できる時間を取り戻します。
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <button className="btn-primary" onClick={() => onEnter('midwife')}>
              助産師として試す →
            </button>
            <button className="btn-outline" onClick={() => onEnter('mama')}>
              ママとして試す
            </button>
          </div>
          <div className="mt-8 flex flex-wrap gap-6 text-xs text-ink-400">
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
      <div className="kpi-num text-2xl">{value}</div>
      <div className="label mt-1">{label}</div>
    </div>
  );
}

function HeroMock({ onEnter }: { onEnter: (m: AppMode) => void }) {
  return (
    <div className="relative">
      <div className="absolute -inset-4 bg-cyber-grad-soft blur-3xl opacity-60 rounded-full" />
      <div className="relative card-hero scanner overflow-hidden">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2">
            <div className="dot bg-ng-500" />
            <div className="dot bg-warn-500" />
            <div className="dot bg-ok-500" />
            <span className="ml-2 text-[11px] mono text-ink-400">
              manary.os / dashboard
            </span>
          </div>
          <span className="chip-cyan">LIVE</span>
        </div>
        <div className="grid grid-cols-3 gap-2 mb-4">
          {[
            { l: '本日の予約', v: '7', s: '↑ 2' },
            { l: '問診回収', v: '92%', s: '↑ 8%' },
            { l: '緊急チャット', v: '2', s: 'NEW' },
          ].map((k) => (
            <div
              key={k.l}
              className="rounded-lg p-3 border border-white/5 bg-white/[0.03]"
            >
              <div className="label">{k.l}</div>
              <div className="kpi-num text-2xl mt-1">{k.v}</div>
              <div className="text-[10px] mono text-cyber-400">{k.s}</div>
            </div>
          ))}
        </div>
        <div className="space-y-2">
          {[
            { t: '09:30', p: '佐藤 みなみ', type: '産後ケア', risk: 'mental' },
            { t: '11:00', p: '田中 ゆかり', type: '乳房ケア', risk: 'breast' },
            { t: '14:00', p: '高橋 ありさ', type: '初回相談', risk: null },
          ].map((r) => (
            <div
              key={r.t}
              className="flex items-center gap-3 px-3 py-2 rounded-lg bg-white/[0.02] border border-white/5"
            >
              <span className="mono text-cyber-400 text-sm w-12">{r.t}</span>
              <span className="text-sm text-ink-100 flex-1">{r.p}</span>
              <span className="chip-plasma text-[10px]">{r.type}</span>
              {r.risk === 'mental' && (
                <span className="chip-warn text-[10px]">🧠</span>
              )}
              {r.risk === 'breast' && (
                <span className="chip-pink text-[10px]">🫧</span>
              )}
            </div>
          ))}
        </div>
        <button
          onClick={() => onEnter('midwife')}
          className="mt-4 w-full text-xs py-2 rounded-lg border border-cyber-700/40 text-cyber-300 hover:bg-cyber-900/30 transition"
        >
          ▸ ダッシュボードを開く
        </button>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════
// Marquee (信頼の指標)
// ════════════════════════════════════════════
function Marquee() {
  const items = [
    '🫧 乳房・母乳ケア専門',
    '⚡ ダブルブッキング 0件',
    '🌸 助産師の想いを翻訳',
    '🔒 患者データは端末内に保管',
    '📡 公式LINE 自動通知',
    '🤖 AI問診トリアージ',
    '🇯🇵 国産・国内ホスティング',
  ];
  return (
    <div className="border-y border-white/5 bg-white/[0.02] overflow-hidden">
      <div className="py-4 flex gap-12 whitespace-nowrap text-sm mono text-ink-400 animate-[wiggle_20s_linear_infinite]">
        {[...items, ...items, ...items].map((t, i) => (
          <span key={i}>{t}</span>
        ))}
      </div>
    </div>
  );
}

// ════════════════════════════════════════════
// 差別化: 乳房・母乳ケア
// ════════════════════════════════════════════
function BreastCareSection() {
  return (
    <section className="max-w-7xl mx-auto px-5 py-20">
      <div className="text-center max-w-2xl mx-auto mb-12">
        <span className="chip-pink mb-4 inline-flex">🫧 差別化ポイント</span>
        <h2 className="display text-3xl md:text-4xl font-bold text-ink-50 leading-tight">
          産後の乳房トラブル、<br />
          <span className="holo">どこに相談したらいい？</span> を、解消する。
        </h2>
        <p className="text-ink-300 mt-4">
          ママズケアの強み「<span className="hand-underline">母乳・乳房ケア</span>」を軸に、
          相談・記録・ケアまでを 1つのSaaS に。
        </p>
      </div>
      <div className="grid md:grid-cols-3 gap-4">
        {[
          {
            icon: '📷',
            title: '乳房写真タイムライン',
            desc: '張り・しこり・発赤の経過を時系列で。助産師は前回比をワンタップで確認。',
            tag: 'BREAST-TIMELINE',
          },
          {
            icon: '🧠',
            title: 'AIうっ滞・乳腺炎チェック',
            desc: '問診と写真から乳腺炎リスクを推定。早期受診を促すスコアリング。',
            tag: 'AI-TRIAGE',
          },
          {
            icon: '🎓',
            title: '授乳姿勢ライブラリ',
            desc: 'ママの状態に合わせた動画を自動アサイン。LINEで個別配信も可能。',
            tag: 'EDU-CONTENT',
          },
        ].map((f) => (
          <div key={f.title} className="card-glow group">
            <div className="text-3xl mb-3">{f.icon}</div>
            <div className="mono text-[10px] text-cyber-400 mb-1">{f.tag}</div>
            <div className="display font-bold text-lg text-ink-50">
              {f.title}
            </div>
            <div className="text-sm text-ink-300 mt-2 leading-relaxed">
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
      tag: 'BOOKING',
      title: '予約 ＝ 問診 セット予約',
      desc: '予約完了と同時に問診票が必ず提出される設計。ノーショウや「事前情報がない」を撲滅。',
      icon: '🗓️',
    },
    {
      tag: 'SHIFT',
      title: '1時間枠をそのまま',
      desc: 'Storesの「30分2分割」操作は不要。1時間 / 90分 / 1日休診 をワンクリックで設定。',
      icon: '⚙️',
    },
    {
      tag: 'LINE',
      title: '公式LINE × LINE WORKS',
      desc: '予約・問診・緊急時を自動通知。「予約入ってよかちゃん！」も標準搭載。',
      icon: '💬',
    },
    {
      tag: 'CHART',
      title: 'SOAPカルテ＋AI下書き',
      desc: '問診から SOAP を自動ドラフト。助産師は確認と微修正だけ。記入時間が約 1/3 に。',
      icon: '✍️',
    },
    {
      tag: 'PHOTO',
      title: '乳房・赤ちゃん写真共有',
      desc: 'LINEで散らかる写真を構造化保管。カテゴリ別・時系列で診療品質を底上げ。',
      icon: '📸',
    },
    {
      tag: 'WEB',
      title: 'Webアプリ／再インストール不要',
      desc: '同一URLで更新が反映。スマホでも PC でも、ブラウザだけで動きます。',
      icon: '🌐',
    },
  ];
  return (
    <section id="features" className="max-w-7xl mx-auto px-5 py-20">
      <div className="text-center mb-12">
        <span className="chip-cyan mb-4 inline-flex">FEATURES</span>
        <h2 className="display text-3xl md:text-4xl font-bold text-ink-50">
          助産院の業務を、<span className="holo">ひとつのOS</span>に
        </h2>
        <p className="text-ink-300 mt-3 max-w-xl mx-auto">
          LINE、Stores、ホームページ、紙の問診票──
          バラバラだった道具を、迷わない 1 つの画面へ。
        </p>
      </div>
      <div className="grid md:grid-cols-3 gap-4">
        {features.map((f) => (
          <div key={f.tag} className="card hover:border-cyber-700/40 transition group">
            <div className="flex items-center justify-between mb-3">
              <div className="text-2xl">{f.icon}</div>
              <div className="mono text-[10px] text-ink-500 group-hover:text-cyber-400 transition">
                {f.tag}
              </div>
            </div>
            <div className="display font-semibold text-ink-50">{f.title}</div>
            <div className="text-sm text-ink-300 mt-2 leading-relaxed">
              {f.desc}
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}

// ════════════════════════════════════════════
// 予約フローセクション
// ════════════════════════════════════════════
function BookingFlowSection() {
  const steps = [
    {
      n: '01',
      title: 'ママが空き枠を選ぶ',
      desc: '空いている枠だけが選択可能。ダブルブッキングは構造的に発生しません。',
      code: 'select(slot) → reserve',
    },
    {
      n: '02',
      title: '問診票がそのまま続く',
      desc: '名前・赤ちゃん・電話・アレルギー・オプション──9項目を予約と同時に提出。',
      code: 'intake.attach(appointment)',
    },
    {
      n: '03',
      title: '公式LINEに自動通知',
      desc: '「予約入ってよかちゃん！」と同時に、助産師LINE WORKSにも詳細が届きます。',
      code: 'line.notify(official + works)',
    },
    {
      n: '04',
      title: 'AIが要点を要約',
      desc: 'メンタルスコアや乳房状態が要注意なら、優先度フラグを付けて表示。',
      code: 'ai.triage(intake)',
    },
  ];
  return (
    <section id="booking" className="max-w-7xl mx-auto px-5 py-20">
      <div className="text-center mb-12">
        <span className="chip-plasma mb-4 inline-flex">BOOKING FLOW</span>
        <h2 className="display text-3xl md:text-4xl font-bold text-ink-50">
          予約 → 問診 → 通知 が、<span className="holo">1本の流れ</span>に
        </h2>
      </div>
      <div className="grid md:grid-cols-4 gap-3">
        {steps.map((s) => (
          <div key={s.n} className="card relative overflow-hidden">
            <div className="display text-6xl font-bold text-cyber-900/30 absolute -top-2 -right-1">
              {s.n}
            </div>
            <div className="relative">
              <div className="mono text-[10px] text-cyber-400">STEP {s.n}</div>
              <div className="display font-semibold text-ink-50 mt-1">
                {s.title}
              </div>
              <div className="text-sm text-ink-300 mt-2">{s.desc}</div>
              <div className="mt-3 mono text-[10px] text-plasma-400 bg-plasma-500/10 border border-plasma-500/20 rounded px-2 py-1">
                {s.code}
              </div>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}

// ════════════════════════════════════════════
// LINE 連携セクション
// ════════════════════════════════════════════
function LineSection({ config }: { config?: AppConfig }) {
  return (
    <section className="max-w-7xl mx-auto px-5 py-20">
      <div className="card-hero">
        <div className="grid md:grid-cols-2 gap-8 items-center">
          <div>
            <span className="chip-ok mb-4 inline-flex">LINE INTEGRATION</span>
            <h2 className="display text-3xl font-bold text-ink-50 leading-tight">
              「予約入ってよかちゃん！」を<br />
              <span className="holo">自動で送信</span>
            </h2>
            <p className="text-ink-300 mt-4 leading-relaxed">
              {config?.lineLinked ? (
                <>
                  公式LINE <span className="chip-ok text-[10px] ml-1">CONNECTED</span> ・ LINE WORKS <span className="chip-ok text-[10px] ml-1">CONNECTED</span>
                </>
              ) : (
                <>連携前のお試しモードでも、通知のプレビューを確認できます。</>
              )}
              <br />
              アプリで予約が入った瞬間、公式LINE と スタッフの LINE WORKS に通知が飛びます。
              緊急ワード（出血・発熱など）を含むチャットは赤いアラートで優先表示。
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
              text="🌸 予約入ってよかちゃん！&#10;田中ゆかり様 / 11:00 / 乳房ケア"
            />
            <LinePreview
              channel="LINE WORKS"
              text="📝 問診票が届きました&#10;佐藤みなみ様 / メンタル4 / 睡眠4h → 要注意"
              warn
            />
            <LinePreview
              channel="公式LINE"
              text="🫧 授乳姿勢の動画をお送りしました&#10;高橋ありさ様"
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
      className={`rounded-lg p-3 border ${
        warn
          ? 'bg-warn-500/10 border-warn-500/30'
          : 'bg-ok-500/10 border-ok-500/30'
      }`}
    >
      <div className="flex items-center justify-between mb-1">
        <span className="mono text-[10px] text-ink-300">{channel}</span>
        <span
          className={`mono text-[10px] ${warn ? 'text-warn-500' : 'text-ok-500'}`}
        >
          {warn ? 'NOTICE' : 'DELIVERED'}
        </span>
      </div>
      <div className="text-sm text-ink-100 whitespace-pre-line leading-relaxed">
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
    <section className="max-w-7xl mx-auto px-5 py-20">
      <div className="text-center mb-10">
        <span className="chip-cyan mb-4 inline-flex">DASHBOARD</span>
        <h2 className="display text-3xl md:text-4xl font-bold text-ink-50">
          紙のカルテと予約ノートを、<span className="holo">ひと目で</span>
        </h2>
      </div>
      <div className="card-hero relative overflow-hidden">
        <div className="grid md:grid-cols-4 gap-3 mb-4">
          {[
            ['本日の予約', '7', '+2'],
            ['問診回収率', '92%', '+8%'],
            ['再来率', '74%', '+3%'],
            ['緊急アラート', '2', 'NEW'],
          ].map(([l, v, s]) => (
            <div key={l} className="card">
              <div className="label">{l}</div>
              <div className="kpi-num mt-2">{v}</div>
              <div className="mono text-[10px] text-cyber-400 mt-1">{s}</div>
            </div>
          ))}
        </div>
        <div className="grid md:grid-cols-3 gap-3">
          <div className="card md:col-span-2">
            <div className="section-title mb-3">
              <span className="text-cyber-400">●</span> 本日のスケジュール
            </div>
            <div className="space-y-1.5">
              {[
                ['09:30', '佐藤 みなみ', '産後ケア (60min)', 'mental'],
                ['11:00', '田中 ゆかり', '乳房ケア (60min)', 'breast'],
                ['13:30', '伊藤 のぞみ', '産後ケア (60min)', null],
                ['14:00', '高橋 ありさ', '初回相談 (60min)', null],
                ['15:30', '鈴木 さやか', '母乳相談 (30min)', null],
              ].map(([t, n, type, risk], i) => (
                <div
                  key={i}
                  className="flex items-center gap-3 px-3 py-2 rounded-lg bg-white/[0.02] border border-white/5"
                >
                  <span className="mono text-cyber-400 w-12 text-sm">{t}</span>
                  <span className="text-sm text-ink-100 flex-1">{n}</span>
                  <span className="text-xs text-ink-400">{type}</span>
                  {risk === 'mental' && (
                    <span className="chip-warn text-[10px]">🧠</span>
                  )}
                  {risk === 'breast' && (
                    <span className="chip-pink text-[10px]">🫧</span>
                  )}
                </div>
              ))}
            </div>
          </div>
          <div className="card">
            <div className="section-title mb-3">
              <span className="text-signal-500">●</span> AIインサイト
            </div>
            <div className="space-y-2">
              {[
                'みなみ様: EPDS再評価を推奨',
                'ゆかり様: 乳腺うっ滞 経過良好',
                'ありさ様: 乳頭亀裂 強い痛み',
              ].map((t, i) => (
                <div
                  key={i}
                  className="text-xs text-ink-200 bg-plasma-500/5 border border-plasma-500/15 rounded px-2.5 py-1.5"
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
// Pricing
// ════════════════════════════════════════════
function PricingSection() {
  const plans = [
    {
      name: 'ベーシック',
      price: 9800,
      desc: '小規模助産院・新規開業の方に',
      features: [
        '予約・問診セット',
        '公式LINE通知',
        'シフト管理',
        'モバイルWebアプリ',
        '利用者 50名まで',
      ],
      cta: '14日間無料で試す',
      featured: false,
    },
    {
      name: 'プロ',
      price: 28000,
      desc: '複数スタッフ・標準プラン',
      features: [
        'ベーシックのすべて',
        'SOAPカルテ＋AI下書き',
        '写真タイムライン',
        '緊急トリアージ',
        '利用者 200名まで',
        'スタッフ 3名まで',
      ],
      cta: '14日間無料で試す',
      featured: true,
    },
    {
      name: 'プレミアム',
      price: 40000,
      desc: '本格運用・教育プログラム連携',
      features: [
        'プロのすべて',
        'AI乳腺炎リスク推定',
        '授乳姿勢ライブラリ',
        '行政提出書類エクスポート',
        '利用者・スタッフ 無制限',
        '専任サポート',
      ],
      cta: '相談する',
      featured: false,
    },
  ];
  return (
    <section id="pricing" className="max-w-7xl mx-auto px-5 py-20">
      <div className="text-center mb-12">
        <span className="chip-plasma mb-4 inline-flex">PRICING</span>
        <h2 className="display text-3xl md:text-4xl font-bold text-ink-50">
          開発に貢献した人に、<span className="holo">適正に</span>還元する料金
        </h2>
        <p className="text-ink-300 mt-3 max-w-xl mx-auto">
          会社の利益最大化ではなく、関わった人に正当な利益が分配される設計。
        </p>
      </div>
      <div className="grid md:grid-cols-3 gap-4">
        {plans.map((p) => (
          <div
            key={p.name}
            className={p.featured ? 'card-glow relative' : 'card relative'}
          >
            {p.featured && (
              <div className="absolute -top-3 left-1/2 -translate-x-1/2 chip-cyan">
                ★ 一番選ばれている
              </div>
            )}
            <div className="mono text-[10px] text-cyber-400">{p.name.toUpperCase()}</div>
            <div className="display font-bold text-xl text-ink-50 mt-1">
              {p.name}
            </div>
            <div className="text-xs text-ink-400 mt-1">{p.desc}</div>
            <div className="mt-4 flex items-baseline gap-1">
              <span className="display text-4xl font-bold text-ink-50">
                ¥{p.price.toLocaleString()}
              </span>
              <span className="text-sm text-ink-400">/ 月</span>
            </div>
            <ul className="mt-5 space-y-1.5">
              {p.features.map((f) => (
                <li
                  key={f}
                  className="text-sm text-ink-200 flex items-start gap-2"
                >
                  <span className="text-cyber-400 mt-0.5">✓</span>
                  <span>{f}</span>
                </li>
              ))}
            </ul>
            <button
              className={`mt-6 w-full ${p.featured ? 'btn-primary' : 'btn-outline'}`}
            >
              {p.cta}
            </button>
          </div>
        ))}
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
      phase: 'PHASE 1',
      label: '〜 6月末',
      title: '予約・問診のセット運用',
      status: 'now',
      bullets: [
        'ホームページ公開 → 予約導線を Manary+ に集約',
        '完成までは Stores 予約へフォールバック',
        'コーミングスーン画面の暫定公開',
      ],
    },
    {
      phase: 'PHASE 2',
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
      phase: 'PHASE 3',
      label: '9月〜',
      title: 'Stores 解約・本格運用',
      status: 'plan',
      bullets: [
        'Stores 年間契約 (約30万円) の更新停止',
        '助産院ネットワーク向けマルチテナント',
        '補助金活用・サーバー最適化',
      ],
    },
  ];
  return (
    <section className="max-w-7xl mx-auto px-5 py-20">
      <div className="text-center mb-12">
        <span className="chip-cyan mb-4 inline-flex">ROADMAP</span>
        <h2 className="display text-3xl md:text-4xl font-bold text-ink-50">
          段階的に、<span className="holo">確実に</span>移行する
        </h2>
        <p className="text-ink-300 mt-3 max-w-2xl mx-auto">
          まず予約と問診から。状況にあわせて柔軟に改善・拡張していきます。
        </p>
      </div>
      <div className="grid md:grid-cols-3 gap-4">
        {items.map((it) => (
          <div key={it.phase} className="card relative">
            <div
              className={
                it.status === 'now'
                  ? 'chip-cyan'
                  : it.status === 'next'
                    ? 'chip-plasma'
                    : 'chip'
              }
            >
              {it.phase} ・ {it.label}
            </div>
            <div className="display font-semibold text-ink-50 mt-3">
              {it.title}
            </div>
            <ul className="mt-3 space-y-1.5">
              {it.bullets.map((b) => (
                <li
                  key={b}
                  className="text-sm text-ink-300 flex items-start gap-2"
                >
                  <span className="text-cyber-400 mt-0.5 mono text-xs">▸</span>
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
      a: '9月の更新タイミングに合わせて段階移行できる設計です。それまでは Manary+ → Stores へのフォールバック導線も用意しています。',
    },
    {
      q: 'スマホアプリのインストールは必要？',
      a: 'いいえ、Webアプリです。同じURLでアップデートが反映されるため、再インストールは不要。スマホ・PC どちらでも動きます。',
    },
    {
      q: '公式LINE通知のフレーズはカスタマイズできますか？',
      a: 'はい。「予約入ってよかちゃん！」など、院ごとの口調・絵文字を設定画面から自由に変更できます。',
    },
    {
      q: '1時間枠を「30分×2」に分けずに登録できますか？',
      a: 'できます。Manary+ は内部的に30分slotで管理しますが、UI上は1時間枠そのものとして扱えます。1日休診もワンクリックです。',
    },
    {
      q: 'データはどこに保存されますか？',
      a: 'デモではブラウザの端末内にのみ保存しています。本番では国内ホスティング(お名前.com系VPSも検討中)を予定しています。',
    },
  ];
  return (
    <section id="faq" className="max-w-3xl mx-auto px-5 py-20">
      <div className="text-center mb-10">
        <span className="chip-cyan mb-4 inline-flex">FAQ</span>
        <h2 className="display text-3xl md:text-4xl font-bold text-ink-50">
          よくあるご質問
        </h2>
      </div>
      <div className="space-y-3">
        {items.map((it, i) => (
          <details key={i} className="card group">
            <summary className="cursor-pointer flex items-center justify-between text-ink-100 font-medium">
              <span className="flex items-center gap-3">
                <span className="mono text-[10px] text-cyber-400">
                  Q{String(i + 1).padStart(2, '0')}
                </span>
                {it.q}
              </span>
              <span className="text-cyber-400 group-open:rotate-45 transition">+</span>
            </summary>
            <div className="mt-3 text-sm text-ink-300 leading-relaxed">
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
    <section className="max-w-5xl mx-auto px-5 py-20">
      <div className="card-hero text-center relative overflow-hidden">
        <div className="absolute inset-0 tech-bg opacity-30 pointer-events-none" />
        <div className="relative">
          <h2 className="display text-3xl md:text-4xl font-bold text-ink-50 leading-tight">
            助産師の<span className="holo">第六感</span>を、<br />
            次の時代のスタンダードに。
          </h2>
          <p className="text-ink-300 mt-4">
            まずはデモで触ってみてください。データはお手元のブラウザ内だけに保存されます。
          </p>
          <div className="mt-6 flex flex-wrap gap-3 justify-center">
            <button className="btn-primary" onClick={() => onEnter('midwife')}>
              助産師アプリへ
            </button>
            <button className="btn-outline" onClick={() => onEnter('mama')}>
              ママアプリへ
            </button>
          </div>
        </div>
      </div>
    </section>
  );
}

// ════════════════════════════════════════════
// Footer (HP / SNS リンク動線)
// ════════════════════════════════════════════
function Footer({
  config,
  onUpdateConfig,
}: {
  config?: AppConfig;
  onUpdateConfig?: (patch: Partial<AppConfig>) => void;
}) {
  return (
    <footer className="border-t border-white/5 mt-10">
      <div className="max-w-7xl mx-auto px-5 py-10 grid md:grid-cols-4 gap-8 text-sm">
        <div>
          <div className="flex items-center gap-2 mb-3">
            <Logo />
            <span className="display font-bold text-ink-50">
              Manary<span className="text-cyber-400">+</span>
            </span>
          </div>
          <p className="text-ink-400 text-xs leading-relaxed">
            助産院・産後ケア施設のためのオペレーティングOS。
            <br />
            母乳・乳房ケアを軸に、ママと助産師をつなぎます。
          </p>
        </div>
        <div>
          <div className="label mb-3">プロダクト</div>
          <ul className="space-y-2 text-ink-300">
            <li><a href="#features" className="hover:text-cyber-400">機能</a></li>
            <li><a href="#booking" className="hover:text-cyber-400">予約フロー</a></li>
            <li><a href="#pricing" className="hover:text-cyber-400">料金</a></li>
            <li><a href="#faq" className="hover:text-cyber-400">FAQ</a></li>
          </ul>
        </div>
        <div>
          <div className="label mb-3">リンク</div>
          <ul className="space-y-2 text-ink-300">
            <li>
              <a
                href={config?.homepageUrl ?? '#'}
                target="_blank"
                rel="noopener noreferrer"
                className="hover:text-cyber-400"
              >
                ↗ ホームページ
              </a>
            </li>
            <li>
              <a
                href={config?.instagramUrl ?? '#'}
                target="_blank"
                rel="noopener noreferrer"
                className="hover:text-cyber-400"
              >
                ↗ Instagram
              </a>
            </li>
            <li>
              <a
                href={config?.storesFallbackUrl ?? '#'}
                target="_blank"
                rel="noopener noreferrer"
                className="hover:text-cyber-400"
              >
                ↗ Stores予約 (旧)
              </a>
            </li>
          </ul>
        </div>
        <div>
          <div className="label mb-3">運用デモ</div>
          <p className="text-xs text-ink-400 mb-2">
            ホームページ公開時に「準備中ページ」表示に切り替えるトグル。
          </p>
          {onUpdateConfig && (
            <button
              onClick={() => onUpdateConfig({ comingSoon: true })}
              className="btn-ghost text-xs"
            >
              ▸ 準備中ページに切替
            </button>
          )}
          <div className="text-[10px] text-ink-500 mt-4 mono">
            © 2026 Manary+ / made with ♥ in Japan
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
    <div className="min-h-screen relative flex items-center justify-center px-5">
      <div className="absolute inset-0 tech-bg opacity-30 animate-grid-move pointer-events-none" />
      <div className="absolute inset-0 bg-gradient-to-b from-cyber-900/10 via-transparent to-signal-500/5 pointer-events-none" />

      <div className="relative max-w-2xl w-full text-center">
        <div className="inline-flex items-center gap-2 chip-cyan mb-6">
          <span className="dot bg-cyber-400 animate-pulse-glow" />
          <span className="mono text-[11px]">SYSTEM / BOOTING</span>
        </div>
        <h1 className="display text-5xl md:text-6xl font-bold text-ink-50 leading-tight">
          ただいま<br />
          <span className="holo">構築中</span>です
        </h1>
        <p className="text-ink-300 mt-6 leading-relaxed">
          ママズケアの新しい予約システムは現在準備中です。
          <br />
          ご予約はお手数ですが、現在運用中の予約サイトをご利用ください。
        </p>

        <a
          href={config.storesFallbackUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="btn-primary mt-8 inline-flex"
        >
          ▸ 現行の予約サイト (Stores) へ
        </a>

        <div className="mt-12 grid md:grid-cols-3 gap-3 text-sm">
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
              className="card hover:border-cyber-700/40 transition"
            >
              <div className="text-ink-100">{label}</div>
            </a>
          ))}
        </div>

        <div className="mt-12 text-xs text-ink-500 mono">
          ESTIMATED LAUNCH ・ 2026 Q3
        </div>

        <button
          onClick={() => setAdminOpen(true)}
          className="mt-8 text-[10px] mono text-ink-600 hover:text-cyber-400 transition"
        >
          [ STAFF ACCESS ]
        </button>

        {adminOpen && (
          <div className="mt-6 card-glow inline-flex flex-col gap-2 items-stretch text-left">
            <div className="text-xs text-ink-300">
              スタッフ・開発者は通常のアプリにアクセスできます。
            </div>
            <button
              onClick={() => onEnter('midwife')}
              className="btn-ghost text-xs"
            >
              ▸ 助産師アプリへ
            </button>
            <button
              onClick={() => onEnter('mama')}
              className="btn-ghost text-xs"
            >
              ▸ ママアプリへ
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
