import type { AppMode } from '../types';
import { Manakun } from '../components/Manakun';

export function Landing({ onEnter }: { onEnter: (m: AppMode) => void }) {
  return (
    <div className="min-h-screen">
      <Header onEnter={onEnter} />
      <Hero onEnter={onEnter} />
      <Tagline />
      <Features />
      <ScreensShowcase />
      <AiPrediction />
      <Improvements />
      <Pricing />
      <Voices />
      <Flow />
      <FAQ />
      <CTA onEnter={onEnter} />
      <Footer />
    </div>
  );
}

function Header({ onEnter }: { onEnter: (m: AppMode) => void }) {
  return (
    <header className="sticky top-0 z-40 bg-white/85 backdrop-blur border-b border-sakura-100">
      <div className="max-w-6xl mx-auto px-5 py-3 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Manakun size={36} />
          <div>
            <div className="text-xl font-bold tracking-wide text-sakura-600">
              Manary<span className="text-cocoa-500">+</span>
            </div>
            <div className="text-[10px] text-cocoa-400 -mt-1">マナリー プラス</div>
          </div>
        </div>
        <nav className="hidden md:flex items-center gap-6 text-sm font-bold text-cocoa-600">
          <a href="#features" className="hover:text-sakura-500">特徴</a>
          <a href="#screens" className="hover:text-sakura-500">画面紹介</a>
          <a href="#ai" className="hover:text-sakura-500">AI予測</a>
          <a href="#pricing" className="hover:text-sakura-500">料金</a>
          <a href="#voices" className="hover:text-sakura-500">導入事例</a>
        </nav>
        <div className="flex items-center gap-2">
          <button
            onClick={() => onEnter('mama')}
            className="hidden sm:inline-flex btn-ghost text-xs"
          >
            👩 ママ用
          </button>
          <button onClick={() => onEnter('midwife')} className="btn-primary text-sm">
            🌸 ログイン
          </button>
        </div>
      </div>
    </header>
  );
}

function Hero({ onEnter }: { onEnter: (m: AppMode) => void }) {
  return (
    <section className="relative overflow-hidden">
      <div className="absolute top-10 -left-20 w-80 h-80 bg-sakura-200/40 rounded-full blur-3xl" />
      <div className="absolute bottom-0 right-0 w-96 h-96 bg-peach-200/40 rounded-full blur-3xl" />
      <div className="max-w-6xl mx-auto px-5 py-16 md:py-24 grid md:grid-cols-2 gap-10 items-center relative">
        <div className="space-y-6 animate-pop-in">
          <div className="chip bg-sakura-100 text-sakura-700">
            🌸 助産院向け SaaS アプリ
          </div>
          <h1 className="text-3xl md:text-5xl font-bold leading-tight text-cocoa-700">
            予約・問診票・電子カルテを<br />
            <span className="hand-underline">ひとつに、やさしく</span>
          </h1>
          <p className="text-cocoa-500 text-base md:text-lg leading-relaxed">
            紙のカルテに疲れていませんか？<br />
            Manary+ は、忙しい助産師さんの毎日を効率化し、
            <br className="hidden md:block" />
            ママと赤ちゃんに向き合う時間をもっと豊かにする応援団です。
          </p>
          <div className="flex flex-wrap gap-3">
            <button onClick={() => onEnter('midwife')} className="btn-primary">
              ✨ 助産師さんはこちら
            </button>
            <button onClick={() => onEnter('mama')} className="btn-outline">
              👩 ママとして体験
            </button>
          </div>
          <div className="flex items-center gap-4 pt-2 text-xs text-cocoa-400">
            <span>🔒 医療データを安全に保管</span>
            <span>📱 スマホ・PC両対応</span>
            <span>🌙 ダークモード対応</span>
          </div>
        </div>
        <div className="relative">
          <div className="absolute -top-6 -right-6 z-10 animate-float-slow">
            <Manakun size={120} mood="wave" />
          </div>
          <MockDashboard />
        </div>
      </div>
    </section>
  );
}

function MockDashboard() {
  return (
    <div className="card relative overflow-hidden animate-pop-in" style={{ animationDelay: '0.1s' }}>
      <div className="flex items-center justify-between mb-4">
        <div>
          <div className="label">本日のケア</div>
          <div className="text-xl font-bold text-cocoa-700">5 件の予約</div>
        </div>
        <div className="chip bg-peach-100 text-peach-500">⚡ AI予測 ON</div>
      </div>
      <div className="space-y-2">
        {[
          { t: '09:30', n: '佐藤 みなみ さん', type: '産後ケア', flag: '🧠' },
          { t: '11:00', n: '田中 ゆかり さん', type: '乳房ケア', flag: '🫧' },
          { t: '14:00', n: '高橋 ありさ さん', type: '初回相談', flag: '🌙' },
        ].map((r, i) => (
          <div
            key={i}
            className="flex items-center gap-3 p-3 rounded-2xl bg-sakura-50/60 border border-sakura-100"
          >
            <div className="text-sm font-bold text-sakura-600 w-12">{r.t}</div>
            <div className="flex-1">
              <div className="text-sm font-bold">{r.n}</div>
              <div className="text-[10px] text-cocoa-400">{r.type}</div>
            </div>
            <span className="text-lg">{r.flag}</span>
          </div>
        ))}
      </div>
      <div className="mt-4 p-3 rounded-2xl bg-gradient-to-r from-sakura-100 to-peach-100">
        <div className="text-[10px] font-bold text-cocoa-600">💡 まなくんからの提案</div>
        <div className="text-sm font-bold mt-1">
          佐藤さんはEPDS再評価の閾値が近いです。質問票に追加しますか？
        </div>
      </div>
    </div>
  );
}

function Tagline() {
  return (
    <section className="py-12 bg-white/40">
      <div className="max-w-4xl mx-auto px-5 text-center">
        <div className="inline-flex items-center gap-2 text-sakura-600 font-bold text-sm">
          <span className="dot bg-sakura-500" />
          <span>ママと赤ちゃんの、そして助産師さんの応援団</span>
          <span className="dot bg-sakura-500" />
        </div>
        <p className="mt-4 text-cocoa-500 text-sm md:text-base">
          産後ケア施設と AI スタートアップの共同開発。<br />
          現場の知見と最新テクノロジーを、やさしいデザインで届けます。
        </p>
      </div>
    </section>
  );
}

function Features() {
  const items = [
    {
      icon: '📅',
      title: 'オンライン予約',
      body: 'ウェブ上で利用者様が予約。24h自動受付、重複防止、リマインド。',
    },
    {
      icon: '📝',
      title: '事前質問票',
      body: 'あらかじめママに記入してもらい、当日は会話に集中。',
    },
    {
      icon: '📋',
      title: '電子で記録管理',
      body: '紙のカルテを減らし、SOAPで安全に保管・共有。',
    },
    {
      icon: '📊',
      title: '分析用レポート',
      body: '利用者の傾向を可視化し、運営の意思決定に役立てる。',
    },
  ];
  return (
    <section id="features" className="py-16">
      <div className="max-w-6xl mx-auto px-5">
        <SectionHeader
          eyebrow="FEATURES"
          title="Manary+ は助産師さんの応援団"
        />
        <div className="grid md:grid-cols-4 gap-4 mt-10">
          {items.map((it, i) => (
            <div
              key={i}
              className="card text-center hover:-translate-y-1 hover:shadow-soft transition"
            >
              <div className="text-4xl mb-3">{it.icon}</div>
              <div className="font-bold text-cocoa-700">{it.title}</div>
              <div className="text-xs text-cocoa-500 mt-2 leading-relaxed">
                {it.body}
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function ScreensShowcase() {
  return (
    <section id="screens" className="py-16 bg-white/40">
      <div className="max-w-6xl mx-auto px-5">
        <SectionHeader
          eyebrow="SCREENS"
          title="アプリ画面紹介"
          subtitle="直感的で使いやすいインターフェースで、助産師の皆様の業務をサポートします。"
        />
        <div className="grid md:grid-cols-2 gap-6 mt-10">
          <Showcase
            badge="予約システム"
            title="オンライン予約システム"
            body="24時間いつでも予約受付。重複予約を自動防止し、助産師さんの電話対応負担を大幅に削減します。"
            checks={['24時間自動受付', '重複予約防止', 'リマインド機能']}
            mock={<MockCalendar />}
          />
          <Showcase
            badge="電子カルテ"
            title="電子カルテ管理"
            body="安全で効率的な電子カルテ。乳房ケアにも対応、スタッフ間での情報共有もスムーズに。"
            checks={['安全管理', '検索機能', 'バックアップ']}
            mock={<MockChart />}
            reverse
          />
        </div>
      </div>
    </section>
  );
}

function Showcase({
  badge,
  title,
  body,
  checks,
  mock,
  reverse,
}: {
  badge: string;
  title: string;
  body: string;
  checks: string[];
  mock: React.ReactNode;
  reverse?: boolean;
}) {
  return (
    <div className={`card grid grid-cols-1 ${reverse ? 'md:[direction:rtl]' : ''}`}>
      <div className="space-y-3" style={{ direction: 'ltr' }}>
        <div className="chip bg-sakura-100 text-sakura-700">{badge}</div>
        <h3 className="text-xl font-bold text-cocoa-700">{title}</h3>
        <p className="text-sm text-cocoa-500 leading-relaxed">{body}</p>
        <ul className="space-y-1.5 text-sm">
          {checks.map((c) => (
            <li key={c} className="flex items-center gap-2 text-cocoa-600">
              <span className="text-sakura-500 font-bold">✓</span> {c}
            </li>
          ))}
        </ul>
      </div>
      <div className="mt-5" style={{ direction: 'ltr' }}>{mock}</div>
    </div>
  );
}

function MockCalendar() {
  return (
    <div className="rounded-2xl bg-sakura-50/60 p-3 border border-sakura-100">
      <div className="grid grid-cols-7 gap-1 text-[10px] text-center font-bold text-cocoa-400 mb-1">
        {['日', '月', '火', '水', '木', '金', '土'].map((d) => (
          <div key={d}>{d}</div>
        ))}
      </div>
      <div className="grid grid-cols-7 gap-1 text-center text-xs">
        {Array.from({ length: 21 }).map((_, i) => {
          const isMine = [3, 8, 12, 13, 16, 17, 20].includes(i);
          const today = i === 10;
          return (
            <div
              key={i}
              className={`aspect-square flex items-center justify-center rounded-lg ${
                today
                  ? 'bg-sakura-500 text-white font-bold'
                  : isMine
                    ? 'bg-white border border-sakura-200 text-cocoa-700'
                    : 'text-cocoa-300'
              }`}
            >
              {i + 1}
            </div>
          );
        })}
      </div>
    </div>
  );
}

function MockChart() {
  return (
    <div className="rounded-2xl bg-cream-50 p-3 border border-cocoa-100 text-xs space-y-2">
      <div className="flex items-center justify-between">
        <span className="font-bold text-cocoa-700">📋 SOAP記録</span>
        <span className="chip bg-cocoa-100 text-cocoa-600">自動下書き</span>
      </div>
      {[
        ['S', '夜間4h睡眠。ミルク追加に罪悪感。'],
        ['O', '体重51.2kg / BP108/68'],
        ['A', 'マタニティブルーズ遷延 EPDS要再評価'],
        ['P', '次回EPDS、家族協力依頼'],
      ].map(([k, v]) => (
        <div key={k} className="flex gap-2">
          <span className="w-5 h-5 rounded-full bg-sakura-500 text-white text-[10px] flex items-center justify-center font-bold flex-shrink-0">
            {k}
          </span>
          <span className="text-cocoa-600">{v}</span>
        </div>
      ))}
    </div>
  );
}

function AiPrediction() {
  return (
    <section id="ai" className="py-16">
      <div className="max-w-6xl mx-auto px-5">
        <div className="card bg-gradient-to-br from-sakura-100 via-cream-100 to-peach-100 border-0 grid md:grid-cols-2 gap-8 items-center">
          <div>
            <div className="chip bg-white text-sakura-700">⚡ AI Prediction</div>
            <h3 className="text-2xl md:text-3xl font-bold text-cocoa-700 mt-4">
              助産院監修の<br />
              <span className="hand-underline">AI予測機能</span>
            </h3>
            <p className="text-cocoa-500 mt-4 text-sm leading-relaxed">
              問診票と過去カルテから、産後うつリスク・乳腺炎再発・体重増加不良などをAIが先回りで通知。
              <br />
              判断するのは助産師さん、AIはその目を補助する応援団です。
            </p>
            <ul className="mt-5 space-y-2 text-sm">
              {[
                '🧠 産後うつスクリーニング自動候補',
                '🫧 乳腺うっ滞・再発リスク警戒',
                '⚖️ 月齢曲線との乖離検出',
                '🩸 出血・発熱の緊急トリアージ',
              ].map((x) => (
                <li key={x} className="flex items-center gap-2 text-cocoa-600">
                  <span className="dot bg-sakura-500" />
                  {x}
                </li>
              ))}
            </ul>
          </div>
          <div className="relative">
            <div className="absolute -top-8 -left-8 animate-wiggle">
              <Manakun size={80} mood="wink" />
            </div>
            <div className="card bg-white">
              <div className="text-[10px] label">AI Insights</div>
              <div className="mt-2 space-y-2">
                <Insight
                  level="urgent"
                  icon="🧠"
                  title="EPDS再評価を推奨"
                  body="気分≤4、睡眠4h未満が継続。前回11点で閾値接近。"
                />
                <Insight
                  level="warn"
                  icon="🫧"
                  title="右乳房うっ滞リスク中"
                  body="既往あり。授乳姿勢動画を事前共有済み。"
                />
                <Insight
                  level="info"
                  icon="🌸"
                  title="心身ともに良好"
                  body="次回は2週間後で問題なさそう。"
                />
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function Insight({
  level,
  icon,
  title,
  body,
}: {
  level: 'info' | 'warn' | 'urgent';
  icon: string;
  title: string;
  body: string;
}) {
  const colorMap = {
    urgent: 'bg-sakura-100 border-sakura-300 text-sakura-700',
    warn: 'bg-peach-100 border-peach-300 text-peach-500',
    info: 'bg-cream-100 border-cream-200 text-cocoa-600',
  };
  return (
    <div className={`p-3 rounded-2xl border ${colorMap[level]}`}>
      <div className="flex items-center gap-2 text-sm font-bold">
        <span>{icon}</span>
        <span>{title}</span>
      </div>
      <div className="text-xs text-cocoa-500 mt-1">{body}</div>
    </div>
  );
}

function Improvements() {
  const items = [
    {
      icon: '🌙',
      title: 'ダークモード',
      body: '夜勤・夜間オンコールの目に優しい、専用のダークテーマ。',
    },
    {
      icon: '📸',
      title: '写真タイムライン',
      body: '乳房・便・発疹・体重計の画像を時系列で。比較も簡単。',
    },
    {
      icon: '🆘',
      title: 'SOSチャット',
      body: 'ママから助産師へ直接相談。AIが緊急度を自動トリアージ。',
    },
    {
      icon: '🎙',
      title: '音声入力カルテ',
      body: '抱っこ中でも、声でSOAPを記録。AIが構造化。',
    },
  ];
  return (
    <section className="py-16 bg-white/40">
      <div className="max-w-6xl mx-auto px-5">
        <SectionHeader
          eyebrow="WHAT'S NEW"
          title="Manary+ で進化した4つのポイント"
          subtitle="Manaryの良さはそのままに、現場の声から生まれた機能をプラス。"
        />
        <div className="grid md:grid-cols-4 gap-4 mt-10">
          {items.map((it, i) => (
            <div key={i} className="card text-center">
              <div className="text-4xl mb-3">{it.icon}</div>
              <div className="font-bold text-cocoa-700">{it.title}</div>
              <div className="text-xs text-cocoa-500 mt-2 leading-relaxed">
                {it.body}
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function Pricing() {
  const plans = [
    {
      name: 'ベーシック',
      price: '¥9,800',
      tag: '個人・小規模向け',
      features: [
        '予約システム（基本機能）',
        'オンライン問診票（基本フォーム）',
        '電子カルテ（基本機能）',
      ],
      highlight: false,
    },
    {
      name: 'プロ',
      price: '¥28,000',
      tag: '中規模助産院向け',
      features: [
        '予約システム（高度なカスタマイズ）',
        'オンライン問診票（複数フォーム）',
        '電子カルテ（AI予測 + 分析レポート）',
        'カスタマーサポート優先対応',
      ],
      highlight: true,
    },
    {
      name: 'プレミアム',
      price: '¥40,000',
      tag: '複数拠点・高度分析',
      features: [
        '予約システム（スマホアプリ連携・自動リマインド）',
        '問診票（自由度の高いカスタマイズ）',
        '電子カルテ（高度な統計分析・外部連携）',
        '専任担当によるコンサルティング',
      ],
      highlight: false,
    },
  ];
  return (
    <section id="pricing" className="py-16">
      <div className="max-w-6xl mx-auto px-5">
        <SectionHeader eyebrow="PRICING" title="料金プラン" />
        <div className="grid md:grid-cols-3 gap-5 mt-10">
          {plans.map((p) => (
            <div
              key={p.name}
              className={`card relative ${
                p.highlight
                  ? 'ring-2 ring-sakura-400 shadow-soft -translate-y-2'
                  : ''
              }`}
            >
              {p.highlight && (
                <div className="absolute -top-3 left-1/2 -translate-x-1/2 chip bg-pink-grad text-white">
                  ⭐ おすすめ
                </div>
              )}
              <div className="text-cocoa-400 text-xs">{p.tag}</div>
              <div className="text-2xl font-bold text-cocoa-700 mt-1">
                {p.name}プラン
              </div>
              <div className="text-3xl font-bold text-sakura-600 mt-3">
                {p.price}
                <span className="text-sm text-cocoa-400 font-normal">/月</span>
              </div>
              <ul className="mt-5 space-y-2 text-sm">
                {p.features.map((f) => (
                  <li key={f} className="flex gap-2 text-cocoa-600">
                    <span className="text-sakura-500 font-bold">✓</span>
                    {f}
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function Voices() {
  const voices = [
    {
      who: 'A助産院様',
      avatar: '🌷',
      text: '予約管理がオンライン化されたことで、電話対応や重複予約が減り、産後ケアのカウンセリングに集中できています。',
    },
    {
      who: 'B助産院様',
      avatar: '🌸',
      text: '問診票を事前に送れるので、当日はカルテがすでに準備済み。母子の状態を正確に把握できるため、ケアの質が上がりました！',
    },
    {
      who: 'C助産院様',
      avatar: '🌼',
      text: 'AIの予測機能のおかげで、見落としていたかもしれないサインを早めにキャッチできるようになりました。',
    },
  ];
  return (
    <section id="voices" className="py-16 bg-white/40">
      <div className="max-w-6xl mx-auto px-5">
        <SectionHeader eyebrow="VOICES" title="導入事例・お客様の声" />
        <div className="grid md:grid-cols-3 gap-5 mt-10">
          {voices.map((v) => (
            <div key={v.who} className="card">
              <div className="text-3xl">{v.avatar}</div>
              <p className="text-sm text-cocoa-600 mt-3 leading-relaxed">
                “{v.text}”
              </p>
              <div className="text-xs text-cocoa-400 mt-3">― {v.who}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function Flow() {
  const steps = [
    { n: 1, t: 'お問い合わせ', d: 'まずはフォームからお気軽にご連絡ください。' },
    { n: 2, t: '無料デモ体験', d: '実際の画面を見ながら操作性を体験できます。' },
    { n: 3, t: 'プラン選択', d: '助産院の規模やニーズに合わせて選択。' },
    { n: 4, t: '導入サポート', d: '初期設定やスタッフ向けレクチャーをサポート。' },
  ];
  return (
    <section className="py-16">
      <div className="max-w-6xl mx-auto px-5">
        <SectionHeader eyebrow="HOW TO START" title="導入までの流れ" />
        <div className="grid md:grid-cols-4 gap-5 mt-10">
          {steps.map((s) => (
            <div key={s.n} className="text-center relative">
              <div className="w-14 h-14 mx-auto rounded-full bg-pink-grad text-white text-xl font-bold flex items-center justify-center shadow-soft">
                {s.n}
              </div>
              <div className="font-bold text-cocoa-700 mt-3">{s.t}</div>
              <div className="text-xs text-cocoa-500 mt-2">{s.d}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function FAQ() {
  const items = [
    {
      q: '操作が難しくないか不安です。',
      a: '操作画面は直感的に設計されており、パソコンやスマホが得意でない方でも簡単にご利用いただけます。導入時のサポートも手厚く行っています。',
    },
    {
      q: 'データのセキュリティはどうなっていますか？',
      a: 'クラウド上で高度な暗号化を行い、万全のセキュリティ対策を実施しています。安心してご利用いただけます。',
    },
    {
      q: '無料トライアルはありますか？',
      a: 'はい、1週間の無料トライアルをご用意しています。まずは使い勝手をお試しください。',
    },
    {
      q: 'AI予測の精度は信頼できますか？',
      a: '助産師監修のルールベース＋機械学習で構築。最終判断は必ず助産師さんが行えるよう、根拠を明示する設計です。',
    },
  ];
  return (
    <section className="py-16 bg-white/40">
      <div className="max-w-3xl mx-auto px-5">
        <SectionHeader eyebrow="FAQ" title="よくある質問" />
        <div className="space-y-3 mt-10">
          {items.map((it, i) => (
            <details
              key={i}
              className="card cursor-pointer group"
            >
              <summary className="font-bold text-cocoa-700 flex items-center justify-between list-none">
                <span>Q. {it.q}</span>
                <span className="text-sakura-500 group-open:rotate-45 transition">＋</span>
              </summary>
              <p className="text-sm text-cocoa-500 mt-3 leading-relaxed">
                A. {it.a}
              </p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}

function CTA({ onEnter }: { onEnter: (m: AppMode) => void }) {
  return (
    <section className="py-20">
      <div className="max-w-3xl mx-auto px-5">
        <div className="card bg-gradient-to-br from-sakura-100 via-peach-100 to-cream-100 border-0 text-center relative overflow-hidden">
          <div className="absolute -top-4 left-1/2 -translate-x-1/2">
            <Manakun size={80} mood="love" />
          </div>
          <div className="pt-16">
            <h3 className="text-2xl font-bold text-cocoa-700">
              まずは1週間、無料でお試し
            </h3>
            <p className="text-sm text-cocoa-500 mt-3">
              実際の操作感を、デモアカウントですぐにご体験いただけます。
            </p>
            <div className="flex flex-wrap gap-3 justify-center mt-6">
              <button onClick={() => onEnter('midwife')} className="btn-primary">
                ✨ 助産師ダッシュボードを試す
              </button>
              <button onClick={() => onEnter('mama')} className="btn-outline">
                👩 ママ用アプリを試す
              </button>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function Footer() {
  return (
    <footer className="py-10 border-t border-sakura-100 bg-white/60">
      <div className="max-w-6xl mx-auto px-5 flex flex-col md:flex-row items-center justify-between gap-4">
        <div className="flex items-center gap-2">
          <Manakun size={32} />
          <span className="font-bold text-sakura-600">Manary+</span>
          <span className="text-xs text-cocoa-400">© 2026 Mamas' Care × mihatama</span>
        </div>
        <div className="flex gap-4 text-xs text-cocoa-400">
          <a className="hover:text-sakura-500">利用規約</a>
          <a className="hover:text-sakura-500">プライバシー</a>
          <a className="hover:text-sakura-500">特定商取引</a>
        </div>
      </div>
    </footer>
  );
}

function SectionHeader({
  eyebrow,
  title,
  subtitle,
}: {
  eyebrow: string;
  title: string;
  subtitle?: string;
}) {
  return (
    <div className="text-center">
      <div className="text-[11px] font-bold tracking-[0.3em] text-sakura-500">
        {eyebrow}
      </div>
      <h2 className="text-2xl md:text-3xl font-bold text-cocoa-700 mt-2">
        {title}
      </h2>
      {subtitle && (
        <p className="text-sm text-cocoa-500 mt-3 max-w-xl mx-auto">
          {subtitle}
        </p>
      )}
    </div>
  );
}
