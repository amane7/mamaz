/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        mama: {
          50: '#fff5f7',
          100: '#ffe4ec',
          200: '#fecdd9',
          300: '#fda4be',
          400: '#fb7298',
          500: '#f43f78',
          600: '#e11d5e',
          700: '#be124f',
          800: '#9d1346',
          900: '#831540',
        },
        cream: {
          50: '#fffaf3',
          100: '#fef3e2',
          200: '#fde5c0',
        },
        moon: {
          50: '#f5f7ff',
          100: '#e8edff',
          200: '#c8d4ff',
          500: '#6b7fe0',
          700: '#3f4ea3',
        },
      },
      fontFamily: {
        sans: ['"Hiragino Sans"', '"Noto Sans JP"', 'system-ui', 'sans-serif'],
      },
      boxShadow: {
        soft: '0 8px 24px -8px rgba(244, 63, 120, 0.18)',
        bubble: '0 10px 30px -10px rgba(107, 127, 224, 0.35)',
      },
      animation: {
        'pulse-soft': 'pulseSoft 3s ease-in-out infinite',
        float: 'float 6s ease-in-out infinite',
      },
      keyframes: {
        pulseSoft: {
          '0%, 100%': { opacity: '1', transform: 'scale(1)' },
          '50%': { opacity: '0.85', transform: 'scale(1.03)' },
        },
        float: {
          '0%, 100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-8px)' },
        },
      },
    },
  },
  plugins: [],
};
