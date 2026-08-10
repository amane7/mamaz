export function daysSince(iso: string) {
  return Math.max(0, Math.floor((Date.now() - new Date(iso).getTime()) / 86400000));
}

export function formatDate(iso: string) {
  const d = new Date(iso);
  return `${d.getFullYear()}/${(d.getMonth() + 1).toString().padStart(2, '0')}/${d.getDate().toString().padStart(2, '0')}`;
}

export function formatTime(iso: string) {
  const d = new Date(iso);
  return `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`;
}

export function formatDateTime(iso: string) {
  return `${formatDate(iso)} ${formatTime(iso)}`;
}

export function relative(iso: string) {
  const diff = Date.now() - new Date(iso).getTime();
  const m = Math.floor(diff / 60000);
  if (m < 1) return 'たった今';
  if (m < 60) return `${m}分前`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}時間前`;
  return `${Math.floor(h / 24)}日前`;
}

export function isSameDay(a: Date | string, b: Date | string) {
  const x = typeof a === 'string' ? new Date(a) : a;
  const y = typeof b === 'string' ? new Date(b) : b;
  return (
    x.getFullYear() === y.getFullYear() &&
    x.getMonth() === y.getMonth() &&
    x.getDate() === y.getDate()
  );
}

export function startOfWeek(d: Date) {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  x.setDate(x.getDate() - x.getDay()); // 日曜始まり
  return x;
}

export function weekdayShort(i: number) {
  return ['日', '月', '火', '水', '木', '金', '土'][i];
}

export function appointmentColor(type: string) {
  switch (type) {
    case '産後ケア':
      return 'bg-sakura-500 text-white';
    case '乳房ケア':
      return 'bg-peach-500 text-white';
    case '母乳相談':
      return 'bg-cocoa-400 text-white';
    case '沐浴指導':
      return 'bg-sakura-300 text-cocoa-800';
    case '初回相談':
      return 'bg-cocoa-600 text-white';
    default:
      return 'bg-cocoa-200 text-cocoa-800';
  }
}

export function riskLabel(r: 'breast' | 'mental' | 'weight' | 'sleep'): {
  label: string;
  cls: string;
} {
  switch (r) {
    case 'breast':
      return { label: '🫧 乳房', cls: 'bg-peach-100 text-peach-500' };
    case 'mental':
      return { label: '🧠 メンタル', cls: 'bg-sakura-100 text-sakura-700' };
    case 'weight':
      return { label: '⚖️ 体重', cls: 'bg-cocoa-100 text-cocoa-600' };
    case 'sleep':
      return { label: '🌙 睡眠', cls: 'bg-cream-100 text-peach-500' };
  }
}

// ───── slot ヘルパー (30分単位 = 0:00を0として、9:00=18) ─────
export function slotToTime(i: number) {
  const h = Math.floor(i / 2);
  const m = i % 2 === 0 ? '00' : '30';
  return `${String(h).padStart(2, '0')}:${m}`;
}

export function timeToSlot(h: number, m: number) {
  return h * 2 + (m >= 30 ? 1 : 0);
}

export function ymd(d: Date) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${dd}`;
}

export function addMinutes(iso: string, mins: number) {
  return new Date(new Date(iso).getTime() + mins * 60_000).toISOString();
}

