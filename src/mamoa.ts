// ────────────────────────────────────────────────────────────
// MAMOA デザインシステム — アセット参照 & 定数
// ────────────────────────────────────────────────────────────
// `public/mamoa/` に配置した MAMOA スキルの参考画像を、
// ブランドとして正式採用するアセット。
// UI からは `import { MAMOA } from '@/mamoa'` で参照する想定。

export const MAMOA = {
  // ロゴ／マーク
  icon: '/mamoa/mamoa_icon.png',
  // MOA キャラクター
  moaLarge: '/mamoa/moa_character_cradle.png', // Hero 用（ゆりかご付き）
  moaSmall: '/mamoa/moa_character_small.png',  // アバター円内
  // Website / Ad
  websiteHero: '/mamoa/website_hero.png',
  ad1: '/mamoa/ad_poster_1.png',
  ad2: '/mamoa/ad_poster_2.png',
  // App screens (reference)
  screenHome: '/mamoa/screen_home.png',
  screenChat: '/mamoa/screen_chat.png',
  screenReserve: '/mamoa/screen_reserve.png',
  screenCommunity: '/mamoa/screen_community.png',
  screenJournal: '/mamoa/screen_journal.png',
  // Palette
  brandColors: '/mamoa/brand_color_swatches.png',
  features: '/mamoa/features_row.png',
} as const;

// カラー定数（tailwind 外で JS 側で参照したい場合用）
export const MAMOA_COLORS = {
  pink: '#F1B0B9',
  blush: '#F7C8CE',
  rose: '#EFA4B0',
  deep: '#D98A94',
  cream: '#FFF7F2',
  beige: '#FBEFE8',
  paper: '#FFFBF7',
  mauve: '#8E6A73',
  mauveText: '#6E4F58',
  mauveStrong: '#3A2A30',
  sage: '#9ABF8F',
  sageBg: '#E7EFE6',
  lavender: '#BFA9D3',
  lavenderBg: '#EAE0F1',
  sky: '#7BA6C4',
  warmGray: '#9ABF8F',
} as const;

// ブランドメッセージ
export const MAMOA_MESSAGES = {
  primary: '産後の不安に、温もりが届く。',
  secondary: '助産師の手のぬくもりを、24時間そばに。',
  medicalDisclaimer:
    'MAMOA は医療サービスではなく、医師の診断に代わるものではありません。体調に不安がある場合は医療機関にご相談ください。',
} as const;
