import type { AppState } from './types';
import {
  sumFeedingLast24h,
  sumSleepLast24h,
  predictNextFeeding,
  mamaWellnessScore,
  daysSince,
} from './utils';

// AIケアパートナー「mami」のルールベース応答
// 実運用では LLM API に差し替え可能な構造にしている
export function generateMamiReply(input: string, state: AppState): string {
  const text = input.trim();
  const lower = text.toLowerCase();

  // 緊急ワードはまず最初にケア
  if (
    /死にたい|消えたい|自殺|自分を傷つけ|手をかけ|もう無理/.test(text)
  ) {
    return (
      'お話してくれてありがとう。今あなたがとても辛い場所にいることが伝わってきます。\n' +
      '一人で抱え込まずに、すぐに専門の方とつながってほしいです。\n\n' +
      '📞 よりそいホットライン: 0120-279-338 (24時間)\n' +
      '📞 いのちの電話: 0570-783-556\n' +
      '⛑️ 緊急時は119へ。\n\n' +
      'あなたは大切な存在です。赤ちゃんと同じくらい、あなた自身も守られていい。'
    );
  }

  // 育児ステータスの返答
  const feed = sumFeedingLast24h(state.logs);
  const sleepMs = sumSleepLast24h(state.logs);
  const sleepH = (sleepMs / 3600000).toFixed(1);
  const next = predictNextFeeding(state.logs);
  const score = mamaWellnessScore(state.mamaChecks, state.logs);
  const ageDays = daysSince(state.baby.birthday);

  if (/授乳|ミルク|おっぱい|母乳/.test(text)) {
    let r = `${state.baby.name}ちゃんの直近24時間の授乳は ${feed.count}回 ／ 合計約${feed.ml}ml ／ ${feed.min}分 です。`;
    if (next) {
      const d = new Date(next.at);
      r += `\n過去の間隔から、次は約 ${d.getHours()}:${d.getMinutes().toString().padStart(2, '0')} 頃が目安かも（間隔の平均は${next.intervalMin}分）。`;
    }
    r += '\n母乳の出には水分補給と休息が一番。授乳中の鋭い痛みは乳腺炎のサインかもしれないので無理しないで。';
    return r;
  }

  if (/睡眠|寝ない|夜泣き|寝かしつけ/.test(text)) {
    return (
      `${state.baby.name}ちゃんの直近24時間の合計睡眠は約 ${sleepH}時間。月齢的には${ageDays < 60 ? '14〜17' : ageDays < 120 ? '13〜15' : '12〜14'}時間が目安です。\n` +
      '・寝かしつけは「お風呂→授乳→暗い部屋」のルーティンが効きます。\n' +
      '・ホワイトノイズ、おくるみ（モロー反射対策）、室温24〜26℃を意識して。\n' +
      'ママも仮眠を取れそうな隙には少しでも横になってね。'
    );
  }

  if (/おむつ|うんち|便/.test(text)) {
    return (
      'おむつのチェックポイント：\n' +
      '・回数: 新生児は1日6回以上、月齢が上がると5〜6回が目安。\n' +
      '・色: 黄色〜茶色がOK。白っぽい便、黒い便、血便はすぐ受診。\n' +
      '・皮膚: 赤み・ぶつぶつがあれば、ぬるま湯で優しく流してワセリンを。'
    );
  }

  if (/疲れ|しんどい|つらい|休めない|眠い|不安/.test(text)) {
    return (
      `話してくれてありがとう。今のあなたのウェルネススコアは${score}/100。\n` +
      '産後はホルモンが急激に変化して、心身ともに大きな揺らぎがあって当然です。\n' +
      '・「3時間だけは自分のための時間」を意識して、パートナーや家族に頼ってみて。\n' +
      '・産後ケア事業（自治体）・産後ドゥーラ・訪問助産師の活用も検討を。\n' +
      'よかったら『ママのケア』タブから簡易メンタルチェックもしてみよう。'
    );
  }

  if (/離乳食/.test(text)) {
    if (ageDays < 150) {
      return '離乳食は5〜6ヶ月頃からが目安。今はまだ準備期間。スプーンに慣らすところから始めましょう。';
    }
    return (
      '離乳食初期(5〜6ヶ月): 10倍がゆ小さじ1から。\n' +
      'アレルギー食材は1日1種、午前中に。\n' +
      'はちみつは1歳まで絶対NG。'
    );
  }

  if (/熱|発熱|風邪/.test(text)) {
    return (
      '🚨 3ヶ月未満で38℃以上は即受診。\n' +
      'それ以上の月齢でも以下があれば受診:\n' +
      '・水分を取れない／ぐったり／呼吸が早い・苦しそう\n' +
      '・けいれん／3日以上発熱\n' +
      'まずは服装を1枚減らし、水分補給を。'
    );
  }

  if (/泣き|泣いて|ぐずり/.test(text)) {
    return (
      '泣き声には5つの代表パターンがあります：①空腹 ②眠い ③おむつ ④暑さ寒さ ⑤抱っこ。\n' +
      '『未来ケア』タブの「泣き声AI解析」で推定もできるよ。\n' +
      'どうしても泣き止まないときは、5分だけ離れて深呼吸してOK。ママの心拍が落ち着くと赤ちゃんも落ち着きます。'
    );
  }

  if (/(こんにちは|はじめ|やあ|hello|hi)/i.test(text)) {
    return `こんにちは、${state.mama.name}さん🌸 ${state.baby.name}ちゃんは生後${ageDays}日ですね。今日はどんな日でしたか？`;
  }

  if (/ありがとう|助かった/.test(text)) {
    return 'こちらこそ、話してくれてありがとう。あなたが頑張っているの、ちゃんと見ています☺️';
  }

  // デフォルト：寄り添い応答
  return (
    'なるほど、もう少し詳しく教えてもらえる？\n' +
    `参考までに、${state.baby.name}ちゃんは生後${ageDays}日、ウェルネススコアは${score}/100です。\n` +
    'キーワード例: 「授乳」「睡眠」「おむつ」「離乳食」「泣き止まない」「疲れた」など、自由に話してね。'
  );
}

// 提案カード（ダッシュボード用のAI提案）
export function generateSuggestion(state: AppState): { title: string; body: string; tone: 'gentle' | 'alert' | 'praise' } {
  const score = mamaWellnessScore(state.mamaChecks, state.logs);
  const sleepH = sumSleepLast24h(state.logs) / 3600000;
  const feed = sumFeedingLast24h(state.logs);
  const next = predictNextFeeding(state.logs);
  const ageDays = daysSince(state.baby.birthday);

  if (score < 45) {
    return {
      title: '今日は無理しないで',
      body: `ウェルネススコアが${score}と低めです。家事はおやすみ、SOSを家族や産後ケア事業に出していい日。`,
      tone: 'alert',
    };
  }
  if (sleepH < 4 && ageDays < 90) {
    return {
      title: 'ママの睡眠が足りていません',
      body: '次の授乳までの隙間に20分でも目を閉じて。パートナーに1回ミルク担当を頼んでみよう。',
      tone: 'alert',
    };
  }
  if (feed.count >= 8 && feed.ml > 600) {
    return {
      title: 'よく頑張っています',
      body: `${state.baby.name}ちゃんはしっかり飲めていますね。ママの水分補給も忘れずに（1日2L目安）。`,
      tone: 'praise',
    };
  }
  if (next) {
    const m = new Date(next.at);
    return {
      title: '次の授乳予測',
      body: `平均間隔から ${m.getHours()}:${m.getMinutes().toString().padStart(2, '0')} 頃が目安。早めに水分とお手洗いを済ませて。`,
      tone: 'gentle',
    };
  }
  return {
    title: '今日もおつかれさま',
    body: '小さなことでも記録し続けるあなたは素晴らしい。ひとつ深呼吸を🌸',
    tone: 'gentle',
  };
}
