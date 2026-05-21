import { useMemo, useState } from 'react';
import type { AppState, LogEntry, LogType } from '../types';
import { formatTime } from '../utils';
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  BarChart,
  Bar,
  CartesianGrid,
} from 'recharts';

export function LogScreen({
  state,
  addLog,
  removeLog,
}: {
  state: AppState;
  addLog: (l: Omit<LogEntry, 'id'>) => void;
  removeLog: (id: string) => void;
}) {
  const [activeType, setActiveType] = useState<LogType>('feeding');

  const chartData = useMemo(() => {
    // 直近7日の日別合計
    const buckets: Record<string, { date: string; feed: number; sleepH: number; diaper: number }> =
      {};
    for (let i = 6; i >= 0; i--) {
      const d = new Date();
      d.setHours(0, 0, 0, 0);
      d.setDate(d.getDate() - i);
      const key = `${d.getMonth() + 1}/${d.getDate()}`;
      buckets[key] = { date: key, feed: 0, sleepH: 0, diaper: 0 };
    }
    state.logs.forEach((l) => {
      const d = new Date(l.at);
      d.setHours(0, 0, 0, 0);
      const key = `${d.getMonth() + 1}/${d.getDate()}`;
      if (!buckets[key]) return;
      if (l.type === 'feeding') buckets[key].feed += l.amountMl ?? 0;
      if (l.type === 'sleep') {
        const start = l.sleepStart ?? l.at;
        const end = l.sleepEnd ?? l.at;
        buckets[key].sleepH += (end - start) / 3600000;
      }
      if (l.type === 'diaper') buckets[key].diaper += 1;
    });
    return Object.values(buckets);
  }, [state.logs]);

  return (
    <div className="space-y-4">
      <div className="card">
        <div className="section-title">📊 直近7日のトレンド</div>
        <div className="mt-3">
          <div className="text-xs text-slate-500 mb-1">授乳量 (ml)</div>
          <ResponsiveContainer width="100%" height={140}>
            <BarChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#ffe4ec" />
              <XAxis dataKey="date" fontSize={10} />
              <YAxis fontSize={10} />
              <Tooltip />
              <Bar dataKey="feed" fill="#fb7298" radius={[6, 6, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
          <div className="text-xs text-slate-500 mt-2 mb-1">睡眠 (時間)</div>
          <ResponsiveContainer width="100%" height={140}>
            <LineChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#e8edff" />
              <XAxis dataKey="date" fontSize={10} />
              <YAxis fontSize={10} />
              <Tooltip />
              <Line
                type="monotone"
                dataKey="sleepH"
                stroke="#6b7fe0"
                strokeWidth={3}
                dot={{ r: 3 }}
              />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="card">
        <div className="section-title">➕ 新しい記録</div>
        <div className="flex gap-2 mt-3 overflow-x-auto pb-1">
          {(
            [
              { id: 'feeding', label: '🍼 授乳' },
              { id: 'sleep', label: '😴 睡眠' },
              { id: 'diaper', label: '💧 おむつ' },
              { id: 'mood', label: '💕 きげん' },
              { id: 'note', label: '📝 メモ' },
            ] as const
          ).map((t) => (
            <button
              key={t.id}
              onClick={() => setActiveType(t.id)}
              className={`px-3 py-1.5 rounded-full text-sm whitespace-nowrap ${
                activeType === t.id
                  ? 'bg-mama-500 text-white'
                  : 'bg-mama-50 text-mama-700'
              }`}
            >
              {t.label}
            </button>
          ))}
        </div>
        <div className="mt-4">
          {activeType === 'feeding' && <FeedingForm onSubmit={addLog} />}
          {activeType === 'sleep' && <SleepForm onSubmit={addLog} />}
          {activeType === 'diaper' && <DiaperForm onSubmit={addLog} />}
          {activeType === 'mood' && <MoodForm onSubmit={addLog} />}
          {activeType === 'note' && <NoteForm onSubmit={addLog} />}
        </div>
      </div>

      <div className="card">
        <div className="section-title">📜 すべての記録</div>
        <ul className="mt-3 divide-y divide-mama-50">
          {state.logs.map((l) => (
            <li key={l.id} className="py-2.5 flex items-center gap-3 text-sm">
              <span className="text-lg w-6 text-center">
                {l.type === 'feeding' && '🍼'}
                {l.type === 'sleep' && '😴'}
                {l.type === 'diaper' && '💧'}
                {l.type === 'mood' && '💕'}
                {l.type === 'note' && '📝'}
              </span>
              <span className="flex-1">
                {l.type === 'feeding' &&
                  `授乳 ${l.side === 'bottle' ? 'ミルク' : l.side === 'left' ? '左' : '右'} ${
                    l.amountMl ?? '-'
                  }ml / ${l.durationMin ?? '-'}分`}
                {l.type === 'sleep' &&
                  l.sleepStart &&
                  l.sleepEnd &&
                  `睡眠 ${Math.round((l.sleepEnd - l.sleepStart) / 60000)}分`}
                {l.type === 'diaper' &&
                  `おむつ (${
                    l.diaper === 'pee' ? 'おしっこ' : l.diaper === 'poop' ? 'うんち' : '両方'
                  })`}
                {l.type === 'mood' && `気分 ${l.mood}/5`}
                {l.type === 'note' && (l.note ?? 'メモ')}
              </span>
              <span className="text-xs text-slate-400">{formatTime(l.at)}</span>
              <button
                onClick={() => removeLog(l.id)}
                className="text-xs text-slate-300 hover:text-red-400 px-1"
                title="削除"
              >
                ✕
              </button>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}

function FeedingForm({ onSubmit }: { onSubmit: (l: Omit<LogEntry, 'id'>) => void }) {
  const [side, setSide] = useState<'left' | 'right' | 'bottle'>('left');
  const [amount, setAmount] = useState(100);
  const [duration, setDuration] = useState(15);
  return (
    <div className="space-y-3">
      <div className="flex gap-2">
        {(
          [
            ['left', '左おっぱい'],
            ['right', '右おっぱい'],
            ['bottle', 'ミルク'],
          ] as const
        ).map(([k, l]) => (
          <button
            key={k}
            onClick={() => setSide(k)}
            className={`flex-1 py-2 rounded-2xl text-sm font-semibold border ${
              side === k
                ? 'bg-mama-500 text-white border-mama-500'
                : 'bg-white border-mama-100 text-slate-600'
            }`}
          >
            {l}
          </button>
        ))}
      </div>
      <NumRow label="量 (ml)" value={amount} setValue={setAmount} step={10} />
      <NumRow label="時間 (分)" value={duration} setValue={setDuration} step={5} />
      <button
        className="btn-primary w-full"
        onClick={() =>
          onSubmit({
            type: 'feeding',
            at: Date.now(),
            side,
            amountMl: amount,
            durationMin: duration,
          })
        }
      >
        記録する
      </button>
    </div>
  );
}

function SleepForm({ onSubmit }: { onSubmit: (l: Omit<LogEntry, 'id'>) => void }) {
  const [minutes, setMinutes] = useState(60);
  return (
    <div className="space-y-3">
      <NumRow label="睡眠時間 (分)" value={minutes} setValue={setMinutes} step={15} />
      <p className="text-xs text-slate-500">直前に寝終わったタイミングで記録</p>
      <button
        className="btn-primary w-full"
        onClick={() =>
          onSubmit({
            type: 'sleep',
            at: Date.now(),
            sleepEnd: Date.now(),
            sleepStart: Date.now() - minutes * 60 * 1000,
          })
        }
      >
        記録する
      </button>
    </div>
  );
}

function DiaperForm({ onSubmit }: { onSubmit: (l: Omit<LogEntry, 'id'>) => void }) {
  const [d, setD] = useState<'pee' | 'poop' | 'both'>('pee');
  return (
    <div className="space-y-3">
      <div className="grid grid-cols-3 gap-2">
        {(
          [
            ['pee', 'おしっこ'],
            ['poop', 'うんち'],
            ['both', '両方'],
          ] as const
        ).map(([k, l]) => (
          <button
            key={k}
            onClick={() => setD(k)}
            className={`py-2 rounded-2xl text-sm font-semibold border ${
              d === k
                ? 'bg-mama-500 text-white border-mama-500'
                : 'bg-white border-mama-100 text-slate-600'
            }`}
          >
            {l}
          </button>
        ))}
      </div>
      <button
        className="btn-primary w-full"
        onClick={() => onSubmit({ type: 'diaper', at: Date.now(), diaper: d })}
      >
        記録する
      </button>
    </div>
  );
}

function MoodForm({ onSubmit }: { onSubmit: (l: Omit<LogEntry, 'id'>) => void }) {
  const [m, setM] = useState<1 | 2 | 3 | 4 | 5>(3);
  return (
    <div className="space-y-3">
      <div className="flex justify-between">
        {([1, 2, 3, 4, 5] as const).map((v) => (
          <button
            key={v}
            onClick={() => setM(v)}
            className={`text-3xl transition ${m === v ? 'scale-125' : 'opacity-40'}`}
          >
            {['😭', '😟', '😐', '🙂', '😊'][v - 1]}
          </button>
        ))}
      </div>
      <button
        className="btn-primary w-full"
        onClick={() => onSubmit({ type: 'mood', at: Date.now(), mood: m })}
      >
        記録する
      </button>
    </div>
  );
}

function NoteForm({ onSubmit }: { onSubmit: (l: Omit<LogEntry, 'id'>) => void }) {
  const [note, setNote] = useState('');
  return (
    <div className="space-y-3">
      <textarea
        rows={4}
        className="w-full bg-white border border-mama-100 rounded-2xl px-4 py-3"
        placeholder="今日の出来事、気づき、写真の代わりに…"
        value={note}
        onChange={(e) => setNote(e.target.value)}
      />
      <button
        disabled={!note.trim()}
        className="btn-primary w-full disabled:opacity-50"
        onClick={() => {
          onSubmit({ type: 'note', at: Date.now(), note });
          setNote('');
        }}
      >
        記録する
      </button>
    </div>
  );
}

function NumRow({
  label,
  value,
  setValue,
  step,
}: {
  label: string;
  value: number;
  setValue: (n: number) => void;
  step: number;
}) {
  return (
    <div className="flex items-center justify-between gap-3">
      <span className="text-sm text-slate-600">{label}</span>
      <div className="flex items-center gap-2">
        <button
          className="w-9 h-9 rounded-full bg-mama-50 text-mama-700 font-bold"
          onClick={() => setValue(Math.max(0, value - step))}
        >
          −
        </button>
        <span className="w-14 text-center font-bold">{value}</span>
        <button
          className="w-9 h-9 rounded-full bg-mama-50 text-mama-700 font-bold"
          onClick={() => setValue(value + step)}
        >
          +
        </button>
      </div>
    </div>
  );
}
