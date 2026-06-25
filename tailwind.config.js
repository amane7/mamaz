/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        // ───── Manary残り香（淡いピンクは保ちつつアクセント化） ─────
        sakura: {
          50: '#fff9fb',
          100: '#fff0f5',
          200: '#ffe0eb',
          300: '#fdc2d2',
          400: '#f8a8be',
          500: '#f48fb1',
          600: '#e87199',
          700: '#d05278',
          800: '#a93f5e',
          900: '#7c2e45',
        },
        peach: {
          50: '#fff7f3',
          100: '#ffece1',
          200: '#fed4be',
          300: '#fcb88f',
          400: '#fa9c60',
          500: '#f5803a',
        },
        cocoa: {
          50: '#faf6f4',
          100: '#f1e9e4',
          200: '#dccfc6',
          300: '#b89e8d',
          400: '#9a7e6a',
          500: '#8d6e63',
          600: '#6f5648',
          700: '#544136',
          800: '#3a2c25',
        },
        cream: {
          50: '#fffdf8',
          100: '#fff8e9',
          200: '#fbeed0',
        },
        // ───── クール×未来的（トヨタ風）メインパレット ─────
        // ダーク基調・電子的なシアン/青のアクセント
        ink: {
          50: '#f3f5fa',
          100: '#e2e6ef',
          200: '#c5cbd9',
          300: '#9ea6b8',
          400: '#6f7891',
          500: '#4b5470',
          600: '#323a52',
          700: '#212840',
          800: '#161c32',
          900: '#0c1124',
          950: '#060914',
        },
        cyber: {
          50: '#ecfeff',
          100: '#cffafe',
          200: '#a5f3fc',
          300: '#67e8f9',
          400: '#22d3ee',
          500: '#06b6d4', // primary accent
          600: '#0891b2',
          700: '#0e7490',
          800: '#155e75',
          900: '#164e63',
        },
        plasma: {
          400: '#a78bfa',
          500: '#8b5cf6', // secondary accent
          600: '#7c3aed',
        },
        signal: {
          400: '#f0abfc',
          500: '#e879f9', // tertiary accent (乳房・母乳ケアの差別化色)
          600: '#d946ef',
        },
        // ステータス
        ok: { 500: '#10b981' },
        warn: { 500: '#f59e0b' },
        ng: { 500: '#ef4444' },
        // 旧 night は ink にエイリアス維持
        night: {
          50: '#f3f5fa',
          100: '#e2e6ef',
          800: '#161c32',
          900: '#0c1124',
          950: '#060914',
        },
      },
      fontFamily: {
        sans: [
          '"Inter"',
          '"Noto Sans JP"',
          '"Hiragino Sans"',
          'system-ui',
          'sans-serif',
        ],
        display: [
          '"Space Grotesk"',
          '"Inter"',
          '"Noto Sans JP"',
          'system-ui',
          'sans-serif',
        ],
        mono: ['"JetBrains Mono"', '"SF Mono"', 'ui-monospace', 'monospace'],
        round: [
          '"Zen Maru Gothic"',
          '"Hiragino Maru Gothic ProN"',
          '"Quicksand"',
          'sans-serif',
        ],
      },
      boxShadow: {
        soft: '0 10px 25px -10px rgba(6, 182, 212, 0.20)',
        card: '0 2px 12px -2px rgba(12, 17, 36, 0.30)',
        glow: '0 0 0 4px rgba(6, 182, 212, 0.18)',
        'glow-pink': '0 0 0 4px rgba(232, 121, 249, 0.22)',
        'neon-cyan': '0 0 24px -4px rgba(34, 211, 238, 0.55)',
        'neon-pink': '0 0 24px -4px rgba(232, 121, 249, 0.55)',
        'inset-ring': 'inset 0 0 0 1px rgba(255,255,255,0.08)',
      },
      borderRadius: {
        bubble: '28px',
      },
      animation: {
        'float-slow': 'float 8s ease-in-out infinite',
        wiggle: 'wiggle 4s ease-in-out infinite',
        'pop-in': 'popIn 0.4s cubic-bezier(0.34, 1.56, 0.64, 1)',
        'pulse-glow': 'pulseGlow 2.4s ease-in-out infinite',
        'scan-line': 'scanLine 6s linear infinite',
        'grid-move': 'gridMove 20s linear infinite',
      },
      keyframes: {
        float: {
          '0%, 100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-10px)' },
        },
        wiggle: {
          '0%, 100%': { transform: 'rotate(-2deg)' },
          '50%': { transform: 'rotate(2deg)' },
        },
        popIn: {
          '0%': { transform: 'scale(0.8)', opacity: '0' },
          '100%': { transform: 'scale(1)', opacity: '1' },
        },
        pulseGlow: {
          '0%, 100%': { boxShadow: '0 0 0 0 rgba(34,211,238,0.6)' },
          '50%': { boxShadow: '0 0 0 14px rgba(34,211,238,0)' },
        },
        scanLine: {
          '0%': { transform: 'translateY(-100%)' },
          '100%': { transform: 'translateY(100%)' },
        },
        gridMove: {
          '0%': { backgroundPosition: '0 0' },
          '100%': { backgroundPosition: '40px 40px' },
        },
      },
      backgroundImage: {
        // 旧ピンク（一部用途で温存）
        'sakura-grad':
          'linear-gradient(135deg, #fff9fb 0%, #fff0f5 50%, #ffece1 100%)',
        'pink-grad': 'linear-gradient(135deg, #f48fb1 0%, #e879f9 100%)',
        // メインのクール背景
        'ink-grad':
          'linear-gradient(180deg, #060914 0%, #0c1124 50%, #161c32 100%)',
        'cyber-grad':
          'linear-gradient(135deg, #06b6d4 0%, #8b5cf6 60%, #e879f9 100%)',
        'cyber-grad-soft':
          'linear-gradient(135deg, rgba(6,182,212,0.18) 0%, rgba(139,92,246,0.18) 50%, rgba(232,121,249,0.18) 100%)',
        // ガラスモーフィズム用
        'glass-card':
          'linear-gradient(180deg, rgba(255,255,255,0.06) 0%, rgba(255,255,255,0.02) 100%)',
        // グリッド背景
        'tech-grid':
          'linear-gradient(rgba(34,211,238,0.06) 1px, transparent 1px), linear-gradient(90deg, rgba(34,211,238,0.06) 1px, transparent 1px)',
      },
      backgroundSize: {
        'grid-40': '40px 40px',
      },
    },
  },
  plugins: [],
};
