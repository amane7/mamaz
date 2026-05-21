import { useState } from 'react';
import type { BabyProfile, MamaProfile } from '../types';

export function Onboarding({
  onDone,
}: {
  onDone: (baby: Partial<BabyProfile>, mama: Partial<MamaProfile>) => void;
}) {
  const [step, setStep] = useState(0);
  const [mamaName, setMamaName] = useState('');
  const [babyName, setBabyName] = useState('');
  const [birthday, setBirthday] = useState(() => {
    const d = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    return d.toISOString().slice(0, 10);
  });
  const [gender, setGender] = useState<'boy' | 'girl' | 'unknown'>('unknown');
  const [deliveryType, setDeliveryType] = useState<
    '自然分娩' | '帝王切開' | '無痛分娩' | 'その他'
  >('自然分娩');

  const finish = () => {
    onDone(
      {
        name: babyName || 'はる',
        birthday: new Date(birthday).toISOString(),
        gender,
        avatar: gender === 'girl' ? '👶🏻' : gender === 'boy' ? '🧒' : '👶',
      },
      {
        name: mamaName || 'ママ',
        deliveryDate: new Date(birthday).toISOString(),
        deliveryType,
        avatar: '🌸',
      },
    );
  };

  return (
    <div className="min-h-screen flex flex-col items-center justify-center p-6">
      <div className="max-w-md w-full card space-y-5 animate-pulse-soft">
        {step === 0 && (
          <>
            <div className="text-center space-y-2">
              <div className="text-5xl animate-float">🌸</div>
              <h1 className="text-2xl font-bold bg-gradient-to-r from-mama-500 to-moon-500 bg-clip-text text-transparent">
                mamaz へようこそ
              </h1>
              <p className="text-sm text-slate-600 leading-relaxed">
                産後のあなたと赤ちゃんに、やさしく寄り添うAIケアパートナー。
                <br />
                記録・癒し・つながり・予測ケアで、毎日をそっと支えます。
              </p>
            </div>
            <ul className="text-sm text-slate-600 space-y-2">
              <li>💖 AIアシスタント mami があなたの相談相手に</li>
              <li>📊 育児ログから次の授乳を予測</li>
              <li>🎤 赤ちゃんの泣き声をAIで5パターン分析</li>
              <li>🌿 ママ自身のメンタル＆体調ケア</li>
              <li>👥 同じ月齢のママとつながるコミュニティ</li>
            </ul>
            <button className="btn-primary w-full" onClick={() => setStep(1)}>
              はじめる
            </button>
          </>
        )}

        {step === 1 && (
          <>
            <h2 className="section-title">あなたのお名前</h2>
            <input
              autoFocus
              className="w-full bg-white border border-mama-100 rounded-2xl px-4 py-3"
              placeholder="ニックネームでOK"
              value={mamaName}
              onChange={(e) => setMamaName(e.target.value)}
            />
            <div>
              <div className="label mb-2">出産の種類</div>
              <div className="grid grid-cols-2 gap-2">
                {(['自然分娩', '帝王切開', '無痛分娩', 'その他'] as const).map((t) => (
                  <button
                    key={t}
                    onClick={() => setDeliveryType(t)}
                    className={`py-2 rounded-2xl text-sm font-semibold border ${
                      deliveryType === t
                        ? 'bg-mama-500 text-white border-mama-500'
                        : 'bg-white border-mama-100 text-slate-600'
                    }`}
                  >
                    {t}
                  </button>
                ))}
              </div>
            </div>
            <div className="flex gap-2">
              <button className="btn-ghost flex-1" onClick={() => setStep(0)}>
                戻る
              </button>
              <button className="btn-primary flex-1" onClick={() => setStep(2)}>
                次へ
              </button>
            </div>
          </>
        )}

        {step === 2 && (
          <>
            <h2 className="section-title">赤ちゃんのこと</h2>
            <input
              className="w-full bg-white border border-mama-100 rounded-2xl px-4 py-3"
              placeholder="赤ちゃんのお名前"
              value={babyName}
              onChange={(e) => setBabyName(e.target.value)}
            />
            <div>
              <div className="label mb-2">生まれた日</div>
              <input
                type="date"
                className="w-full bg-white border border-mama-100 rounded-2xl px-4 py-3"
                value={birthday}
                onChange={(e) => setBirthday(e.target.value)}
              />
            </div>
            <div>
              <div className="label mb-2">性別</div>
              <div className="grid grid-cols-3 gap-2">
                {([
                  ['girl', '女の子'],
                  ['boy', '男の子'],
                  ['unknown', '回答しない'],
                ] as const).map(([k, label]) => (
                  <button
                    key={k}
                    onClick={() => setGender(k)}
                    className={`py-2 rounded-2xl text-sm font-semibold border ${
                      gender === k
                        ? 'bg-mama-500 text-white border-mama-500'
                        : 'bg-white border-mama-100 text-slate-600'
                    }`}
                  >
                    {label}
                  </button>
                ))}
              </div>
            </div>
            <div className="flex gap-2">
              <button className="btn-ghost flex-1" onClick={() => setStep(1)}>
                戻る
              </button>
              <button className="btn-primary flex-1" onClick={finish}>
                mamaz をはじめる
              </button>
            </div>
            <p className="text-[10px] text-slate-400 text-center">
              ※入力データは端末内（localStorage）にのみ保存されます。
            </p>
          </>
        )}
      </div>
    </div>
  );
}
