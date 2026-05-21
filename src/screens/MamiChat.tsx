import { useEffect, useRef, useState } from 'react';
import type { AppState, ChatMessage } from '../types';
import { generateMamiReply } from '../mami';

const SUGGESTIONS = [
  '夜泣きがつらい',
  '授乳量が心配',
  '気分が落ち込む',
  '離乳食はいつから？',
  '寝かしつけのコツ',
];

export function MamiChat({
  state,
  addChat,
}: {
  state: AppState;
  addChat: (m: Omit<ChatMessage, 'id'>) => void;
}) {
  const [input, setInput] = useState('');
  const [typing, setTyping] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: 99999, behavior: 'smooth' });
  }, [state.chat, typing]);

  const send = (text: string) => {
    if (!text.trim()) return;
    addChat({ role: 'user', text, at: Date.now() });
    setInput('');
    setTyping(true);
    setTimeout(() => {
      const reply = generateMamiReply(text, state);
      addChat({ role: 'mami', text: reply, at: Date.now() });
      setTyping(false);
    }, 600 + Math.random() * 500);
  };

  return (
    <div className="flex flex-col h-[calc(100vh-180px)]">
      <div
        ref={scrollRef}
        className="flex-1 overflow-y-auto space-y-3 pb-3 px-1"
      >
        {state.chat.map((m) => (
          <Bubble key={m.id} msg={m} />
        ))}
        {typing && (
          <div className="flex items-end gap-2">
            <div className="text-2xl">🌸</div>
            <div className="bg-white rounded-2xl rounded-bl-none px-4 py-3 shadow-soft">
              <div className="flex gap-1">
                <span className="w-2 h-2 bg-mama-300 rounded-full animate-pulse" />
                <span
                  className="w-2 h-2 bg-mama-300 rounded-full animate-pulse"
                  style={{ animationDelay: '0.2s' }}
                />
                <span
                  className="w-2 h-2 bg-mama-300 rounded-full animate-pulse"
                  style={{ animationDelay: '0.4s' }}
                />
              </div>
            </div>
          </div>
        )}
      </div>

      <div className="flex gap-2 overflow-x-auto py-2 -mx-1 px-1">
        {SUGGESTIONS.map((s) => (
          <button
            key={s}
            onClick={() => send(s)}
            className="whitespace-nowrap chip bg-white text-mama-700 border border-mama-100"
          >
            {s}
          </button>
        ))}
      </div>

      <form
        onSubmit={(e) => {
          e.preventDefault();
          send(input);
        }}
        className="flex gap-2 sticky bottom-0 bg-gradient-to-t from-white via-white/80 to-transparent pt-2"
      >
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="mami に話しかけてみる…"
          className="flex-1 bg-white border border-mama-100 rounded-2xl px-4 py-3"
        />
        <button type="submit" className="btn-primary px-5">
          送信
        </button>
      </form>
    </div>
  );
}

function Bubble({ msg }: { msg: ChatMessage }) {
  const isMe = msg.role === 'user';
  return (
    <div className={`flex items-end gap-2 ${isMe ? 'flex-row-reverse' : ''}`}>
      <div className="text-2xl">{isMe ? '🧑' : '🌸'}</div>
      <div
        className={`max-w-[78%] px-4 py-2.5 rounded-2xl text-sm leading-relaxed whitespace-pre-line shadow-soft ${
          isMe
            ? 'bg-gradient-to-br from-mama-400 to-mama-500 text-white rounded-br-none'
            : 'bg-white text-slate-800 rounded-bl-none'
        }`}
      >
        {msg.text}
      </div>
    </div>
  );
}
