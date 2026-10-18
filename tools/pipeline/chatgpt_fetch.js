// Paste into the ChatGPT tab (javascript tool) to pull generated images out of a chat.
// Why: the chat page drops images from the DOM when they scroll away, so read them
// from ChatGPT's own backend instead. Uses the user's existing sign-in; no passwords.
// Rewritten from the working session notes — test on one image first.
//
//   await __init()                      -> token
//   await __refresh()                   -> window.__assets = [[create_time, "sediment://file_..", w, h], ...] oldest first
//   await __fetchAsset(__assets[i][1], ID, 0.92)  -> [ID, w, h, base64Length, chunkCount]
//   __chunk(ID, n, 240000)              -> "I<ID>C<n>:<base64 slice>"  (call once per chunk; tool results
//                                          over ~250K chars are rejected, so keep chunks at 240000)
// Then on the Linux side: python3 assemble2.py OUTDIR <since_ms> rebuilds img<ID>.png from the saved tool results.

window.__init = async () => {
  window.__tok = (await fetch('/api/auth/session').then(r => r.json())).accessToken;
  window.__blobs = window.__blobs || {};
  return !!window.__tok;
};

window.__refresh = async () => {
  if (!window.__tok) await window.__init();
  const cid = location.pathname.split('/c/')[1];
  const c = await fetch('/backend-api/conversation/' + cid, { headers: { Authorization: 'Bearer ' + window.__tok } }).then(r => r.json());
  const out = [];
  for (const n of Object.values(c.mapping)) {
    const m = n.message; if (!m || !m.content || !m.content.parts) continue;
    for (const p of m.content.parts) {
      if (p && typeof p === 'object' && p.asset_pointer) out.push([m.create_time || 0, p.asset_pointer, p.width, p.height]);
    }
  }
  out.sort((a, b) => a[0] - b[0]);
  window.__assets = out;
  return out.length;
};

// image url -> JPEG base64 kept in window.__blobs[id]
window.__prep = (src, id, q) => new Promise((res, rej) => {
  const im = new Image();
  im.onload = () => {
    const cv = document.createElement('canvas'); cv.width = im.naturalWidth; cv.height = im.naturalHeight;
    cv.getContext('2d').drawImage(im, 0, 0);
    const b64 = cv.toDataURL('image/jpeg', q || 0.92).split(',')[1];
    window.__blobs[id] = b64;
    res([id, cv.width, cv.height, b64.length, Math.ceil(b64.length / 240000)]);
  };
  im.onerror = rej; im.src = src;
});

window.__fetchAsset = async (ptr, id, q) => {
  if (!window.__tok) await window.__init();
  const fid = ptr.split('://')[1];
  const cid = location.pathname.split('/c/')[1];
  const j = await fetch('/backend-api/files/download/' + fid + '?conversation_id=' + cid + '&inline=false',
    { headers: { Authorization: 'Bearer ' + window.__tok } }).then(r => r.json());
  const b = await fetch(j.download_url).then(r => r.blob());
  return await window.__prep(URL.createObjectURL(b), id, q);
};

window.__chunk = (id, n, size) => 'I' + id + 'C' + n + ':' + window.__blobs[id].slice(n * size, (n + 1) * size);
