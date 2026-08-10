/** @type {import('tailwindcss').Config} */
// ─────────────────────────────────────────────────────────────
// MAMOA デザインシステム踏襲（産後ケア・和のウェルネス）
// - Primary: MAMOA Pink #F1B0B9 / Blush #F7C8CE
// - BG: Cream #FFF7F2 / Pink Beige #FBEFE8 / White
// - Text: Mauve #6E4F58 (body) / #3A2A30 (heading) — 純黒禁止
// - Accent: Sage #E7EFE6 / Pale Blue / Lavender #BFA9D3 (MOA専用)
// - 影は warm(rgba(142,106,115,*))
// - 角丸は 16/22/28/9999
// ─────────────────────────────────────────────────────────────
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        // ── MAMOA Primary（ピンク〜モーヴ）────────────────────
        mamoa: {
          pink: '#F1B0B9',   // Primary
          blush: '#F7C8CE',  // Blush（ボタン/主要チップ）
          rose: '#EFA4B0',   // 強調ピンク
          deep: '#D98A94',   // hover/active
          cream: '#FFF7F2',  // 主要背景
          beige: '#FBEFE8',  // カード背景の別トーン
          paper: '#FFFBF7',  // カード内背景
        },
        // ── Mauve（文字色）──────────────────────────────────
        mauve: {
          50: '#F6EFF0',
          100: '#EBD9DE',
          200: '#D5B4BB',
          300: '#B78E96',
          400: '#8E6A73',   // ブランド Mauve（見出しアクセント）
          500: '#6E4F58',   // body 文字
          600: '#5A3E48',
          700: '#4A323B',
          800: '#3A2A30',   // 強調見出し
          900: '#2A1E23',
        },
        // ── アクセント（自然/信頼/MOA）──────────────────────
        sage: {
          50: '#F5F9F3',
          100: '#E7EFE6',   // 主要 sage 背景
          200: '#CCD9C7',
          300: '#B0C2A9',
          400: '#9ABF8F',   // 強調
          500: '#7FA073',
        },
        sky: {
          50: '#F1F6FA',
          100: '#E1ECF4',
          200: '#C1D8E8',
          300: '#9DBFD8',
          400: '#7BA6C4',
          500: '#5C8BB0',
        },
        lavender: {
          50: '#F5F1F9',
          100: '#EAE0F1',
          200: '#D6C4E4',
          300: '#BFA9D3',   // MOA / 夜モード / 休息
          400: '#A78EC2',
          500: '#8B72A9',
        },
        warmgray: {
          50: '#FAF7F5',
          100: '#EFEAE6',
          200: '#DCD3CC',
          300: '#BFB2A8',
          400: '#9ABF8F',
          500: '#9ABF8F',
        },
        // ── ステータス（優しい色）────────────────────────
        ok: { 50: '#EFF7EE', 500: '#7FA073', 600: '#5F8156' },
        warn: { 50: '#FBF3E7', 500: '#D8A85A', 600: '#B78638' },
        ng: { 50: '#FBEDEE', 500: '#D98A94', 600: '#B85F6A' },

        // ── 旧トークン互換エイリアス（既存 tsx を壊さない）────
        // ink → mauve、cyber → mamoa.pink、plasma → lavender、
        // signal → mamoa.rose、cream → mamoa.cream
        ink: {
          50: '#FFF7F2',   // = cream
          100: '#FBEFE8',  // = beige
          200: '#EFE1DC',
          300: '#D5B4BB',  // ≒ mauve 200
          400: '#B78E96',  // ≒ mauve 300
          500: '#8E6A73',  // ≒ mauve 400
          600: '#6E4F58',  // ≒ mauve 500
          700: '#5A3E48',
          800: '#4A323B',
          900: '#3A2A30',  // ≒ mauve 800
          950: '#2A1E23',
        },
        cyber: {
          50: '#FDF4F5',
          100: '#FBE6EA',
          200: '#F7C8CE',   // Blush
          300: '#F1B0B9',   // MAMOA Pink
          400: '#EFA4B0',
          500: '#EFA4B0',
          600: '#D98A94',
          700: '#B85F6A',
          800: '#8E4A53',
          900: '#6A3740',
        },
        plasma: {
          400: '#D6C4E4',
          500: '#BFA9D3',   // Lavender
          600: '#A78EC2',
        },
        signal: {
          400: '#F7C8CE',
          500: '#EFA4B0',
          600: '#D98A94',
        },
        // 旧 sakura/peach/cocoa/cream を warm 系にリマップ
        sakura: {
          50: '#FFFBF9',
          100: '#FDF4F5',
          200: '#FBE6EA',
          300: '#F7C8CE',
          400: '#F1B0B9',
          500: '#EFA4B0',
          600: '#D98A94',
          700: '#B85F6A',
          800: '#8E4A53',
          900: '#6A3740',
        },
        peach: {
          50: '#FFFBF7',
          100: '#FDF3EA',
          200: '#F9E1CE',
          300: '#F2C6A6',
          400: '#E8A97F',
          500: '#D8895A',
        },
        cocoa: {
          50: '#FAF6F4',
          100: '#F1E9E4',
          200: '#DCCFC6',
          300: '#B78E96',
          400: '#8E6A73',
          500: '#6E4F58',
          600: '#5A3E48',
          700: '#4A323B',
          800: '#3A2A30',
        },
        cream: {
          50: '#FFFBF7',
          100: '#FFF7F2',
          200: '#FBEFE8',
        },
        night: {
          50: '#FFF7F2',
          100: '#FBEFE8',
          800: '#4A323B',
          900: '#3A2A30',
          950: '#2A1E23',
        },
      },
      fontFamily: {
        // 本文
        sans: [
          '"Noto Sans JP"',
          '"Hiragino Sans"',
          '"Yu Gothic UI"',
          'system-ui',
          'sans-serif',
        ],
        // 見出し／MOAダイアログ（丸ゴシック）
        display: [
          '"Zen Maru Gothic"',
          '"Hiragino Maru Gothic ProN"',
          '"Noto Sans JP"',
          'system-ui',
          'sans-serif',
        ],
        // Editorial（産後ジャーナル等）
        serif: [
          '"Noto Serif JP"',
          '"Hiragino Mincho ProN"',
          'serif',
        ],
        mono: ['"JetBrains Mono"', 'ui-monospace', 'monospace'],
        round: [
          '"Zen Maru Gothic"',
          '"Hiragino Maru Gothic ProN"',
          'sans-serif',
        ],
      },
      boxShadow: {
        // warm shadow tokens (rgba(142,106,115,*))
        'warm-1': '0 1px 2px rgba(142, 106, 115, 0.06)',
        'warm-2': '0 4px 12px rgba(142, 106, 115, 0.08)',
        'warm-3': '0 10px 30px rgba(142, 106, 115, 0.10)',
        'warm-4': '0 20px 50px rgba(142, 106, 115, 0.14)',
        soft: '0 10px 30px -12px rgba(142, 106, 115, 0.18)',
        card: '0 4px 16px -4px rgba(142, 106, 115, 0.10)',
        glow: '0 0 0 4px rgba(241, 176, 185, 0.25)',
        'glow-pink': '0 0 0 4px rgba(239, 164, 176, 0.30)',
        'neon-cyan': '0 8px 30px -8px rgba(241, 176, 185, 0.5)',
        'neon-pink': '0 8px 30px -8px rgba(239, 164, 176, 0.5)',
        'inset-ring': 'inset 0 0 0 1px rgba(142, 106, 115, 0.06)',
      },
      borderRadius: {
        // MAMOA の柔らかい角丸トークン
        'mamoa-sm': '12px',
        mamoa: '18px',
        'mamoa-lg': '22px',
        'mamoa-xl': '28px',
        bubble: '22px',
      },
      animation: {
        'float-slow': 'float 8s ease-in-out infinite',
        wiggle: 'wiggle 4s ease-in-out infinite',
        'pop-in': 'popIn 0.4s cubic-bezier(0.34, 1.56, 0.64, 1)',
        'pulse-glow': 'pulseGlow 2.4s ease-in-out infinite',
        'scan-line': 'scanLine 6s linear infinite',
        'grid-move': 'gridMove 20s linear infinite',
        breathe: 'breathe 5s ease-in-out infinite',
      },
      keyframes: {
        float: {
          '0%, 100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-8px)' },
        },
        wiggle: {
          '0%, 100%': { transform: 'rotate(-2deg)' },
          '50%': { transform: 'rotate(2deg)' },
        },
        popIn: {
          '0%': { transform: 'scale(0.9)', opacity: '0' },
          '100%': { transform: 'scale(1)', opacity: '1' },
        },
        pulseGlow: {
          '0%, 100%': { boxShadow: '0 0 0 0 rgba(241,176,185,0.6)' },
          '50%': { boxShadow: '0 0 0 14px rgba(241,176,185,0)' },
        },
        scanLine: {
          '0%': { transform: 'translateY(-100%)' },
          '100%': { transform: 'translateY(100%)' },
        },
        gridMove: {
          '0%': { backgroundPosition: '0 0' },
          '100%': { backgroundPosition: '40px 40px' },
        },
        breathe: {
          '0%, 100%': { transform: 'scale(1)', opacity: '0.9' },
          '50%': { transform: 'scale(1.03)', opacity: '1' },
        },
      },
      backgroundImage: {
        // MAMOA 温かグラデ（ヒーロー・ボタン用）
        'mamoa-grad':
          'linear-gradient(135deg, #F7C8CE 0%, #F1B0B9 55%, #EFA4B0 100%)',
        'mamoa-grad-soft':
          'linear-gradient(135deg, rgba(247,200,206,0.35) 0%, rgba(241,176,185,0.25) 60%, rgba(191,169,211,0.20) 100%)',
        'cream-grad':
          'linear-gradient(180deg, #FFFBF7 0%, #FFF7F2 55%, #FBEFE8 100%)',
        'moa-grad':
          'linear-gradient(135deg, #EAE0F1 0%, #F1B0B9 100%)',
        'sage-grad':
          'linear-gradient(135deg, #F5F9F3 0%, #E7EFE6 100%)',
        // 旧トークン互換（既存 tsx が参照するもの）
        'sakura-grad':
          'linear-gradient(135deg, #FFFBF9 0%, #FBE6EA 55%, #FBEFE8 100%)',
        'pink-grad': 'linear-gradient(135deg, #F1B0B9 0%, #EFA4B0 100%)',
        'ink-grad':
          'linear-gradient(180deg, #FFFBF7 0%, #FFF7F2 50%, #FBEFE8 100%)',
        'cyber-grad':
          'linear-gradient(135deg, #F1B0B9 0%, #EFA4B0 60%, #D98A94 100%)',
        'cyber-grad-soft':
          'linear-gradient(135deg, rgba(241,176,185,0.20) 0%, rgba(239,164,176,0.20) 50%, rgba(191,169,211,0.20) 100%)',
        'glass-card':
          'linear-gradient(180deg, rgba(255,255,255,0.85) 0%, rgba(255,255,255,0.65) 100%)',
        // 和のドットパターン（tech-grid の後継）
        'tech-grid':
          'radial-gradient(circle, rgba(142,106,115,0.06) 1px, transparent 1px)',
      },
      backgroundSize: {
        'grid-40': '24px 24px',
      },
      letterSpacing: {
        'mamoa-wide': '0.18em',
        'mamoa-wider': '0.22em',
      },
    },
  },
  plugins: [],
};
