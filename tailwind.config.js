/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        // Manary風メインピンクパレット
        sakura: {
          50: '#fff9f9',
          100: '#fff0f3',
          200: '#ffe0e8',
          300: '#fdc2d2',
          400: '#f8a8be',
          500: '#f48fb1', // Manary primary
          600: '#e87199',
          700: '#d05278',
          800: '#a93f5e',
          900: '#7c2e45',
        },
        // ピーチ
        peach: {
          50: '#fff7f3',
          100: '#ffece1',
          200: '#fed4be',
          300: '#fcb88f',
          400: '#fa9c60',
          500: '#f5803a',
        },
        // アクセントブラウン
        cocoa: {
          50: '#faf6f4',
          100: '#f1e9e4',
          200: '#dccfc6',
          300: '#b89e8d',
          400: '#9a7e6a',
          500: '#8d6e63', // Manary accent
          600: '#6f5648',
          700: '#544136',
          800: '#3a2c25',
        },
        // クリーム
        cream: {
          50: '#fffdf8',
          100: '#fff8e9',
          200: '#fbeed0',
        },
        // ダークモード基調
        night: {
          50: '#f6f7fb',
          100: '#e7e9f3',
          800: '#272332',
          900: '#1c1826',
          950: '#13101b',
        },
      },
      fontFamily: {
        sans: [
          '"Hiragino Maru Gothic ProN"',
          '"Hiragino Maru Gothic Pro"',
          '"Quicksand"',
          '"Nunito"',
          '"Noto Sans JP"',
          'system-ui',
          'sans-serif',
        ],
        round: ['"Quicksand"', '"Hiragino Maru Gothic ProN"', '"Nunito"', 'sans-serif'],
      },
      boxShadow: {
        soft: '0 10px 25px -10px rgba(244, 143, 177, 0.25)',
        card: '0 2px 12px -2px rgba(141, 110, 99, 0.10)',
        glow: '0 0 0 4px rgba(244, 143, 177, 0.18)',
      },
      borderRadius: {
        bubble: '28px',
      },
      animation: {
        'float-slow': 'float 8s ease-in-out infinite',
        'wiggle': 'wiggle 4s ease-in-out infinite',
        'pop-in': 'popIn 0.4s cubic-bezier(0.34, 1.56, 0.64, 1)',
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
      },
      backgroundImage: {
        'sakura-grad': 'linear-gradient(135deg, #fff9f9 0%, #fff0f3 50%, #ffece1 100%)',
        'pink-grad': 'linear-gradient(135deg, #f48fb1 0%, #fa9c60 100%)',
      },
    },
  },
  plugins: [],
};
