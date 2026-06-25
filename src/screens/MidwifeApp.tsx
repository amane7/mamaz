import { useMemo, useState } from 'react';
import type {
  MidwifeTab,
  Patient,
  ChartEntry,
  Appointment,
} from '../types';
import {
  formatDate,
  formatDateTime,
  formatTime,
  relative,
  startOfWeek,
  weekdayShort,
  isSameDay,
  riskLabel,
  daysSince,
  slotToTime,
  ymd,
} from '../utils';
import { analyzeIntake, suggestSOAP, triageMessage } from '../ai';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  CartesianGrid,
  PieChart,
  Pie,
  Cell,
  Legend,
  LineChart,
  Line,
} from 'recharts';

type Store = ReturnType<typeof import('../store').useStore>;

// アクセントカラー (種類別)
function typeAccent(type: string) {
  switch (type) {
    case '産後ケア':
      return 'bg-cyber-500/15 text-cyber-300 border-cyber-500/30';
    case '乳房ケア':
      return 'bg-signal-500/15 text-signal-400 border-signal-500/30';
    case '母乳相談':
      return 'bg-plasma-500/15 text-plasma-400 border-plasma-500/30';
    case '沐浴指導':
      return 'bg-ok-500/15 text-ok-500 border-ok-500/30';
    case '初回相談':
      return 'bg-warn-500/15 text-warn-500 border-warn-500/30';
    default:
      return 'bg-white/5 text-ink-300 border-white/10';
  }
}

export function MidwifeApp({ store, onExit }: { store: Store; onExit: () => void }) {
  const [tab, setTab] = useState<MidwifeTab>('dashboard');
  const [selectedPatientId, setSelectedPatientId] = useState<string | null>(null);

  const urgentCount = store.state.chats.filter(
    (c) => c.from === 'mama' && c.urgent,
  ).length;

  return (
    <div className="min-h-screen flex flex-col md:flex-row relative">
      <div className="fixed inset-0 tech-bg opacity-25 pointer-events-none" />
      <SideNav
        tab={tab}
        setTab={setTab}
        onExit={onExit}
        inboxBadge={urgentCount}
        lineLinked={store.state.config.lineLinked}
      />
      <main className="flex-1 px-4 md:px-8 py-6 md:py-10 max-w-7xl w-full mx-auto pb-32 md:pb-10 relative">
        {tab === 'dashboard' && (
          <Dashboard
            store={store}
            setTab={setTab}
            openPatient={(id) => {
              setSelectedPatientId(id);
              setTab('chart');
            }}
          />
        )}
        {tab === 'calendar' && <Calendar store={store} />}
        {tab === 'patients' && (
          <Patients
            store={store}
            onSelect={(id) => {
              setSelectedPatientId(id);
              setTab('chart');
            }}
          />
        )}
        {tab === 'chart' && (
          <ChartScreen
            store={store}
            patientId={selectedPatientId}
            setPatientId={setSelectedPatientId}
          />
        )}
        {tab === 'analytics' && <Analytics store={store} />}
        {tab === 'inbox' && <Inbox store={store} />}
        {tab === 'shift' && <Shift store={store} />}
        {tab === 'settings' && <Settings store={store} />}
      </main>
      <MobileTabBar tab={tab} setTab={setTab} urgentCount={urgentCount} />
    </div>
  );
}

// ════════════════════════════════════════════
// SideNav (desktop)
// ════════════════════════════════════════════
function SideNav({
  tab,
  setTab,
  onExit,
  inboxBadge,
  lineLinked,
}: {
  tab: MidwifeTab;
  setTab: (t: MidwifeTab) => void;
  onExit: () => void;
  inboxBadge: number;
  lineLinked: boolean;
}) {
  const items: { id: MidwifeTab; icon: string; label: string }[] = [
    { id: 'dashboard', icon: '◉', label: 'ダッシュボード' },
    { id: 'calendar', icon: '▦', label: 'カレンダー' },
    { id: 'shift', icon: '◧', label: 'シフト' },
    { id: 'patients', icon: '◐', label: '利用者' },
    { id: 'chart', icon: '◭', label: 'カルテ' },
    { id: 'analytics', icon: '◊', label: '分析' },
    { id: 'inbox', icon: '◈', label: '受信箱' },
    { id: 'settings', icon: '⚙', label: '設定' },
  ];
  return (
    <aside className="hidden md:flex md:flex-col w-60 shrink-0 border-r border-white/5 bg-ink-950/60 backdrop-blur-xl sticky top-0 h-screen z-20">
      <div className="p-5 border-b border-white/5">
        <div className="flex items-center gap-2.5">
          <div className="w-9 h-9 rounded-lg bg-cyber-grad flex items-center justify-center shadow-neon-cyan">
            <svg viewBox="0 0 24 24" className="w-5 h-5 text-white">
              <path
                d="M12 2L4 7v6c0 5 3.5 8.5 8 9 4.5-.5 8-4 8-9V7l-8-5z"
                fill="currentColor"
                opacity="0.9"
              />
              <circle cx="12" cy="11" r="2.5" fill="#0c1124" />
            </svg>
          </div>
          <div>
            <div className="display font-bold text-ink-50">
              Manary<span className="text-cyber-400">+</span>
            </div>
            <div className="mono text-[10px] text-ink-400">MIDWIFE OS</div>
          </div>
        </div>
      </div>
      <nav className="flex-1 px-3 py-4 space-y-1">
        {items.map((it) => {
          const active = tab === it.id;
          return (
            <button
              key={it.id}
              onClick={() => setTab(it.id)}
              className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition relative ${
                active
                  ? 'bg-cyber-500/15 text-cyber-300 border border-cyber-500/30'
                  : 'text-ink-300 hover:bg-white/[0.03] border border-transparent'
              }`}
            >
              <span className={`mono ${active ? 'text-cyber-400' : 'text-ink-500'}`}>
                {it.icon}
              </span>
              <span className="flex-1 text-left font-medium">{it.label}</span>
              {it.id === 'inbox' && inboxBadge > 0 && (
                <span className="chip-ng text-[10px]">{inboxBadge}</span>
              )}
            </button>
          );
        })}
      </nav>
      <div className="p-3 border-t border-white/5 space-y-2">
        <div className="px-3 py-2 rounded-lg bg-white/[0.02] border border-white/5">
          <div className="flex items-center justify-between text-xs">
            <span className="text-ink-300">公式LINE</span>
            <span className={lineLinked ? 'chip-ok text-[10px]' : 'chip-warn text-[10px]'}>
              {lineLinked ? 'LINKED' : 'NOT LINKED'}
            </span>
          </div>
        </div>
        <button
          onClick={onExit}
          className="w-full px-3 py-2 rounded-lg text-xs text-ink-400 hover:bg-white/[0.03] transition flex items-center gap-2"
        >
          ← ランディングへ
        </button>
      </div>
    </aside>
  );
}

// ════════════════════════════════════════════
// MobileTabBar
// ════════════════════════════════════════════
function MobileTabBar({
  tab,
  setTab,
  urgentCount,
}: {
  tab: MidwifeTab;
  setTab: (t: MidwifeTab) => void;
  urgentCount: number;
}) {
  const items: { id: MidwifeTab; icon: string; label: string }[] = [
    { id: 'dashboard', icon: '◉', label: 'Dash' },
    { id: 'calendar', icon: '▦', label: '予約' },
    { id: 'patients', icon: '◐', label: '利用者' },
    { id: 'inbox', icon: '◈', label: '受信' },
    { id: 'settings', icon: '⚙', label: '設定' },
  ];
  return (
    <nav className="md:hidden fixed bottom-0 left-0 right-0 z-30 pb-[env(safe-area-inset-bottom)] px-3 pb-3 pointer-events-none">
      <div className="backdrop-blur-xl bg-ink-900/85 border border-white/10 rounded-2xl flex justify-between p-1 shadow-card pointer-events-auto">
        {items.map((it) => {
          const active = tab === it.id;
          return (
            <button
              key={it.id}
              onClick={() => setTab(it.id)}
              className={`relative flex-1 flex flex-col items-center gap-0.5 py-2 rounded-xl ${
                active
                  ? 'bg-cyber-grad text-white shadow-neon-cyan'
                  : 'text-ink-400'
              }`}
            >
              <span className="text-base mono">{it.icon}</span>
              <span className="text-[10px] font-semibold">{it.label}</span>
              {it.id === 'inbox' && urgentCount > 0 && (
                <span className="absolute top-1 right-3 w-2 h-2 rounded-full bg-ng-500 animate-pulse" />
              )}
            </button>
          );
        })}
      </div>
    </nav>
  );
}

// ════════════════════════════════════════════
// Dashboard
// ════════════════════════════════════════════
function Dashboard({
  store,
  setTab,
  openPatient,
}: {
  store: Store;
  setTab: (t: MidwifeTab) => void;
  openPatient: (id: string) => void;
}) {
  const today = new Date();
  const todayAppts = store.state.appointments
    .filter((a) => isSameDay(a.start, today))
    .sort((a, b) => a.start.localeCompare(b.start));
  const urgentChats = store.state.chats.filter(
    (c) => c.from === 'mama' && c.urgent,
  );
  const intakeRate = Math.round(
    (store.state.intakes.length /
      Math.max(1, store.state.appointments.length)) *
      100,
  );
  const lineLogs = store.state.lineNotifications.slice(0, 4);

  return (
    <div className="space-y-6">
      {/* ヘッダー */}
      <div className="flex items-end justify-between flex-wrap gap-3">
        <div>
          <div className="mono text-[10px] text-cyber-400">
            {formatDateTime(today.toISOString())}
          </div>
          <h1 className="display text-3xl font-bold text-ink-50 mt-1">
            ダッシュボード
          </h1>
        </div>
        <div className="flex gap-2">
          <span className="chip-cyan">
            <span className="dot bg-cyber-400 animate-pulse-glow" /> ONLINE
          </span>
          <span className="chip">Staff: 田村</span>
        </div>
      </div>

      {/* KPI */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Kpi label="本日の予約" value={`${todayAppts.length}`} note="+2 vs 昨日" />
        <Kpi label="問診回収率" value={`${intakeRate}%`} note="目標 90%" />
        <Kpi label="緊急チャット" value={`${urgentChats.length}`} note="要確認" warn={urgentChats.length > 0} />
        <Kpi label="登録利用者" value={`${store.state.patients.length}`} note="累計" />
      </div>

      <div className="grid lg:grid-cols-3 gap-4">
        {/* 今日のスケジュール */}
        <div className="lg:col-span-2 card">
          <div className="flex items-center justify-between mb-4">
            <div className="section-title text-ink-50">
              <span className="text-cyber-400">●</span> 本日のスケジュール
            </div>
            <button
              onClick={() => setTab('calendar')}
              className="text-xs mono text-cyber-400 hover:text-cyber-300"
            >
              ▸ カレンダー全体
            </button>
          </div>
          {todayAppts.length === 0 ? (
            <div className="text-center py-6 text-ink-400 text-sm">本日の予約はありません</div>
          ) : (
            <div className="space-y-1.5">
              {todayAppts.map((a) => {
                const p = store.state.patients.find((x) => x.id === a.patientId);
                if (!p) return null;
                const intake = store.state.intakes.find((i) => i.appointmentId === a.id);
                return (
                  <button
                    key={a.id}
                    onClick={() => openPatient(p.id)}
                    className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg bg-white/[0.02] border border-white/5 hover:border-cyber-700/40 transition text-left"
                  >
                    <span className="mono text-cyber-400 text-sm w-12">
                      {formatTime(a.start)}
                    </span>
                    <span className="text-xl">{p.avatar}</span>
                    <div className="flex-1">
                      <div className="text-sm text-ink-50 font-medium">{p.name}</div>
                      <div className="text-[10px] mono text-ink-500">
                        {a.durationMin}min ・ {p.babyName}ちゃん / D{daysSince(p.birthday)}
                      </div>
                    </div>
                    <span className={`chip border ${typeAccent(a.type)}`}>{a.type}</span>
                    {p.riskFlags.map((r) => (
                      <span key={r} className={`chip text-[10px] ${riskLabel(r).cls}`}>
                        {riskLabel(r).label.split(' ')[0]}
                      </span>
                    ))}
                    {intake ? (
                      <span className="chip-ok text-[10px]">📝</span>
                    ) : (
                      <span className="chip-warn text-[10px]">未</span>
                    )}
                  </button>
                );
              })}
            </div>
          )}
        </div>

        {/* AIインサイト */}
        <div className="card">
          <div className="section-title text-ink-50 mb-3">
            <span className="text-signal-500">●</span> AIインサイト
          </div>
          <div className="space-y-2">
            {store.state.intakes.slice(0, 2).flatMap((i) => {
              const patient = store.state.patients.find((p) => p.id === i.patientId);
              if (!patient) return [];
              const insights = analyzeIntake(i, patient, store.state.charts);
              return insights.slice(0, 2).map((ins, idx) => (
                <div
                  key={`${i.id}-${idx}`}
                  className={`text-xs leading-relaxed p-2.5 rounded-lg border ${
                    ins.severity === 'urgent'
                      ? 'bg-ng-500/10 border-ng-500/30 text-ng-500'
                      : ins.severity === 'warn'
                        ? 'bg-warn-500/10 border-warn-500/30 text-warn-500'
                        : 'bg-plasma-500/10 border-plasma-500/30 text-plasma-400'
                  }`}
                >
                  <div className="font-bold">{patient.name}様</div>
                  <div className="text-ink-200 mt-0.5">{ins.message}</div>
                </div>
              ));
            })}
          </div>
        </div>

        {/* 緊急チャット */}
        <div className="card lg:col-span-2">
          <div className="section-title text-ink-50 mb-3">
            <span className="text-ng-500">●</span> 緊急チャット
            {urgentChats.length > 0 && (
              <span className="chip-ng ml-2 text-[10px] animate-pulse">{urgentChats.length}</span>
            )}
          </div>
          {urgentChats.length === 0 ? (
            <div className="text-sm text-ink-400 text-center py-3">緊急の連絡はありません</div>
          ) : (
            <div className="space-y-2">
              {urgentChats.map((c) => {
                const p = store.state.patients.find((x) => x.id === c.roomId);
                return (
                  <button
                    key={c.id}
                    onClick={() => setTab('inbox')}
                    className="w-full text-left p-3 rounded-lg bg-ng-500/5 border border-ng-500/20 hover:border-ng-500/40 transition flex items-start gap-3"
                  >
                    <span className="text-xl">{p?.avatar}</span>
                    <div className="flex-1">
                      <div className="flex items-center gap-2">
                        <span className="text-sm font-medium text-ink-50">{p?.name}</span>
                        <span className="chip-ng text-[10px]">🆘 URGENT</span>
                        <span className="mono text-[10px] text-ink-500">{relative(c.at)}</span>
                      </div>
                      <div className="text-sm text-ink-200 mt-1 line-clamp-2">{c.text}</div>
                    </div>
                  </button>
                );
              })}
            </div>
          )}
        </div>

        {/* LINE通知ログ */}
        <div className="card">
          <div className="section-title text-ink-50 mb-3">
            <span className="text-ok-500">●</span> LINE通知
          </div>
          <div className="space-y-2">
            {lineLogs.map((n) => (
              <div
                key={n.id}
                className="text-[11px] p-2 rounded bg-white/[0.02] border border-white/5"
              >
                <div className="flex items-center justify-between mb-0.5">
                  <span className="mono text-[10px] text-cyber-400">{n.to}</span>
                  <span className="mono text-[10px] text-ink-500">{relative(n.at)}</span>
                </div>
                <div className="text-ink-200 line-clamp-2 whitespace-pre-line">{n.message}</div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function Kpi({
  label,
  value,
  note,
  warn,
}: {
  label: string;
  value: string;
  note?: string;
  warn?: boolean;
}) {
  return (
    <div className={`card ${warn ? 'border-ng-500/30' : ''}`}>
      <div className="label">{label}</div>
      <div className={`kpi-num mt-2 ${warn ? '!bg-none !text-ng-500' : ''}`}>{value}</div>
      {note && (
        <div className={`mono text-[10px] mt-1 ${warn ? 'text-ng-500' : 'text-cyber-400'}`}>
          {note}
        </div>
      )}
    </div>
  );
}

// ════════════════════════════════════════════
// Calendar
// ════════════════════════════════════════════
function Calendar({ store }: { store: Store }) {
  const [weekStart, setWeekStart] = useState(() => startOfWeek(new Date()));
  const days = useMemo(
    () =>
      Array.from({ length: 7 }, (_, i) => {
        const d = new Date(weekStart);
        d.setDate(d.getDate() + i);
        return d;
      }),
    [weekStart],
  );

  const hourFrom = store.state.config.openHour;
  const hourTo = store.state.config.closeHour;
  const hours = useMemo(
    () => Array.from({ length: hourTo - hourFrom }, (_, i) => hourFrom + i),
    [hourFrom, hourTo],
  );

  const shift = (n: number) => {
    const d = new Date(weekStart);
    d.setDate(d.getDate() + n * 7);
    setWeekStart(d);
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <div className="mono text-[10px] text-cyber-400">CALENDAR</div>
          <h1 className="display text-3xl font-bold text-ink-50 mt-1">予約カレンダー</h1>
        </div>
        <div className="flex items-center gap-2">
          <button onClick={() => shift(-1)} className="btn-ghost text-xs">←</button>
          <button onClick={() => setWeekStart(startOfWeek(new Date()))} className="btn-ghost text-xs">
            今週
          </button>
          <button onClick={() => shift(1)} className="btn-ghost text-xs">→</button>
        </div>
      </div>

      <div className="card overflow-x-auto">
        <div className="grid grid-cols-[60px_repeat(7,1fr)] gap-px bg-white/5 rounded-lg overflow-hidden min-w-[700px]">
          <div className="bg-ink-900 p-2 mono text-[10px] text-ink-500" />
          {days.map((d, i) => (
            <div
              key={i}
              className={`bg-ink-900 p-2 text-center ${
                isSameDay(d, new Date()) ? 'text-cyber-400' : 'text-ink-300'
              }`}
            >
              <div className="mono text-[10px]">{weekdayShort(d.getDay())}</div>
              <div className={`display font-bold ${isSameDay(d, new Date()) ? '' : 'text-ink-50'}`}>
                {d.getDate()}
              </div>
            </div>
          ))}
          {hours.map((h) => (
            <>
              <div key={`h-${h}`} className="bg-ink-900 p-2 mono text-[10px] text-ink-500 text-right">
                {String(h).padStart(2, '0')}:00
              </div>
              {days.map((d, i) => {
                const slotAppts = store.state.appointments.filter((a) => {
                  const ad = new Date(a.start);
                  return isSameDay(ad, d) && ad.getHours() === h;
                });
                const dateStr = ymd(d);
                const isClosed = store.state.shifts
                  .filter((s) => s.date === dateStr && (s.slotIndex === h * 2 || s.slotIndex === h * 2 + 1))
                  .every((s) => s.closed);
                return (
                  <div
                    key={`${h}-${i}`}
                    className={`bg-ink-900 p-1 min-h-[56px] relative ${
                      isClosed ? 'bg-stripe opacity-50' : ''
                    }`}
                    style={
                      isClosed
                        ? {
                            backgroundImage:
                              'repeating-linear-gradient(45deg, rgba(255,255,255,0.04) 0 6px, transparent 6px 12px)',
                          }
                        : undefined
                    }
                  >
                    {slotAppts.map((a) => {
                      const p = store.state.patients.find((x) => x.id === a.patientId);
                      return (
                        <div
                          key={a.id}
                          className={`text-[10px] p-1 rounded mb-0.5 border ${typeAccent(a.type)}`}
                          title={`${a.type} ${a.durationMin}min`}
                        >
                          <div className="mono font-bold">{formatTime(a.start)}</div>
                          <div className="truncate text-ink-200">{p?.name}</div>
                        </div>
                      );
                    })}
                  </div>
                );
              })}
            </>
          ))}
        </div>
        <div className="flex flex-wrap gap-2 mt-4 text-xs">
          <span className={`chip border ${typeAccent('産後ケア')}`}>産後ケア</span>
          <span className={`chip border ${typeAccent('乳房ケア')}`}>乳房ケア</span>
          <span className={`chip border ${typeAccent('母乳相談')}`}>母乳相談</span>
          <span className={`chip border ${typeAccent('沐浴指導')}`}>沐浴指導</span>
          <span className={`chip border ${typeAccent('初回相談')}`}>初回相談</span>
          <span className="chip">斜線 = 休診</span>
        </div>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════
// Shift 管理
// ════════════════════════════════════════════
function Shift({ store }: { store: Store }) {
  const [weekStart, setWeekStart] = useState(() => startOfWeek(new Date()));
  const days = useMemo(
    () =>
      Array.from({ length: 7 }, (_, i) => {
        const d = new Date(weekStart);
        d.setDate(d.getDate() + i);
        return d;
      }),
    [weekStart],
  );
  const hourFrom = store.state.config.openHour;
  const hourTo = store.state.config.closeHour;
  const slots = useMemo(
    () =>
      Array.from({ length: (hourTo - hourFrom) * 2 }, (_, i) => hourFrom * 2 + i),
    [hourFrom, hourTo],
  );

  // 1日まるごと休診トグル
  const toggleDay = (date: string) => {
    const daySlots = store.state.shifts.filter((s) => s.date === date);
    const anyOpen = daySlots.some((s) => !s.closed);
    daySlots.forEach((s) => {
      if (anyOpen !== s.closed) {
        store.toggleShift(s.id);
      }
    });
  };

  // 1時間まるごとトグル
  const toggleHour = (date: string, h: number) => {
    const ids = store.state.shifts
      .filter(
        (s) =>
          s.date === date && (s.slotIndex === h * 2 || s.slotIndex === h * 2 + 1),
      )
      .map((s) => s.id);
    ids.forEach((id) => store.toggleShift(id));
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <div className="mono text-[10px] text-cyber-400">SHIFT</div>
          <h1 className="display text-3xl font-bold text-ink-50 mt-1">シフト管理</h1>
          <p className="text-sm text-ink-400 mt-1">
            Storesのような「30分2分割」操作は不要。1時間/1日をワンクリックで休診に。
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button onClick={() => {
            const d = new Date(weekStart);
            d.setDate(d.getDate() - 7);
            setWeekStart(d);
          }} className="btn-ghost text-xs">←</button>
          <button onClick={() => setWeekStart(startOfWeek(new Date()))} className="btn-ghost text-xs">今週</button>
          <button onClick={() => {
            const d = new Date(weekStart);
            d.setDate(d.getDate() + 7);
            setWeekStart(d);
          }} className="btn-ghost text-xs">→</button>
        </div>
      </div>

      <div className="card overflow-x-auto">
        <div className="grid grid-cols-[80px_repeat(7,1fr)] gap-px bg-white/5 rounded-lg overflow-hidden min-w-[800px]">
          <div className="bg-ink-900 p-2 mono text-[10px] text-ink-500" />
          {days.map((d, i) => {
            const dateStr = ymd(d);
            const open = store.state.shifts.filter((s) => s.date === dateStr && !s.closed).length;
            return (
              <div key={i} className="bg-ink-900 p-2 text-center">
                <div className="mono text-[10px] text-ink-500">{weekdayShort(d.getDay())}</div>
                <div className="display font-bold text-ink-50">{d.getDate()}</div>
                <button
                  onClick={() => toggleDay(dateStr)}
                  className="mt-1 mono text-[10px] text-cyber-400 hover:underline"
                >
                  {open > 0 ? '✕ 1日休診' : '◯ 1日開放'}
                </button>
              </div>
            );
          })}
          {Array.from({ length: hourTo - hourFrom }, (_, hi) => hourFrom + hi).map((h) => (
            <>
              <div key={`hs-${h}`} className="bg-ink-900 p-2 mono text-[10px] text-ink-500 text-right">
                {String(h).padStart(2, '0')}:00
              </div>
              {days.map((d, i) => {
                const dateStr = ymd(d);
                const ds = store.state.shifts.filter(
                  (s) => s.date === dateStr && (s.slotIndex === h * 2 || s.slotIndex === h * 2 + 1),
                );
                const closed = ds.length > 0 && ds.every((s) => s.closed);
                const partial = ds.some((s) => s.closed) && !closed;
                return (
                  <button
                    key={`${h}-${i}`}
                    onClick={() => toggleHour(dateStr, h)}
                    className={`bg-ink-900 p-2 min-h-[44px] text-center transition mono text-[10px] ${
                      closed
                        ? 'text-ink-600 line-through'
                        : partial
                          ? 'text-warn-500'
                          : 'text-ok-500 hover:bg-cyber-500/5'
                    }`}
                  >
                    {closed ? '休' : partial ? '△' : '◯'}
                  </button>
                );
              })}
            </>
          ))}
        </div>
        <div className="flex flex-wrap gap-2 mt-4 text-xs text-ink-400">
          <span className="chip-ok">◯ 受付中</span>
          <span className="chip-warn">△ 一部閉</span>
          <span className="chip">休 = 休診</span>
          <span className="ml-auto mono text-[10px] text-ink-500">
            ※ slot は内部的に30分単位、UI上は1時間単位で操作
          </span>
        </div>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════
// Patients
// ════════════════════════════════════════════
function Patients({
  store,
  onSelect,
}: {
  store: Store;
  onSelect: (id: string) => void;
}) {
  const [q, setQ] = useState('');
  const filtered = store.state.patients.filter(
    (p) =>
      p.name.includes(q) ||
      p.furigana.includes(q) ||
      p.babyName.includes(q) ||
      p.phone.includes(q),
  );
  return (
    <div className="space-y-4">
      <div className="flex items-end justify-between flex-wrap gap-3">
        <div>
          <div className="mono text-[10px] text-cyber-400">PATIENTS</div>
          <h1 className="display text-3xl font-bold text-ink-50 mt-1">利用者一覧</h1>
        </div>
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="🔍 名前・電話で検索"
          className="input w-full md:w-72"
        />
      </div>

      <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-3">
        {filtered.map((p) => (
          <button
            key={p.id}
            onClick={() => onSelect(p.id)}
            className="card text-left hover:border-cyber-700/40 transition"
          >
            <div className="flex items-start gap-3">
              <div className="w-12 h-12 rounded-xl bg-white/[0.05] border border-white/10 flex items-center justify-center text-2xl">
                {p.avatar}
              </div>
              <div className="flex-1 min-w-0">
                <div className="display font-semibold text-ink-50">{p.name}</div>
                <div className="text-xs mono text-ink-500">{p.furigana}</div>
                <div className="text-xs text-ink-400 mt-1">
                  {p.babyName}ちゃん ・ D{daysSince(p.birthday)}
                </div>
              </div>
            </div>
            <div className="flex flex-wrap gap-1 mt-3">
              <span className="chip">{p.delivery}</span>
              {p.feedingStyle && <span className="chip-plasma">{p.feedingStyle}</span>}
              {p.riskFlags.map((r) => (
                <span key={r} className={`chip text-[10px] ${riskLabel(r).cls}`}>
                  {riskLabel(r).label}
                </span>
              ))}
            </div>
            {p.notes && (
              <div className="text-xs text-ink-400 mt-3 line-clamp-2">{p.notes}</div>
            )}
          </button>
        ))}
      </div>
    </div>
  );
}

// ════════════════════════════════════════════
// Chart Screen
// ════════════════════════════════════════════
function ChartScreen({
  store,
  patientId,
  setPatientId,
}: {
  store: Store;
  patientId: string | null;
  setPatientId: (id: string | null) => void;
}) {
  const patient = patientId
    ? store.state.patients.find((p) => p.id === patientId)
    : null;
  if (!patient) {
    return (
      <div className="card text-center py-12">
        <div className="display text-xl text-ink-50">カルテを開くママを選んでください</div>
        <div className="text-sm text-ink-400 mt-2">「利用者一覧」から開けます</div>
      </div>
    );
  }
  const charts = store.state.charts
    .filter((c) => c.patientId === patient.id)
    .sort((a, b) => b.at.localeCompare(a.at));
  const intakes = store.state.intakes
    .filter((i) => i.patientId === patient.id)
    .sort((a, b) => (b.submittedAt ?? '').localeCompare(a.submittedAt ?? ''));
  const photos = store.state.photos
    .filter((p) => p.patientId === patient.id)
    .sort((a, b) => b.at.localeCompare(a.at));
  const latestIntake = intakes[0];
  const insights = latestIntake ? analyzeIntake(latestIntake, patient, charts) : [];

  return (
    <div className="space-y-4">
      <button
        onClick={() => setPatientId(null)}
        className="mono text-[10px] text-cyber-400 hover:underline"
      >
        ← 別の利用者を選ぶ
      </button>

      <div className="card-hero">
        <div className="flex items-center gap-4">
          <div className="w-16 h-16 rounded-xl bg-white/[0.05] border border-white/10 flex items-center justify-center text-3xl">
            {patient.avatar}
          </div>
          <div className="flex-1">
            <h2 className="display text-2xl font-bold text-ink-50">{patient.name}</h2>
            <div className="text-xs mono text-ink-400">
              {patient.furigana} / TEL {patient.phone}
            </div>
            <div className="flex flex-wrap gap-1 mt-2">
              <span className="chip">{patient.delivery}</span>
              <span className="chip">D{daysSince(patient.birthday)} / {patient.babyName}</span>
              {patient.feedingStyle && <span className="chip-plasma">{patient.feedingStyle}</span>}
              {patient.allergy && patient.allergy !== 'なし' && (
                <span className="chip-warn">アレ: {patient.allergy}</span>
              )}
              {patient.riskFlags.map((r) => (
                <span key={r} className={`chip text-[10px] ${riskLabel(r).cls}`}>
                  {riskLabel(r).label}
                </span>
              ))}
            </div>
          </div>
        </div>
        {patient.notes && (
          <div className="mt-4 text-sm text-ink-300 leading-relaxed border-l-2 border-cyber-500/40 pl-3">
            {patient.notes}
          </div>
        )}
      </div>

      {latestIntake && (
        <div className="card">
          <div className="section-title text-ink-50 mb-3">
            <span className="text-plasma-400">●</span> 直近の問診票 (
            {latestIntake.submittedAt && formatDateTime(latestIntake.submittedAt)})
          </div>
          <div className="grid md:grid-cols-3 gap-2 text-sm">
            <Stat label="睡眠" value={`${latestIntake.sleepHours}h`} />
            <Stat label="気分" value={`${latestIntake.moodScore}/10`} />
            <Stat label="痛み" value={`${latestIntake.bodyPain}/10`} />
            <Stat label="出血" value={latestIntake.bleeding} />
            <Stat label="乳房" value={latestIntake.breastCondition} />
            <Stat label="きげん" value={latestIntake.babyMood} />
          </div>
          {latestIntake.concerns && (
            <div className="mt-3 p-3 rounded-lg bg-white/[0.02] border border-white/5 text-sm text-ink-200">
              💭 {latestIntake.concerns}
            </div>
          )}
          {insights.length > 0 && (
            <div className="mt-3 space-y-2">
              {insights.map((ins, i) => (
                <div
                  key={i}
                  className={`text-xs leading-relaxed p-2.5 rounded-lg border ${
                    ins.severity === 'urgent'
                      ? 'bg-ng-500/10 border-ng-500/30 text-ng-500'
                      : ins.severity === 'warn'
                        ? 'bg-warn-500/10 border-warn-500/30 text-warn-500'
                        : 'bg-plasma-500/10 border-plasma-500/30 text-plasma-400'
                  }`}
                >
                  <span className="mono text-[10px] mr-1">[{ins.severity.toUpperCase()}]</span>
                  {ins.message}
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      <SOAPForm
        patient={patient}
        latestIntake={latestIntake}
        onSubmit={(c) => store.addChart(c)}
      />

      <PhotoTimeline photos={photos} />

      {charts.length > 0 && <WeightChart charts={charts} />}

      <div className="card">
        <div className="section-title text-ink-50 mb-3">
          <span className="text-cyber-400">●</span> 過去のカルテ
        </div>
        {charts.length === 0 ? (
          <div className="text-sm text-ink-400 text-center py-3">まだカルテはありません</div>
        ) : (
          <div className="space-y-3">
            {charts.map((c) => (
              <div key={c.id} className="p-3 rounded-lg bg-white/[0.02] border border-white/5">
                <div className="flex items-center justify-between mb-2">
                  <span className="mono text-[10px] text-cyber-400">
                    {formatDateTime(c.at)}
                  </span>
                  <span className="mono text-[10px] text-ink-500">{c.midwife}</span>
                </div>
                <SoapView c={c} />
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="p-2.5 rounded-lg bg-white/[0.02] border border-white/5">
      <div className="label">{label}</div>
      <div className="font-semibold text-ink-50 mt-0.5">{value}</div>
    </div>
  );
}

function SoapView({ c }: { c: ChartEntry }) {
  return (
    <div className="grid gap-2 text-sm">
      {(
        [
          ['S', c.subjective],
          ['O', c.objective],
          ['A', c.assessment],
          ['P', c.plan],
        ] as const
      ).map(([k, v]) => (
        <div key={k} className="flex gap-2">
          <span className="w-6 h-6 rounded bg-cyber-500/15 text-cyber-400 text-[10px] flex items-center justify-center font-bold mono shrink-0 mt-0.5 border border-cyber-500/30">
            {k}
          </span>
          <span className="text-ink-200 leading-relaxed whitespace-pre-line">{v}</span>
        </div>
      ))}
      {c.aiInsights && c.aiInsights.length > 0 && (
        <div className="mt-2 p-2 rounded bg-plasma-500/5 border border-plasma-500/20">
          <div className="mono text-[10px] text-plasma-400 mb-1">✨ AI INSIGHTS</div>
          {c.aiInsights.map((ai, i) => (
            <div key={i} className="text-xs text-ink-200">
              • {ai}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function SOAPForm({
  patient,
  latestIntake,
  onSubmit,
}: {
  patient: Patient;
  latestIntake: any;
  onSubmit: (c: Omit<ChartEntry, 'id'>) => void;
}) {
  const [s, setS] = useState('');
  const [o, setO] = useState('');
  const [a, setA] = useState('');
  const [p, setP] = useState('');

  const fillSuggested = () => {
    if (!latestIntake) return;
    const draft = suggestSOAP(latestIntake, patient);
    setS(draft.S);
    setO(draft.O);
    setA(draft.A);
    setP(draft.P);
  };

  return (
    <div className="card">
      <div className="flex items-center justify-between mb-3">
        <div className="section-title text-ink-50">
          <span className="text-plasma-400">●</span> 新しいSOAP記録
        </div>
        <button
          onClick={fillSuggested}
          disabled={!latestIntake}
          className="chip-plasma hover:bg-plasma-500/20 disabled:opacity-40 disabled:cursor-not-allowed"
        >
          ✨ AI下書き
        </button>
      </div>
      <div className="space-y-2">
        {([
          ['S', s, setS, '主訴・主観的情報'],
          ['O', o, setO, '客観的所見・計測値'],
          ['A', a, setA, 'アセスメント'],
          ['P', p, setP, '計画・指導内容'],
        ] as Array<[string, string, (v: string) => void, string]>).map(([label, val, setter, ph]) => (
          <div key={label} className="flex gap-2">
            <span className="w-7 h-7 mt-1 rounded bg-cyber-500/15 text-cyber-400 text-xs flex items-center justify-center font-bold mono flex-shrink-0 border border-cyber-500/30">
              {label}
            </span>
            <textarea
              rows={2}
              placeholder={ph}
              value={val}
              onChange={(e) => setter(e.target.value)}
              className="input flex-1"
            />
          </div>
        ))}
      </div>
      <button
        onClick={() => {
          if (!s && !o && !a && !p) return;
          onSubmit({
            patientId: patient.id,
            at: new Date().toISOString(),
            midwife: '助産師 田村',
            subjective: s,
            objective: o,
            assessment: a,
            plan: p,
          });
          setS(''); setO(''); setA(''); setP('');
          alert('カルテを保存しました。');
        }}
        className="btn-primary mt-3 w-full"
      >
        ✓ カルテを保存
      </button>
    </div>
  );
}

function PhotoTimeline({ photos }: { photos: any[] }) {
  if (photos.length === 0) return null;
  return (
    <div className="card">
      <div className="section-title text-ink-50 mb-3">
        <span className="text-signal-500">●</span> 写真タイムライン
      </div>
      <div className="grid grid-cols-3 md:grid-cols-5 gap-2">
        {photos.map((p) => (
          <div key={p.id} className="rounded-lg bg-white/[0.02] border border-white/5 p-2">
            <div className="aspect-square rounded bg-white/[0.04] flex items-center justify-center text-3xl">
              {p.emoji}
            </div>
            <div className="text-[10px] mono text-cyber-400 mt-1">{p.category}</div>
            <div className="text-[10px] text-ink-300 line-clamp-2">{p.caption}</div>
            <div className="text-[10px] mono text-ink-500 mt-1">{relative(p.at)}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

function WeightChart({ charts }: { charts: ChartEntry[] }) {
  const data = charts
    .filter((c) => c.babyWeightG)
    .map((c) => ({
      date: formatDate(c.at).slice(5),
      weight: c.babyWeightG,
    }))
    .reverse();
  if (data.length === 0) return null;
  return (
    <div className="card">
      <div className="section-title text-ink-50 mb-3">
        <span className="text-cyber-400">●</span> 赤ちゃんの体重推移
      </div>
      <ResponsiveContainer width="100%" height={200}>
        <LineChart data={data}>
          <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
          <XAxis dataKey="date" stroke="#6f7891" />
          <YAxis stroke="#6f7891" />
          <Tooltip contentStyle={{ background: '#0c1124', border: '1px solid #1f2937' }} />
          <Line type="monotone" dataKey="weight" stroke="#22d3ee" strokeWidth={2} dot={{ fill: '#22d3ee' }} />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}

// ════════════════════════════════════════════
// Analytics
// ════════════════════════════════════════════
function Analytics({ store }: { store: Store }) {
  const typeData = useMemo(() => {
    const m = new Map<string, number>();
    store.state.appointments.forEach((a) => {
      m.set(a.type, (m.get(a.type) ?? 0) + 1);
    });
    return Array.from(m.entries()).map(([name, value]) => ({ name, value }));
  }, [store.state.appointments]);

  const weekData = useMemo(() => {
    const start = startOfWeek(new Date());
    return Array.from({ length: 7 }, (_, i) => {
      const d = new Date(start);
      d.setDate(d.getDate() + i);
      const count = store.state.appointments.filter((a) =>
        isSameDay(a.start, d),
      ).length;
      return { day: weekdayShort(d.getDay()), count };
    });
  }, [store.state.appointments]);

  const colors = ['#22d3ee', '#a78bfa', '#e879f9', '#10b981', '#f59e0b', '#ef4444'];

  return (
    <div className="space-y-4">
      <div>
        <div className="mono text-[10px] text-cyber-400">ANALYTICS</div>
        <h1 className="display text-3xl font-bold text-ink-50 mt-1">分析</h1>
      </div>
      <div className="grid md:grid-cols-2 gap-4">
        <div className="card">
          <div className="section-title text-ink-50 mb-3">
            <span className="text-cyber-400">●</span> 今週の予約数
          </div>
          <ResponsiveContainer width="100%" height={240}>
            <BarChart data={weekData}>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
              <XAxis dataKey="day" stroke="#6f7891" />
              <YAxis stroke="#6f7891" />
              <Tooltip contentStyle={{ background: '#0c1124', border: '1px solid #1f2937' }} />
              <Bar dataKey="count" fill="#22d3ee" radius={[6, 6, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
        <div className="card">
          <div className="section-title text-ink-50 mb-3">
            <span className="text-signal-500">●</span> サービス別比率
          </div>
          <ResponsiveContainer width="100%" height={240}>
            <PieChart>
              <Pie
                data={typeData}
                dataKey="value"
                nameKey="name"
                outerRadius={80}
                innerRadius={40}
                label
              >
                {typeData.map((_, i) => (
                  <Cell key={i} fill={colors[i % colors.length]} />
                ))}
              </Pie>
              <Legend wrapperStyle={{ color: '#9ea6b8', fontSize: 12 }} />
              <Tooltip contentStyle={{ background: '#0c1124', border: '1px solid #1f2937' }} />
            </PieChart>
          </ResponsiveContainer>
        </div>
      </div>
      <div className="card">
        <div className="section-title text-ink-50 mb-3">
          <span className="text-plasma-400">●</span> 経営指標（デモ）
        </div>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <Kpi label="月間予約" value="48" note="先月 +6" />
          <Kpi label="リピート率" value="74%" note="目標 70%" />
          <Kpi label="紹介率" value="18%" note="口コミ経由" />
          <Kpi label="平均単価" value="¥6,800" note="" />
        </div>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════
// Inbox
// ════════════════════════════════════════════
function Inbox({ store }: { store: Store }) {
  const [selectedRoom, setSelectedRoom] = useState<string | null>(null);
  const rooms = useMemo(() => {
    const map = new Map<string, any>();
    store.state.chats.forEach((c) => {
      const cur = map.get(c.roomId);
      if (!cur || c.at > cur.at) {
        map.set(c.roomId, c);
      }
    });
    return Array.from(map.values()).sort((a, b) => b.at.localeCompare(a.at));
  }, [store.state.chats]);

  const messages = selectedRoom
    ? store.state.chats
        .filter((c) => c.roomId === selectedRoom)
        .sort((a, b) => a.at.localeCompare(b.at))
    : [];
  const selectedPatient = selectedRoom
    ? store.state.patients.find((p) => p.id === selectedRoom)
    : null;
  const [draft, setDraft] = useState('');

  const send = () => {
    if (!draft.trim() || !selectedRoom) return;
    store.addChat({
      roomId: selectedRoom,
      from: 'midwife',
      text: draft,
      at: new Date().toISOString(),
    });
    setDraft('');
  };

  return (
    <div className="space-y-4">
      <div>
        <div className="mono text-[10px] text-cyber-400">INBOX</div>
        <h1 className="display text-3xl font-bold text-ink-50 mt-1">受信箱</h1>
      </div>
      <div className="grid md:grid-cols-[280px_1fr] gap-3">
        <div className="card max-h-[600px] overflow-y-auto">
          {rooms.map((r) => {
            const p = store.state.patients.find((pa) => pa.id === r.roomId);
            const active = selectedRoom === r.roomId;
            const triage = r.from === 'mama' ? triageMessage(r.text) : null;
            return (
              <button
                key={r.id}
                onClick={() => setSelectedRoom(r.roomId)}
                className={`w-full text-left p-3 rounded-lg mb-1 border transition ${
                  active
                    ? 'bg-cyber-500/15 border-cyber-500/40'
                    : 'bg-white/[0.02] border-white/5 hover:border-cyber-700/30'
                }`}
              >
                <div className="flex items-center gap-2 mb-1">
                  <span className="text-lg">{p?.avatar}</span>
                  <span className="text-sm font-medium text-ink-50 flex-1">{p?.name}</span>
                  {triage?.urgent && <span className="chip-ng text-[10px]">🆘</span>}
                </div>
                <div className="text-xs text-ink-400 line-clamp-1">{r.text}</div>
                <div className="mono text-[10px] text-ink-500 mt-1">{relative(r.at)}</div>
              </button>
            );
          })}
        </div>
        <div className="card flex flex-col min-h-[400px] md:min-h-[600px]">
          {!selectedPatient ? (
            <div className="m-auto text-ink-400 text-sm">ルームを選択してください</div>
          ) : (
            <>
              <div className="flex items-center gap-2 pb-3 border-b border-white/5 mb-3">
                <span className="text-2xl">{selectedPatient.avatar}</span>
                <div>
                  <div className="display font-semibold text-ink-50">{selectedPatient.name}</div>
                  <div className="mono text-[10px] text-ink-500">{selectedPatient.phone}</div>
                </div>
              </div>
              <div className="flex-1 overflow-y-auto space-y-3 pr-1">
                {messages.map((m) => {
                  const isMidwife = m.from === 'midwife';
                  const triage = m.from === 'mama' ? triageMessage(m.text) : null;
                  return (
                    <div key={m.id} className={`flex items-end gap-2 ${isMidwife ? 'flex-row-reverse' : ''}`}>
                      <span className="text-xl">{isMidwife ? '🌸' : selectedPatient.avatar}</span>
                      <div className={`max-w-[75%] ${isMidwife ? 'bubble bubble-me' : 'bubble'} text-sm leading-relaxed`}>
                        {triage?.urgent && (
                          <div className="text-[10px] chip-ng inline-flex mb-1">🆘 緊急ワード検知</div>
                        )}
                        {m.text}
                        <div className="mono text-[10px] text-ink-500 mt-1">{formatTime(m.at)}</div>
                      </div>
                    </div>
                  );
                })}
              </div>
              <form
                onSubmit={(e) => {
                  e.preventDefault();
                  send();
                }}
                className="flex gap-2 pt-3 border-t border-white/5 mt-3"
              >
                <input
                  value={draft}
                  onChange={(e) => setDraft(e.target.value)}
                  placeholder="助産師として返信…"
                  className="input flex-1"
                />
                <button type="submit" className="btn-primary px-5 text-sm">
                  送信
                </button>
              </form>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════
// Settings
// ════════════════════════════════════════════
function Settings({ store }: { store: Store }) {
  const cfg = store.state.config;
  const [hp, setHp] = useState(cfg.homepageUrl);
  const [insta, setInsta] = useState(cfg.instagramUrl);
  const [stores, setStores] = useState(cfg.storesFallbackUrl);
  const [lineName, setLineName] = useState(cfg.lineDisplayName);

  const save = () => {
    store.updateConfig({
      homepageUrl: hp,
      instagramUrl: insta,
      storesFallbackUrl: stores,
      lineDisplayName: lineName,
    });
    alert('保存しました。');
  };

  const testLine = () => {
    store.addLineNotification({
      at: new Date().toISOString(),
      channel: 'official-line',
      to: '公式LINE',
      message:
        '🌸 これはテスト通知です\nManary+ から送信されました',
      triggeredBy: '手動テスト',
    });
    alert('LINE通知ログに記録しました（設定画面下部で確認できます）。');
  };

  return (
    <div className="space-y-4">
      <div>
        <div className="mono text-[10px] text-cyber-400">SETTINGS</div>
        <h1 className="display text-3xl font-bold text-ink-50 mt-1">設定</h1>
      </div>

      {/* 公式LINE連携 */}
      <div className="card">
        <div className="flex items-center justify-between mb-4">
          <div>
            <div className="section-title text-ink-50">
              <span className="text-ok-500">●</span> 公式LINE連携
            </div>
            <p className="text-xs text-ink-400 mt-1">
              予約が入った時に「予約入ってよかちゃん！」を自動送信
            </p>
          </div>
          <span className={cfg.lineLinked ? 'chip-ok' : 'chip-warn'}>
            {cfg.lineLinked ? 'CONNECTED' : 'NOT LINKED'}
          </span>
        </div>
        <div className="space-y-3">
          <Field label="LINE表示名" value={lineName} onChange={setLineName} />
          <div className="flex items-center justify-between gap-3">
            <div className="text-sm text-ink-200">連携状態</div>
            <button
              onClick={() => store.updateConfig({ lineLinked: !cfg.lineLinked })}
              className={cfg.lineLinked ? 'btn-ghost' : 'btn-primary'}
            >
              {cfg.lineLinked ? '連携解除' : '連携する'}
            </button>
          </div>
          <button onClick={testLine} className="btn-outline w-full">
            ▸ テスト通知を送る
          </button>
        </div>
      </div>

      {/* 動線設定 */}
      <div className="card">
        <div className="section-title text-ink-50 mb-3">
          <span className="text-cyber-400">●</span> 外部リンク (ホームページ動線)
        </div>
        <div className="space-y-3">
          <Field label="ホームページ URL" value={hp} onChange={setHp} />
          <Field label="Instagram URL" value={insta} onChange={setInsta} />
          <Field label="Stores 予約 URL (フォールバック用)" value={stores} onChange={setStores} />
        </div>
      </div>

      {/* 6月末暫定対応 */}
      <div className="card">
        <div className="section-title text-ink-50 mb-3">
          <span className="text-warn-500">●</span> 公開ステータス
        </div>
        <p className="text-xs text-ink-400 mb-3">
          アプリ未完成時は「準備中ページ」に切り替えて、Stores予約サイトへ自動誘導します。
        </p>
        <div className="flex items-center justify-between gap-3">
          <div className="text-sm text-ink-200">
            現在: <span className="font-bold">{cfg.comingSoon ? '🚧 準備中ページ表示中' : '✅ 通常公開中'}</span>
          </div>
          <button
            onClick={() => store.updateConfig({ comingSoon: !cfg.comingSoon })}
            className={cfg.comingSoon ? 'btn-primary' : 'btn-ghost'}
          >
            {cfg.comingSoon ? '通常公開に戻す' : '🚧 準備中ページに切替'}
          </button>
        </div>
      </div>

      <button onClick={save} className="btn-primary w-full">
        ✓ 設定を保存
      </button>

      {/* LINE通知ログ */}
      <div className="card">
        <div className="section-title text-ink-50 mb-3">
          <span className="text-cyber-400">●</span> LINE通知ログ
        </div>
        <div className="space-y-2 max-h-80 overflow-y-auto">
          {store.state.lineNotifications.map((n) => (
            <div
              key={n.id}
              className="text-xs p-2.5 rounded-lg bg-white/[0.02] border border-white/5"
            >
              <div className="flex items-center justify-between mb-1">
                <span className="mono text-[10px] text-cyber-400">{n.to}</span>
                <span className="mono text-[10px] text-ink-500">{relative(n.at)}</span>
              </div>
              <div className="text-ink-200 whitespace-pre-line leading-relaxed">{n.message}</div>
              <div className="mono text-[10px] text-ink-500 mt-1">trigger: {n.triggeredBy}</div>
            </div>
          ))}
        </div>
      </div>

      <button
        onClick={() => {
          if (confirm('デモデータをリセットしますか？')) store.reset();
        }}
        className="btn-ghost w-full text-xs"
      >
        ↺ デモデータをリセット
      </button>
    </div>
  );
}

function Field({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <div>
      <div className="label mb-1">{label}</div>
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="input"
      />
    </div>
  );
}
