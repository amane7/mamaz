/**
 * MAMOA 音声カルテ（試作）— Google ドライブへの保存と、アプリの配信
 *
 * 使い方
 *  1. 保存先フォルダに「MAMOA_音声カルテ試作.html」を置く（同じ名前が複数あれば、いちばん新しいものを使います）。
 *  2. このスクリプトを「デプロイ → 新しいデプロイ → 種類：ウェブアプリ」で公開する。
 *       実行するユーザー：自分 ／ アクセスできるユーザー：全員
 *  3. 表示された URL（…/exec）を、各端末のブラウザで開く。  例）…/exec?room=A室&staff=南田
 *
 * 保存されるもの（1回のケアごとに1フォルダ）
 *   <セッション番号>/<セッション番号>_音声.m4a          … 録音（終了時に1本にまとめる）
 *   <セッション番号>/<セッション番号>_文字起こし.txt など … 文字起こし・初稿・問い・ログ
 *   <セッション番号>/parts/                              … 録音中に届いた小分けの音声（まとめの元。消さずに残します）
 */
var FOLDER_ID = '1YhW18xMmL_Wk-FpG-xG0c-YlRogzIwcc';   // 保存先：202611_実証
var APP_FILE = 'MAMOA_音声カルテ試作.html';
var MAX_MERGE = 45 * 1024 * 1024;                        // これより大きい音声は、まとめずに parts のまま残す

function doGet() {
  var f = appFile_();
  if (!f) {
    return HtmlService.createHtmlOutput('<p style="font:16px/1.8 sans-serif;padding:24px">保存先フォルダに「' + APP_FILE + '」が見つかりません。フォルダに置いてから、もう一度開いてください。</p>')
      .setTitle('MAMOA 音声カルテ').addMetaTag('viewport', 'width=device-width, initial-scale=1');
  }
  return HtmlService.createHtmlOutput(f.getBlob().getDataAsString('UTF-8'))
    .setTitle('MAMOA 音声カルテ')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1, viewport-fit=cover');
}

/** ほかの場所（https）に置いたアプリから呼ぶときの入口。本文は JSON。 */
function doPost(e) {
  var p = null;
  try { p = JSON.parse(e.postData.contents); } catch (err) { p = null; }
  return ContentService.createTextOutput(JSON.stringify(p ? api(p) : { ok: false, error: 'bad request' })).setMimeType(ContentService.MimeType.JSON);
}

/** アプリからの呼び出し口（google.script.run.api / doPost） */
function api(p) {
  try {
    p = p || {};
    if (p.a === 'ping') return ping_(p);
    p.sid = clean_(p.sid);
    if (p.sid.length < 6) return { ok: false, error: 'bad sid' };
    if (p.a === 'chunk') return chunk_(p);
    if (p.a === 'file') return file_(p);
    if (p.a === 'finish') return finish_(p);
    if (p.a === 'discard') return discard_(p);
    return { ok: false, error: 'unknown action' };
  } catch (err) {
    return { ok: false, error: String((err && err.message) || err) };
  }
}

/* ---- 保存 ---- */
function root_() { return DriveApp.getFolderById(FOLDER_ID); }
function clean_(s) { return String(s === null || s === undefined ? '' : s).replace(/[\\\/:*?"<>|\u0000-\u001f]/g, '_').replace(/^\.+/, '').slice(0, 120); }
function ext_(s) { s = String(s || '').toLowerCase().replace(/[^a-z0-9]/g, ''); return s || 'bin'; }
function pad_(n) { n = String(n); while (n.length < 4) n = '0' + n; return n; }
function ensure_(parent, name) {
  var it = parent.getFoldersByName(name);
  if (it.hasNext()) return it.next();
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    it = parent.getFoldersByName(name);
    return it.hasNext() ? it.next() : parent.createFolder(name);
  } finally { lock.releaseLock(); }
}
function partName_(sid, seg, seq, ext) { return sid + '_音声' + (seg > 1 ? '-' + seg : '') + '_part' + pad_(seq) + '.' + ext_(ext); }
function audioName_(sid, seg, ext) { return sid + '_音声' + (seg > 1 ? '-' + seg : '') + '.' + ext_(ext); }

function ping_(p) {
  var root = root_(), out = { ok: true, folder: root.getName(), time: new Date().toISOString(), app: !!appFile_() };
  if (p.write) {
    var name = '接続テスト_' + (clean_(p.room) || '端末') + '.txt', it = root.getFilesByName(name), text = '接続テスト ' + Utilities.formatDate(new Date(), 'Asia/Tokyo', 'yyyy-MM-dd HH:mm:ss') + '（このファイルは消してかまいません）';
    if (it.hasNext()) it.next().setContent(text); else root.createFile(name, text, 'text/plain');
    out.wrote = name;
  }
  return out;
}
function appFile_() {
  var it = root_().getFilesByName(APP_FILE), best = null, f;
  while (it.hasNext()) { f = it.next(); if (!best || f.getLastUpdated().getTime() > best.getLastUpdated().getTime()) best = f; }
  return best;
}

/** 録音中に届く小分けの音声。同じ番号が二度届いても、二重には作らない。 */
function chunk_(p) {
  var seg = Number(p.seg) || 1, seq = Number(p.seq) || 0;
  if (seq < 1 || !p.b64) return { ok: false, error: 'bad chunk' };
  var parts = ensure_(ensure_(root_(), p.sid), 'parts'), name = partName_(p.sid, seg, seq, p.ext);
  var it = parts.getFilesByName(name);
  if (it.hasNext()) return { ok: true, name: name, dup: true, size: it.next().getSize() };
  var bytes = Utilities.base64Decode(p.b64);
  parts.createFile(Utilities.newBlob(bytes, p.mime || 'application/octet-stream', name));
  return { ok: true, name: name, size: bytes.length };
}

/** 文字起こし・初稿・問い・ログ。同じ名前があれば、中身を入れ替える。 */
function file_(p) {
  var folder = ensure_(root_(), p.sid), name = clean_(p.name), text = String(p.text === null || p.text === undefined ? '' : p.text);
  if (!name) return { ok: false, error: 'no name' };
  var it = folder.getFilesByName(name);
  if (it.hasNext()) {
    var old = it.next();
    try { old.setContent(text); return { ok: true, name: name, updated: true }; } catch (err) { old.setTrashed(true); }
  }
  folder.createFile(name, text, p.mime || 'text/plain');
  return { ok: true, name: name };
}

/** 終了：小分けの音声を、区間ごとに1本にまとめる。まとめられないときは parts のまま残す（音声は失わない）。 */
function finish_(p) {
  var folder = ensure_(root_(), p.sid), segs = p.segs || [], out = [], i;
  for (i = 0; i < segs.length; i++) {
    try { out.push(merge_(folder, p.sid, segs[i])); }
    catch (err) { out.push({ name: audioName_(p.sid, Number(segs[i].seg) || 1, segs[i].ext), merged: false, reason: String((err && err.message) || err) }); }
  }
  // まとめられなかった音声があれば、つなぎ方をフォルダに書いておく（音声そのものは parts にそろっています）
  if (out.some(function (a) { return !a.merged && a.reason !== 'empty'; })) {
    var note = p.sid + '_音声は小分けのままです.txt';
    if (!folder.getFilesByName(note).hasNext()) folder.createFile(note, [
      'このケアの音声は、1本にまとめられませんでした（' + out.filter(function (a) { return !a.merged; }).map(function (a) { return a.reason; }).join('、') + '）。',
      '音声は parts フォルダに、番号順の小分けのファイルとしてそろっています。番号順につなぐと、1本の音声になります。',
      '',
      'つなぎ方（parts フォルダをパソコンに取り出してから）',
      '  Windows：  copy /b *_part*.* 音声.m4a',
      '  Mac：      cat *_part* > 音声.m4a',
      '（webm のときは、拡張子を webm にしてください。区間が複数あるときは、「音声-2」などの区間ごとにつないでください）'
    ].join('\n'), 'text/plain');
  }
  return { ok: true, audio: out, folder: folder.getName(), url: folder.getUrl() };
}
function merge_(folder, sid, seg) {
  var n = Number(seg.seg) || 1, count = Number(seg.parts) || 0, name = audioName_(sid, n, seg.ext), i, j, it, f, files = [], total = 0, missing = [];
  var done = folder.getFilesByName(name);
  if (done.hasNext()) return { name: name, merged: true, dup: true, size: done.next().getSize() };
  if (!count) return { name: name, merged: false, reason: 'empty' };
  var pit = folder.getFoldersByName('parts');
  if (!pit.hasNext()) return { name: name, merged: false, reason: 'no parts' };
  var parts = pit.next();
  for (i = 1; i <= count; i++) {
    it = parts.getFilesByName(partName_(sid, n, i, seg.ext));
    if (!it.hasNext()) { missing.push(i); continue; }
    f = it.next(); files.push(f); total += f.getSize();
  }
  if (missing.length) return { name: name, merged: false, reason: 'missing', missing: missing };
  if (total > MAX_MERGE) return { name: name, merged: false, reason: 'too large', size: total, parts: files.length };
  var all = [], b;
  for (i = 0; i < files.length; i++) { b = files[i].getBlob().getBytes(); for (j = 0; j < b.length; j++) all.push(b[j]); }
  var made = folder.createFile(Utilities.newBlob(all, seg.mime || 'application/octet-stream', name));
  if (made.getSize() !== total) { made.setTrashed(true); return { name: name, merged: false, reason: 'size mismatch', size: total }; }
  return { name: name, merged: true, size: total, parts: files.length };
}

/** 途中でやめて消すとき：そのケアのフォルダを、ごみ箱に入れる。 */
function discard_(p) {
  var it = root_().getFoldersByName(p.sid), n = 0;
  while (it.hasNext()) { it.next().setTrashed(true); n++; }
  return { ok: true, trashed: n };
}

/** エディタから一度実行すると、保存先に書けるかを確かめられます（初回は、ここでアクセスの承認を求められます）。 */
function checkSetup() {
  var r = ping_({ write: true, room: 'セットアップ' });
  Logger.log(JSON.stringify(r));
  return r;
}
