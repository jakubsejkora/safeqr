export const bioPage = `<!doctype html>
<html lang="cs">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="robots" content="noindex,nofollow">
  <title>Klára ✨ · Tréninková ukázka Safe QR</title>
  <link rel="stylesheet" href="/bio.css">
</head>
<body>
  <main>
    <p class="training-label">Smyšlený profil · Cvičení</p>
    <div class="avatar" aria-hidden="true"></div>
    <h1>Klára ✨</h1>
    <p class="bio">Trocha zvědavosti, trochu města.<br>Moje odkazy najdeš tady ↓</p>
    <nav aria-label="Odkazy profilu">
      <a href="https://onlyfans.com/klara-training" rel="nofollow noopener" target="_blank"><span>Placený obsah pro dospělé · 18+</span><small>OnlyFans</small></a>
      <a href="https://t.me/klara_training" rel="nofollow noopener" target="_blank"><span>Napiš mi na Telegram</span><small>Telegram · kontakt</small></a>
      <a href="https://bit.ly/klara-vip" rel="nofollow noopener" target="_blank"><span>Moje VIP odkazy</span><small>bit.ly · zkrácený odkaz</small></a>
      <a href="https://linktr.ee/klara-training" rel="nofollow noopener" target="_blank"><span>Vše na jednom místě</span><small>Linktree</small></a>
      <a href="https://instagram.com/klara.training" rel="nofollow noopener" target="_blank"><span>Můj Instagram</span><small>@klara.training</small></a>
    </nav>
  </main>
  <footer><strong>Tréninková ukázka Safe QR</strong><p>Klára je smyšlená postava, ne skutečná osoba.<br>Odkazy jsou cvičné. Neotevírejte je.</p></footer>
</body>
</html>`;

export const bioStyle = `
:root{color-scheme:light;font:17px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:#f6f0ed;color:#372c35}
*{box-sizing:border-box}
body{margin:0}
main,footer{width:min(440px,calc(100% - 40px));margin-inline:auto;text-align:center}
main{padding-top:32px}
.training-label{margin:0 0 24px;font-size:11px;font-weight:700;letter-spacing:.14em;text-transform:uppercase;color:#6b5261}
.avatar{width:104px;height:104px;margin:auto;border-radius:50%;background:radial-gradient(circle at 26% 24%,#f8ddb2,transparent 58%),linear-gradient(135deg,#e7a89c,#bba6d4 65%,#809d9a);border:4px solid #fff;box-shadow:0 8px 24px #6e455518}
h1{font-size:34px;line-height:1.2;letter-spacing:-1px;margin:20px 0 12px}
.bio{margin:0;color:#6b5261}
nav{display:grid;gap:12px;margin-top:28px}
a{display:flex;flex-direction:column;align-items:center;justify-content:center;min-height:76px;padding:13px 20px;border:1px solid #dfd2d9;border-radius:18px;background:#fffaf8;color:inherit;text-decoration:none;box-shadow:0 3px 0 #dfd2d960}
a span{font-weight:650}
a small{font-size:12px;color:#6b5261}
a:hover{background:#f0e6ed}
a:focus-visible{outline:3px solid #82415e;outline-offset:4px}
footer{padding:30px 0;font-size:12px;color:#6b5261}
footer strong{font-size:13px;color:#372c35}
footer p{margin:8px 0 0}
`;
