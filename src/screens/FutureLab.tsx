import { useState, useRef } from 'react';
import type { AppState } from '../types';
import { analyzeCrySim, CRY_CATEGORIES, predictNextFeeding } from '../utils';

type Tab = 'cry' | 'predict' | 'voice' | 'partner' | 'ar' | 'family';

export function FutureLab({ state }: { state: AppState }) {
  const [tab, setTab] = useState<Tab>('cry');
  return (
    <div className="space-y-4">
      <section className="card bg-gradient-to-br from-moon-100 via-mama-50 to-cream-100 border-0">
        <div className="flex items-center gap-2">
          <div className="text-2xl animate-float">✨</div>
          <div>
            <div className="text-xs font-bold text-moon-700">FUTURE LAB</div>
            <div className="font-bold">未来志向のケア機能をプレビュー</div>
            <p className="text-xs text-slate-600 mt-1">
              AIと音声、ARで「もっと早く・もっとやさしく」を実験中。
            </p>
          </div>
        </div>
      </section>

      <div className="grid grid-cols-3 gap-2">
        {(
          [
            ['cry', '🎤 泣き声AI'],
            ['predict', '🔮 予測ケア'],
            ['voice', '🗣 音声ログ'],
            ['partner', '🤝 パートナー'],
            ['ar', '🪞 AR遊び'],
            ['family', '🌳 家族の絆'],
          ] as const
        ).map(([k, l]) => (
          <button
            key={k}
            onClick={() => setTab(k)}
            className={`py-2 rounded-2xl text-xs font-semibold border ${
              tab === k
                ? 'bg-mama-500 text-white border-mama-500'
                : 'bg-white border-mama-100 text-slate-600'
            }`}
          >
            {l}
          </button>
        ))}
      </div>

      {tab === 'cry' && <CryAI />}
      {tab === 'predict' && <PredictiveCare state={state} />}
      {tab === 'voice' && <VoiceLog />}
      {tab === 'partner' && <PartnerSync state={state} />}
      {tab === 'ar' && <ARPlay />}
      {tab === 'family' && <FamilyGarden state={state} />}
    </div>
  );
}

function CryAI() {
  const [recording, setRecording] = useState(false);
  const [analyzing, setAnalyzing] = useState(false);
  const [result, setResult] = useState<ReturnType<typeof analyzeCrySim> | null>(null);
  const startedAt = useRef(0);

  const start = () => {
    setRecording(true);
    setResult(null);
    startedAt.current = Date.now();
    setTimeout(() => {
      setRecording(false);
      setAnalyzing(true);
      setTimeout(() => {
        setAnalyzing(false);
        setResult(analyzeCrySim(Date.now()));
      }, 1500);
    }, 3000);
  };

  return (
    <section className="card">
      <div className="section-title">🎤 泣き声AI解析</div>
      <p className="text-xs text-slate-500 mt-1">
        マイクの代わりにシミュレーションで動作中。録音→AIが5つの理由を推定します。
      </p>
      <div className="flex flex-col items-center my-6">
        <button
          onClick={start}
          disabled={recording || analyzing}
          className={`w-28 h-28 rounded-full text-white text-4xl flex items-center justify-center shadow-soft transition ${
            recording
              ? 'bg-red-400 animate-pulse-soft'
              : analyzing
                ? 'bg-moon-500 animate-pulse'
                : 'bg-gradient-to-br from-mama-400 to-mama-500 hover:scale-105'
          }`}
        >
          {recording ? '●REC' : analyzing ? '...' : '🎤'}
        </button>
        <div className="mt-3 text-xs text-slate-500">
          {recording
            ? '録音中…3秒間泣き声を聞かせてね'
            : analyzing
              ? 'AIが分析中…'
              : 'タップして録音スタート'}
        </div>
      </div>
      {result && (
        <div className="space-y-2">
          <div className="text-sm font-semibold">
            推定: {result[0].emoji} {result[0].label}
          </div>
          {result.map((r) => (
            <div key={r.id}>
              <div className="flex justify-between text-xs">
                <span>
                  {r.emoji} {r.label}
                </span>
                <span className="text-slate-500">{r.percent}%</span>
              </div>
              <div className="h-2 bg-mama-50 rounded-full overflow-hidden">
                <div
                  className="h-full bg-gradient-to-r from-mama-400 to-moon-500"
                  style={{ width: `${r.percent}%` }}
                />
              </div>
            </div>
          ))}
          <div className="mt-3 card bg-mama-50/60 border-mama-100">
            <div className="text-xs font-bold text-mama-700">💡 アドバイス</div>
            <div className="text-sm mt-1">{result[0].advice}</div>
          </div>
        </div>
      )}
      <div className="mt-4 text-[10px] text-slate-400">
        ※将来的にはオンデバイス推論で、音声データを外に送らずに分析する予定です。
      </div>
    </section>
  );
}

function PredictiveCare({ state }: { state: AppState }) {
  const next = predictNextFeeding(state.logs);
  // 今後24時間の授乳予測（平均間隔から推定）
  const intervals = [];
  if (next) {
    for (let i = 0; i < 8; i++) {
      intervals.push(new Date(next.at + i * next.intervalMin * 60000));
    }
  }
  return (
    <section className="card">
      <div className="section-title">🔮 予測ケア (24時間先まで)</div>
      <p className="text-xs text-slate-500 mt-1">
        過去の授乳・睡眠リズムから今後のケアタイミングをAIが予測。
      </p>
      {next ? (
        <ul className="mt-3 space-y-2">
          {intervals.map((d, i) => (
            <li
              key={i}
              className="flex items-center justify-between p-3 rounded-2xl bg-gradient-to-r from-moon-50 to-mama-50 border border-moon-100"
            >
              <div className="flex items-center gap-3">
                <span className="text-xl">🍼</span>
                <div>
                  <div className="font-bold">
                    {d.getHours()}:
                    {d.getMinutes().toString().padStart(2, '0')}
                  </div>
                  <div className="text-[10px] text-slate-500">
                    予測 #{i + 1}
                  </div>
                </div>
              </div>
              <span className="chip bg-white text-moon-700 border border-moon-200">
                信頼度 {Math.max(40, 95 - i * 8)}%
              </span>
            </li>
          ))}
        </ul>
      ) : (
        <div className="text-sm text-slate-500 mt-3">
          まだデータが少ないため予測できません。授乳記録を2回以上つけると予測が始まります。
        </div>
      )}
    </section>
  );
}

function VoiceLog() {
  const [listening, setListening] = useState(false);
  const [transcript, setTranscript] = useState('');
  const start = () => {
    setListening(true);
    setTranscript('');
    // SpeechRecognition API: ブラウザ対応がある場合
    const SR =
      (window as any).webkitSpeechRecognition ||
      (window as any).SpeechRecognition;
    if (!SR) {
      setTimeout(() => {
        setListening(false);
        setTranscript('（このブラウザは音声認識に未対応。デモ: 「3時に左側で10分授乳しました」）');
      }, 1500);
      return;
    }
    const rec = new SR();
    rec.lang = 'ja-JP';
    rec.interimResults = false;
    rec.onresult = (e: any) => {
      setTranscript(e.results[0][0].transcript);
      setListening(false);
    };
    rec.onerror = () => setListening(false);
    rec.onend = () => setListening(false);
    rec.start();
  };

  return (
    <section className="card">
      <div className="section-title">🗣 音声ログ</div>
      <p className="text-xs text-slate-500 mt-1">
        抱っこ中でも、声で記録。AIが文章を構造化してログに変換します。
      </p>
      <div className="flex flex-col items-center my-6">
        <button
          onClick={start}
          disabled={listening}
          className={`w-24 h-24 rounded-full text-white text-3xl flex items-center justify-center shadow-soft ${
            listening
              ? 'bg-red-400 animate-pulse'
              : 'bg-gradient-to-br from-moon-500 to-mama-400'
          }`}
        >
          🎙
        </button>
        <div className="text-xs text-slate-500 mt-2">
          {listening ? '聞いています…' : 'タップして話す'}
        </div>
      </div>
      {transcript && (
        <div className="card bg-mama-50/60 border-mama-100">
          <div className="text-xs font-bold text-mama-700">📜 認識結果</div>
          <div className="text-sm mt-1">{transcript}</div>
          <div className="text-[10px] text-slate-500 mt-2">
            ✨ AIが構造化: 「授乳・3:00・左側・10分」として記録可能（次バージョンで実装予定）
          </div>
        </div>
      )}
    </section>
  );
}

function PartnerSync({ state }: { state: AppState }) {
  const code = 'MAMAZ-' + (state.baby.name.charCodeAt(0) % 1000 + 100);
  return (
    <section className="card">
      <div className="section-title">🤝 パートナーと共有</div>
      <p className="text-xs text-slate-500 mt-1">
        パートナーのデバイスからこのコードでログイン。育児ログ・予測がリアルタイムで共有されます。
      </p>
      <div className="my-5 text-center">
        <div className="text-xs label">共有コード</div>
        <div className="text-3xl font-bold tracking-widest bg-gradient-to-r from-mama-500 to-moon-500 bg-clip-text text-transparent">
          {code}
        </div>
        <button className="btn-ghost mt-3 text-xs">📤 リンクで送る</button>
      </div>
      <ul className="text-sm space-y-2">
        <li>👀 「今授乳中」ステータスがリアルタイム表示</li>
        <li>🔔 ママが疲れているサインを検知 → パートナーに通知</li>
        <li>📊 育児タスクのバランス可視化（家事育児の偏り対策）</li>
      </ul>
    </section>
  );
}

function ARPlay() {
  const scenes = [
    { emoji: '🐘', label: 'サバンナの動物' },
    { emoji: '🐠', label: '海の中' },
    { emoji: '🌌', label: '宇宙旅行' },
    { emoji: '🌸', label: '春の花畑' },
  ];
  return (
    <section className="card">
      <div className="section-title">🪞 AR視覚刺激プレイ</div>
      <p className="text-xs text-slate-500 mt-1">
        ねんね中の赤ちゃんに、月齢に合わせた高コントラスト映像を投影。視覚の発達をやさしく刺激します。
      </p>
      <div className="grid grid-cols-2 gap-2 mt-3">
        {scenes.map((s) => (
          <button
            key={s.label}
            className="aspect-video rounded-2xl bg-gradient-to-br from-moon-200 to-mama-200 text-4xl flex flex-col items-center justify-center hover:scale-105 transition"
          >
            {s.emoji}
            <span className="text-xs mt-1 text-slate-700 font-semibold">
              {s.label}
            </span>
          </button>
        ))}
      </div>
      <div className="text-[10px] text-slate-400 mt-3">
        ※カメラ＋AR (WebXR) は実装プレビュー段階。
      </div>
    </section>
  );
}

function FamilyGarden({ state }: { state: AppState }) {
  // 育児ログの数で「成長する庭」のメタファー
  const total = state.logs.length;
  const flowers = Math.min(20, Math.floor(total / 2));
  return (
    <section className="card">
      <div className="section-title">🌳 家族の絆ガーデン</div>
      <p className="text-xs text-slate-500 mt-1">
        記録するほど庭が育つ、家族の歩みをやさしく可視化。
      </p>
      <div className="mt-4 bg-gradient-to-b from-moon-50 to-emerald-50 rounded-2xl p-4 min-h-[140px] flex flex-wrap gap-2 items-end">
        {Array.from({ length: flowers }).map((_, i) => (
          <span
            key={i}
            className="text-2xl animate-float"
            style={{ animationDelay: `${(i * 0.3) % 3}s` }}
          >
            {['🌸', '🌼', '🌷', '🌻', '🌿'][i % 5]}
          </span>
        ))}
        {flowers === 0 && (
          <span className="text-xs text-slate-400">
            記録を始めると、ここに花が咲きます🌱
          </span>
        )}
      </div>
      <div className="text-xs text-slate-500 mt-3">
        現在 {flowers} 本の花 ／ {total} 件の記録
      </div>
    </section>
  );
}
