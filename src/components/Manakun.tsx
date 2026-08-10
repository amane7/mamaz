// クマのマスコット「まなくん」インラインSVG（軽量・スケール可）
type Mood = 'smile' | 'wave' | 'sleep' | 'wink' | 'love';

export function Manakun({
  size = 96,
  mood = 'smile',
  className = '',
}: {
  size?: number;
  mood?: Mood;
  className?: string;
}) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 200 200"
      className={className}
      xmlns="http://www.w3.org/2000/svg"
    >
      {/* 耳 */}
      <circle cx="55" cy="55" r="22" fill="#dccfc6" />
      <circle cx="145" cy="55" r="22" fill="#dccfc6" />
      <circle cx="55" cy="55" r="12" fill="#f8a8be" />
      <circle cx="145" cy="55" r="12" fill="#f8a8be" />
      {/* 頭 */}
      <circle cx="100" cy="105" r="60" fill="#f1e9e4" />
      <circle cx="100" cy="105" r="60" fill="none" stroke="#dccfc6" strokeWidth="2" />
      {/* ほっぺ */}
      <circle cx="65" cy="120" r="10" fill="#fdc2d2" opacity="0.7" />
      <circle cx="135" cy="120" r="10" fill="#fdc2d2" opacity="0.7" />
      {/* 目 */}
      {mood === 'sleep' ? (
        <>
          <path d="M75 105 Q82 110 90 105" stroke="#544136" strokeWidth="3" fill="none" strokeLinecap="round" />
          <path d="M110 105 Q117 110 125 105" stroke="#544136" strokeWidth="3" fill="none" strokeLinecap="round" />
        </>
      ) : mood === 'wink' ? (
        <>
          <circle cx="82" cy="108" r="4" fill="#544136" />
          <path d="M110 108 Q117 113 125 108" stroke="#544136" strokeWidth="3" fill="none" strokeLinecap="round" />
        </>
      ) : (
        <>
          <circle cx="82" cy="108" r="4.5" fill="#544136" />
          <circle cx="118" cy="108" r="4.5" fill="#544136" />
          <circle cx="83.5" cy="106.5" r="1.5" fill="#fff" />
          <circle cx="119.5" cy="106.5" r="1.5" fill="#fff" />
        </>
      )}
      {/* 鼻 */}
      <ellipse cx="100" cy="125" rx="5" ry="4" fill="#544136" />
      {/* 口 */}
      {mood === 'love' ? (
        <path
          d="M100 135 C95 138, 88 138, 90 132 C92 128, 100 130, 100 134 C100 130, 108 128, 110 132 C112 138, 105 138, 100 135 Z"
          fill="#e87199"
        />
      ) : (
        <path
          d="M90 134 Q100 144 110 134"
          stroke="#544136"
          strokeWidth="3"
          fill="none"
          strokeLinecap="round"
        />
      )}
      {/* 手 (waveなら手を上げる) */}
      {mood === 'wave' && (
        <g>
          <circle cx="160" cy="80" r="14" fill="#f1e9e4" stroke="#dccfc6" strokeWidth="2" />
          <line x1="155" y1="65" x2="160" y2="55" stroke="#544136" strokeWidth="2" strokeLinecap="round" />
        </g>
      )}
    </svg>
  );
}
