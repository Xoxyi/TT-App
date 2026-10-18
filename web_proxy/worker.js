// FITeT proxy for the hosted web build, as a Cloudflare Worker.
// Same rules as tool/fitet_proxy.dart: only portale.fitet.org, only the pages
// the app reads, only from the origins below. GET answers are cached for
// 10 minutes so several browsers don't multiply the traffic to the portal.
//
// Set ALLOWED_ORIGINS (comma separated, e.g. "https://xoxyi.github.io")
// as a Worker variable. See WEB_GUIDE.md.

const FITET = 'https://portale.fitet.org';
const ALLOWED_PATH = /^\/(risultati\/[A-Za-z0-9_\/]+\.(php|asp)|scheda_unica_i\.php|ajax\.php)$/;
const FORWARDED = ['X-Requested-With', 'Referer', 'Accept', 'Cookie'];
const CACHE_SECONDS = 600;

export default {
  async fetch(request, env, ctx) {
    const origin = request.headers.get('Origin') || '';
    const allowed = (env.ALLOWED_ORIGINS || '').split(',').map((s) => s.trim()).filter(Boolean);
    const cors = allowed.includes(origin)
      ? {
          'Access-Control-Allow-Origin': origin,
          Vary: 'Origin',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': ['Content-Type', ...FORWARDED.map((h) => `X-Fitet-${h}`), 'X-Fitet-Content-Type'].join(', '),
          'Access-Control-Expose-Headers': 'X-Fitet-Set-Cookie',
        }
      : null;
    if (!cors) return new Response('Forbidden', { status: 403 });
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });

    const url = new URL(request.url);
    if (!['GET', 'POST'].includes(request.method) || !ALLOWED_PATH.test(url.pathname)) {
      return new Response('Forbidden', { status: 403, headers: cors });
    }

    const headers = new Headers({ 'User-Agent': 'TT-Piciulin club app (low volume, web)' });
    for (const h of FORWARDED) {
      const v = request.headers.get(`X-Fitet-${h}`);
      if (!v) continue;
      if (h === 'Referer' && !v.startsWith(`${FITET}/`)) continue;
      headers.set(h, v);
    }
    const type = request.headers.get('Content-Type');
    if (type) headers.set('Content-Type', type);

    const target = `${FITET}${url.pathname}${url.search}`;
    // Cache key includes the XHR header: the athlete sheet differs with it.
    const cacheKey = new Request(`${target}${url.search ? '&' : '?'}_xhr=${headers.has('X-Requested-With') ? 1 : 0}`);
    const cache = caches.default;
    if (request.method === 'GET') {
      const hit = await cache.match(cacheKey);
      if (hit) return withCors(hit, cors);
    }

    const answer = await fetch(target, {
      method: request.method,
      headers,
      body: request.method === 'POST' ? await request.arrayBuffer() : undefined,
      redirect: 'follow',
    });
    const out = new Headers({ 'Content-Type': answer.headers.get('Content-Type') || 'text/html' });
    const cookies = answer.headers.getSetCookie ? answer.headers.getSetCookie() : [];
    if (cookies.length) out.set('X-Fitet-Set-Cookie', cookies.join('\n'));
    const response = new Response(await answer.arrayBuffer(), { status: answer.status, headers: out });
    if (request.method === 'GET' && answer.status === 200) {
      const cached = response.clone();
      cached.headers.set('Cache-Control', `max-age=${CACHE_SECONDS}`);
      cached.headers.delete('X-Fitet-Set-Cookie');
      ctx.waitUntil(cache.put(cacheKey, cached));
    }
    return withCors(response, cors);
  },
};

function withCors(response, cors) {
  const r = new Response(response.body, response);
  for (const [k, v] of Object.entries(cors)) r.headers.set(k, v);
  return r;
}
