import { useMemo, useState } from 'react';
import type { MidwifeTab, Patient, ChartEntry } from '../types';
import { Manakun } from '../components/Manakun';
import {
  formatDate,
  formatDateTime,
  formatTime,
  relative,
  startOfWeek,
  weekdayShort,
  isSameDay,
  appointmentColor,
  riskLabel,
  daysSince,
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

export function MidwifeApp({ store, onExit }: { store: Store; onExit: () => void }) {
  const [tab, setTab] = useState<MidwifeTab>('dashboard');
  const [selectedPatientId, setSelectedPatientId] = useState<string | null>(null);

  return (
    <div className="min-h-screen flex flex-col md:flex-row">
      <SideNav
        tab={tab}
        setTab={setTab}
        dark={store.state.dark}
        setDark={store.setDark}
        onExit={onExit}
        inboxBadge={store.state.chats.filter((c) => c.from === 'mama' && c.urgent).length}
      />
      <main className="flex-1 px-4 md:px-8 py-6 md:py-10 max-w-7xl w-full mx-auto pb-32 md:pb-10">
        {tab === 'dashboard' && (
          <Dashboard store={store} setTab={setTab} openPatient={(id) => {
            setSelectedPatientId(id);
            setTab('chart');
          }} />
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
      </main>
      <MobileTabBar tab={tab} setTab={setTab} />
    </div>
  );
}

function SideNav({
  tab,
  setTab,
  dark,
  setDark,
  onExit,
  inboxBadge,
}: {
  tab: MidwifeTab;
  setTab: (t: MidwifeTab) => void;
  dark: boolean;
  setDark: (v: boolean) => void;
  onExit: () => void;
  inboxBadge: number;
}) {
  const items: { id: MidwifeTab; icon: string; label: string }[] = [
    { id: 'dashboard', icon: '🏠', label: 'ホーム' },
    { id: 'calendar', icon: '📅', label: '予約' },
    { id: 'patients', icon: '👥', label: '利用者' },
    { id: 'chart', icon: '📋', label: 'カルテ' },
    { id: 'inbox', icon: '💬', label: 'チャット' },
    { id: 'analytics', icon: '📊', label: '分析' },
  ];
  return (
    <aside className="hidden md:flex md:w-64 md:flex-col md:fixed md:inset-y-0 bg-white/80 dark:bg-night-900 backdrop-blur border-r border-sakura-100 dark:border-cocoa-700/40 px-5 py-6">
      <div className="flex items-center gap-2 mb-8">
        <Manakun size={36} />
        <div>
          <div className="text-lg font-bold text-sakura-600">
            Manary<span className="text-cocoa-500">+</span>
          </div>
          <div className="text-[10px] text-cocoa-400">桜助産院 デモ環境</div>
        </div>
      </div>
      <nav className="flex-1 space-y-1">
        {items.map((it) => (
          <button
            key={it.id}
            onClick={() => setTab(it.id)}
            className={`w-full flex items-center gap-3 px-4 py-3 rounded-2xl text-sm font-bold transition relative ${
              tab === it.id
                ? 'bg-pink-grad text-white shadow-soft'
                : 'text-cocoa-600 hover:bg-sakura-50 dark:text-night-50 dark:hover:bg-night-800'
            }`}
          >
            <span className="text-lg">{it.icon}</span>
            <span>{it.label}</span>
            {it.id === 'inbox' && inboxBadge > 0 && (
              <span className="ml-auto inline-flex items-center justify-center w-5 h-5 rounded-full bg-sakura-500 text-white text-[10px]">
                {inboxBadge}
              </span>
            )}
          </button>
        ))}
      </nav>
      <div className="space-y-2 mt-4">
        <button
          onClick={() => setDark(!dark)}
          className="w-full flex items-center gap-3 px-4 py-2 rounded-2xl text-xs font-bold text-cocoa-500 dark:text-night-50 hover:bg-sakura-50 dark:hover:bg-night-800"
        >
          {dark ? '☀️ ライト' : '🌙 ダーク'}モード
        </button>
        <button
          onClick={onExit}
          className="w-full flex items-center gap-3 px-4 py-2 rounded-2xl text-xs font-bold text-cocoa-400 hover:bg-sakura-50 dark:hover:bg-night-800"
        >
          ← トップに戻る
        </button>
      </div>
    </aside>
  );
}

function MobileTabBar({
  tab,
  setTab,
}: {
  tab: MidwifeTab;
  setTab: (t: MidwifeTab) => void;
}) {
  const items: { id: MidwifeTab; icon: string; label: string }[] = [
    { id: 'dashboard', icon: '🏠', label: 'ホーム' },
    { id: 'calendar', icon: '📅', label: '予約' },
    { id: 'patients', icon: '👥', label: '利用者' },
    { id: 'inbox', icon: '💬', label: 'チャット' },
    { id: 'analytics', icon: '📊', label: '分析' },
  ];
  return (
    <nav className="md:hidden fixed bottom-0 left-0 right-0 z-30 px-3 pb-[env(safe-area-inset-bottom)] pt-2">
      <div className="bg-white/95 dark:bg-night-900/95 backdrop-blur shadow-soft border border-sakura-100 dark:border-cocoa-700/40 rounded-3xl flex justify-between p-1">
        {items.map((it) => (
          <button
            key={it.id}
            onClick={() => setTab(it.id)}
            className={`flex-1 flex flex-col items-center gap-0.5 py-2 rounded-2xl ${
              tab === it.id
                ? 'bg-pink-grad text-white'
                : 'text-cocoa-500 dark:text-night-50'
            }`}
          >
            <span className="text-base leading-none">{it.icon}</span>
            <span className="text-[10px] font-bold">{it.label}</span>
          </button>
        ))}
      </div>
    </nav>
  );
}

function PageHeader({
  title,
  subtitle,
  right,
}: {
  title: string;
  subtitle?: string;
  right?: React.ReactNode;
}) {
  return (
    <div className="md:ml-64 md:-ml-0">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl md:text-3xl font-bold text-cocoa-700 dark:text-night-50">
            {title}
          </h1>
          {subtitle && (
            <p className="text-sm text-cocoa-400 dark:text-night-50/60 mt-1">{subtitle}</p>
          )}
        </div>
        {right}
      </div>
    </div>
  );
}

// =============== Dashboard ===============
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
  const todaysAppointments = store.state.appointments.filter(
    (a) => isSameDay(a.start, today) && a.status !== 'キャンセル',
  );
  const urgentChats = store.state.chats.filter(
    (c) => c.from === 'mama' && c.urgent,
  );
  const pendingIntakes = store.state.intakes.length;
  const patientCount = store.state.patients.length;

  return (
    <div className="md:ml-64">
      <PageHeader
        title="おかえりなさい、田村さん"
        subtitle={`${formatDate(today.toISOString())} - 今日も応援しています🌸`}
        right={
          <div className="hidden md:block">
            <Manakun size={56} mood="wave" />
          </div>
        }
      />

      {/* KPI cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        <Kpi icon="📅" label="本日の予約" value={`${todaysAppointments.length}件`} />
        <Kpi icon="📝" label="提出済み問診票" value={`${pendingIntakes}件`} />
        <Kpi
          icon="🆘"
          label="緊急チャット"
          value={`${urgentChats.length}件`}
          tone={urgentChats.length > 0 ? 'urgent' : 'default'}
          onClick={() => setTab('inbox')}
        />
        <Kpi icon="👥" label="利用者総数" value={`${patientCount}名`} />
      </div>

      <div className="grid md:grid-cols-3 gap-5">
        {/* Today's schedule */}
        <div className="card md:col-span-2">
          <div className="flex items-center justify-between">
            <div className="section-title">📅 今日のスケジュール</div>
            <button
              onClick={() => setTab('calendar')}
              className="text-xs font-bold text-sakura-600 hover:underline"
            >
              すべて見る →
            </button>
          </div>
          {todaysAppointments.length === 0 ? (
            <div className="text-sm text-cocoa-400 mt-4 text-center py-6">
              本日の予約はありません。ゆっくりお過ごしください。
            </div>
          ) : (
            <ul className="mt-4 space-y-2">
              {todaysAppointments
                .sort((a, b) => a.start.localeCompare(b.start))
                .map((a) => {
                  const p = store.state.patients.find((x) => x.id === a.patientId)!;
                  const intake = store.state.intakes.find(
                    (i) => i.appointmentId === a.id,
                  );
                  return (
                    <li
                      key={a.id}
                      className="p-3 rounded-2xl bg-sakura-50/60 dark:bg-night-800 border border-sakura-100 dark:border-cocoa-700/40 cursor-pointer hover:shadow-soft transition"
                      onClick={() => openPatient(p.id)}
                    >
                      <div className="flex items-center gap-3">
                        <div className="text-center min-w-[60px]">
                          <div className="text-lg font-bold text-sakura-600">
                            {formatTime(a.start)}
                          </div>
                          <div className="text-[10px] text-cocoa-400">
                            {a.durationMin}分
                          </div>
                        </div>
                        <div className="text-2xl">{p.avatar}</div>
                        <div className="flex-1 min-w-0">
                          <div className="font-bold text-cocoa-700 dark:text-night-50">
                            {p.name} <span className="text-xs text-cocoa-400">＆ {p.babyName}ちゃん</span>
                          </div>
                          <div className="flex items-center gap-2 text-xs text-cocoa-500 dark:text-night-50/60 mt-0.5">
                            <span className={`chip ${appointmentColor(a.type)}`}>
                              {a.type}
                            </span>
                            {intake && (
                              <span className="chip bg-cocoa-100 text-cocoa-600">
                                📝 問診済
                              </span>
                            )}
                            {p.riskFlags.map((r) => (
                              <span key={r} className={`chip ${riskLabel(r).cls}`}>
                                {riskLabel(r).label}
                              </span>
                            ))}
                          </div>
                        </div>
                        <span className="text-cocoa-300">›</span>
                      </div>
                    </li>
                  );
                })}
            </ul>
          )}
        </div>

        {/* AI suggestions */}
        <div className="card bg-gradient-to-br from-sakura-100 via-cream-100 to-peach-100 border-0">
          <div className="flex items-center gap-2">
            <Manakun size={36} mood="wink" />
            <div>
              <div className="text-[10px] label">AI Insights</div>
              <div className="font-bold text-cocoa-700">まなくんからの提案</div>
            </div>
          </div>
          <div className="mt-3 space-y-2 text-sm">
            <SuggestCard
              level="urgent"
              text="佐藤みなみさん（9:30）はEPDS再評価を推奨。問診票で気分4/10、夜間睡眠4h。"
            />
            <SuggestCard
              level="warn"
              text="田中ゆかりさん（11:00）は乳腺うっ滞の既往あり。授乳姿勢の動画リンクが事前共有済み。"
            />
            <SuggestCard
              level="info"
              text="本日の予約利用者の平均年齢: 生後38日。離乳食準備のコンテンツ送信に最適期。"
            />
          </div>
        </div>

        {/* Urgent chats preview */}
        {urgentChats.length > 0 && (
          <div className="card md:col-span-3 bg-sakura-50 dark:bg-sakura-900/20 border-sakura-300 border-2">
            <div className="flex items-center justify-between">
              <div className="section-title text-sakura-700">
                🆘 緊急チャット ({urgentChats.length}件)
              </div>
              <button
                onClick={() => setTab('inbox')}
                className="btn-primary text-xs"
              >
                返信する →
              </button>
            </div>
            <ul className="mt-3 space-y-2">
              {urgentChats.slice(0, 3).map((c) => {
                const p = store.state.patients.find((x) => x.id === c.roomId);
                return (
                  <li key={c.id} className="flex gap-3 items-start text-sm">
                    <span className="text-xl">{p?.avatar}</span>
                    <div className="flex-1">
                      <div className="font-bold text-cocoa-700 dark:text-night-50">{p?.name}</div>
                      <div className="text-cocoa-600 dark:text-night-50/80">{c.text}</div>
                    </div>
                    <div className="text-[10px] text-cocoa-400">{relative(c.at)}</div>
                  </li>
                );
              })}
            </ul>
          </div>
        )}
      </div>
    </div>
  );
}

function Kpi({
  icon,
  label,
  value,
  tone = 'default',
  onClick,
}: {
  icon: string;
  label: string;
  value: string;
  tone?: 'default' | 'urgent';
  onClick?: () => void;
}) {
  return (
    <button
      onClick={onClick}
      className={`card text-left hover:shadow-soft transition ${
        tone === 'urgent' ? 'bg-sakura-50 border-sakura-300' : ''
      }`}
    >
      <div className="text-2xl">{icon}</div>
      <div className="label mt-2">{label}</div>
      <div className="text-2xl font-bold text-cocoa-700 dark:text-night-50">{value}</div>
    </button>
  );
}

function SuggestCard({
  level,
  text,
}: {
  level: 'info' | 'warn' | 'urgent';
  text: string;
}) {
  const map = {
    urgent: 'bg-white border-sakura-300 text-cocoa-700',
    warn: 'bg-white border-peach-300 text-cocoa-700',
    info: 'bg-white/70 border-cream-200 text-cocoa-700',
  };
  const dot = {
    urgent: 'bg-sakura-500',
    warn: 'bg-peach-500',
    info: 'bg-cocoa-300',
  };
  return (
    <div className={`bubble p-3 ${map[level]}`}>
      <div className="flex gap-2 items-start">
        <span className={`dot ${dot[level]} mt-1.5 flex-shrink-0`} />
        <span className="leading-relaxed">{text}</span>
      </div>
    </div>
  );
}

// =============== Calendar ===============
function Calendar({ store }: { store: Store }) {
  const [weekStart, setWeekStart] = useState(() => startOfWeek(new Date()));
  const days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(weekStart);
    d.setDate(weekStart.getDate() + i);
    return d;
  });
  const hours = Array.from({ length: 10 }, (_, i) => i + 8); // 8-17

  return (
    <div className="md:ml-64">
      <PageHeader
        title="予約カレンダー"
        subtitle="ドラッグ&ドロップ感覚で、一週間の予約を俯瞰"
        right={
          <div className="flex items-center gap-2">
            <button
              onClick={() => {
                const d = new Date(weekStart);
                d.setDate(d.getDate() - 7);
                setWeekStart(d);
              }}
              className="btn-ghost text-xs"
            >
              ‹ 前週
            </button>
            <button
              onClick={() => setWeekStart(startOfWeek(new Date()))}
              className="btn-ghost text-xs"
            >
              今週
            </button>
            <button
              onClick={() => {
                const d = new Date(weekStart);
                d.setDate(d.getDate() + 7);
                setWeekStart(d);
              }}
              className="btn-ghost text-xs"
            >
              次週 ›
            </button>
          </div>
        }
      />

      <div className="card overflow-x-auto">
        <div className="min-w-[700px]">
          {/* day headers */}
          <div className="grid grid-cols-8 gap-1 mb-2">
            <div></div>
            {days.map((d, i) => {
              const today = isSameDay(d, new Date());
              return (
                <div
                  key={i}
                  className={`text-center py-2 rounded-2xl ${
                    today ? 'bg-pink-grad text-white' : 'bg-sakura-50 dark:bg-night-800'
                  }`}
                >
                  <div className="text-[10px] font-bold">{weekdayShort(d.getDay())}</div>
                  <div className="text-lg font-bold">{d.getDate()}</div>
                </div>
              );
            })}
          </div>
          {/* grid */}
          <div className="grid grid-cols-8 gap-1">
            {hours.map((h) => (
              <FragmentHourRow
                key={h}
                hour={h}
                days={days}
                appointments={store.state.appointments}
                patients={store.state.patients}
              />
            ))}
          </div>
          <div className="mt-4 flex flex-wrap gap-2 text-xs">
            {['産後ケア', '乳房ケア', '母乳相談', '沐浴指導', '初回相談'].map((t) => (
              <span key={t} className={`chip ${appointmentColor(t)}`}>
                {t}
              </span>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function FragmentHourRow({
  hour,
  days,
  appointments,
  patients,
}: {
  hour: number;
  days: Date[];
  appointments: any[];
  patients: Patient[];
}) {
  return (
    <>
      <div className="text-right pr-2 text-xs text-cocoa-400 py-2">
        {hour}:00
      </div>
      {days.map((d, i) => {
        const slot = appointments.filter((a) => {
          const ad = new Date(a.start);
          return isSameDay(ad, d) && ad.getHours() === hour;
        });
        return (
          <div
            key={i}
            className="min-h-[48px] p-1 rounded-xl bg-sakura-50/30 dark:bg-night-800/30 border border-dashed border-sakura-100 dark:border-cocoa-700/30"
          >
            {slot.map((a) => {
              const p = patients.find((x) => x.id === a.patientId)!;
              return (
                <div
                  key={a.id}
                  className={`text-[10px] px-1.5 py-1 rounded-lg mb-0.5 truncate ${appointmentColor(
                    a.type,
                  )}`}
                  title={`${formatTime(a.start)} ${p.name} (${a.type})`}
                >
                  {formatTime(a.start)} {p.name}
                </div>
              );
            })}
          </div>
        );
      })}
    </>
  );
}

// =============== Patients ===============
function Patients({ store, onSelect }: { store: Store; onSelect: (id: string) => void }) {
  const [q, setQ] = useState('');
  const filtered = store.state.patients.filter(
    (p) =>
      p.name.includes(q) ||
      p.furigana.includes(q) ||
      p.babyName.includes(q),
  );
  return (
    <div className="md:ml-64">
      <PageHeader title="利用者一覧" subtitle={`${store.state.patients.length}名のママ・赤ちゃん`} />
      <div className="card mb-4">
        <input
          type="search"
          placeholder="🔎 名前・ふりがな・赤ちゃんの名前で検索"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          className="w-full px-4 py-3 rounded-2xl bg-sakura-50 dark:bg-night-800 border border-sakura-100 dark:border-cocoa-700/40 text-sm"
        />
      </div>
      <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-4">
        {filtered.map((p) => (
          <button
            key={p.id}
            onClick={() => onSelect(p.id)}
            className="card text-left hover:shadow-soft transition"
          >
            <div className="flex items-start gap-3">
              <div className="text-4xl">{p.avatar}</div>
              <div className="flex-1 min-w-0">
                <div className="font-bold text-cocoa-700 dark:text-night-50">{p.name}</div>
                <div className="text-[10px] text-cocoa-400">{p.furigana}</div>
                <div className="text-xs text-cocoa-500 dark:text-night-50/60 mt-1">
                  👶 {p.babyName} ／ 生後{daysSince(p.birthday)}日
                </div>
                <div className="text-xs text-cocoa-400 mt-0.5">{p.delivery}</div>
              </div>
            </div>
            {p.riskFlags.length > 0 && (
              <div className="flex flex-wrap gap-1 mt-3">
                {p.riskFlags.map((r) => (
                  <span key={r} className={`chip ${riskLabel(r).cls}`}>
                    {riskLabel(r).label}
                  </span>
                ))}
              </div>
            )}
            {p.notes && (
              <div className="text-xs text-cocoa-500 dark:text-night-50/60 mt-3 line-clamp-2">
                {p.notes}
              </div>
            )}
            {p.lastVisit && (
              <div className="text-[10px] text-cocoa-400 mt-2">
                最終来院: {relative(p.lastVisit)}
              </div>
            )}
          </button>
        ))}
      </div>
    </div>
  );
}

// =============== Chart (Electronic Medical Record) ===============
function ChartScreen({
  store,
  patientId,
  setPatientId,
}: {
  store: Store;
  patientId: string | null;
  setPatientId: (id: string | null) => void;
}) {
  const patient = store.state.patients.find((p) => p.id === patientId);

  if (!patient) {
    return (
      <div className="md:ml-64">
        <PageHeader title="電子カルテ" subtitle="患者を選択してください" />
        <div className="grid md:grid-cols-3 gap-3">
          {store.state.patients.map((p) => (
            <button
              key={p.id}
              onClick={() => setPatientId(p.id)}
              className="card text-left hover:shadow-soft"
            >
              <div className="flex items-center gap-2">
                <span className="text-2xl">{p.avatar}</span>
                <div>
                  <div className="font-bold">{p.name}</div>
                  <div className="text-xs text-cocoa-400">{p.babyName}ちゃん</div>
                </div>
              </div>
            </button>
          ))}
        </div>
      </div>
    );
  }

  const intake = store.state.intakes.find((i) => i.patientId === patient.id);
  const charts = store.state.charts.filter((c) => c.patientId === patient.id);
  const photos = store.state.photos.filter((ph) => ph.patientId === patient.id);
  const insights = intake ? analyzeIntake(intake, patient, charts) : [];

  return (
    <div className="md:ml-64">
      <button
        onClick={() => setPatientId(null)}
        className="text-xs text-cocoa-400 hover:text-sakura-500 mb-2"
      >
        ← 利用者一覧に戻る
      </button>
      <div className="flex items-center gap-4 mb-6">
        <div className="text-5xl">{patient.avatar}</div>
        <div className="flex-1">
          <h1 className="text-2xl font-bold text-cocoa-700 dark:text-night-50">
            {patient.name}
          </h1>
          <div className="text-xs text-cocoa-400">{patient.furigana}</div>
          <div className="text-sm text-cocoa-500 dark:text-night-50/60 mt-1">
            👶 {patient.babyName}ちゃん ／ 生後{daysSince(patient.birthday)}日 ／ {patient.delivery}
          </div>
        </div>
      </div>

      <div className="grid lg:grid-cols-3 gap-5">
        {/* Left: Intake & AI */}
        <div className="space-y-5">
          {intake ? (
            <div className="card">
              <div className="section-title">📝 事前問診票</div>
              <div className="text-[10px] text-cocoa-400 mt-1">
                提出: {intake.submittedAt && relative(intake.submittedAt)}
              </div>
              <div className="space-y-2 mt-3 text-sm">
                <Row k="ママの睡眠" v={`${intake.sleepHours}h`} />
                <Row k="気分" v={`${intake.moodScore}/10`} />
                <Row k="からだの痛み" v={`${intake.bodyPain}/10`} />
                <Row k="出血" v={intake.bleeding} />
                <Row k="乳房" v={intake.breastCondition} />
                <Row k="赤ちゃん体重" v={`${intake.babyWeightG}g`} />
                <Row k="授乳/日" v={`${intake.feedingPerDay}回`} />
                <Row k="おむつ/日" v={`${intake.diaperPerDay}回`} />
                <Row k="きげん" v={intake.babyMood} />
              </div>
              <div className="mt-3 p-3 rounded-2xl bg-sakura-50 dark:bg-night-800 text-sm">
                <div className="text-[10px] label">心配ごと</div>
                <p className="mt-1 text-cocoa-600 dark:text-night-50/80 leading-relaxed">
                  「{intake.concerns}」
                </p>
                <div className="flex flex-wrap gap-1 mt-2">
                  {intake.consultTopics.map((t) => (
                    <span key={t} className="chip bg-white text-sakura-600 border border-sakura-200">
                      {t}
                    </span>
                  ))}
                </div>
              </div>
            </div>
          ) : (
            <div className="card text-center text-sm text-cocoa-400">
              事前問診票はまだ提出されていません
            </div>
          )}

          {insights.length > 0 && (
            <div className="card bg-gradient-to-br from-sakura-100 via-cream-100 to-peach-100 border-0">
              <div className="flex items-center gap-2">
                <Manakun size={28} mood="wink" />
                <div className="section-title">⚡ AI Insights</div>
              </div>
              <div className="space-y-2 mt-3">
                {insights.map((ins, i) => (
                  <div key={i} className="bubble p-3 text-sm">
                    <div className="flex items-center gap-2 font-bold">
                      <span>{ins.icon}</span>
                      <span
                        className={
                          ins.level === 'urgent'
                            ? 'text-sakura-700'
                            : ins.level === 'warn'
                              ? 'text-peach-500'
                              : 'text-cocoa-600'
                        }
                      >
                        {ins.title}
                      </span>
                    </div>
                    <div className="text-xs text-cocoa-500 mt-1 leading-relaxed">
                      {ins.detail}
                    </div>
                    <div className="text-[10px] text-cocoa-400 mt-2">
                      📊 根拠: {ins.source}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Middle: SOAP entry */}
        <div className="space-y-5">
          <SoapForm patient={patient} intake={intake} onSubmit={store.addChart} />
          {charts.length > 0 && (
            <div className="card">
              <div className="section-title">📜 過去のカルテ</div>
              <ul className="mt-3 space-y-3">
                {charts.map((c) => (
                  <ChartCard key={c.id} chart={c} />
                ))}
              </ul>
            </div>
          )}
        </div>

        {/* Right: Photo timeline + weight chart */}
        <div className="space-y-5">
          <div className="card">
            <div className="section-title">📈 体重推移</div>
            <ResponsiveContainer width="100%" height={160}>
              <LineChart
                data={[
                  { d: '生後7日', w: 3050 },
                  { d: '生後14日', w: 3280 },
                  { d: '生後21日', w: 3600 },
                  { d: '生後28日', w: 3950 },
                  { d: '生後35日', w: 4150 },
                  { d: '生後42日', w: intake?.babyWeightG ?? 4200 },
                ]}
              >
                <CartesianGrid strokeDasharray="3 3" stroke="#fde2e9" />
                <XAxis dataKey="d" fontSize={9} />
                <YAxis fontSize={9} domain={[2800, 4500]} />
                <Tooltip />
                <Line
                  type="monotone"
                  dataKey="w"
                  stroke="#f48fb1"
                  strokeWidth={3}
                  dot={{ r: 4, fill: '#f48fb1' }}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>

          <div className="card">
            <div className="section-title">📸 写真タイムライン</div>
            <p className="text-[10px] text-cocoa-400 mt-1">
              乳房・便・発疹などの記録写真（プライバシー保護のため絵文字表示）
            </p>
            {photos.length === 0 ? (
              <div className="text-sm text-cocoa-400 mt-4 text-center py-4">
                写真はまだ送られていません
              </div>
            ) : (
              <ul className="grid grid-cols-2 gap-2 mt-3">
                {photos.map((ph) => (
                  <li
                    key={ph.id}
                    className="rounded-2xl bg-sakura-50/60 dark:bg-night-800 p-3 border border-sakura-100 dark:border-cocoa-700/40"
                  >
                    <div className="aspect-square rounded-xl bg-white dark:bg-night-900 flex items-center justify-center text-4xl">
                      {ph.emoji}
                    </div>
                    <div className="text-[10px] text-cocoa-400 mt-1">
                      {ph.category}
                    </div>
                    <div className="text-xs text-cocoa-600 dark:text-night-50/80 line-clamp-2">
                      {ph.caption}
                    </div>
                    <div className="text-[10px] text-cocoa-400 mt-1">
                      {relative(ph.at)}
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function Row({ k, v }: { k: string; v: string }) {
  return (
    <div className="flex justify-between gap-2 text-sm">
      <span className="text-cocoa-400">{k}</span>
      <span className="font-bold text-cocoa-700 dark:text-night-50">{v}</span>
    </div>
  );
}

function ChartCard({ chart }: { chart: ChartEntry }) {
  return (
    <li className="p-3 rounded-2xl bg-sakura-50/40 dark:bg-night-800 border border-sakura-100 dark:border-cocoa-700/40 text-sm">
      <div className="flex justify-between mb-2 text-xs">
        <span className="font-bold text-cocoa-600 dark:text-night-50">
          {formatDateTime(chart.at)}
        </span>
        <span className="text-cocoa-400">{chart.midwife}</span>
      </div>
      {[
        ['S', chart.subjective],
        ['O', chart.objective],
        ['A', chart.assessment],
        ['P', chart.plan],
      ].map(([k, v]) => (
        <div key={k} className="flex gap-2 mt-1">
          <span className="w-5 h-5 rounded-full bg-sakura-500 text-white text-[10px] flex items-center justify-center font-bold flex-shrink-0">
            {k}
          </span>
          <span className="text-cocoa-600 dark:text-night-50/80 leading-relaxed">{v}</span>
        </div>
      ))}
      {chart.aiInsights && (
        <div className="mt-2 p-2 rounded-xl bg-white dark:bg-night-900 border border-sakura-200 dark:border-cocoa-700/40 text-[11px]">
          <div className="text-[10px] font-bold text-sakura-600">⚡ AI Insight</div>
          <ul className="mt-1 space-y-0.5 text-cocoa-500 dark:text-night-50/80">
            {chart.aiInsights.map((x, i) => (
              <li key={i}>• {x}</li>
            ))}
          </ul>
        </div>
      )}
    </li>
  );
}

function SoapForm({
  patient,
  intake,
  onSubmit,
}: {
  patient: Patient;
  intake: any;
  onSubmit: (c: Omit<ChartEntry, 'id'>) => void;
}) {
  const suggested = suggestSOAP(intake, patient);
  const [s, setS] = useState(suggested.subjective);
  const [o, setO] = useState(suggested.objective);
  const [a, setA] = useState(suggested.assessment);
  const [p, setP] = useState(suggested.plan);

  const fillSuggested = () => {
    setS(suggested.subjective);
    setO(suggested.objective);
    setA(suggested.assessment);
    setP(suggested.plan);
  };

  return (
    <div className="card">
      <div className="flex items-center justify-between">
        <div className="section-title">✍️ SOAP記録</div>
        <button
          onClick={fillSuggested}
          className="chip bg-cocoa-100 text-cocoa-600 hover:bg-cocoa-200"
        >
          ✨ AI下書き
        </button>
      </div>
      <div className="space-y-2 mt-3">
        {([
          ['S', s, setS, '主訴・主観的情報'],
          ['O', o, setO, '客観的所見・計測値'],
          ['A', a, setA, 'アセスメント'],
          ['P', p, setP, '計画・指導内容'],
        ] as Array<[string, string, (v: string) => void, string]>).map(([label, val, setter, ph]) => (
          <div key={label} className="flex gap-2">
            <span className="w-7 h-7 mt-1 rounded-full bg-sakura-500 text-white text-xs flex items-center justify-center font-bold flex-shrink-0">
              {label}
            </span>
            <textarea
              rows={2}
              placeholder={ph}
              value={val}
              onChange={(e) => setter(e.target.value)}
              className="flex-1 px-3 py-2 rounded-2xl bg-sakura-50 dark:bg-night-800 border border-sakura-100 dark:border-cocoa-700/40 text-sm"
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
          setS('');
          setO('');
          setA('');
          setP('');
          alert('カルテに記録しました🌸');
        }}
        className="btn-primary w-full mt-3"
      >
        💾 カルテを保存
      </button>
    </div>
  );
}

// =============== Analytics ===============
function Analytics({ store }: { store: Store }) {
  // 月別予約件数
  const monthlyData = useMemo(() => {
    const map: Record<string, number> = {};
    const now = new Date();
    for (let i = 5; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      map[`${d.getMonth() + 1}月`] = 0;
    }
    store.state.appointments.forEach((a) => {
      const d = new Date(a.start);
      const key = `${d.getMonth() + 1}月`;
      if (key in map) map[key]++;
    });
    // ダミーで膨らませる
    Object.keys(map).forEach((k, i) => (map[k] += 18 + i * 3));
    return Object.entries(map).map(([month, count]) => ({ month, count }));
  }, [store.state.appointments]);

  const typeData = useMemo(() => {
    const map: Record<string, number> = {};
    store.state.appointments.forEach((a) => {
      map[a.type] = (map[a.type] || 0) + 1;
    });
    return Object.entries(map).map(([name, value]) => ({ name, value }));
  }, [store.state.appointments]);

  const COLORS = ['#f48fb1', '#fa9c60', '#8d6e63', '#fdc2d2', '#544136'];

  return (
    <div className="md:ml-64">
      <PageHeader
        title="分析レポート"
        subtitle="運営の意思決定に役立てる利用者傾向の可視化"
      />
      <div className="grid md:grid-cols-3 gap-4 mb-5">
        <Kpi icon="📅" label="今月の予約" value="64件" />
        <Kpi icon="💝" label="リピート率" value="78%" />
        <Kpi icon="🌸" label="満足度" value="4.8/5" />
      </div>
      <div className="grid lg:grid-cols-2 gap-5">
        <div className="card">
          <div className="section-title">📊 月別予約件数</div>
          <ResponsiveContainer width="100%" height={240}>
            <BarChart data={monthlyData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#fde2e9" />
              <XAxis dataKey="month" fontSize={11} />
              <YAxis fontSize={11} />
              <Tooltip />
              <Bar dataKey="count" fill="#f48fb1" radius={[8, 8, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>

        <div className="card">
          <div className="section-title">🥧 ケアの種別構成</div>
          <ResponsiveContainer width="100%" height={240}>
            <PieChart>
              <Pie
                data={typeData}
                dataKey="value"
                nameKey="name"
                innerRadius={45}
                outerRadius={85}
                paddingAngle={2}
              >
                {typeData.map((_, i) => (
                  <Cell key={i} fill={COLORS[i % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip />
              <Legend wrapperStyle={{ fontSize: 11 }} />
            </PieChart>
          </ResponsiveContainer>
        </div>

        <div className="card lg:col-span-2">
          <div className="section-title">⚡ 利用者の月齢分布 (AI insight)</div>
          <ResponsiveContainer width="100%" height={200}>
            <BarChart
              data={[
                { age: '0-2週', count: 3 },
                { age: '3-4週', count: 5 },
                { age: '1-2ヶ月', count: 8 },
                { age: '2-3ヶ月', count: 6 },
                { age: '3-6ヶ月', count: 9 },
                { age: '6ヶ月+', count: 4 },
              ]}
            >
              <CartesianGrid strokeDasharray="3 3" stroke="#fde2e9" />
              <XAxis dataKey="age" fontSize={11} />
              <YAxis fontSize={11} />
              <Tooltip />
              <Bar dataKey="count" fill="#fa9c60" radius={[8, 8, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
          <div className="mt-3 bubble p-3 text-sm bg-sakura-50 dark:bg-night-800">
            <div className="flex items-center gap-2 font-bold">
              <Manakun size={24} mood="smile" />
              <span>💡 まなくんからの提案</span>
            </div>
            <p className="text-cocoa-600 dark:text-night-50/80 mt-1 leading-relaxed">
              3-6ヶ月の利用者が最多。離乳食準備のグループセミナーを月1回設定すると満足度向上が期待できます。
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

// =============== Inbox / Chat ===============
function Inbox({ store }: { store: Store }) {
  const [roomId, setRoomId] = useState<string | null>(
    store.state.chats[0]?.roomId ?? null,
  );
  const [draft, setDraft] = useState('');
  const rooms = useMemo(() => {
    const ids = Array.from(new Set(store.state.chats.map((c) => c.roomId)));
    return ids
      .map((id) => {
        const p = store.state.patients.find((x) => x.id === id)!;
        const messages = store.state.chats
          .filter((c) => c.roomId === id)
          .sort((a, b) => a.at.localeCompare(b.at));
        const last = messages[messages.length - 1];
        const urgent = messages.some((m) => m.urgent && m.from === 'mama');
        return { patient: p, last, urgent };
      })
      .sort((a, b) => b.last.at.localeCompare(a.last.at));
  }, [store.state.chats, store.state.patients]);

  const room = rooms.find((r) => r.patient.id === roomId);
  const messages = roomId
    ? store.state.chats
        .filter((c) => c.roomId === roomId)
        .sort((a, b) => a.at.localeCompare(b.at))
    : [];
  const lastMamaMsg = [...messages]
    .reverse()
    .find((m) => m.from === 'mama');
  const triage = lastMamaMsg ? triageMessage(lastMamaMsg.text) : null;

  return (
    <div className="md:ml-64">
      <PageHeader
        title="SOSチャット"
        subtitle="ママからの相談に直接返信。AIが緊急度をトリアージ"
      />
      <div className="grid md:grid-cols-3 gap-4 h-[calc(100vh-220px)]">
        {/* room list */}
        <div className="card overflow-y-auto md:col-span-1 p-2">
          <ul className="space-y-1">
            {rooms.map((r) => (
              <li key={r.patient.id}>
                <button
                  onClick={() => setRoomId(r.patient.id)}
                  className={`w-full flex items-center gap-2 p-3 rounded-2xl text-left transition ${
                    roomId === r.patient.id
                      ? 'bg-pink-grad text-white'
                      : 'hover:bg-sakura-50 dark:hover:bg-night-800'
                  }`}
                >
                  <span className="text-2xl">{r.patient.avatar}</span>
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-bold flex items-center gap-1">
                      {r.patient.name}
                      {r.urgent && <span className="text-xs">🆘</span>}
                    </div>
                    <div className={`text-xs truncate ${roomId === r.patient.id ? 'text-white/80' : 'text-cocoa-400'}`}>
                      {r.last.text}
                    </div>
                  </div>
                  <div className={`text-[10px] ${roomId === r.patient.id ? 'text-white/80' : 'text-cocoa-400'}`}>
                    {relative(r.last.at)}
                  </div>
                </button>
              </li>
            ))}
          </ul>
        </div>

        {/* messages */}
        <div className="card md:col-span-2 flex flex-col p-0 overflow-hidden">
          {room ? (
            <>
              <div className="p-4 border-b border-sakura-100 dark:border-cocoa-700/40 flex items-center gap-3">
                <span className="text-2xl">{room.patient.avatar}</span>
                <div>
                  <div className="font-bold">{room.patient.name}</div>
                  <div className="text-[10px] text-cocoa-400">
                    👶 {room.patient.babyName}ちゃん／生後{daysSince(room.patient.birthday)}日
                  </div>
                </div>
              </div>
              {triage?.urgent && (
                <div className="mx-4 mt-3 p-3 rounded-2xl bg-sakura-50 dark:bg-night-800 border border-sakura-300">
                  <div className="text-xs font-bold text-sakura-700">
                    ⚡ AIトリアージ: 緊急度高 ({triage.reason})
                  </div>
                  <div className="text-xs text-cocoa-600 dark:text-night-50/80 mt-1">
                    推奨返信: 「{triage.suggestedReply}」
                  </div>
                  <button
                    onClick={() => setDraft(triage.suggestedReply)}
                    className="chip bg-white text-sakura-600 mt-2"
                  >
                    🩹 推奨返信を使う
                  </button>
                </div>
              )}
              <div className="flex-1 overflow-y-auto p-4 space-y-3">
                {messages.map((m) => (
                  <Msg key={m.id} msg={m} avatar={room.patient.avatar} />
                ))}
              </div>
              <form
                onSubmit={(e) => {
                  e.preventDefault();
                  if (!draft.trim() || !roomId) return;
                  store.addChat({
                    roomId,
                    from: 'midwife',
                    text: draft,
                    at: new Date().toISOString(),
                  });
                  setDraft('');
                }}
                className="p-3 border-t border-sakura-100 dark:border-cocoa-700/40 flex gap-2"
              >
                <input
                  value={draft}
                  onChange={(e) => setDraft(e.target.value)}
                  placeholder="返信を入力…"
                  className="flex-1 px-4 py-3 rounded-full bg-sakura-50 dark:bg-night-800 border border-sakura-100 dark:border-cocoa-700/40 text-sm"
                />
                <button type="submit" className="btn-primary px-5">送信</button>
              </form>
            </>
          ) : (
            <div className="flex-1 flex items-center justify-center text-cocoa-400 text-sm">
              ルームを選択してください
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function Msg({ msg, avatar }: { msg: any; avatar: string }) {
  const isMidwife = msg.from === 'midwife';
  return (
    <div className={`flex items-end gap-2 ${isMidwife ? 'flex-row-reverse' : ''}`}>
      <span className="text-2xl flex-shrink-0">{isMidwife ? '🌸' : avatar}</span>
      <div
        className={`max-w-[75%] px-4 py-2.5 rounded-bubble text-sm leading-relaxed whitespace-pre-line ${
          isMidwife
            ? 'bg-pink-grad text-white rounded-br-md'
            : msg.urgent
              ? 'bg-sakura-50 dark:bg-night-800 border border-sakura-300 rounded-bl-md'
              : 'bg-white dark:bg-night-800 border border-sakura-100 dark:border-cocoa-700/40 rounded-bl-md'
        }`}
      >
        {msg.urgent && msg.from === 'mama' && (
          <div className="text-[10px] font-bold text-sakura-600 mb-1">🆘 緊急</div>
        )}
        {msg.text}
        <div className={`text-[10px] mt-1 ${isMidwife ? 'text-white/70' : 'text-cocoa-400'}`}>
          {formatTime(msg.at)}
        </div>
      </div>
    </div>
  );
}
