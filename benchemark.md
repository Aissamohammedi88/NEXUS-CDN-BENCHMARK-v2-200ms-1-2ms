
═══[ TRACE — le datacenter Cloudflare qui répond VRAIMENT à ta machine ]═══
  ✓ trafic sortant : 72.136.108.197 · PoP Cloudflare = YYZ (Toronto)
  pays réseau: CA · ce datacenter PHYSIQUE a répondu à tes sondes

── 10 sondes × 14 endpoints · 11 réseaux CDN majeurs · réseau réel ──
[bench 1/14] 
═══[ cdnjs — Cloudflare ]═════════════════════════════════════════════════════
  GET https://cdnjs.cloudflare.com/ajax/libs/jquery/3.7.1/jquery.min.js
  PoP réel : YYZ (Toronto)
  serveur: cloudflare · cf-cache-status: HIT · age: 2296093
  FROID — 10 sondes, nouvelle connexion complète à chaque sonde
bash: printf: 1.2: nombre non valable
bash: printf: 1.5: nombre non valable
bash: printf: 1.5: nombre non valable
bash: printf: 2.4: nombre non valable
bash: printf: 2.4: nombre non valable
      DNS     min     1,0  avg     1,0  p50     1,0  p95     2,0  max     2,0  ms
bash: printf: 35.1: nombre non valable
bash: printf: 35.1: nombre non valable
bash: printf: 29.8: nombre non valable
bash: printf: 28.8: nombre non valable
bash: printf: 28.8: nombre non valable
      TCP     min    35,0  avg    35,0  p50    29,0  p95    28,0  max    28,0  ms
bash: printf: 92.9: nombre non valable
bash: printf: 96.2: nombre non valable
bash: printf: 89.0: nombre non valable
bash: printf: 93.4: nombre non valable
bash: printf: 93.4: nombre non valable
      TLS     min    92,0  avg    96,0  p50    89,0  p95    93,0  max    93,0  ms
bash: printf: 146.4: nombre non valable
bash: printf: 149.4: nombre non valable
bash: printf: 157.6: nombre non valable
bash: printf: 148.3: nombre non valable
bash: printf: 148.3: nombre non valable
      TTFB    min   146,0  avg   149,0  p50   157,0  p95   148,0  max   148,0  ms
bash: printf: 185.2: nombre non valable
bash: printf: 199.8: nombre non valable
bash: printf: 223.1: nombre non valable
bash: printf: 204.1: nombre non valable
bash: printf: 204.1: nombre non valable
      TOTAL   min   185,0  avg   199,0  p50   223,0  p95   204,0  max   204,0  ms
      code HTTP 200 · 0 sondes échouées · taille: 87533 octets
  CHAUD — 10 requêtes sur UNE seule connexion (keep-alive)
bash: printf: 64.7: nombre non valable
bash: printf: 64.6: nombre non valable
bash: printf: 47.7: nombre non valable
bash: printf: 166.3: nombre non valable
bash: printf: 166.3: nombre non valable
      TTFB    min    64,0  avg    64,0  p50    47,0  p95   166,0  max   166,0  ms
bash: printf: 105.9: nombre non valable
bash: printf: 91.1: nombre non valable
bash: printf: 105.9: nombre non valable
bash: printf: 213.4: nombre non valable
bash: printf: 213.4: nombre non valable
      TOTAL   min   105,0  avg    91,0  p50   105,0  p95   213,0  max   213,0  ms
[bench 2/14] 
═══[ jsDelivr — Cloudflare+Fastly ]═════════════════════════════════════════════════════
  GET https://cdn.jsdelivr.net/npm/jquery@3.7.1/dist/jquery.min.js
  PoP réel : YYZ (Toronto)
  x-cache: HIT, HIT · age: 35071
  FROID — 10 sondes, nouvelle connexion complète à chaque sonde
bash: printf: 1.4: nombre non valable
bash: printf: 2.0: nombre non valable
bash: printf: 1.7: nombre non valable
bash: printf: 4.9: nombre non valable
bash: printf: 4.9: nombre non valable
      DNS     min     1,0  avg     2,0  p50     1,0  p95     4,0  max     4,0  ms
bash: printf: 41.4: nombre non valable
bash: printf: 41.1: nombre non valable
bash: printf: 51.8: nombre non valable
bash: printf: 43.5: nombre non valable
bash: printf: 43.5: nombre non valable
      TCP     min    41,0  avg    41,0  p50    51,0  p95    43,0  max    43,0  ms
bash: printf: 101.9: nombre non valable
bash: printf: 106.2: nombre non valable
bash: printf: 118.9: nombre non valable
bash: printf: 110.1: nombre non valable
bash: printf: 110.1: nombre non valable
      TLS     min   101,0  avg   106,0  p50   118,0  p95   110,0  max   110,0  ms
bash: printf: 143.6: nombre non valable
bash: printf: 151.1: nombre non valable
bash: printf: 156.7: nombre non valable
bash: printf: 155.0: nombre non valable
bash: printf: 155.0: nombre non valable
      TTFB    min   143,0  avg   151,0  p50   156,0  p95   155,0  max   155,0  ms
bash: printf: 218.6: nombre non valable
bash: printf: 214.4: nombre non valable
bash: printf: 213.4: nombre non valable
bash: printf: 216.5: nombre non valable
bash: printf: 216.5: nombre non valable
      TOTAL   min   218,0  avg   214,0  p50   213,0  p95   216,0  max   216,0  ms
      code HTTP 200 · 0 sondes échouées · taille: 87533 octets
  CHAUD — 10 requêtes sur UNE seule connexion (keep-alive)
bash: printf: 64.1: nombre non valable
bash: printf: 65.4: nombre non valable
bash: printf: 47.1: nombre non valable
bash: printf: 184.6: nombre non valable
bash: printf: 184.6: nombre non valable
      TTFB    min    64,0  avg    65,0  p50    47,0  p95   184,0  max   184,0  ms
bash: printf: 93.9: nombre non valable
bash: printf: 91.2: nombre non valable
bash: printf: 68.9: nombre non valable
bash: printf: 255.4: nombre non valable
bash: printf: 255.4: nombre non valable
      TOTAL   min    93,0  avg    91,0  p50    68,0  p95   255,0  max   255,0  ms
[bench 3/14] 
═══[ Fastly-jsDelivr — Fastly ]═════════════════════════════════════════════════════
  GET https://fastly.jsdelivr.net/npm/jquery@3.7.1/dist/jquery.min.js
  PoP réel : YYZ (Toronto)
  x-cache: HIT, MISS · age: 35059
  FROID — 10 sondes, nouvelle connexion complète à chaque sonde
bash: printf: 1.4: nombre non valable
bash: printf: 1.5: nombre non valable
bash: printf: 1.5: nombre non valable
bash: printf: 1.7: nombre non valable
bash: printf: 1.7: nombre non valable
      DNS     min     1,0  avg     1,0  p50     1,0  p95     1,0  max     1,0  ms
bash: printf: 40.4: nombre non valable
bash: printf: 38.0: nombre non valable
bash: printf: 29.4: nombre non valable
bash: printf: 41.5: nombre non valable
bash: printf: 41.5: nombre non valable
      TCP     min    40,0  avg    38,0  p50    29,0  p95    41,0  max    41,0  ms
bash: printf: 106.4: nombre non valable
bash: printf: 102.5: nombre non valable
bash: printf: 84.8: nombre non valable
bash: printf: 104.4: nombre non valable
bash: printf: 104.4: nombre non valable
      TLS     min   106,0  avg   102,0  p50    84,0  p95   104,0  max   104,0  ms
bash: printf: 160.1: nombre non valable
bash: printf: 164.2: nombre non valable
bash: printf: 122.5: nombre non valable
bash: printf: 154.9: nombre non valable
bash: printf: 154.9: nombre non valable
      TTFB    min   160,0  avg   164,0  p50   122,0  p95   154,0  max   154,0  ms
bash: printf: 259.9: nombre non valable
bash: printf: 238.6: nombre non valable
bash: printf: 169.5: nombre non valable
bash: printf: 247.0: nombre non valable
bash: printf: 247.0: nombre non valable
      TOTAL   min   259,0  avg   238,0  p50   169,0  p95   247,0  max   247,0  ms
      code HTTP 200 · 0 sondes échouées · taille: 87533 octets
  CHAUD — 10 requêtes sur UNE seule connexion (keep-alive)
bash: printf: 72.2: nombre non valable
bash: printf: 62.8: nombre non valable
bash: printf: 47.6: nombre non valable
bash: printf: 145.4: nombre non valable
bash: printf: 145.4: nombre non valable
      TTFB    min    72,0  avg    62,0  p50    47,0  p95   145,0  max   145,0  ms
bash: printf: 97.9: nombre non valable
bash: printf: 87.2: nombre non valable
bash: printf: 63.3: nombre non valable
bash: printf: 227.3: nombre non valable
bash: printf: 227.3: nombre non valable
      TOTAL   min    97,0  avg    87,0  p50    63,0  p95   227,0  max   227,0  ms
[bench 4/14] 
═══[ Google-CDN — Google ]═════════════════════════════════════════════════════
  GET https://ajax.googleapis.com/ajax/libs/jquery/3.7.1/jquery.min.js
  PoP : non exposé par ce réseau
  serveur: sffe · age: 323897
  FROID — 10 sondes, nouvelle connexion complète à chaque sonde
bash: printf: 1.1: nombre non valable
bash: printf: 1.4: nombre non valable
bash: printf: 1.3: nombre non valable
bash: printf: 1.9: nombre non valable
bash: printf: 1.9: nombre non valable
      DNS     min     1,0  avg     1,0  p50     1,0  p95     1,0  max     1,0  ms
bash: printf: 29.9: nombre non valable
bash: printf: 32.1: nombre non valable
bash: printf: 30.9: nombre non valable
bash: printf: 32.9: nombre non valable
bash: printf: 32.9: nombre non valable
      TCP     min    29,0  avg    32,0  p50    30,0  p95    32,0  max    32,0  ms
bash: printf: 100.2: nombre non valable
bash: printf: 105.8: nombre non valable
bash: printf: 100.0: nombre non valable
bash: printf: 104.5: nombre non valable
bash: printf: 104.5: nombre non valable
      TLS     min   100,0  avg   105,0  p50   100,0  p95   104,0  max   104,0  ms
bash: printf: 137.7: nombre non valable
bash: printf: 145.9: nombre non valable
bash: printf: 138.7: nombre non valable
bash: printf: 142.7: nombre non valable
bash: printf: 142.7: nombre non valable
      TTFB    min   137,0  avg   145,0  p50   138,0  p95   142,0  max   142,0  ms
bash: printf: 207.8: nombre non valable
bash: printf: 225.8: nombre non valable
bash: printf: 198.2: nombre non valable
bash: printf: 231.3: nombre non valable
bash: printf: 231.3: nombre non valable
      TOTAL   min   207,0  avg   225,0  p50   198,0  p95   231,0  max   231,0  ms
      code HTTP 200 · 0 sondes échouées · taille: 87533 octets
  CHAUD — 10 requêtes sur UNE seule connexion (keep-alive)
bash: printf: 35.9: nombre non valable
bash: printf: 55.1: nombre non valable
bash: printf: 39.5: nombre non valable
bash: printf: 166.0: nombre non valable
bash: printf: 166.0: nombre non valable
      TTFB    min    35,0  avg    55,0  p50    39,0  p95   166,0  max   166,0  ms
bash: printf: 55.1: nombre non valable
bash: printf: 78.2: nombre non valable
bash: printf: 61.4: nombre non valable
bash: printf: 233.9: nombre non valable
bash: printf: 233.9: nombre non valable
      TOTAL   min    55,0  avg    78,0  p50    61,0  p95   233,0  max   233,0  ms
[bench 5/14] 
═══[ Google-Fonts — Google ]═════════════════════════════════════════════════════
  GET https://fonts.googleapis.com/css2?family=Roboto&display=swap
  PoP : non exposé par ce réseau
  serveur: ESF
  FROID — 10 sondes, nouvelle connexion complète à chaque sonde
bash: printf: 1.1: nombre non valable
bash: printf: 1.5: nombre non valable
bash: printf: 1.2: nombre non valable
bash: printf: 3.5: nombre non valable
bash: printf: 3.5: nombre non valable
      DNS     min     1,0  avg     1,0  p50     1,0  p95     3,0  max     3,0  ms
bash: printf: 28.6: nombre non valable
bash: printf: 31.4: nombre non valable
bash: printf: 26.0: nombre non valable
bash: printf: 29.0: nombre non valable
bash: printf: 29.0: nombre non valable
      TCP     min    28,0  avg    31,0  p50    26,0  p95    29,0  max    29,0  ms
bash: printf: 96.6: nombre non valable
bash: printf: 105.0: nombre non valable
bash: printf: 94.9: nombre non valable
bash: printf: 101.5: nombre non valable
bash: printf: 101.5: nombre non valable
      TLS     min    96,0  avg   105,0  p50    94,0  p95   101,0  max   101,0  ms
bash: printf: 163.3: nombre non valable
bash: printf: 173.1: nombre non valable
bash: printf: 160.3: nombre non valable
bash: printf: 169.2: nombre non valable
bash: printf: 169.2: nombre non valable
      TTFB    min   163,0  avg   173,0  p50   160,0  p95   169,0  max   169,0  ms
bash: printf: 163.6: nombre non valable
bash: printf: 173.9: nombre non valable
bash: printf: 160.4: nombre non valable
bash: printf: 169.4: nombre non valable
bash: printf: 169.4: nombre non valable
      TOTAL   min   163,0  avg   173,0  p50   160,0  p95   169,0  max   169,0  ms
      code HTTP 200 · 0 sondes échouées · taille: 256 octets
  CHAUD — 10 requêtes sur UNE seule connexion (keep-alive)
bash: printf: 62.7: nombre non valable
bash: printf: 78.7: nombre non valable
bash: printf: 66.9: nombre non valable
bash: printf: 179.3: nombre non valable
bash: printf: 179.3: nombre non valable
      TTFB    min    62,0  avg    78,0  p50    66,0  p95   179,0  max   179,0  ms
bash: printf: 62.8: nombre non valable
bash: printf: 79.2: nombre non valable
bash: printf: 67.0: nombre non valable
bash: printf: 179.7: nombre non valable
bash: printf: 179.7: nombre non valable
      TOTAL   min    62,0  avg    79,0  p50    67,0  p95   179,0  max   179,0  ms
[bench 6/14] 
═══[ Azure-CDN — Microsoft ]═════════════════════════════════════════════════════
  GET https://ajax.aspnetcdn.com/ajax/jquery/jquery-3.7.1.min.js
  PoP : non exposé par ce réseau
  FROID — 10 sondes, nouvelle connexion complète à chaque sonde
bash: printf: 1.4: nombre non valable
bash: printf: 1.8: nombre non valable
bash: printf: 1.5: nombre non valable
bash: printf: 3.3: nombre non valable
bash: printf: 3.3: nombre non valable
      DNS     min     1,0  avg     1,0  p50     1,0  p95     3,0  max     3,0  ms
bash: printf: 28.2: nombre non valable
bash: printf: 31.6: nombre non valable
bash: printf: 37.5: nombre non valable
bash: printf: 33.6: nombre non valable
bash: printf: 33.6: nombre non valable
      TCP     min    28,0  avg    31,0  p50    37,0  p95    33,0  max    33,0  ms
bash: printf: 99.6: nombre non valable
bash: printf: 106.8: nombre non valable
bash: printf: 115.9: nombre non valable
bash: printf: 106.3: nombre non valable
bash: printf: 106.3: nombre non valable
      TLS     min    99,0  avg   106,0  p50   115,0  p95   106,0  max   106,0  ms
bash: printf: 136.6: nombre non valable
bash: printf: 147.0: nombre non valable
bash: printf: 151.4: nombre non valable
bash: printf: 143.3: nombre non valable
bash: printf: 143.3: nombre non valable
      TTFB    min   136,0  avg   147,0  p50   151,0  p95   143,0  max   143,0  ms
bash: printf: 187.1: nombre non valable
bash: printf: 200.5: nombre non valable
bash: printf: 232.1: nombre non valable
bash: printf: 193.1: nombre non valable
bash: printf: 193.1: nombre non valable
      TOTAL   min   187,0  avg   200,0  p50   232,0  p95   193,0  max   193,0  ms
      code HTTP 200 · 0 sondes échouées · taille: 87533 octets
  CHAUD — 10 requêtes sur UNE seule connexion (keep-alive)
bash: printf: 40.2: nombre non valable
bash: printf: 51.4: nombre non valable
bash: printf: 44.5: nombre non valable
bash: printf: 148.5: nombre non valable
bash: printf: 148.5: nombre non valable
      TTFB    min    40,0  avg    51,0  p50    44,0  p95   148,0  max   148,0  ms
bash: printf: 83.0: nombre non valable
bash: printf: 82.1: nombre non valable
bash: printf: 62.0: nombre non valable
bash: printf: 206.2: nombre non valable
bash: printf: 206.2: nombre non valable
      TOTAL   min    83,0  avg    82,0  p50    62,0  p95   206,0  max   206,0  ms
[bench 7/14] 
═══[ unpkg — Cloudflare ]═════════════════════════════════════════════════════
  GET https://unpkg.com/jquery@3.7.1/dist/jquery.min.js
  PoP réel : YYZ (Toronto)
  serveur: cloudflare · cf-cache-status: HIT · age: 9002291
  FROID — 10 sondes, nouvelle connexion complète à chaque sonde
bash: printf: 1.1: nombre non valable
bash: printf: 1.3: nombre non valable
bash: printf: 1.3: nombre non valable
bash: printf: 1.5: nombre non valable
bash: printf: 1.5: nombre non valable
      DNS     min     1,0  avg     1,0  p50     1,0  p95     1,0  max     1,0  ms
bash: printf: 29.3: nombre non valable
bash: printf: 32.7: nombre non valable
bash: printf: 27.8: nombre non valable
bash: printf: 33.3: nombre non valable
bash: printf: 33.3: nombre non valable
      TCP     min    29,0  avg    32,0  p50    27,0  p95    33,0  max    33,0  ms
bash: printf: 84.2: nombre non valable
bash: printf: 95.6: nombre non valable
bash: printf: 101.1: nombre non valable
bash: printf: 96.6: nombre non valable
bash: printf: 96.6: nombre non valable
      TLS     min    84,0  avg    95,0  p50   101,0  p95    96,0  max    96,0  ms
bash: printf: 134.1: nombre non valable
bash: printf: 148.3: nombre non valable
bash: printf: 150.4: nombre non valable
bash: printf: 145.1: nombre non valable
bash: printf: 145.1: nombre non valable
      TTFB    min   134,0  avg   148,0  p50   150,0  p95   145,0  max   145,0  ms
bash: printf: 180.1: nombre non valable
bash: printf: 199.1: nombre non valable
bash: printf: 199.2: nombre non valable
bash: printf: 194.5: nombre non valable
bash: printf: 194.5: nombre non valable
      TOTAL   min   180,0  avg   199,0  p50   199,0  p95   194,0  max   194,0  ms
      code HTTP 200 · 0 sondes échouées · taille: 87533 octets
  CHAUD — 10 requêtes sur UNE seule connexion (keep-alive)
bash: printf: 44.3: nombre non valable
bash: printf: 61.3: nombre non valable
bash: printf: 58.8: nombre non valable
bash: printf: 145.8: nombre non valable
bash: printf: 145.8: nombre non valable
      TTFB    min    44,0  avg    61,0  p50    58,0  p95   145,0  max   145,0  ms
bash: printf: 77.9: nombre non valable
bash: printf: 82.1: nombre non valable
bash: printf: 80.1: nombre non valable
bash: printf: 194.3: nombre non valable
bash: printf: 194.3: nombre non valable
      TOTAL   min    77,0  avg    82,0  p50    80,0  p95   194,0  max   194,0  ms
[bench 8/14] 
═══[ Vercel — Vercel ]═════════════════════════════════════════════════════
  GET https://nextjs.org/
  PoP réel : YUL1 (PoP YUL)
  serveur: Vercel · x-vercel-cache: HIT · age: 872
  FROID — 10 sondes, nouvelle connexion complète à chaque sonde
bash: printf: 1.0: nombre non valable
bash: printf: 1.2: nombre non valable
bash: printf: 1.2: nombre non valable
bash: printf: 1.6: nombre non valable
bash: printf: 1.6: nombre non valable
      DNS     min     1,0  avg     1,0  p50     1,0  p95     1,0  max     1,0  ms
bash: printf: 32.3: nombre non valable
bash: printf: 38.2: nombre non valable
bash: printf: 34.5: nombre non valable
bash: printf: 41.5: nombre non valable
bash: printf: 41.5: nombre non valable
      TCP     min    32,0  avg    38,0  p50    34,0  p95    41,0  max    41,0  ms
bash: printf: 93.8: nombre non valable
bash: printf: 100.8: nombre non valable
bash: printf: 97.8: nombre non valable
bash: printf: 96.8: nombre non valable
bash: printf: 96.8: nombre non valable
      TLS     min    93,0  avg   100,0  p50    97,0  p95    96,0  max    96,0  ms
bash: printf: 183.1: nombre non valable
bash: printf: 192.7: nombre non valable
bash: printf: 197.0: nombre non valable
bash: printf: 182.3: nombre non valable
bash: printf: 182.3: nombre non valable
      TTFB    min   183,0  avg   192,0  p50   197,0  p95   182,0  max   182,0  ms
bash: printf: 366.9: nombre non valable
bash: printf: 343.7: nombre non valable
bash: printf: 341.0: nombre non valable
bash: printf: 307.0: nombre non valable
bash: printf: 307.0: nombre non valable
      TOTAL   min   366,0  avg   343,0  p50   341,0  p95   307,0  max   307,0  ms
      code HTTP 200 · 0 sondes échouées · taille: 268341 octets
  CHAUD — 10 requêtes sur UNE seule connexion (keep-alive)
bash: printf: 183.8: nombre non valable
bash: printf: 183.8: nombre non valable
bash: printf: 183.8: nombre non valable
bash: printf: 183.8: nombre non valable
bash: printf: 183.8: nombre non valable
      TTFB    min   183,0  avg   183,0  p50   183,0  p95   183,0  max   183,0  ms
bash: printf: 349.2: nombre non valable
bash: printf: 349.2: nombre non valable
bash: printf: 349.2: nombre non valable
bash: printf: 349.2: nombre non valable
bash: printf: 349.2: nombre non valable
      TOTAL   min   349,0  avg   349,0  p50   349,0  p95   349,0  max   349,0  ms
[bench 9/14] 
═══[ CloudFront — Amazon AWS ]═════════════════════════════════════════════════════
  GET https://sdk.amazonaws.com/js/aws-sdk-2.1691.0.min.js
  PoP réel : YTO53 (PoP YTO)
  serveur: AmazonS3 · X-Cache: Miss from cloudfront
  FROID — 10 sondes, nouvelle connexion complète à chaque sonde
bash: printf: 1.3: nombre non valable
bash: printf: 1.5: nombre non valable
bash: printf: 1.4: nombre non valable
bash: printf: 1.8: nombre non valable
bash: printf: 1.8: nombre non valable
      DNS     min     1,0  avg     1,0  p50     1,0  p95     1,0  max     1,0  ms
bash: printf: 32.9: nombre non valable
bash: printf: 32.9: nombre non valable
bash: printf: 28.6: nombre non valable
bash: printf: 33.8: nombre non valable
bash: printf: 33.8: nombre non valable
      TCP     min    32,0  avg    32,0  p50    28,0  p95    33,0  max    33,0  ms
bash: printf: 93.2: nombre non valable
bash: printf: 94.0: nombre non valable
bash: printf: 106.5: nombre non valable
bash: printf: 93.5: nombre non valable
bash: printf: 93.5: nombre non valable
      TLS     min    93,0  avg    94,0  p50   106,0  p95    93,0  max    93,0  ms
bash: printf: 134.7: nombre non valable
bash: printf: 136.3: nombre non valable
bash: printf: 146.7: nombre non valable
bash: printf: 130.0: nombre non valable
bash: printf: 130.0: nombre non valable
      TTFB    min   134,0  avg   136,0  p50   146,0  p95   130,0  max   130,0  ms
bash: printf: 661.4: nombre non valable
bash: printf: 598.9: nombre non valable
bash: printf: 534.4: nombre non valable
bash: printf: 640.9: nombre non valable
bash: printf: 640.9: nombre non valable
      TOTAL   min   661,0  avg   598,0  p50   534,0  p95   640,0  max   640,0  ms
      code HTTP 200 · 0 sondes échouées · taille: 3399173 octets
  CHAUD — 10 requêtes sur UNE seule connexion (keep-alive)
bash: printf: 47.0: nombre non valable
bash: printf: 50.3: nombre non valable
bash: printf: 36.4: nombre non valable
bash: printf: 131.7: nombre non valable
bash: printf: 131.7: nombre non valable
      TTFB    min    47,0  avg    50,0  p50    36,0  p95   131,0  max   131,0  ms
bash: printf: 246.1: nombre non valable
bash: printf: 320.2: nombre non valable
bash: printf: 302.9: nombre non valable
bash: printf: 516.3: nombre non valable
bash: printf: 516.3: nombre non valable
      TOTAL   min   246,0  avg   320,0  p50   302,0  p95   516,0  max   516,0  ms
[bench 10/14] 
═══[ Netlify — Netlify ]═════════════════════════════════════════════════════
  GET https://www.netlify.com/
  PoP : non exposé par ce réseau
  serveur: Netlify · age: 8316
  FROID — 10 sondes, nouvelle connexion complète à chaque sonde
bash: printf: 1.1: nombre non valable
bash: printf: 1.6: nombre non valable
bash: printf: 1.3: nombre non valable
bash: printf: 4.1: nombre non valable
bash: printf: 4.1: nombre non valable
      DNS     min     1,0  avg     1,0  p50     1,0  p95     4,0  max     4,0  ms
bash: printf: 29.2: nombre non valable
bash: printf: 35.5: nombre non valable
bash: printf: 35.0: nombre non valable
bash: printf: 35.1: nombre non valable
bash: printf: 35.1: nombre non valable
      TCP     min    29,0  avg    35,0  p50    35,0  p95    35,0  max    35,0  ms
bash: printf: 98.4: nombre non valable
bash: printf: 96.5: nombre non valable
bash: printf: 90.5: nombre non valable
bash: printf: 95.2: nombre non valable
bash: printf: 95.2: nombre non valable
      TLS     min    98,0  avg    96,0  p50    90,0  p95    95,0  max    95,0  ms
bash: printf: 359.9: nombre non valable
bash: printf: 373.4: nombre non valable
bash: printf: 302.0: nombre non valable
bash: printf: 341.5: nombre non valable
bash: printf: 341.5: nombre non valable
      TTFB    min   359,0  avg   373,0  p50   302,0  p95   341,0  max   341,0  ms
bash: printf: 789.4: nombre non valable
bash: printf: 603.1: nombre non valable
bash: printf: 567.5: nombre non valable
bash: printf: 492.1: nombre non valable
bash: printf: 492.1: nombre non valable
      TOTAL   min   789,0  avg   603,0  p50   567,0  p95   492,0  max   492,0  ms
      code HTTP 200 · 0 sondes échouées · taille: 410849 octets
  CHAUD — 10 requêtes sur UNE seule connexion (keep-alive)
bash: printf: 321.1: nombre non valable
bash: printf: 321.1: nombre non valable
bash: printf: 321.1: nombre non valable
bash: printf: 321.1: nombre non valable
bash: printf: 321.1: nombre non valable
      TTFB    min   321,0  avg   321,0  p50   321,0  p95   321,0  max   321,0  ms
bash: printf: 586.0: nombre non valable
bash: printf: 586.0: nombre non valable
bash: printf: 586.0: nombre non valable
bash: printf: 586.0: nombre non valable
bash: printf: 586.0: nombre non valable
      TOTAL   min   586,0  avg   586,0  p50   586,0  p95   586,0  max   586,0  ms
[bench 11/14] 
═══[ BunnyCDN — Bunny ]═════════════════════════════════════════════════════
  GET https://bunny.net/
  PoP réel : CA1 (PoP CA)
  serveur: BunnyCDN-CA1-1025
  FROID — 10 sondes, nouvelle connexion complète à chaque sonde
bash: printf: 1.0: nombre non valable
bash: printf: 1.2: nombre non valable
bash: printf: 1.1: nombre non valable
bash: printf: 1.7: nombre non valable
bash: printf: 1.7: nombre non valable
      DNS     min     1,0  avg     1,0  p50     1,0  p95     1,0  max     1,0  ms
bash: printf: 30.7: nombre non valable
bash: printf: 32.9: nombre non valable
bash: printf: 27.2: nombre non valable
bash: printf: 41.0: nombre non valable
bash: printf: 41.0: nombre non valable
      TCP     min    30,0  avg    32,0  p50    27,0  p95    41,0  max    41,0  ms
bash: printf: 86.3: nombre non valable
bash: printf: 92.2: nombre non valable
bash: printf: 88.2: nombre non valable
bash: printf: 99.0: nombre non valable
bash: printf: 99.0: nombre non valable
      TLS     min    86,0  avg    92,0  p50    88,0  p95    99,0  max    99,0  ms
bash: printf: 253.2: nombre non valable
bash: printf: 239.8: nombre non valable
bash: printf: 237.5: nombre non valable
bash: printf: 239.2: nombre non valable
bash: printf: 239.2: nombre non valable
      TTFB    min   253,0  avg   239,0  p50   237,0  p95   239,0  max   239,0  ms
bash: printf: 319.2: nombre non valable
bash: printf: 311.9: nombre non valable
bash: printf: 324.2: nombre non valable
bash: printf: 305.2: nombre non valable
bash: printf: 305.2: nombre non valable
      TOTAL   min   319,0  avg   311,0  p50   324,0  p95   305,0  max   305,0  ms
      code HTTP 200 · 0 sondes échouées · taille: 81412 octets
  CHAUD — 10 requêtes sur UNE seule connexion (keep-alive)
bash: printf: 241.6: nombre non valable
bash: printf: 241.6: nombre non valable
bash: printf: 241.6: nombre non valable
bash: printf: 241.6: nombre non valable
bash: printf: 241.6: nombre non valable
      TTFB    min   241,0  avg   241,0  p50   241,0  p95   241,0  max   241,0  ms
bash: printf: 323.3: nombre non valable
bash: printf: 323.3: nombre non valable
bash: printf: 323.3: nombre non valable
bash: printf: 323.3: nombre non valable
bash: printf: 323.3: nombre non valable
      TOTAL   min   323,0  avg   323,0  p50   323,0  p95   323,0  max   323,0  ms
[bench 12/14] 
═══[ Steam-CDN — Akamai ]═════════════════════════════════════════════════════
  GET https://cdn.akamai.steamstatic.com/steam/apps/730/header.jpg
  PoP : non exposé par ce réseau
  serveur: nginx
  FROID — 10 sondes, nouvelle connexion complète à chaque sonde
bash: printf: 1.2: nombre non valable
bash: printf: 1.4: nombre non valable
bash: printf: 1.3: nombre non valable
bash: printf: 1.9: nombre non valable
bash: printf: 1.9: nombre non valable
      DNS     min     1,0  avg     1,0  p50     1,0  p95     1,0  max     1,0  ms
bash: printf: 30.6: nombre non valable
bash: printf: 32.6: nombre non valable
bash: printf: 25.8: nombre non valable
bash: printf: 30.7: nombre non valable
bash: printf: 30.7: nombre non valable
      TCP     min    30,0  avg    32,0  p50    25,0  p95    30,0  max    30,0  ms
bash: printf: 103.6: nombre non valable
bash: printf: 112.8: nombre non valable
bash: printf: 107.6: nombre non valable
bash: printf: 123.9: nombre non valable
bash: printf: 123.9: nombre non valable
      TLS     min   103,0  avg   112,0  p50   107,0  p95   123,0  max   123,0  ms
bash: printf: 151.6: nombre non valable
bash: printf: 165.8: nombre non valable
bash: printf: 175.5: nombre non valable
bash: printf: 162.8: nombre non valable
bash: printf: 162.8: nombre non valable
      TTFB    min   151,0  avg   165,0  p50   175,0  p95   162,0  max   162,0  ms
bash: printf: 164.4: nombre non valable
bash: printf: 172.2: nombre non valable
bash: printf: 179.8: nombre non valable
bash: printf: 168.2: nombre non valable
bash: printf: 168.2: nombre non valable
      TOTAL   min   164,0  avg   172,0  p50   179,0  p95   168,0  max   168,0  ms
      code HTTP 200 · 0 sondes échouées · taille: 34296 octets
  CHAUD — 10 requêtes sur UNE seule connexion (keep-alive)
      TTFB    toutes sondes échouées
      TOTAL   toutes sondes échouées
[bench 13/14] 
═══[ Cloudinary — Cloudinary ]═════════════════════════════════════════════════════
  GET https://res.cloudinary.com/demo/image/upload/sample.jpg
  PoP : non exposé par ce réseau
  serveur: Cloudinary
  FROID — 10 sondes, nouvelle connexion complète à chaque sonde
bash: printf: 1.0: nombre non valable
bash: printf: 1.5: nombre non valable
bash: printf: 1.3: nombre non valable
bash: printf: 3.3: nombre non valable
bash: printf: 3.3: nombre non valable
      DNS     min     1,0  avg     1,0  p50     1,0  p95     3,0  max     3,0  ms
bash: printf: 45.1: nombre non valable
bash: printf: 31.3: nombre non valable
bash: printf: 33.3: nombre non valable
bash: printf: 26.2: nombre non valable
bash: printf: 26.2: nombre non valable
      TCP     min    45,0  avg    31,0  p50    33,0  p95    26,0  max    26,0  ms
bash: printf: 104.7: nombre non valable
bash: printf: 92.3: nombre non valable
bash: printf: 103.3: nombre non valable
bash: printf: 81.8: nombre non valable
bash: printf: 81.8: nombre non valable
      TLS     min   104,0  avg    92,0  p50   103,0  p95    81,0  max    81,0  ms
bash: printf: 150.0: nombre non valable
bash: printf: 138.7: nombre non valable
bash: printf: 142.2: nombre non valable
bash: printf: 120.2: nombre non valable
bash: printf: 120.2: nombre non valable
      TTFB    min   150,0  avg   138,0  p50   142,0  p95   120,0  max   120,0  ms
bash: printf: 219.0: nombre non valable
bash: printf: 214.7: nombre non valable
bash: printf: 207.8: nombre non valable
bash: printf: 189.7: nombre non valable
bash: printf: 189.7: nombre non valable
      TOTAL   min   219,0  avg   214,0  p50   207,0  p95   189,0  max   189,0  ms
      code HTTP 200 · 0 sondes échouées · taille: 109669 octets
  CHAUD — 10 requêtes sur UNE seule connexion (keep-alive)
      TTFB    toutes sondes échouées
      TOTAL   toutes sondes échouées
[bench 14/14] 
═══[ GitHub-raw — GitHub (Fastly) ]═════════════════════════════════════════════════════
  GET https://raw.githubusercontent.com/jquery/jquery/main/README.md
  PoP réel : YYZ (Toronto)
  x-cache: MISS
  FROID — 10 sondes, nouvelle connexion complète à chaque sonde
bash: printf: 1.2: nombre non valable
bash: printf: 1.6: nombre non valable
bash: printf: 1.4: nombre non valable
bash: printf: 2.9: nombre non valable
bash: printf: 2.9: nombre non valable
      DNS     min     1,0  avg     1,0  p50     1,0  p95     2,0  max     2,0  ms
bash: printf: 33.2: nombre non valable
bash: printf: 30.2: nombre non valable
bash: printf: 28.3: nombre non valable
bash: printf: 39.9: nombre non valable
bash: printf: 39.9: nombre non valable
      TCP     min    33,0  avg    30,0  p50    28,0  p95    39,0  max    39,0  ms
bash: printf: 87.8: nombre non valable
bash: printf: 90.1: nombre non valable
bash: printf: 98.2: nombre non valable
bash: printf: 94.2: nombre non valable
bash: printf: 94.2: nombre non valable
      TLS     min    87,0  avg    90,0  p50    98,0  p95    94,0  max    94,0  ms
bash: printf: 132.9: nombre non valable
bash: printf: 133.4: nombre non valable
bash: printf: 154.5: nombre non valable
bash: printf: 131.3: nombre non valable
bash: printf: 131.3: nombre non valable
      TTFB    min   132,0  avg   133,0  p50   154,0  p95   131,0  max   131,0  ms
bash: printf: 137.7: nombre non valable
bash: printf: 138.2: nombre non valable
bash: printf: 156.6: nombre non valable
bash: printf: 135.6: nombre non valable
bash: printf: 135.6: nombre non valable
      TOTAL   min   137,0  avg   138,0  p50   156,0  p95   135,0  max   135,0  ms
      code HTTP 200 · 0 sondes échouées · taille: 15044 octets
  CHAUD — 10 requêtes sur UNE seule connexion (keep-alive)
bash: printf: 35.7: nombre non valable
bash: printf: 52.9: nombre non valable
bash: printf: 49.8: nombre non valable
bash: printf: 125.0: nombre non valable
bash: printf: 125.0: nombre non valable
      TTFB    min    35,0  avg    52,0  p50    49,0  p95   125,0  max   125,0  ms
bash: printf: 43.9: nombre non valable
bash: printf: 57.0: nombre non valable
bash: printf: 49.9: nombre non valable
bash: printf: 128.9: nombre non valable
bash: printf: 128.9: nombre non valable
      TOTAL   min    43,0  avg    57,0  p50    49,0  p95   128,0  max   128,0  ms

═══[ CONTRASTE — nœud NEXUS local :8765 (optionnel, démo pitch) ]═════
  NEXUS répond — p95 TTFB local : 1.2 ms

╔══════════════════════════════════════════════════════════════════╗
║   CLASSEMENT — p95 TTFB connexion froide (le ressenti réel)       ║
╚══════════════════════════════════════════════════════════════════╝
CDN              réseau             p95 froid  p95 chaud   PoP    cache
──────────────────────────────────────────────────────────────────────────────
Cloudinary       Cloudinary            120.2 ms       NA ms   —      —
CloudFront       Amazon AWS            130.0 ms    131.7 ms   YTO53  X-Cache: Miss from cloudfront
GitHub-raw       GitHub (Fastly)       131.3 ms    125.0 ms   YYZ    x-cache: MISS
Google-CDN       Google                142.7 ms    166.0 ms   —      age: 323897
Azure-CDN        Microsoft             143.3 ms    148.5 ms   —      —
unpkg            Cloudflare            145.1 ms    145.8 ms   YYZ    cf-cache-status: HIT · age: 9002
cdnjs            Cloudflare            148.3 ms    166.3 ms   YYZ    cf-cache-status: HIT · age: 2296
Fastly-jsDelivr  Fastly                154.9 ms    145.4 ms   YYZ    x-cache: HIT, MISS · age: 35059
jsDelivr         Cloudflare+Fastly     155.0 ms    184.6 ms   YYZ    x-cache: HIT, HIT · age: 35071
Steam-CDN        Akamai                162.8 ms       NA ms   —      —
Google-Fonts     Google                169.2 ms    179.3 ms   —      —
Vercel           Vercel                182.3 ms    183.8 ms   YUL1   x-vercel-cache: HIT · age: 872
BunnyCDN         Bunny                 239.2 ms    241.6 ms   CA1    —
Netlify          Netlify               341.5 ms    321.1 ms   —      age: 8316

VERDICT :
  • meilleur CDN réel ici : Cloudinary à p95 120.2 ms (TTFB froid)
  • mesure prise depuis CETTE machine — réseau réel, assets réels, rien de simulé
  • NEXUS local p95 : 1.2 ms → 100.2× plus rapide que le meilleur CDN réel (120.2 ms)
  • le CDN reste limité par le trajet aller-retour ; NEXUS sert à <50 km, 100% RAM
  rapports : /home/nexus/CDN_REEL_BENCH_20261116-174553.txt
              /home/nexus/CDN_REEL_BENCH_20261116-174553.json
  ✓ rapport JSON validé : /home/nexus/CDN_REEL_BENCH_20261116-174553.json

terminé — 10 sondes × 14 endpoints · rapports :
  /home/nexus/CDN_REEL_BENCH_20261116-174553.txt
  /home/nexus/CDN_REEL_BENCH_20261116-174553.json
nexus@nexus-Latitude-5520:~$ 

