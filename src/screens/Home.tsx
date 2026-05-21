import type { AppState, ScreenId } from '../types';
import {
  sumFeedingLast24h,
  sumSleepLast24h,
  sumDiaperLast24h,
  predictNextFeeding,
  mamaWellnessScore,
  tipsForAge,
  daysSince,
  formatTime,
} from '../utils';
import { generateSuggestion } from '../mami';
import { useMemo } from 'react';

export function Home({ state, go }: { state: AppState; go: (s: ScreenId) => void }) {
  const feed = sumFeedingLast24h(state.logs);
  const sleepMs = sumSleepLast24h(state.logs);
  const sleepH = (sleepMs / 3600000).toFixed(1);
  const diapers = sumDiaperLast24h(state.logs);
  const next = predictNextFeeding(state.logs);
  const score = mamaWellnessScore(state.mamaChecks, state.logs);
  const ageDays = daysSince(state.baby.birthday);
  const tips = useMemo(() => tipsForAge(ageDays), [ageDays]);
  const suggestion = useMemo(() => generateSuggestion(state), [state]);

  const toneStyles: Record<string, string> = {
    gentle: 'from-moon-200/60 to-mama-100/60 text-moon-700',
    alert: 'from-amber-100 to-red-100 text-amber-800',
    praise: 'from-emerald-100 to-mama-100 text-emerald-700',
  };

  return (
    <div className="space-y-4">
      {/* Greeting */}
      <section className="card relative overflow-hidden">
        <div className="absolute -top-10 -right-10 w-32 h-32 bg-mama-200/40 rounded-full blur-2xl" />
        <div className="relative">
          <div className="text-xs text-slate-500">
            {new Date().toLocaleDateString('ja-JP', {
              month: 'long',
              day: 'numeric',
              weekday: 'short',
            })}
          </div>
          <h2 className="text-xl font-bold mt-1">
            おかえりなさい、{state.mama.name}さん
          </h2>
          <p className="text-sm text-slate-600 mt-1">
            {state.baby.name}ちゃん、今日も生まれてきてくれてありがとう。
          </p>
        </div>
      </section>

      {/* AI Suggestion */}
      <section
        className={`card bg-gradient-to-br ${toneStyles[suggestion.tone]} border-0`}
      >
        <div className="flex items-start gap-3">
          <div className="text-2xl">💡</div>
          <div className="flex-1">
            <div className="text-xs font-bold opacity-70">AI mami からの提案</div>
            <div className="font-bold mt-0.5">{suggestion.title}</div>
            <div className="text-sm mt-1 leading-relaxed whitespace-pre-line">
              {suggestion.body}
            </div>
            <button
              onClick={() => go('mami')}
              className="mt-3 inline-flex items-center gap-1 text-xs font-bold underline underline-offset-4"
            >
              mami に相談する →
            </button>
          </div>
        </div>
      </section>

      {/* Wellness Score */}
      <section className="card">
        <div className="flex items-center justify-between">
          <div>
            <div className="label">ママのウェルネス</div>
            <div className="text-3xl font-bold mt-1">
              {score}
              <span className="text-sm font-normal text-slate-400 ml-1">/100</span>
            </div>
          </div>
          <ScoreRing value={score} />
        </div>
        <div className="mt-3 h-2 bg-mama-100 rounded-full overflow-hidden">
          <div
            className="h-full bg-gradient-to-r from-mama-400 to-moon-500 transition-all"
            style={{ width: `${score}%` }}
          />
        </div>
        <button
          onClick={() => go('mama')}
          className="text-xs text-mama-600 font-semibold mt-2"
        >
          詳しくチェックする →
        </button>
      </section>

      {/* Today summary */}
      <section className="grid grid-cols-3 gap-3">
        <StatCard
          icon="🍼"
          label="授乳"
          main={`${feed.count}回`}
          sub={`${feed.ml}ml`}
          onClick={() => go('log')}
        />
        <StatCard
          icon="😴"
          label="睡眠"
          main={`${sleepH}h`}
          sub="24時間"
          onClick={() => go('log')}
        />
        <StatCard
          icon="💧"
          label="おむつ"
          main={`${diapers}回`}
          sub="24時間"
          onClick={() => go('log')}
        />
      </section>

      {/* Next feeding prediction */}
      {next && (
        <section className="card bg-gradient-to-br from-moon-50 to-mama-50 border-moon-200">
          <div className="flex items-center gap-3">
            <div className="text-2xl animate-float">🔮</div>
            <div className="flex-1">
              <div className="text-xs font-bold text-moon-700">
                次の授乳予測 (AI)
              </div>
              <div className="text-lg font-bold mt-0.5">
                {new Date(next.at).getHours()}:
                {new Date(next.at).getMinutes().toString().padStart(2, '0')}
                <span className="text-xs font-normal text-slate-500 ml-2">
                  ／ 平均間隔 {next.intervalMin}分
                </span>
              </div>
            </div>
          </div>
        </section>
      )}

      {/* Quick actions */}
      <section className="card">
        <div className="section-title">⚡ クイック記録</div>
        <div className="grid grid-cols-2 gap-2 mt-3">
          <button onClick={() => go('log')} className="btn-ghost">
            🍼 授乳
          </button>
          <button onClick={() => go('log')} className="btn-ghost">
            😴 睡眠
          </button>
          <button onClick={() => go('log')} className="btn-ghost">
            💧 おむつ
          </button>
          <button onClick={() => go('future')} className="btn-ghost">
            🎤 泣き声解析
          </button>
        </div>
      </section>

      {/* Tips */}
      <section className="card">
        <div className="section-title">📚 今の月齢のヒント</div>
        <ul className="space-y-2 mt-3">
          {tips.map((t, i) => (
            <li
              key={i}
              className="text-sm text-slate-600 leading-relaxed pl-4 border-l-2 border-mama-200"
            >
              {t}
            </li>
          ))}
        </ul>
      </section>

      {/* Recent logs */}
      <section className="card">
        <div className="section-title">🕒 最近の記録</div>
        <ul className="mt-3 divide-y divide-mama-50">
          {state.logs.slice(0, 5).map((l) => (
            <li key={l.id} className="py-2 flex items-center gap-3 text-sm">
              <span className="text-lg">
                {l.type === 'feeding' && '🍼'}
                {l.type === 'sleep' && '😴'}
                {l.type === 'diaper' && '💧'}
                {l.type === 'mood' && '💕'}
                {l.type === 'note' && '📝'}
              </span>
              <span className="flex-1">
                {l.type === 'feeding' && `授乳 ${l.amountMl ?? '-'}ml / ${l.durationMin ?? '-'}分`}
                {l.type === 'sleep' && '睡眠'}
                {l.type === 'diaper' && `おむつ (${l.diaper === 'pee' ? 'おしっこ' : l.diaper === 'poop' ? 'うんち' : '両方'})`}
                {l.type === 'mood' && `気分 ${l.mood}/5`}
                {l.type === 'note' && (l.note ?? 'メモ')}
              </span>
              <span className="text-xs text-slate-400">{formatTime(l.at)}</span>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}

function StatCard({
  icon,
  label,
  main,
  sub,
  onClick,
}: {
  icon: string;
  label: string;
  main: string;
  sub: string;
  onClick?: () => void;
}) {
  return (
    <button
      onClick={onClick}
      className="card hover:shadow-lg transition text-left active:scale-95"
    >
      <div className="text-xl">{icon}</div>
      <div className="text-[10px] text-slate-500 mt-1">{label}</div>
      <div className="text-lg font-bold">{main}</div>
      <div className="text-[10px] text-slate-400">{sub}</div>
    </button>
  );
}

function ScoreRing({ value }: { value: number }) {
  const r = 26;
  const c = 2 * Math.PI * r;
  const offset = c - (value / 100) * c;
  return (
    <svg width="72" height="72" viewBox="0 0 72 72">
      <circle cx="36" cy="36" r={r} stroke="#ffe4ec" strokeWidth="8" fill="none" />
      <circle
        cx="36"
        cy="36"
        r={r}
        stroke="url(#ringg)"
        strokeWidth="8"
        fill="none"
        strokeLinecap="round"
        strokeDasharray={c}
        strokeDashoffset={offset}
        transform="rotate(-90 36 36)"
      />
      <defs>
        <linearGradient id="ringg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#fb7298" />
          <stop offset="100%" stopColor="#6b7fe0" />
        </linearGradient>
      </defs>
      <text x="36" y="40" textAnchor="middle" fontSize="14" fontWeight="700" fill="#831540">
        {value}
      </text>
    </svg>
  );
}
