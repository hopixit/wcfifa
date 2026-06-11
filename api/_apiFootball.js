const defaultHost = 'v3.football.api-sports.io';
const leagueId = '1';
const season = '2026';
const apiTimezone = 'Europe/Sofia';
const dailyStartDate = '2026-06-11';

const endpointHelp = [
  { path: '/api/health', description: 'Proxy health check' },
  { path: '/api/news', description: 'World Cup RSS news' },
  { path: '/api/worldcup/fixtures', description: 'World Cup fixtures' },
  { path: '/api/worldcup/results', description: 'Match-day results' },
  { path: '/api/worldcup/predictions', description: 'Group-stage predictions' },
  { path: '/api/worldcup/standings', description: 'Group standings' },
  { path: '/api/worldcup/teams', description: 'Tournament teams' },
  {
    path: '/api/worldcup/team-squad?team=16',
    description: 'Squad by API-Football team id',
  },
  {
    path: '/api/worldcup/team-coach?team=16',
    description: 'Coach by API-Football team id',
  },
  { path: '/api/worldcup/top-scorers', description: 'Top scorers' },
  { path: '/api/worldcup/top-assists', description: 'Top assists' },
  { path: '/api/worldcup/status', description: 'API-Football status' },
];

export { apiTimezone, endpointHelp, leagueId, season };

export function setCors(response) {
  response.setHeader('Access-Control-Allow-Origin', '*');
  response.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
  response.setHeader('Access-Control-Allow-Headers', 'Content-Type');
}

export function queryValue(request, key, fallback = undefined) {
  const raw = request.query?.[key];
  if (Array.isArray(raw)) return raw[0] ?? fallback;
  if (raw != null) return `${raw}`;

  try {
    const url = new URL(request.url, 'https://wcfifa2026.site');
    return url.searchParams.get(key) ?? fallback;
  } catch (_) {
    return fallback;
  }
}

export function allowReadRequest(request, response) {
  setCors(response);

  if (request.method === 'OPTIONS') {
    response.status(204).end();
    return false;
  }

  if (request.method !== 'GET' && request.method !== 'HEAD') {
    sendJson(response, 405, { error: 'Method not allowed' });
    return false;
  }

  return true;
}

export function sendJson(
  response,
  statusCode,
  body,
  { cacheSeconds = 0, staleSeconds = 0, cacheHeader } = {},
) {
  setCors(response);
  response.setHeader('Content-Type', 'application/json; charset=utf-8');
  if (cacheHeader) {
    response.setHeader('Cache-Control', cacheHeader);
  } else if (cacheSeconds > 0) {
    const stale = staleSeconds > 0 ? `, stale-while-revalidate=${staleSeconds}` : '';
    response.setHeader('Cache-Control', `s-maxage=${cacheSeconds}${stale}`);
  } else {
    response.setHeader('Cache-Control', 'no-store');
  }
  response.status(statusCode).json(body);
}

export function sendRawJson(
  response,
  statusCode,
  body,
  { cacheSeconds = 0, staleSeconds = 0, cacheHeader } = {},
) {
  setCors(response);
  response.setHeader('Content-Type', 'application/json; charset=utf-8');
  if (cacheHeader) {
    response.setHeader('Cache-Control', cacheHeader);
  } else if (cacheSeconds > 0) {
    const stale = staleSeconds > 0 ? `, stale-while-revalidate=${staleSeconds}` : '';
    response.setHeader('Cache-Control', `s-maxage=${cacheSeconds}${stale}`);
  } else {
    response.setHeader('Cache-Control', 'no-store');
  }
  response.status(statusCode).send(body);
}

export function handleEndpointHelp(request, response, statusCode = 200) {
  if (!allowReadRequest(request, response)) return;
  sendJson(response, statusCode, {
    service: 'Sport AP API-Football proxy',
    requestedPath: request.url ?? request.query?.path ?? '/',
    upstream: `https://${upstreamHost()}`,
    apiKeyConfigured: Boolean(apiKey()),
    endpoints: endpointHelp,
  });
}

export function handleHealth(request, response) {
  if (!allowReadRequest(request, response)) return;
  sendJson(response, 200, {
    ok: true,
    upstream: `https://${upstreamHost()}`,
    apiKeyConfigured: Boolean(apiKey()),
  });
}

export async function handleDirectApiFootball(
  request,
  response,
  { endpoint, params, cacheSeconds, staleSeconds = 60 },
) {
  if (!allowReadRequest(request, response)) return;

  try {
    const upstream = await fetchApiFootball(endpoint, params);
    copyRateLimitHeaders(response, upstream.headers);
    sendRawJson(response, upstream.status, upstream.body, {
      cacheSeconds: upstream.status === 200 ? cacheSeconds : 0,
      staleSeconds,
    });
  } catch (error) {
    sendJson(response, 502, {
      error: 'Proxy request failed',
      message: `${error}`,
    });
  }
}

export async function handleResults(request, response) {
  if (!allowReadRequest(request, response)) return;

  const force = queryValue(request, 'force') === 'true';
  const plan = resultRefreshPlan(new Date(), queryValue(request, 'date'));

  if (!plan.enabled) {
    sendJson(
      response,
      200,
      {
        generatedAt: new Date().toISOString(),
        mode: plan.mode,
        date: plan.dateKey,
        dailyStartDate,
        cacheKey: plan.cacheKey,
        fixtureCount: 0,
        requestCount: 0,
        requestsRemainingToday: null,
        errors: [],
        response: [],
      },
      { cacheSeconds: plan.ttlSeconds, staleSeconds: 60 },
    );
    return;
  }

  try {
    const upstream = await fetchApiFootball('/fixtures', {
      league: leagueId,
      season,
      date: plan.dateKey,
      timezone: apiTimezone,
    });
    copyRateLimitHeaders(response, upstream.headers);

    if (upstream.status < 200 || upstream.status >= 300) {
      throw new Error(
        `API-Football results returned HTTP ${upstream.status}: ${upstream.body}`,
      );
    }

    const root = jsonMap(JSON.parse(upstream.body));
    const errors = root.errors;
    if (errors && typeof errors === 'object' && Object.keys(errors).length > 0) {
      throw new Error(`API-Football results error: ${JSON.stringify(errors)}`);
    }

    const items = Array.isArray(root.response) ? root.response : [];
    const payload = {
      generatedAt: new Date().toISOString(),
      mode: plan.mode,
      date: plan.dateKey,
      dailyStartDate,
      cacheKey: plan.cacheKey,
      fixtureCount: items.length,
      requestCount: 1,
      requestsRemainingToday: asInt(
        upstream.headers.get('x-ratelimit-requests-remaining'),
      ),
      errors: [],
      response: items,
    };

    response.setHeader('x-cache', force ? 'REFRESH' : 'MISS');
    sendJson(response, 200, payload, {
      cacheSeconds: force ? 0 : plan.ttlSeconds,
      staleSeconds: 60,
      cacheHeader: force ? 'no-store' : undefined,
    });
  } catch (error) {
    sendJson(response, 502, {
      error: 'Proxy request failed',
      message: `${error}`,
    });
  }
}

export async function handlePredictions(request, response) {
  if (!allowReadRequest(request, response)) return;

  const force = queryValue(request, 'force') === 'true';
  const plan = predictionRefreshPlan(new Date());

  try {
    const fixtures = await fixturesForPredictions();
    const selectedFixtures = fixtures.filter((fixture) =>
      predictionPlanIncludesFixture(plan, fixture),
    );
    const { predictions, errors, requestsRemainingToday } =
      await fetchPredictionsForFixtures(selectedFixtures);

    const payload = {
      generatedAt: new Date().toISOString(),
      mode: plan.mode,
      date: plan.dateKey,
      dailyStartDate,
      cacheKey: plan.cacheKey,
      fixtureCount: selectedFixtures.length,
      requestCount: predictions.length + errors.length,
      requestsRemainingToday,
      errors,
      response: predictions,
    };

    response.setHeader('x-cache', force ? 'REFRESH' : 'MISS');
    sendJson(response, 200, payload, {
      cacheSeconds: force ? 0 : plan.ttlSeconds,
      staleSeconds: 300,
      cacheHeader: force ? 'no-store' : undefined,
    });
  } catch (error) {
    sendJson(response, 502, {
      error: 'Proxy request failed',
      message: `${error}`,
    });
  }
}

export function worldCupRouteParams(request, routeName) {
  if (routeName === 'fixtures') {
    return {
      endpoint: '/fixtures',
      params: {
        league: leagueId,
        season,
        timezone: queryValue(request, 'timezone', apiTimezone),
      },
      cacheSeconds: 1800,
    };
  }

  if (routeName === 'standings') {
    return {
      endpoint: '/standings',
      params: { league: leagueId, season },
      cacheSeconds: 3600,
    };
  }

  if (routeName === 'teams') {
    return {
      endpoint: '/teams',
      params: { league: leagueId, season },
      cacheSeconds: 43200,
    };
  }

  if (routeName === 'team-squad') {
    const team = queryValue(request, 'team');
    if (!team || !/^\d+$/.test(team)) return null;
    return {
      endpoint: '/players/squads',
      params: { team },
      cacheSeconds: 604800,
    };
  }

  if (routeName === 'team-coach') {
    const team = queryValue(request, 'team');
    if (!team || !/^\d+$/.test(team)) return null;
    return {
      endpoint: '/coachs',
      params: { team },
      cacheSeconds: 86400,
    };
  }

  if (routeName === 'top-scorers') {
    return {
      endpoint: '/players/topscorers',
      params: { league: leagueId, season },
      cacheSeconds: 21600,
    };
  }

  if (routeName === 'top-assists') {
    return {
      endpoint: '/players/topassists',
      params: { league: leagueId, season },
      cacheSeconds: 21600,
    };
  }

  if (routeName === 'status') {
    return {
      endpoint: '/status',
      params: {},
      cacheSeconds: 300,
    };
  }

  return null;
}

export async function handleWorldCupRoute(request, response, routeName) {
  const route = worldCupRouteParams(request, routeName);
  if (!route) {
    if (!allowReadRequest(request, response)) return;
    sendJson(response, 404, {
      error: 'Unknown endpoint',
      endpoints: endpointHelp,
    });
    return;
  }

  await handleDirectApiFootball(request, response, route);
}

async function fixturesForPredictions() {
  const upstream = await fetchApiFootball('/fixtures', {
    league: leagueId,
    season,
    timezone: apiTimezone,
  });

  if (upstream.status < 200 || upstream.status >= 300) {
    throw new Error(
      `API-Football fixtures returned HTTP ${upstream.status}: ${upstream.body}`,
    );
  }

  const root = jsonMap(JSON.parse(upstream.body));
  const errors = root.errors;
  if (errors && typeof errors === 'object' && Object.keys(errors).length > 0) {
    throw new Error(`API-Football fixtures error: ${JSON.stringify(errors)}`);
  }

  return Array.isArray(root.response) ? root.response.map(jsonMap) : [];
}

async function fetchApiFootball(endpoint, params = {}) {
  const key = apiKey();
  if (!key) {
    throw new Error(
      'Missing API_FOOTBALL_KEY. Add it to the Vercel project environment.',
    );
  }

  const url = new URL(`https://${upstreamHost()}${endpoint}`);
  for (const [keyName, value] of Object.entries(params)) {
    if (value != null && `${value}`.trim() !== '') {
      url.searchParams.set(keyName, `${value}`);
    }
  }

  const upstream = await fetch(url, {
    headers: { 'x-apisports-key': key },
    signal: timeoutSignal(20000),
  });
  const body = await upstream.text();
  return { status: upstream.status, headers: upstream.headers, body };
}

function copyRateLimitHeaders(response, headers) {
  for (const header of [
    'x-ratelimit-requests-limit',
    'x-ratelimit-requests-remaining',
    'x-ratelimit-limit',
    'x-ratelimit-remaining',
  ]) {
    const value = headers.get(header);
    if (value != null) response.setHeader(header, value);
  }
}

function apiKey() {
  return process.env.API_FOOTBALL_KEY || '';
}

function upstreamHost() {
  const value =
    process.env.API_FOOTBALL_HOST ||
    process.env.API_FOOTBALL_BASE_URL ||
    defaultHost;
  return value.replace(/^https?:\/\//, '').trim();
}

function timeoutSignal(ms) {
  if (typeof AbortSignal !== 'undefined' && AbortSignal.timeout) {
    return AbortSignal.timeout(ms);
  }

  const controller = new AbortController();
  setTimeout(() => controller.abort(), ms);
  return controller.signal;
}

function predictionRefreshPlan(now) {
  const localDateKey = dateKeyInTimeZone(now, apiTimezone);
  if (localDateKey < dailyStartDate) {
    return {
      mode: 'pre_tournament_all',
      dateKey: 'initial',
      cacheKey: 'predictions_initial_all',
      ttlSeconds: 31536000,
    };
  }

  return {
    mode: 'all_group_stage',
    dateKey: 'all',
    cacheKey: 'predictions_all_group_stage',
    ttlSeconds: 93600,
  };
}

function resultRefreshPlan(now, dateOverride) {
  const overrideDateKey = parseDateKey(dateOverride);
  const localDateKey = overrideDateKey ?? dateKeyInTimeZone(now, apiTimezone);

  if (!overrideDateKey && localDateKey < dailyStartDate) {
    return {
      mode: 'pre_tournament_waiting',
      dateKey: 'pre_tournament',
      cacheKey: 'results_pre_tournament',
      ttlSeconds: 300,
      enabled: false,
    };
  }

  return {
    mode: 'match_day_results',
    dateKey: localDateKey,
    cacheKey: `results_day_${localDateKey}`,
    ttlSeconds: 300,
    enabled: true,
  };
}

function predictionPlanIncludesFixture(plan, fixture) {
  if (!apiFixtureId(fixture)) return false;
  if (!hasConcreteTeams(fixture)) return false;
  if (!isWorldCupGroupFixture(fixture)) return false;
  if (plan.mode === 'pre_tournament_all' || plan.mode === 'all_group_stage') {
    return true;
  }

  const fixtureDateKey = fixtureLocalDateKey(fixture);
  return fixtureDateKey === plan.dateKey;
}

async function fetchPredictionsForFixtures(fixtures) {
  const predictions = [];
  const errors = [];
  let requestsRemainingToday = null;
  const batchSize = 8;

  for (let index = 0; index < fixtures.length; index += batchSize) {
    const batch = fixtures.slice(index, index + batchSize);
    const results = await Promise.all(batch.map(fetchPredictionForFixture));

    for (const result of results) {
      if (result.requestsRemainingToday != null) {
        requestsRemainingToday = result.requestsRemainingToday;
      }
      if (result.prediction) predictions.push(result.prediction);
      if (result.error) errors.push(result.error);
    }
  }

  return { predictions, errors, requestsRemainingToday };
}

async function fetchPredictionForFixture(fixture) {
  const fixtureId = apiFixtureId(fixture);
  if (!fixtureId) return {};

  try {
    const upstream = await fetchApiFootball('/predictions', {
      fixture: fixtureId,
    });
    const requestsRemainingToday = asInt(
      upstream.headers.get('x-ratelimit-requests-remaining'),
    );

    if (upstream.status < 200 || upstream.status >= 300) {
      return {
        requestsRemainingToday,
        error: {
          fixture: fixtureId,
          statusCode: upstream.status,
          message: upstream.body,
        },
      };
    }

    const root = jsonMap(JSON.parse(upstream.body));
    const apiErrors = root.errors;
    if (
      apiErrors &&
      typeof apiErrors === 'object' &&
      Object.keys(apiErrors).length > 0
    ) {
      return {
        requestsRemainingToday,
        error: {
          fixture: fixtureId,
          statusCode: upstream.status,
          message: JSON.stringify(apiErrors),
        },
      };
    }

    return {
      requestsRemainingToday,
      prediction: { fixture: fixtureSummary(fixture), payload: root },
    };
  } catch (error) {
    return {
      error: { fixture: fixtureId, message: `${error}` },
    };
  }
}

function fixtureSummary(fixture) {
  const fixtureData = jsonMap(fixture.fixture);
  const league = jsonMap(fixture.league);
  const teams = jsonMap(fixture.teams);
  const home = jsonMap(teams.home);
  const away = jsonMap(teams.away);

  return {
    id: apiFixtureId(fixture),
    date: fixtureData.date?.toString(),
    round: league.round?.toString(),
    home: { id: asInt(home.id), name: home.name?.toString() },
    away: { id: asInt(away.id), name: away.name?.toString() },
  };
}

function apiFixtureId(fixture) {
  const id = asInt(jsonMap(fixture.fixture).id);
  return id == null ? null : `${id}`;
}

function hasConcreteTeams(fixture) {
  const teams = jsonMap(fixture.teams);
  const home = jsonMap(teams.home);
  const away = jsonMap(teams.away);
  return (
    asInt(home.id) != null &&
    asInt(away.id) != null &&
    `${home.name ?? ''}`.trim() !== '' &&
    `${away.name ?? ''}`.trim() !== ''
  );
}

function isWorldCupGroupFixture(fixture) {
  const round = jsonMap(fixture.league).round?.toString() ?? '';
  return /Group\s+Stage|Group\s+[A-L]/i.test(round);
}

function fixtureLocalDateKey(fixture) {
  const value = jsonMap(fixture.fixture).date?.toString();
  if (!value) return null;
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return null;
  return dateKeyInTimeZone(parsed, apiTimezone);
}

function dateKeyInTimeZone(date, timeZone) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

function parseDateKey(value) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return /^\d{4}-\d{2}-\d{2}$/.test(trimmed) ? trimmed : null;
}

function jsonMap(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

function asInt(value) {
  if (typeof value === 'number' && Number.isFinite(value)) return Math.trunc(value);
  if (typeof value === 'string' && value.trim() !== '') {
    const parsed = Number.parseInt(value, 10);
    return Number.isNaN(parsed) ? null : parsed;
  }
  return null;
}
