import { useMemo, useState } from 'react';
import type { MamaTab, AppointmentType, Appointment } from '../types';
import { Manakun } from '../components/Manakun';
import {
  daysSince,
  formatDate,
  formatTime,
  relative,
  ymd,
} from '../utils';
import { hasOverlap } from '../store';

type Store = ReturnType<typeof import('../store').useStore>;

// デモ用: ママは p1 = 佐藤みなみさん として体験
const ME_ID = 'p1';

export function MamaApp({ store, onExit }: { store: Store; onExit: () => void }) {
  const me = store.state.patients.find((p) => p.id === ME_ID)!;
  const [tab, setTab] = useState<MamaTab>('home');

  return (
    <div className="min-h-screen flex flex-col max-w-md mx-auto relative">
      <div className="fixed inset-0 tech-bg opacity-30 pointer-events-none" />

      <header className="sticky top-0 z-30 backdrop-blur-xl bg-ink-950/70 border-b border-white/5">
        <div className="px-4 py-3 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-cyber-grad flex items-center justify-center shadow-neon-cyan">
              <span className="text-sm">🌸</span>
            </div>
            <div>
              <div className="display text-sm font-bold text-ink-50">
                Manary<span className="text-cyber-400">+</span>
              </div>
              <div className="text-[10px] mono text-ink-400">桜助産院</div>
            </div>
          </div>
          <button onClick={onExit} className="text-xs text-ink-400 hover:text-cyber-400 transition">
            ✕ 閉じる
          </button>
        </div>
      </header>

      <main className="flex-1 px-4 py-4 safe-bottom relative">
        {tab === 'home' && <MamaHome me={me} store={store} setTab={setTab} />}
        {tab === 'book' && <BookFlow me={me} store={store} setTab={setTab} />}
        {tab === 'intake' && <IntakeStandalone me={me} store={store} setTab={setTab} />}
        {tab === 'photos' && <PhotoUpload me={me} store={store} />}
        {tab === 'chat' && <MamaChat me={me} store={store} />}
        {tab === 'visits' && <Visits me={me} store={store} setTab={setTab} />}
      </main>

      <nav className="fixed bottom-0 left-0 right-0 z-30 pb-[env(safe-area-inset-bottom)] max-w-md mx-auto">
        <div className="px-3 pb-3">
          <div className="backdrop-blur-xl bg-ink-900/80 border border-white/10 rounded-2xl flex justify-between p-1 shadow-card">
            {(
              [
                ['home', '🏠', 'ホーム'],
                ['book', '📅', '予約'],
                ['photos', '📸', '写真'],
                ['chat', '💬', '相談'],
                ['visits', '🗓️', '履歴'],
              ] as const
            ).map(([id, icon, label]) => (
              <button
                key={id}
                onClick={() => setTab(id)}
                className={`flex-1 flex flex-col items-center gap-0.5 py-2 rounded-xl transition ${
                  tab === id
                    ? 'bg-cyber-grad text-white shadow-neon-cyan'
                    : 'text-ink-400 hover:text-ink-100'
                }`}
              >
                <span className="text-base leading-none">{icon}</span>
                <span className="text-[10px] font-semibold">{label}</span>
              </button>
            ))}
          </div>
        </div>
      </nav>
    </div>
  );
}

// ════════════════════════════════════════════
// ホーム
// ════════════════════════════════════════════
function MamaHome({
  me,
  store,
  setTab,
}: {
  me: any;
  store: Store;
  setTab: (t: MamaTab) => void;
}) {
  const ageDays = daysSince(me.birthday);
  const nextAppointment = store.state.appointments
    .filter((a) => a.patientId === me.id && new Date(a.start) >= new Date())
    .sort((a, b) => a.start.localeCompare(b.start))[0];
  const myChat = store.state.chats.filter((c) => c.roomId === me.id);
  const lastReply = [...myChat].reverse().find((m) => m.from === 'midwife');
  const intakeForNext = nextAppointment
    ? store.state.intakes.find((i) => i.appointmentId === nextAppointment.id)
    : undefined;

  return (
    <div className="space-y-4">
      <div className="card-hero relative overflow-hidden">
        <div className="absolute -top-1 -right-1">
          <Manakun size={72} mood="wave" />
        </div>
        <div className="text-[10px] mono text-cyber-400">
          {formatDate(new Date().toISOString())} / DAY {ageDays}
        </div>
        <h2 className="display text-xl font-bold text-ink-50 mt-1">
          みなみさん、<br />
          今日もお疲れさま 🌸
        </h2>
        <p className="text-sm text-ink-300 mt-2">
          {me.babyName}ちゃんは生後 <span className="text-cyber-400 font-bold">{ageDays}日目</span> です
        </p>
      </div>

      {nextAppointment && (
        <div className="card-glow">
          <div className="flex items-center justify-between mb-3">
            <div className="label">次回の予約</div>
            <span className="chip-cyan text-[10px]">UPCOMING</span>
          </div>
          <div className="flex items-center gap-3">
            <div className="w-16 h-16 rounded-xl bg-cyber-grad text-white flex flex-col items-center justify-center shadow-neon-cyan">
              <div className="text-[10px] mono opacity-90">
                {new Date(nextAppointment.start).getMonth() + 1}月
              </div>
              <div className="display text-2xl font-bold leading-none">
                {new Date(nextAppointment.start).getDate()}
              </div>
            </div>
            <div className="flex-1">
              <div className="display font-bold text-ink-50">
                {nextAppointment.type}
              </div>
              <div className="text-xs text-ink-400 mono">
                {formatTime(nextAppointment.start)} ・ {nextAppointment.durationMin}min ・ 田村
              </div>
            </div>
          </div>
          {!intakeForNext ? (
            <button onClick={() => setTab('intake')} className="btn-primary w-full mt-3 text-sm">
              📝 事前問診票を入力する
            </button>
          ) : (
            <div className="mt-3 chip-ok w-full justify-center py-2">
              ✓ 問診票 提出済み
            </div>
          )}
        </div>
      )}

      <div className="grid grid-cols-2 gap-3">
        <QuickAction
          icon="📅"
          title="予約する"
          desc="空き枠から選んで問診まで一気通貫"
          onClick={() => setTab('book')}
          color="cyber"
        />
        <QuickAction
          icon="🆘"
          title="すぐ相談"
          desc="助産師さんへメッセージ"
          onClick={() => setTab('chat')}
          color="signal"
        />
        <QuickAction
          icon="📸"
          title="写真で見て欲しい"
          desc="乳房・便・発疹"
          onClick={() => setTab('photos')}
          color="plasma"
        />
        <QuickAction
          icon="🗓️"
          title="予約履歴"
          desc="過去の来院記録"
          onClick={() => setTab('visits')}
          color="cyber"
        />
      </div>

      {lastReply && (
        <div className="card">
          <div className="flex items-start gap-2.5">
            <Manakun size={36} mood="smile" />
            <div className="flex-1">
              <div className="flex items-center gap-2 mb-1">
                <span className="label">助産師さんからの返信</span>
                <span className="mono text-[10px] text-ink-500">{relative(lastReply.at)}</span>
              </div>
              <p className="text-sm text-ink-200 leading-relaxed">{lastReply.text}</p>
            </div>
          </div>
        </div>
      )}

      <div className="card">
        <div className="section-title text-ink-50">
          <span className="text-cyber-400">●</span> 今の月齢のヒント
        </div>
        <ul className="space-y-2 mt-3 text-sm">
          {[
            '黄昏泣き（コリック）が増える時期。15分の抱っこで落ち着きます。',
            'ママはホルモン変動で涙もろくなって当然。自分を責めないで。',
            '昼夜のリズムを整えるなら、朝の光と夜の暗さを意識して。',
          ].map((t, i) => (
            <li
              key={i}
              className="pl-3 border-l-2 border-cyber-700/40 text-ink-300 leading-relaxed"
            >
              {t}
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}

function QuickAction({
  icon,
  title,
  desc,
  onClick,
  color,
}: {
  icon: string;
  title: string;
  desc: string;
  onClick: () => void;
  color: 'cyber' | 'signal' | 'plasma';
}) {
  const ringMap: Record<string, string> = {
    cyber: 'hover:shadow-neon-cyan hover:border-cyber-500/40',
    signal: 'hover:shadow-neon-pink hover:border-signal-500/40',
    plasma: 'hover:border-plasma-500/40',
  };
  return (
    <button onClick={onClick} className={`card text-left active:scale-95 transition ${ringMap[color]}`}>
      <div className="text-2xl mb-2">{icon}</div>
      <div className="display font-bold text-ink-50 text-sm">{title}</div>
      <div className="text-xs text-ink-400 mt-1 leading-tight">{desc}</div>
    </button>
  );
}

// ════════════════════════════════════════════
// 予約フロー (BookFlow) — 予約＋問診セット
// ════════════════════════════════════════════
function BookFlow({
  me,
  store,
  setTab,
}: {
  me: any;
  store: Store;
  setTab: (t: MamaTab) => void;
}) {
  const [step, setStep] = useState<1 | 2 | 3 | 4>(1);
  const [type, setType] = useState<AppointmentType>('産後ケア');
  const [duration, setDuration] = useState(60);
  const [option, setOption] = useState<string[]>([]);

  // 日付・時間
  const [date, setDate] = useState<string>(() => {
    const d = new Date();
    d.setDate(d.getDate() + 1);
    return ymd(d);
  });
  const [hour, setHour] = useState<number | null>(null);

  // 問診
  const [sleep, setSleep] = useState(5);
  const [mood, setMood] = useState(6);
  const [pain, setPain] = useState(2);
  const [bleeding, setBleeding] = useState<'なし' | '少量' | '中等量' | '多量'>('なし');
  const [breast, setBreast] = useState<
    '良好' | '張り' | '痛み' | 'しこり' | '乳腺炎疑い'
  >('良好');
  const [weight, setWeight] = useState(4500);
  const [feeding, setFeeding] = useState(8);
  const [diaper, setDiaper] = useState(7);
  const [babyMood, setBabyMood] = useState<'機嫌よし' | 'ぐずり多め' | '泣き止まない'>('機嫌よし');
  const [concerns, setConcerns] = useState('');
  const [topics, setTopics] = useState<string[]>([]);
  const [allergy, setAllergy] = useState(me.allergy ?? 'なし');
  const [phone, setPhone] = useState(me.phone);

  // 利用可能な時間枠 (営業時間 9-17、その日に他予約がある時間は無効化)
  const availableHours = useMemo(() => {
    const dayShifts = store.state.shifts.filter((s) => s.date === date && !s.closed);
    const startOfDay = new Date(`${date}T00:00:00`);
    const result: { hour: number; slotIndex: number; ok: boolean }[] = [];
    for (let h = store.state.config.openHour; h < store.state.config.closeHour; h++) {
      const slotIndex = h * 2;
      const isOpen = dayShifts.some((s) => s.slotIndex === slotIndex || s.slotIndex === slotIndex + 1);
      if (!isOpen) continue;
      const startISO = new Date(
        startOfDay.getTime() + h * 60 * 60_000,
      ).toISOString();
      const overlap = hasOverlap(store.state.appointments, startISO, duration);
      result.push({ hour: h, slotIndex, ok: !overlap });
    }
    return result;
  }, [date, duration, store.state.appointments, store.state.shifts, store.state.config]);

  const toggleTopic = (t: string) =>
    setTopics((arr) => (arr.includes(t) ? arr.filter((x) => x !== t) : [...arr, t]));
  const toggleOption = (t: string) =>
    setOption((arr) => (arr.includes(t) ? arr.filter((x) => x !== t) : [...arr, t]));

  const submit = () => {
    if (hour === null) return;
    const startISO = new Date(`${date}T${String(hour).padStart(2, '0')}:00:00`).toISOString();
    const result = store.bookAppointmentWithIntake(
      {
        patientId: me.id,
        start: startISO,
        durationMin: duration,
        type,
        notes: option.length ? `オプション: ${option.join(' / ')}` : undefined,
        channel: 'app',
      },
      {
        patientId: me.id,
        submittedAt: new Date().toISOString(),
        motherName: me.name,
        babyName: me.babyName,
        babyBirthday: me.birthday,
        phone,
        allergy,
        optionRequested: option,
        sleepHours: sleep,
        moodScore: mood,
        bodyPain: pain,
        bleeding,
        breastCondition: breast,
        babyWeightG: weight,
        feedingPerDay: feeding,
        diaperPerDay: diaper,
        babyMood,
        concerns,
        consultTopics: topics,
      },
    );
    if (!result.ok) {
      alert(`予約できませんでした: ${result.reason}`);
      return;
    }
    setStep(4);
  };

  if (step === 4) {
    return (
      <div className="space-y-4">
        <div className="card-glow text-center py-10">
          <div className="text-6xl mb-3">🌸</div>
          <div className="display text-2xl font-bold text-ink-50">
            予約が完了しました
          </div>
          <p className="text-sm text-ink-300 mt-3">
            問診票も助産師さんへ届きました。
            <br />
            公式LINEに自動通知が送信されます。
          </p>
          <div className="mt-6 mono text-[10px] text-cyber-400">
            ▸ official-line.notify("予約入ってよかちゃん！")
          </div>
          <button onClick={() => setTab('home')} className="btn-primary mt-6">
            ホームに戻る
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-4 pb-4">
      <StepperBar step={step} />
      {step === 1 && (
        <div className="space-y-4">
          <div className="card">
            <div className="section-title">
              <span className="text-cyber-400">①</span> ケアの種類を選んでください
            </div>
            <div className="grid grid-cols-2 gap-2 mt-4">
              {(
                [
                  ['産後ケア', '🌸', '60min'],
                  ['乳房ケア', '🫧', '60min'],
                  ['母乳相談', '🍼', '30min'],
                  ['沐浴指導', '🛁', '60min'],
                  ['初回相談', '💬', '60min'],
                ] as const
              ).map(([t, icon, dur]) => (
                <button
                  key={t}
                  onClick={() => {
                    setType(t);
                    setDuration(parseInt(dur));
                  }}
                  className={`p-3 rounded-xl border text-left transition ${
                    type === t
                      ? 'border-cyber-500 bg-cyber-500/10 shadow-neon-cyan'
                      : 'border-white/10 bg-white/[0.03] hover:border-cyber-700/40'
                  }`}
                >
                  <div className="text-2xl">{icon}</div>
                  <div className="display font-semibold text-ink-50 text-sm mt-1">{t}</div>
                  <div className="text-[10px] mono text-ink-400">{dur}</div>
                </button>
              ))}
            </div>
          </div>

          <div className="card">
            <div className="label mb-2">オプション (任意)</div>
            <div className="flex flex-wrap gap-2">
              {['沐浴', '写真撮影', 'おやつ', '整体', '骨盤ケア'].map((o) => (
                <button
                  key={o}
                  onClick={() => toggleOption(o)}
                  className={
                    option.includes(o) ? 'chip-cyan' : 'chip'
                  }
                >
                  {option.includes(o) ? '✓ ' : '＋ '}
                  {o}
                </button>
              ))}
            </div>
          </div>

          <button onClick={() => setStep(2)} className="btn-primary w-full">
            次へ：日時を選ぶ →
          </button>
        </div>
      )}

      {step === 2 && (
        <div className="space-y-4">
          <div className="card">
            <div className="section-title">
              <span className="text-cyber-400">②</span> 日時を選ぶ
            </div>
            <div className="label mt-3 mb-2">日付</div>
            <input
              type="date"
              value={date}
              onChange={(e) => {
                setDate(e.target.value);
                setHour(null);
              }}
              className="input"
              min={ymd(new Date())}
            />

            <div className="label mt-4 mb-2">時間 ({duration}分枠 / 空き枠のみ選択可)</div>
            <div className="grid grid-cols-3 gap-2">
              {availableHours.length === 0 && (
                <div className="col-span-3 text-sm text-ink-400 text-center py-4">
                  この日は受付しておりません
                </div>
              )}
              {availableHours.map((s) => (
                <button
                  key={s.hour}
                  disabled={!s.ok}
                  onClick={() => setHour(s.hour)}
                  className={`p-2.5 rounded-lg text-sm mono transition ${
                    hour === s.hour
                      ? 'bg-cyber-grad text-white shadow-neon-cyan'
                      : s.ok
                        ? 'bg-white/[0.03] border border-white/10 text-ink-100 hover:border-cyber-700/40'
                        : 'bg-white/[0.01] text-ink-600 line-through cursor-not-allowed'
                  }`}
                >
                  {String(s.hour).padStart(2, '0')}:00
                </button>
              ))}
            </div>
            <div className="mt-3 mono text-[10px] text-ink-500">
              ▸ ダブルブッキング自動防止 / 1時間枠そのまま予約可
            </div>
          </div>

          <div className="flex gap-2">
            <button onClick={() => setStep(1)} className="btn-ghost flex-1">
              ← 戻る
            </button>
            <button
              onClick={() => setStep(3)}
              disabled={hour === null}
              className={`flex-1 ${hour === null ? 'btn-ghost opacity-50 cursor-not-allowed' : 'btn-primary'}`}
            >
              次へ：問診 →
            </button>
          </div>
        </div>
      )}

      {step === 3 && (
        <div className="space-y-4">
          <div className="card">
            <div className="section-title">
              <span className="text-cyber-400">③</span> 事前問診票 (予約とセットで送信)
            </div>
            <div className="mt-4 space-y-3">
              <Input label="お母さんのお名前" value={me.name} disabled />
              <Input label="赤ちゃんのお名前" value={me.babyName} disabled />
              <Input
                label="電話番号"
                value={phone}
                onChange={(v) => setPhone(v)}
              />
              <Input
                label="アレルギー"
                value={allergy}
                onChange={(v) => setAllergy(v)}
              />
            </div>
          </div>

          <div className="card space-y-4">
            <div className="text-sm font-semibold text-ink-50">🌸 ママのこと</div>
            <Slider label="昨夜の睡眠" min={0} max={12} step={0.5} unit="h" value={sleep} setValue={setSleep} />
            <Slider label="気分" min={1} max={10} step={1} unit="/10" value={mood} setValue={setMood} />
            <Slider label="からだの痛み" min={1} max={10} step={1} unit="/10" value={pain} setValue={setPain} />
            <ChoiceRow
              label="出血"
              value={bleeding}
              options={['なし', '少量', '中等量', '多量']}
              onChange={(v) => setBleeding(v as any)}
            />
            <ChoiceRow
              label="乳房の状態"
              value={breast}
              options={['良好', '張り', '痛み', 'しこり', '乳腺炎疑い']}
              onChange={(v) => setBreast(v as any)}
            />
          </div>

          <div className="card space-y-4">
            <div className="text-sm font-semibold text-ink-50">
              👶 {me.babyName}ちゃんのこと
            </div>
            <NumberRow label="体重 (g)" value={weight} setValue={setWeight} step={50} />
            <NumberRow label="授乳/日" value={feeding} setValue={setFeeding} step={1} />
            <NumberRow label="おむつ/日" value={diaper} setValue={setDiaper} step={1} />
            <ChoiceRow
              label="きげん"
              value={babyMood}
              options={['機嫌よし', 'ぐずり多め', '泣き止まない']}
              onChange={(v) => setBabyMood(v as any)}
            />
          </div>

          <div className="card">
            <div className="text-sm font-semibold text-ink-50 mb-3">
              💭 心配ごと・相談したいこと
            </div>
            <textarea
              rows={3}
              value={concerns}
              onChange={(e) => setConcerns(e.target.value)}
              placeholder="気になっていることをご自由に。"
              className="input"
            />
            <div className="label mt-3 mb-2">相談トピック</div>
            <div className="flex flex-wrap gap-2">
              {['夜泣き', 'メンタル', '母乳量', '乳腺ケア', '体重', '離乳食', '沐浴', '寝かしつけ'].map(
                (t) => (
                  <button
                    key={t}
                    onClick={() => toggleTopic(t)}
                    className={topics.includes(t) ? 'chip-cyan' : 'chip'}
                  >
                    {t}
                  </button>
                ),
              )}
            </div>
          </div>

          <div className="flex gap-2">
            <button onClick={() => setStep(2)} className="btn-ghost flex-1">
              ← 戻る
            </button>
            <button onClick={submit} className="btn-primary flex-1">
              🌸 予約 ＋ 問診 を送信
            </button>
          </div>
          <p className="text-[10px] text-ink-500 text-center mono">
            ▸ booking + intake はアトミックに保存 / 公式LINE自動通知
          </p>
        </div>
      )}
    </div>
  );
}

function StepperBar({ step }: { step: 1 | 2 | 3 | 4 }) {
  const labels = ['ケア選択', '日時', '問診', '完了'];
  return (
    <div className="card">
      <div className="flex items-center justify-between">
        {labels.map((l, i) => {
          const n = i + 1;
          const active = n === step;
          const done = n < step;
          return (
            <div key={l} className="flex items-center flex-1">
              <div
                className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold transition ${
                  done
                    ? 'bg-ok-500 text-white'
                    : active
                      ? 'bg-cyber-grad text-white shadow-neon-cyan'
                      : 'bg-white/[0.05] text-ink-500 border border-white/10'
                }`}
              >
                {done ? '✓' : n}
              </div>
              <div
                className={`text-[10px] mono ml-1.5 ${
                  active ? 'text-cyber-400' : done ? 'text-ok-500' : 'text-ink-500'
                }`}
              >
                {l}
              </div>
              {i < labels.length - 1 && (
                <div
                  className={`flex-1 h-px mx-2 ${
                    n < step ? 'bg-ok-500' : 'bg-white/10'
                  }`}
                />
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ════════════════════════════════════════════
// 単独問診（次回予約に対して）
// ════════════════════════════════════════════
function IntakeStandalone({
  me,
  store,
  setTab,
}: {
  me: any;
  store: Store;
  setTab: (t: MamaTab) => void;
}) {
  const next = store.state.appointments
    .filter((a) => a.patientId === me.id && new Date(a.start) >= new Date())
    .sort((a, b) => a.start.localeCompare(b.start))[0];

  const [sleep, setSleep] = useState(4);
  const [mood, setMood] = useState(4);
  const [pain, setPain] = useState(3);
  const [bleeding, setBleeding] = useState<'なし' | '少量' | '中等量' | '多量'>('少量');
  const [breast, setBreast] = useState<
    '良好' | '張り' | '痛み' | 'しこり' | '乳腺炎疑い'
  >('張り');
  const [weight, setWeight] = useState(4200);
  const [feeding, setFeeding] = useState(9);
  const [diaper, setDiaper] = useState(7);
  const [babyMood, setBabyMood] = useState<'機嫌よし' | 'ぐずり多め' | '泣き止まない'>('ぐずり多め');
  const [concerns, setConcerns] = useState('');
  const [topics, setTopics] = useState<string[]>([]);
  const toggleTopic = (t: string) =>
    setTopics((arr) => (arr.includes(t) ? arr.filter((x) => x !== t) : [...arr, t]));

  if (!next) {
    return (
      <div className="card text-center py-10">
        <div className="text-5xl mb-3">📅</div>
        <div className="display font-bold text-ink-50">予約がまだありません</div>
        <p className="text-sm text-ink-300 mt-2">先に予約を作成してください。</p>
        <button onClick={() => setTab('book')} className="btn-primary mt-4">
          ▸ 予約する
        </button>
      </div>
    );
  }

  const submit = () => {
    store.addIntake({
      patientId: me.id,
      appointmentId: next.id,
      submittedAt: new Date().toISOString(),
      motherName: me.name,
      babyName: me.babyName,
      babyBirthday: me.birthday,
      phone: me.phone,
      allergy: me.allergy ?? 'なし',
      optionRequested: [],
      sleepHours: sleep,
      moodScore: mood,
      bodyPain: pain,
      bleeding,
      breastCondition: breast,
      babyWeightG: weight,
      feedingPerDay: feeding,
      diaperPerDay: diaper,
      babyMood,
      concerns,
      consultTopics: topics,
    });
    alert('問診票を送信しました🌸 当日お会いできるのを楽しみにしています。');
    setTab('home');
  };

  return (
    <div className="space-y-4">
      <div className="card-glow">
        <div className="flex items-center gap-2">
          <Manakun size={32} mood="wink" />
          <div>
            <div className="display font-bold text-ink-50">事前問診票</div>
            <div className="text-xs text-ink-400 mono">
              {formatDate(next.start)} {formatTime(next.start)} / {next.type}
            </div>
          </div>
        </div>
      </div>

      <div className="card space-y-4">
        <div className="text-sm font-semibold text-ink-50">🌸 ママのこと</div>
        <Slider label="昨夜の睡眠" min={0} max={12} step={0.5} unit="h" value={sleep} setValue={setSleep} />
        <Slider label="気分" min={1} max={10} step={1} unit="/10" value={mood} setValue={setMood} />
        <Slider label="からだの痛み" min={1} max={10} step={1} unit="/10" value={pain} setValue={setPain} />
        <ChoiceRow
          label="出血"
          value={bleeding}
          options={['なし', '少量', '中等量', '多量']}
          onChange={(v) => setBleeding(v as any)}
        />
        <ChoiceRow
          label="乳房の状態"
          value={breast}
          options={['良好', '張り', '痛み', 'しこり', '乳腺炎疑い']}
          onChange={(v) => setBreast(v as any)}
        />
      </div>

      <div className="card space-y-4">
        <div className="text-sm font-semibold text-ink-50">
          👶 {me.babyName}ちゃんのこと
        </div>
        <NumberRow label="体重 (g)" value={weight} setValue={setWeight} step={50} />
        <NumberRow label="授乳/日" value={feeding} setValue={setFeeding} step={1} />
        <NumberRow label="おむつ/日" value={diaper} setValue={setDiaper} step={1} />
        <ChoiceRow
          label="きげん"
          value={babyMood}
          options={['機嫌よし', 'ぐずり多め', '泣き止まない']}
          onChange={(v) => setBabyMood(v as any)}
        />
      </div>

      <div className="card">
        <div className="text-sm font-semibold text-ink-50 mb-3">
          💭 心配ごと・相談したいこと
        </div>
        <textarea
          rows={4}
          value={concerns}
          onChange={(e) => setConcerns(e.target.value)}
          placeholder="気になっていることをご自由に。"
          className="input"
        />
        <div className="label mt-3 mb-2">相談トピック (複数選択可)</div>
        <div className="flex flex-wrap gap-2">
          {['夜泣き', 'メンタル', '母乳量', '乳腺ケア', '体重', '離乳食', '沐浴', '寝かしつけ'].map(
            (t) => (
              <button
                key={t}
                onClick={() => toggleTopic(t)}
                className={topics.includes(t) ? 'chip-cyan' : 'chip'}
              >
                {t}
              </button>
            ),
          )}
        </div>
      </div>

      <button onClick={submit} className="btn-primary w-full">
        🌸 助産師さんに送信
      </button>
    </div>
  );
}

// ════════════════════════════════════════════
// 写真
// ════════════════════════════════════════════
function PhotoUpload({ me, store }: { me: any; store: Store }) {
  const [category, setCategory] = useState<
    '乳房' | '便' | '発疹' | '体重計' | 'その他'
  >('便');
  const [caption, setCaption] = useState('');
  const [emoji, setEmoji] = useState('💩');

  const myPhotos = store.state.photos
    .filter((p) => p.patientId === me.id)
    .sort((a, b) => b.at.localeCompare(a.at));

  const send = () => {
    if (!caption.trim()) return;
    store.addPhoto({
      patientId: me.id,
      at: new Date().toISOString(),
      category,
      caption,
      emoji,
    });
    setCaption('');
    alert('写真を助産師さんに送りました🌸');
  };

  const emojiMap: Record<string, string[]> = {
    乳房: ['🫧', '💗', '🌹'],
    便: ['💩', '🟤', '🟡', '🟢'],
    発疹: ['🌹', '🔴', '🟠'],
    体重計: ['⚖️', '📏'],
    その他: ['📸', '💭'],
  };

  return (
    <div className="space-y-4">
      <div className="card-hero">
        <div className="flex items-center gap-2">
          <Manakun size={32} />
          <div>
            <div className="display font-bold text-ink-50">写真で見てもらう</div>
            <div className="text-xs text-ink-400">乳房・便・発疹を時系列で共有</div>
          </div>
        </div>
      </div>

      <div className="card">
        <div className="text-sm font-semibold mb-2 text-ink-50">📸 新しい写真を送る</div>
        <div className="label mt-3 mb-2">カテゴリー</div>
        <div className="flex flex-wrap gap-2 mb-3">
          {(['乳房', '便', '発疹', '体重計', 'その他'] as const).map((c) => (
            <button
              key={c}
              onClick={() => {
                setCategory(c);
                setEmoji(emojiMap[c][0]);
              }}
              className={category === c ? 'chip-cyan' : 'chip'}
            >
              {c}
            </button>
          ))}
        </div>

        <div className="aspect-video rounded-xl bg-white/[0.03] border-2 border-dashed border-white/10 flex flex-col items-center justify-center my-3">
          <div className="text-5xl">{emoji}</div>
          <div className="text-xs text-ink-400 mt-2">タップして撮影 (デモ)</div>
          <div className="flex gap-1 mt-2">
            {emojiMap[category].map((e) => (
              <button
                key={e}
                onClick={() => setEmoji(e)}
                className={`text-xl p-1 rounded ${emoji === e ? 'bg-cyber-500/20 ring-1 ring-cyber-500/50' : ''}`}
              >
                {e}
              </button>
            ))}
          </div>
        </div>

        <textarea
          rows={2}
          placeholder="メモ（例: 右胸の外側、しこりがある場所）"
          value={caption}
          onChange={(e) => setCaption(e.target.value)}
          className="input"
        />
        <button onClick={send} className="btn-primary w-full mt-3">
          🌸 助産師さんに送る
        </button>
      </div>

      <div className="card">
        <div className="section-title text-ink-50">📜 これまでの送信履歴</div>
        {myPhotos.length === 0 ? (
          <div className="text-sm text-ink-400 text-center py-4 mt-2">
            まだ写真はありません
          </div>
        ) : (
          <ul className="grid grid-cols-2 gap-2 mt-3">
            {myPhotos.map((p) => (
              <li
                key={p.id}
                className="rounded-xl bg-white/[0.03] p-3 border border-white/10"
              >
                <div className="aspect-square rounded-lg bg-white/[0.04] flex items-center justify-center text-4xl">
                  {p.emoji}
                </div>
                <div className="text-[10px] mono text-cyber-400 mt-2">{p.category}</div>
                <div className="text-xs line-clamp-2 text-ink-200">
                  {p.caption}
                </div>
                <div className="text-[10px] mono text-ink-500 mt-1">{relative(p.at)}</div>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}

// ════════════════════════════════════════════
// チャット
// ════════════════════════════════════════════
function MamaChat({ me, store }: { me: any; store: Store }) {
  const [draft, setDraft] = useState('');
  const messages = store.state.chats
    .filter((c) => c.roomId === me.id)
    .sort((a, b) => a.at.localeCompare(b.at));

  const send = (urgent: boolean) => {
    if (!draft.trim()) return;
    store.addChat({
      roomId: me.id,
      from: 'mama',
      text: draft,
      at: new Date().toISOString(),
      urgent,
    });
    setDraft('');
    setTimeout(() => {
      store.addChat({
        roomId: me.id,
        from: 'midwife',
        text: urgent
          ? 'お知らせありがとうございます。すぐに状況を確認します。少々お待ちください🌸'
          : 'メッセージありがとうございます。詳しく伺いますね。',
        at: new Date().toISOString(),
      });
    }, 1500);
  };

  return (
    <div className="flex flex-col h-[calc(100vh-180px)]">
      <div className="card-hero mb-3">
        <div className="flex items-center gap-2">
          <Manakun size={32} mood="love" />
          <div>
            <div className="display font-bold text-ink-50">助産師 田村さん</div>
            <div className="text-xs text-ink-400 mono">桜助産院 / 通常 24h 以内に返信</div>
          </div>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto space-y-3 pb-3">
        {messages.length === 0 && (
          <div className="text-center text-ink-400 text-sm py-8">
            まだメッセージはありません。気軽に話しかけてくださいね。
          </div>
        )}
        {messages.map((m) => {
          const isMama = m.from === 'mama';
          return (
            <div key={m.id} className={`flex items-end gap-2 ${isMama ? 'flex-row-reverse' : ''}`}>
              <span className="text-2xl">{isMama ? me.avatar : '🌸'}</span>
              <div className={`max-w-[80%] ${isMama ? 'bubble bubble-me' : 'bubble'} text-sm leading-relaxed whitespace-pre-line`}>
                {m.urgent && isMama && (
                  <div className="text-[10px] mb-1 chip-ng inline-flex">🆘 緊急として送信</div>
                )}
                {m.text}
                <div className={`text-[10px] mono mt-1 ${isMama ? 'text-cyber-300' : 'text-ink-500'}`}>
                  {formatTime(m.at)}
                </div>
              </div>
            </div>
          );
        })}
      </div>

      <div className="sticky bottom-0 pt-2 -mx-1 bg-gradient-to-t from-ink-950 via-ink-950/80 to-transparent">
        <div className="flex flex-wrap gap-1 mb-2 px-1">
          {['夜泣きが辛いです', '授乳が痛いです', '体重増えてますか？'].map((q) => (
            <button
              key={q}
              onClick={() => setDraft(q)}
              className="chip"
            >
              {q}
            </button>
          ))}
        </div>
        <form
          onSubmit={(e) => {
            e.preventDefault();
            send(false);
          }}
          className="flex gap-2 px-1"
        >
          <input
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            placeholder="メッセージ…"
            className="input flex-1"
          />
          <button
            type="button"
            onClick={() => send(true)}
            className="btn-danger text-sm"
            title="緊急として送信"
          >
            🆘
          </button>
          <button type="submit" className="btn-primary px-5 text-sm">
            送信
          </button>
        </form>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════
// 訪問履歴 / これからの予約
// ════════════════════════════════════════════
function Visits({
  me,
  store,
  setTab,
}: {
  me: any;
  store: Store;
  setTab: (t: MamaTab) => void;
}) {
  const mine = store.state.appointments
    .filter((a) => a.patientId === me.id)
    .sort((a, b) => b.start.localeCompare(a.start));
  const upcoming = mine.filter((a) => new Date(a.start) >= new Date());
  const past = mine.filter((a) => new Date(a.start) < new Date());

  return (
    <div className="space-y-4">
      <div className="card-hero">
        <div className="flex items-center gap-2">
          <Manakun size={32} mood="wave" />
          <div>
            <div className="display font-bold text-ink-50">予約管理</div>
            <div className="text-xs text-ink-400">いつでも24時間予約・変更</div>
          </div>
        </div>
      </div>

      <div className="card">
        <div className="section-title text-ink-50">📅 これからの予約</div>
        {upcoming.length === 0 ? (
          <div className="text-sm text-ink-400 mt-3 text-center py-3">
            次の予約はありません
          </div>
        ) : (
          <ul className="mt-3 space-y-2">
            {upcoming.map((a) => (
              <AppointmentRow key={a.id} a={a} store={store} />
            ))}
          </ul>
        )}
        <button onClick={() => setTab('book')} className="btn-primary w-full mt-3 text-sm">
          ＋ 新しく予約する
        </button>
      </div>

      {past.length > 0 && (
        <div className="card">
          <div className="section-title text-ink-50">📜 来院履歴</div>
          <ul className="mt-3 space-y-2 text-sm">
            {past.map((a) => (
              <li key={a.id} className="flex justify-between items-center py-1">
                <span className="text-ink-200">
                  {formatDate(a.start)} {a.type}
                </span>
                <span className="mono text-[10px] text-ink-500">{a.status}</span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}

function AppointmentRow({ a, store }: { a: Appointment; store: Store }) {
  const intake = store.state.intakes.find((i) => i.appointmentId === a.id);
  return (
    <li className="p-3 rounded-xl bg-white/[0.03] border border-white/10">
      <div className="flex items-center gap-3">
        <div className="w-14 h-14 rounded-xl bg-cyber-grad text-white flex flex-col items-center justify-center shadow-neon-cyan">
          <div className="text-[10px] mono opacity-90">
            {new Date(a.start).getMonth() + 1}月
          </div>
          <div className="display text-xl font-bold leading-none">
            {new Date(a.start).getDate()}
          </div>
        </div>
        <div className="flex-1">
          <div className="display font-semibold text-ink-50">{a.type}</div>
          <div className="text-xs mono text-ink-400">
            {formatTime(a.start)} ・ {a.durationMin}min
          </div>
        </div>
        <div className="flex flex-col gap-1 items-end">
          <span className="chip">{a.status}</span>
          {intake && <span className="chip-ok text-[10px]">📝 ✓</span>}
        </div>
      </div>
    </li>
  );
}

// ════════════════════════════════════════════
// Form helpers
// ════════════════════════════════════════════
function Slider({
  label,
  min,
  max,
  step,
  unit,
  value,
  setValue,
}: {
  label: string;
  min: number;
  max: number;
  step: number;
  unit: string;
  value: number;
  setValue: (n: number) => void;
}) {
  return (
    <div>
      <div className="flex justify-between text-sm mb-1">
        <span className="text-ink-200">{label}</span>
        <span className="font-bold text-cyber-400 mono">
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
        onChange={(e) => setValue(parseFloat(e.target.value))}
        className="w-full accent-cyber-500"
      />
    </div>
  );
}

function NumberRow({
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
    <div className="flex items-center justify-between">
      <span className="text-sm text-ink-200">{label}</span>
      <div className="flex items-center gap-2">
        <button
          onClick={() => setValue(Math.max(0, value - step))}
          className="w-9 h-9 rounded-lg bg-white/[0.05] border border-white/10 text-ink-200 font-bold hover:border-cyber-700/40"
        >
          −
        </button>
        <span className="w-16 text-center font-bold mono text-cyber-400">{value}</span>
        <button
          onClick={() => setValue(value + step)}
          className="w-9 h-9 rounded-lg bg-white/[0.05] border border-white/10 text-ink-200 font-bold hover:border-cyber-700/40"
        >
          +
        </button>
      </div>
    </div>
  );
}

function ChoiceRow({
  label,
  value,
  options,
  onChange,
}: {
  label: string;
  value: string;
  options: string[];
  onChange: (v: string) => void;
}) {
  return (
    <div>
      <div className="text-sm text-ink-200 mb-2">{label}</div>
      <div className="flex flex-wrap gap-2">
        {options.map((o) => (
          <button
            key={o}
            onClick={() => onChange(o)}
            className={value === o ? 'chip-cyan' : 'chip'}
          >
            {o}
          </button>
        ))}
      </div>
    </div>
  );
}

function Input({
  label,
  value,
  onChange,
  disabled,
}: {
  label: string;
  value: string;
  onChange?: (v: string) => void;
  disabled?: boolean;
}) {
  return (
    <div>
      <div className="label mb-1">{label}</div>
      <input
        value={value}
        onChange={(e) => onChange?.(e.target.value)}
        disabled={disabled}
        className={`input ${disabled ? 'opacity-60' : ''}`}
      />
    </div>
  );
}
