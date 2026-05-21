import { useState } from 'react';
import type { AppState, MamaCheck } from '../types';
import { EPDS_QUESTIONS, mamaWellnessScore } from '../utils';
import {
  ResponsiveContainer,
  RadarChart,
  PolarGrid,
  PolarAngleAxis,
  Radar,
} from 'recharts';

export function MamaCare({
  state,
  addMamaCheck,
}: {
  state: AppState;
  addMamaCheck: (m: Omit<MamaCheck, 'id'>) => void;
}) {
  const [sleepHours, setSleepHours] = useState(5);
  const [mood, setMood] = useState(5);
  const [pain, setPain] = useState(3);
  const [stress, setStress] = useState(5);
  const [help, setHelp] = useState(true);
  const [notes, setNotes] = useState('');
  const [epdsOpen, setEpdsOpen] = useState(false);

  const score = mamaWellnessScore(state.mamaChecks, state.logs);
  const latest = state.mamaChecks[0];
  const radarData = latest
    ? [
        { axis: '気分', v: latest.moodScore },
        { axis: '睡眠', v: Math.min(10, latest.sleepHours * 1.4) },
        { axis: 'からだ', v: 10 - latest.bodyPainScore },
        { axis: 'こころ', v: 10 - latest.stressScore },
        { axis: 'サポート', v: latest.hasHelp ? 9 : 4 },
      ]
    : [];

  return (
    <div className="space-y-4">
      <section className="card bg-gradient-to-br from-mama-100 to-moon-100 border-0">
        <div className="flex items-center gap-3">
          <div className="text-4xl animate-pulse-soft">🌸</div>
          <div>
            <div className="label">あなたのウェルネス</div>
            <div className="text-3xl font-bold">{score}/100</div>
            <p className="text-xs text-slate-600 mt-1">
              {score >= 70
                ? '今日はとても良い状態です。'
                : score >= 50
                  ? 'まずまず。引き続き自分を労って。'
                  : '休息と支援が必要なサインかも。'}
            </p>
          </div>
        </div>
      </section>

      {latest && radarData.length > 0 && (
        <section className="card">
          <div className="section-title">📡 直近のセルフチェック</div>
          <ResponsiveContainer width="100%" height={220}>
            <RadarChart data={radarData}>
              <PolarGrid stroke="#ffe4ec" />
              <PolarAngleAxis dataKey="axis" fontSize={11} />
              <Radar
                dataKey="v"
                stroke="#fb7298"
                fill="#fb7298"
                fillOpacity={0.4}
              />
            </RadarChart>
          </ResponsiveContainer>
        </section>
      )}

      <section className="card">
        <div className="section-title">📝 今日のセルフチェック</div>
        <div className="space-y-3 mt-3">
          <Slider label="🛌 睡眠時間" min={0} max={12} step={0.5} unit="時間" value={sleepHours} onChange={setSleepHours} />
          <Slider label="😊 気分" min={1} max={10} step={1} unit="/10" value={mood} onChange={setMood} />
          <Slider label="💪 からだの痛み" min={1} max={10} step={1} unit="/10" value={pain} onChange={setPain} />
          <Slider label="🌪 ストレス" min={1} max={10} step={1} unit="/10" value={stress} onChange={setStress} />
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={help}
              onChange={(e) => setHelp(e.target.checked)}
              className="w-5 h-5 accent-mama-500"
            />
            今日、家族やパートナーから具体的な助けがあった
          </label>
          <textarea
            rows={2}
            placeholder="気持ちを言葉にしてみる（任意）"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            className="w-full bg-white border border-mama-100 rounded-2xl px-4 py-3 text-sm"
          />
          <button
            className="btn-primary w-full"
            onClick={() => {
              addMamaCheck({
                at: Date.now(),
                sleepHours,
                moodScore: mood,
                bodyPainScore: pain,
                stressScore: stress,
                hasHelp: help,
                notes: notes.trim() || undefined,
              });
              setNotes('');
              alert('記録しました🌸 自分を労ってあげて。');
            }}
          >
            セルフチェックを記録
          </button>
        </div>
      </section>

      <section className="card">
        <div className="flex items-center justify-between">
          <div>
            <div className="section-title">🩺 EPDS 産後うつスクリーニング</div>
            <p className="text-xs text-slate-500 mt-1">
              エジンバラ産後うつ病自己評価票（参考値）。9点以上で要相談が目安。
            </p>
          </div>
          <button
            onClick={() => setEpdsOpen((v) => !v)}
            className="btn-ghost text-xs"
          >
            {epdsOpen ? '閉じる' : 'はじめる'}
          </button>
        </div>
        {epdsOpen && <EPDSForm />}
      </section>

      <section className="card bg-gradient-to-br from-moon-50 to-mama-50">
        <div className="section-title">📞 困ったときの連絡先</div>
        <ul className="text-sm mt-3 space-y-2">
          <li>👶 産後ケア事業（自治体）— 宿泊・日帰り・訪問型ケア</li>
          <li>📞 よりそいホットライン: 0120-279-338 (24時間/無料)</li>
          <li>📞 児童相談所虐待対応ダイヤル: 189</li>
          <li>📞 産婦人科オンライン: 妊娠・出産・産後の専門相談</li>
        </ul>
      </section>
    </div>
  );
}

function Slider({
  label,
  min,
  max,
  step,
  unit,
  value,
  onChange,
}: {
  label: string;
  min: number;
  max: number;
  step: number;
  unit: string;
  value: number;
  onChange: (n: number) => void;
}) {
  return (
    <div>
      <div className="flex justify-between text-sm">
        <span>{label}</span>
        <span className="font-bold text-mama-600">
          {value}
          {unit}
        </span>
      </div>
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={(e) => onChange(parseFloat(e.target.value))}
        className="w-full accent-mama-500"
      />
    </div>
  );
}

function EPDSForm() {
  const [answers, setAnswers] = useState<number[]>(Array(10).fill(0));
  const total = answers.reduce((a, b) => a + b, 0);
  // 設問1,2は逆配点。簡易版なので0-3の選択を直接合計。
  return (
    <div className="mt-3 space-y-3">
      {EPDS_QUESTIONS.map((q, i) => (
        <div key={i} className="text-sm">
          <div className="mb-1">
            <span className="font-semibold">Q{i + 1}.</span> {q}
          </div>
          <div className="grid grid-cols-4 gap-1">
            {[
              'まったくなかった',
              'たまにあった',
              'よくあった',
              'いつもあった',
            ].map((label, v) => (
              <button
                key={v}
                onClick={() => {
                  const next = [...answers];
                  next[i] = v;
                  setAnswers(next);
                }}
                className={`text-xs py-1.5 rounded-xl border ${
                  answers[i] === v
                    ? 'bg-mama-500 text-white border-mama-500'
                    : 'bg-white border-mama-100 text-slate-600'
                }`}
              >
                {label}
              </button>
            ))}
          </div>
        </div>
      ))}
      <div
        className={`text-center font-bold py-3 rounded-2xl ${
          total >= 9 ? 'bg-amber-100 text-amber-800' : 'bg-emerald-50 text-emerald-700'
        }`}
      >
        スコア: {total} / 30
        <div className="text-xs font-normal mt-1">
          {total >= 9
            ? '9点以上：産婦人科や心療内科への相談を強くおすすめします。'
            : '現時点では大きな懸念サインはないようです。'}
        </div>
      </div>
    </div>
  );
}
