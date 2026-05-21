import { useMemo, useState } from 'react';
import type { MamaTab } from '../types';
import { Manakun } from '../components/Manakun';
import {
  daysSince,
  formatDate,
  formatTime,
  isSameDay,
  relative,
} from '../utils';

type Store = ReturnType<typeof import('../store').useStore>;

// デモ用: ママは p1 = 佐藤みなみさん として体験
const ME_ID = 'p1';

export function MamaApp({ store, onExit }: { store: Store; onExit: () => void }) {
  const me = store.state.patients.find((p) => p.id === ME_ID)!;
  const [tab, setTab] = useState<MamaTab>('home');

  return (
    <div className="min-h-screen flex flex-col max-w-md mx-auto">
      <header className="sticky top-0 z-30 bg-white/85 dark:bg-night-900/85 backdrop-blur border-b border-sakura-100 dark:border-cocoa-700/40">
        <div className="px-4 py-3 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Manakun size={32} mood="smile" />
            <div>
              <div className="text-sm font-bold text-sakura-600">Manary+</div>
              <div className="text-[10px] text-cocoa-400">桜助産院</div>
            </div>
          </div>
          <button onClick={onExit} className="text-xs text-cocoa-400">
            ✕ 閉じる
          </button>
        </div>
      </header>

      <main className="flex-1 px-4 py-4 safe-bottom">
        {tab === 'home' && <MamaHome me={me} store={store} setTab={setTab} />}
        {tab === 'intake' && <Intake me={me} store={store} setTab={setTab} />}
        {tab === 'photos' && <PhotoUpload me={me} store={store} />}
        {tab === 'chat' && <MamaChat me={me} store={store} />}
        {tab === 'visits' && <Visits me={me} store={store} />}
      </main>

      <nav className="fixed bottom-0 left-0 right-0 z-30 pb-[env(safe-area-inset-bottom)] max-w-md mx-auto">
        <div className="px-3 pb-3">
          <div className="bg-white/95 dark:bg-night-900/95 backdrop-blur shadow-soft border border-sakura-100 dark:border-cocoa-700/40 rounded-3xl flex justify-between p-1">
            {(
              [
                ['home', '🏠', 'ホーム'],
                ['intake', '📝', '問診'],
                ['photos', '📸', '写真'],
                ['chat', '💬', '相談'],
                ['visits', '📅', '予約'],
              ] as const
            ).map(([id, icon, label]) => (
              <button
                key={id}
                onClick={() => setTab(id)}
                className={`flex-1 flex flex-col items-center gap-0.5 py-2 rounded-2xl ${
                  tab === id ? 'bg-pink-grad text-white' : 'text-cocoa-500 dark:text-night-50'
                }`}
              >
                <span className="text-base leading-none">{icon}</span>
                <span className="text-[10px] font-bold">{label}</span>
              </button>
            ))}
          </div>
        </div>
      </nav>
    </div>
  );
}

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
  const intake = store.state.intakes.find((i) => i.patientId === me.id);

  return (
    <div className="space-y-4">
      <div className="card bg-gradient-to-br from-sakura-100 via-cream-100 to-peach-100 border-0 relative overflow-hidden">
        <div className="absolute -top-2 -right-2">
          <Manakun size={64} mood="wave" />
        </div>
        <div className="text-xs text-cocoa-500">
          {formatDate(new Date().toISOString())}
        </div>
        <h2 className="text-xl font-bold text-cocoa-700 mt-1">
          みなみさん、今日もお疲れさま
        </h2>
        <p className="text-sm text-cocoa-500 mt-1">
          {me.babyName}ちゃんは生後{ageDays}日目です🌸
        </p>
      </div>

      {nextAppointment && (
        <div className="card">
          <div className="label">次回の予約</div>
          <div className="mt-2 flex items-center gap-3">
            <div className="w-14 h-14 rounded-2xl bg-pink-grad text-white flex flex-col items-center justify-center">
              <div className="text-[10px]">
                {new Date(nextAppointment.start).getMonth() + 1}月
              </div>
              <div className="text-xl font-bold leading-none">
                {new Date(nextAppointment.start).getDate()}
              </div>
            </div>
            <div className="flex-1">
              <div className="font-bold text-cocoa-700">
                {nextAppointment.type}
              </div>
              <div className="text-xs text-cocoa-500">
                {formatTime(nextAppointment.start)}〜（{nextAppointment.durationMin}分）／ 担当: 助産師 田村
              </div>
            </div>
          </div>
          {!intake && (
            <button onClick={() => setTab('intake')} className="btn-primary w-full mt-3 text-sm">
              📝 事前問診票を入力する
            </button>
          )}
          {intake && (
            <div className="mt-3 chip bg-cocoa-100 text-cocoa-600 w-full justify-center py-2">
              ✓ 問診票提出済み
            </div>
          )}
        </div>
      )}

      {lastReply && (
        <div className="card bg-sakura-50/60 dark:bg-night-800 border-sakura-100">
          <div className="flex items-start gap-2">
            <Manakun size={36} mood="smile" />
            <div className="flex-1">
              <div className="text-[10px] label">助産師さんからの返信</div>
              <p className="text-sm text-cocoa-600 dark:text-night-50/80 mt-1 leading-relaxed">
                {lastReply.text}
              </p>
              <div className="text-[10px] text-cocoa-400 mt-2">
                {relative(lastReply.at)}
              </div>
            </div>
          </div>
        </div>
      )}

      <div className="grid grid-cols-2 gap-3">
        <button onClick={() => setTab('chat')} className="card text-left active:scale-95 transition">
          <div className="text-3xl">🆘</div>
          <div className="font-bold text-cocoa-700 dark:text-night-50 mt-2">
            すぐ相談したい
          </div>
          <div className="text-xs text-cocoa-500 mt-1">
            助産師さんへ直接メッセージ
          </div>
        </button>
        <button onClick={() => setTab('photos')} className="card text-left active:scale-95 transition">
          <div className="text-3xl">📸</div>
          <div className="font-bold text-cocoa-700 dark:text-night-50 mt-2">
            写真で見てほしい
          </div>
          <div className="text-xs text-cocoa-500 mt-1">
            乳房・便・発疹を共有
          </div>
        </button>
      </div>

      <div className="card">
        <div className="section-title">📚 今の月齢のヒント</div>
        <ul className="space-y-2 mt-3 text-sm">
          {[
            '黄昏泣き（コリック）が増える時期。15分の抱っこで落ち着きます。',
            'ママはホルモン変動で涙もろくなって当然。自分を責めないで。',
            '昼夜のリズムを整えるなら、朝の光と夜の暗さを意識して。',
          ].map((t, i) => (
            <li key={i} className="pl-4 border-l-2 border-sakura-200 text-cocoa-600 dark:text-night-50/80 leading-relaxed">
              {t}
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}

function Intake({
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
  const [babyMood, setBabyMood] = useState<
    '機嫌よし' | 'ぐずり多め' | '泣き止まない'
  >('ぐずり多め');
  const [concerns, setConcerns] = useState('');
  const [topics, setTopics] = useState<string[]>([]);

  const toggleTopic = (t: string) =>
    setTopics((arr) => (arr.includes(t) ? arr.filter((x) => x !== t) : [...arr, t]));

  const submit = () => {
    if (!next) return;
    store.addIntake({
      patientId: me.id,
      appointmentId: next.id,
      submittedAt: new Date().toISOString(),
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
      <div className="card bg-gradient-to-br from-sakura-100 to-peach-100 border-0">
        <div className="flex items-center gap-2">
          <Manakun size={32} mood="wink" />
          <div>
            <div className="font-bold">事前問診票</div>
            <div className="text-xs text-cocoa-500">当日のケアの質が上がります</div>
          </div>
        </div>
      </div>

      <div className="card space-y-4">
        <div className="text-sm font-bold text-cocoa-700 dark:text-night-50">
          🌸 ママのこと
        </div>
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
        <div className="text-sm font-bold text-cocoa-700 dark:text-night-50">
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
        <div className="text-sm font-bold text-cocoa-700 dark:text-night-50 mb-3">
          💭 心配ごと・相談したいこと
        </div>
        <textarea
          rows={4}
          value={concerns}
          onChange={(e) => setConcerns(e.target.value)}
          placeholder="気になっていることをご自由に。書ききれない場合は当日でも大丈夫です。"
          className="w-full px-3 py-2 rounded-2xl bg-sakura-50 dark:bg-night-800 border border-sakura-100 dark:border-cocoa-700/40 text-sm"
        />
        <div className="text-xs text-cocoa-400 mt-3 mb-2">相談トピック (複数選択可)</div>
        <div className="flex flex-wrap gap-2">
          {['夜泣き', 'メンタル', '母乳量', '乳腺ケア', '体重', '離乳食', '沐浴', '寝かしつけ'].map(
            (t) => (
              <button
                key={t}
                onClick={() => toggleTopic(t)}
                className={`chip ${
                  topics.includes(t)
                    ? 'bg-pink-grad text-white'
                    : 'bg-white text-sakura-700 border border-sakura-200'
                }`}
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
      <p className="text-[10px] text-cocoa-400 text-center">
        ※入力データは暗号化され、担当の助産師さんのみが閲覧できます。
      </p>
    </div>
  );
}

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
      <div className="card bg-gradient-to-br from-sakura-100 to-peach-100 border-0">
        <div className="flex items-center gap-2">
          <Manakun size={32} />
          <div>
            <div className="font-bold">写真で見てもらう</div>
            <div className="text-xs text-cocoa-500">乳房・便・発疹を時系列で記録・共有</div>
          </div>
        </div>
      </div>

      <div className="card">
        <div className="text-sm font-bold mb-2">📸 新しい写真を送る</div>
        <div className="text-[10px] text-cocoa-400 mb-2">カテゴリー</div>
        <div className="flex flex-wrap gap-2 mb-3">
          {(['乳房', '便', '発疹', '体重計', 'その他'] as const).map((c) => (
            <button
              key={c}
              onClick={() => {
                setCategory(c);
                setEmoji(emojiMap[c][0]);
              }}
              className={`chip ${
                category === c
                  ? 'bg-pink-grad text-white'
                  : 'bg-white text-sakura-700 border border-sakura-200'
              }`}
            >
              {c}
            </button>
          ))}
        </div>

        <div className="aspect-video rounded-2xl bg-sakura-50 dark:bg-night-800 border-2 border-dashed border-sakura-200 dark:border-cocoa-700/40 flex flex-col items-center justify-center my-3">
          <div className="text-5xl">{emoji}</div>
          <div className="text-xs text-cocoa-400 mt-2">タップして撮影 (デモ)</div>
          <div className="flex gap-1 mt-2">
            {emojiMap[category].map((e) => (
              <button
                key={e}
                onClick={() => setEmoji(e)}
                className={`text-xl p-1 rounded ${emoji === e ? 'bg-sakura-200' : ''}`}
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
          className="w-full px-3 py-2 rounded-2xl bg-sakura-50 dark:bg-night-800 border border-sakura-100 dark:border-cocoa-700/40 text-sm"
        />
        <button onClick={send} className="btn-primary w-full mt-3">
          🌸 助産師さんに送る
        </button>
      </div>

      <div className="card">
        <div className="section-title">📜 これまでの送信履歴</div>
        {myPhotos.length === 0 ? (
          <div className="text-sm text-cocoa-400 text-center py-4 mt-2">
            まだ写真はありません
          </div>
        ) : (
          <ul className="grid grid-cols-2 gap-2 mt-3">
            {myPhotos.map((p) => (
              <li
                key={p.id}
                className="rounded-2xl bg-sakura-50/60 dark:bg-night-800 p-3 border border-sakura-100 dark:border-cocoa-700/40"
              >
                <div className="aspect-square rounded-xl bg-white dark:bg-night-900 flex items-center justify-center text-4xl">
                  {p.emoji}
                </div>
                <div className="text-[10px] text-cocoa-400 mt-1">{p.category}</div>
                <div className="text-xs line-clamp-2 text-cocoa-600 dark:text-night-50/80">
                  {p.caption}
                </div>
                <div className="text-[10px] text-cocoa-400 mt-1">{relative(p.at)}</div>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}

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
    // 助産師の自動応答（デモ）
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
      <div className="card bg-gradient-to-br from-sakura-100 to-peach-100 border-0 mb-3">
        <div className="flex items-center gap-2">
          <Manakun size={32} mood="love" />
          <div>
            <div className="font-bold">助産師 田村さん</div>
            <div className="text-xs text-cocoa-500">桜助産院 ／ 通常24h以内に返信</div>
          </div>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto space-y-3 pb-3">
        {messages.length === 0 && (
          <div className="text-center text-cocoa-400 text-sm py-8">
            まだメッセージはありません。気軽に話しかけてくださいね。
          </div>
        )}
        {messages.map((m) => {
          const isMama = m.from === 'mama';
          return (
            <div key={m.id} className={`flex items-end gap-2 ${isMama ? 'flex-row-reverse' : ''}`}>
              <span className="text-2xl">{isMama ? me.avatar : '🌸'}</span>
              <div
                className={`max-w-[80%] px-4 py-2.5 rounded-bubble text-sm leading-relaxed whitespace-pre-line ${
                  isMama
                    ? 'bg-pink-grad text-white rounded-br-md'
                    : 'bg-white dark:bg-night-800 border border-sakura-100 dark:border-cocoa-700/40 rounded-bl-md'
                }`}
              >
                {m.urgent && isMama && (
                  <div className="text-[10px] mb-1 opacity-80">🆘 緊急として送信済み</div>
                )}
                {m.text}
                <div className={`text-[10px] mt-1 ${isMama ? 'text-white/70' : 'text-cocoa-400'}`}>
                  {formatTime(m.at)}
                </div>
              </div>
            </div>
          );
        })}
      </div>

      <div className="sticky bottom-0 bg-gradient-to-t from-sakura-50 via-sakura-50/80 to-transparent pt-2 -mx-1">
        <div className="flex flex-wrap gap-1 mb-2 px-1">
          {['夜泣きが辛いです', '授乳が痛いです', '体重増えてますか？'].map((q) => (
            <button
              key={q}
              onClick={() => setDraft(q)}
              className="chip bg-white text-sakura-700 border border-sakura-200"
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
            className="flex-1 px-4 py-3 rounded-full bg-white dark:bg-night-800 border border-sakura-100 dark:border-cocoa-700/40 text-sm"
          />
          <button
            type="button"
            onClick={() => send(true)}
            className="px-4 py-3 rounded-full bg-sakura-500 text-white font-bold text-sm"
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

function Visits({ me, store }: { me: any; store: Store }) {
  const mine = store.state.appointments
    .filter((a) => a.patientId === me.id)
    .sort((a, b) => b.start.localeCompare(a.start));
  const upcoming = mine.filter((a) => new Date(a.start) >= new Date());
  const past = mine.filter((a) => new Date(a.start) < new Date());

  return (
    <div className="space-y-4">
      <div className="card bg-gradient-to-br from-sakura-100 to-peach-100 border-0">
        <div className="flex items-center gap-2">
          <Manakun size={32} mood="wave" />
          <div>
            <div className="font-bold">予約管理</div>
            <div className="text-xs text-cocoa-500">いつでも24時間予約・変更</div>
          </div>
        </div>
      </div>

      <div className="card">
        <div className="section-title">📅 これからの予約</div>
        {upcoming.length === 0 ? (
          <div className="text-sm text-cocoa-400 mt-3 text-center py-3">
            次の予約はありません
          </div>
        ) : (
          <ul className="mt-3 space-y-2">
            {upcoming.map((a) => (
              <li
                key={a.id}
                className="p-3 rounded-2xl bg-sakura-50/60 dark:bg-night-800 border border-sakura-100 dark:border-cocoa-700/40"
              >
                <div className="flex items-center gap-3">
                  <div className="w-14 h-14 rounded-2xl bg-pink-grad text-white flex flex-col items-center justify-center">
                    <div className="text-[10px]">
                      {new Date(a.start).getMonth() + 1}月
                    </div>
                    <div className="text-xl font-bold leading-none">
                      {new Date(a.start).getDate()}
                    </div>
                  </div>
                  <div className="flex-1">
                    <div className="font-bold">{a.type}</div>
                    <div className="text-xs text-cocoa-500">
                      {formatTime(a.start)}〜（{a.durationMin}分）
                    </div>
                  </div>
                  <span className="chip bg-cocoa-100 text-cocoa-600">{a.status}</span>
                </div>
              </li>
            ))}
          </ul>
        )}
        <button className="btn-primary w-full mt-3 text-sm">＋ 新しく予約する</button>
      </div>

      {past.length > 0 && (
        <div className="card">
          <div className="section-title">📜 来院履歴</div>
          <ul className="mt-3 space-y-2 text-sm">
            {past.map((a) => (
              <li key={a.id} className="flex justify-between items-center py-1">
                <span>
                  {formatDate(a.start)} {a.type}
                </span>
                <span className="text-xs text-cocoa-400">{a.status}</span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}

// ========= Form helpers =========
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
        <span className="text-cocoa-600 dark:text-night-50/80">{label}</span>
        <span className="font-bold text-sakura-600">
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
        className="w-full accent-sakura-500"
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
      <span className="text-sm text-cocoa-600 dark:text-night-50/80">{label}</span>
      <div className="flex items-center gap-2">
        <button
          onClick={() => setValue(Math.max(0, value - step))}
          className="w-9 h-9 rounded-full bg-sakura-100 text-sakura-700 font-bold"
        >
          −
        </button>
        <span className="w-16 text-center font-bold">{value}</span>
        <button
          onClick={() => setValue(value + step)}
          className="w-9 h-9 rounded-full bg-sakura-100 text-sakura-700 font-bold"
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
      <div className="text-sm text-cocoa-600 dark:text-night-50/80 mb-2">{label}</div>
      <div className="flex flex-wrap gap-2">
        {options.map((o) => (
          <button
            key={o}
            onClick={() => onChange(o)}
            className={`chip ${
              value === o
                ? 'bg-pink-grad text-white'
                : 'bg-white text-sakura-700 border border-sakura-200'
            }`}
          >
            {o}
          </button>
        ))}
      </div>
    </div>
  );
}
