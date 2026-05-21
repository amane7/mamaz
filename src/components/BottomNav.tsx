import type { ScreenId } from '../types';

const items: { id: ScreenId; label: string; icon: string }[] = [
  { id: 'home', label: 'ホーム', icon: '🏠' },
  { id: 'log', label: '記録', icon: '📝' },
  { id: 'mami', label: 'mami', icon: '💬' },
  { id: 'mama', label: 'ママ', icon: '🌸' },
  { id: 'future', label: '未来ケア', icon: '✨' },
  { id: 'community', label: 'みんな', icon: '👥' },
];

export function BottomNav({
  current,
  onChange,
}: {
  current: ScreenId;
  onChange: (s: ScreenId) => void;
}) {
  return (
    <nav className="fixed bottom-0 left-0 right-0 z-30 pb-[env(safe-area-inset-bottom)]">
      <div className="max-w-2xl mx-auto px-3 pb-3">
        <div className="bg-white/90 backdrop-blur border border-white shadow-bubble rounded-3xl flex items-center justify-between px-1 py-1">
          {items.map((it) => {
            const active = it.id === current;
            return (
              <button
                key={it.id}
                onClick={() => onChange(it.id)}
                className={`flex-1 flex flex-col items-center gap-0.5 py-2 rounded-2xl transition ${
                  active
                    ? 'bg-gradient-to-br from-mama-400 to-mama-500 text-white shadow-soft'
                    : 'text-slate-500 hover:text-mama-500'
                }`}
              >
                <span className="text-lg leading-none">{it.icon}</span>
                <span className="text-[10px] font-semibold">{it.label}</span>
              </button>
            );
          })}
        </div>
      </div>
    </nav>
  );
}
