import type { AppState } from '../types';
import { daysSince } from '../utils';

export function TopBar({ state, onReset }: { state: AppState; onReset: () => void }) {
  const ageDays = daysSince(state.baby.birthday);
  const months = Math.floor(ageDays / 30);
  const days = ageDays % 30;
  return (
    <header className="sticky top-0 z-30 backdrop-blur bg-white/60 border-b border-white">
      <div className="max-w-2xl mx-auto px-4 py-3 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-2xl bg-gradient-to-br from-mama-400 to-moon-500 flex items-center justify-center text-white text-xl shadow-soft">
            {state.baby.avatar}
          </div>
          <div>
            <div className="text-xs text-slate-500">
              {state.mama.name} ＆ {state.baby.name}
            </div>
            <div className="text-sm font-bold text-slate-800">
              生後 {months}ヶ月{days}日 ／ {ageDays}日目
            </div>
          </div>
        </div>
        <button
          onClick={() => {
            if (confirm('データをリセットして初期状態に戻します。よろしいですか？')) onReset();
          }}
          className="text-xs text-slate-400 hover:text-slate-600 px-2 py-1"
          title="リセット"
        >
          ⟳
        </button>
      </div>
    </header>
  );
}
