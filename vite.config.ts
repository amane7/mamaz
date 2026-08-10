import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Vite 5 では `allowedHosts: true` は型では受け付けるが、内部で文字列配列を期待するため、
// 全許可するには '.sandbox.novita.ai' のようなワイルドカード(プレフィックスのドット)指定が確実。
export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 5173,
    strictPort: true,
    allowedHosts: ['.novita.ai', '.sandbox.novita.ai', 'localhost', '.localhost'],
    hmr: {
      clientPort: 443,
      protocol: 'wss',
    },
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          react: ['react', 'react-dom'],
        },
      },
    },
  },
  preview: {
    host: '0.0.0.0',
    port: 4173,
    strictPort: true,
    allowedHosts: ['.novita.ai', '.sandbox.novita.ai', 'localhost', '.localhost'],
  },
});
