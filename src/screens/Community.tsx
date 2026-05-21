import { useState } from 'react';
import type { AppState } from '../types';
import { daysSince } from '../utils';

interface Post {
  id: string;
  author: string;
  avatar: string;
  ageDays: number;
  text: string;
  likes: number;
  comments: number;
  tag: string;
  ago: string;
  liked?: boolean;
}

const SEED_POSTS: Post[] = [
  {
    id: 'p1',
    author: 'もちこ',
    avatar: '🌷',
    ageDays: 38,
    text:
      '夜中2時から授乳→寝かしつけ→気づいたら6時…💦みんな夜どれくらい寝てる？昼間が記憶ない。',
    likes: 24,
    comments: 8,
    tag: '#夜泣き',
    ago: '15分前',
  },
  {
    id: 'p2',
    author: 'りん',
    avatar: '🌸',
    ageDays: 52,
    text:
      '産後ドゥーラさんに来てもらったら号泣してしまった。「頑張ってきたんだね」って言われて初めて自分を労う気持ちになった🥺',
    likes: 132,
    comments: 21,
    tag: '#メンタル',
    ago: '1時間前',
  },
  {
    id: 'p3',
    author: 'さやか',
    avatar: '🌼',
    ageDays: 28,
    text:
      '帝王切開組の方、傷痛みっていつまで続きました？くしゃみが地獄…！',
    likes: 41,
    comments: 17,
    tag: '#帝王切開',
    ago: '3時間前',
  },
  {
    id: 'p4',
    author: 'パパ@育休中',
    avatar: '🧔',
    ageDays: 60,
    text:
      'ミルク作りに慣れてきた。ママを少しでも休ませたい。同じパパさん、何時間担当してる？',
    likes: 67,
    comments: 12,
    tag: '#パパ育児',
    ago: '5時間前',
  },
];

const TAGS = ['#すべて', '#夜泣き', '#メンタル', '#帝王切開', '#パパ育児', '#離乳食'];

export function Community({ state }: { state: AppState }) {
  const [posts, setPosts] = useState<Post[]>(SEED_POSTS);
  const [tag, setTag] = useState('#すべて');
  const [draft, setDraft] = useState('');

  const filtered = tag === '#すべて' ? posts : posts.filter((p) => p.tag === tag);

  const like = (id: string) =>
    setPosts((ps) =>
      ps.map((p) =>
        p.id === id
          ? { ...p, liked: !p.liked, likes: p.likes + (p.liked ? -1 : 1) }
          : p,
      ),
    );

  const post = () => {
    if (!draft.trim()) return;
    setPosts((ps) => [
      {
        id: crypto.randomUUID(),
        author: state.mama.name,
        avatar: state.mama.avatar,
        ageDays: daysSince(state.baby.birthday),
        text: draft,
        likes: 0,
        comments: 0,
        tag: '#すべて',
        ago: 'たった今',
      },
      ...ps,
    ]);
    setDraft('');
  };

  return (
    <div className="space-y-4">
      <section className="card bg-gradient-to-br from-mama-100 to-moon-100 border-0">
        <div className="flex items-center gap-3">
          <div className="text-3xl">👥</div>
          <div>
            <div className="font-bold">同じ月齢のママ・パパとつながる</div>
            <p className="text-xs text-slate-600">
              匿名で気軽に。AIモデレーターが安全な場を見守ります。
            </p>
          </div>
        </div>
      </section>

      <section className="card">
        <div className="section-title">✍️ 今の気持ちをシェア</div>
        <textarea
          rows={3}
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          placeholder="深夜のひとりごと、つぶやき大歓迎🌙"
          className="w-full mt-2 bg-white border border-mama-100 rounded-2xl px-4 py-3 text-sm"
        />
        <div className="flex justify-end mt-2">
          <button
            disabled={!draft.trim()}
            onClick={post}
            className="btn-primary disabled:opacity-50"
          >
            投稿する
          </button>
        </div>
      </section>

      <div className="flex gap-2 overflow-x-auto pb-1">
        {TAGS.map((t) => (
          <button
            key={t}
            onClick={() => setTag(t)}
            className={`chip whitespace-nowrap ${
              tag === t
                ? 'bg-mama-500 text-white'
                : 'bg-white text-mama-700 border border-mama-100'
            }`}
          >
            {t}
          </button>
        ))}
      </div>

      <ul className="space-y-3">
        {filtered.map((p) => (
          <li key={p.id} className="card">
            <div className="flex items-center gap-2">
              <div className="text-2xl">{p.avatar}</div>
              <div className="flex-1">
                <div className="text-sm font-bold">{p.author}</div>
                <div className="text-[10px] text-slate-400">
                  生後{p.ageDays}日 ／ {p.ago}
                </div>
              </div>
              <span className="chip bg-moon-50 text-moon-700 border border-moon-200">
                {p.tag}
              </span>
            </div>
            <p className="text-sm mt-3 whitespace-pre-line leading-relaxed">
              {p.text}
            </p>
            <div className="flex gap-4 mt-3 text-xs text-slate-500">
              <button
                onClick={() => like(p.id)}
                className={`flex items-center gap-1 ${
                  p.liked ? 'text-mama-600 font-bold' : ''
                }`}
              >
                {p.liked ? '💗' : '🤍'} {p.likes}
              </button>
              <span>💬 {p.comments}</span>
              <span className="ml-auto text-[10px]">AIモデレート済み ✓</span>
            </div>
          </li>
        ))}
      </ul>

      <section className="card bg-gradient-to-br from-cream-100 to-mama-50">
        <div className="section-title">🌷 専門家に聞く（オンライン）</div>
        <ul className="text-sm space-y-2 mt-3">
          <li>👩‍⚕️ 助産師 (チャット相談) — 24時間以内に返答</li>
          <li>🧠 公認心理師 (ビデオ) — 30分 5,000円〜</li>
          <li>🥗 管理栄養士 (テキスト) — 離乳食・授乳期の栄養</li>
        </ul>
        <button className="btn-primary w-full mt-3">予約する</button>
      </section>
    </div>
  );
}
