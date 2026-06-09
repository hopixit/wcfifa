const feeds = [
  {
    source: 'ESPN',
    title: 'ESPN Soccer',
    url: 'https://www.espn.com/espn/rss/soccer/news',
    homeUrl: 'https://www.espn.com/soccer/',
  },
  {
    source: 'Sky Sports',
    title: 'Sky Sports Football',
    url: 'https://www.skysports.com/rss/11661',
    homeUrl: 'https://www.skysports.com/football',
  },
];

const worldCupTerms = [
  'world cup',
  'worldcup',
  'fifa',
  'wcup',
  '2026 world',
  'usmnt',
  'мондиал',
  'световно',
];

export default async function handler(request, response) {
  response.setHeader('Access-Control-Allow-Origin', '*');
  response.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  response.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  response.setHeader(
    'Cache-Control',
    's-maxage=1200, stale-while-revalidate=3600',
  );

  if (request.method === 'OPTIONS') {
    response.status(204).end();
    return;
  }

  if (request.method !== 'GET') {
    response.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const scope = `${request.query.scope || 'worldcup'}`.toLowerCase();
  const source = `${request.query.source || 'all'}`.toLowerCase();
  const limit = Math.min(
    Math.max(Number.parseInt(`${request.query.limit || '36'}`, 10) || 36, 1),
    60,
  );
  const selectedFeeds = feeds.filter((feed) => {
    if (source === 'all') return true;
    return feed.source.toLowerCase().startsWith(source);
  });

  const errors = [];
  const items = [];
  await Promise.all(
    selectedFeeds.map(async (feed) => {
      try {
        items.push(...(await fetchFeed(feed)));
      } catch (error) {
        errors.push({ source: feed.source, message: `${error}` });
      }
    }),
  );

  items.sort((a, b) => (b.publishedAtMillis || 0) - (a.publishedAtMillis || 0));
  const scopedItems =
    scope === 'worldcup'
      ? items.filter((item) => matchesWorldCupTerms(item))
      : items;

  response.status(200).json({
    generatedAt: new Date().toISOString(),
    scope,
    source,
    feeds: selectedFeeds,
    errors,
    items: scopedItems.slice(0, limit),
    totalFetched: items.length,
    totalMatched: scopedItems.length,
  });
}

async function fetchFeed(feed) {
  const upstream = await fetch(feed.url, {
    headers: {
      'user-agent': 'SportAP World Cup News Reader/1.0',
      accept: 'application/rss+xml, application/xml, text/xml',
    },
  });
  if (!upstream.ok) {
    throw new Error(`RSS feed returned HTTP ${upstream.status}`);
  }

  const xml = await upstream.text();
  return allMatches(xml, /<item\b[\s\S]*?<\/item>/gi)
    .map((itemXml) => newsItemFromXml(feed, itemXml))
    .filter(Boolean);
}

function newsItemFromXml(feed, itemXml) {
  const title = stripHtml(xmlText(itemXml, 'title'));
  const link = stripHtml(xmlText(itemXml, 'link'));
  if (!title || !link) return null;

  const summary = truncatePlainText(
    stripHtml(
      xmlText(itemXml, 'content:encoded') ||
        xmlText(itemXml, 'encoded') ||
        xmlText(itemXml, 'description'),
    ),
    1200,
  );
  const publishedLabel = stripHtml(xmlText(itemXml, 'pubDate'));
  const publishedAt = Date.parse(publishedLabel);
  const imageUrl = enclosureUrl(itemXml);

  return {
    source: feed.source,
    sourceTitle: feed.title,
    title,
    summary,
    link,
    publishedLabel,
    publishedAtMillis: Number.isNaN(publishedAt) ? null : publishedAt,
    imageUrl,
  };
}

function matchesWorldCupTerms(item) {
  const haystack = `${item.title} ${item.summary} ${item.link}`.toLowerCase();
  return worldCupTerms.some((term) => haystack.includes(term));
}

function xmlText(xml, tagName) {
  const escaped = tagName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = new RegExp(`<${escaped}\\b[^>]*>([\\s\\S]*?)<\\/${escaped}>`, 'i')
    .exec(xml);
  return match ? decodeXml(match[1].trim()) : '';
}

function enclosureUrl(xml) {
  const match = /<enclosure\b[^>]*\burl=["']([^"']+)["'][^>]*>/i.exec(xml);
  return match ? decodeXml(match[1]) : null;
}

function allMatches(value, regex) {
  const result = [];
  let match;
  while ((match = regex.exec(value)) !== null) {
    result.push(match[0]);
  }
  return result;
}

function stripHtml(value) {
  return decodeXml(value)
    .replace(/<!\[CDATA\[|\]\]>/g, '')
    .replace(/<[^>]*>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function decodeXml(value) {
  return value
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&apos;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>');
}

function truncatePlainText(value, maxLength) {
  if (value.length <= maxLength) return value;
  const trimmed = value.slice(0, maxLength).trimEnd();
  const lastSpace = trimmed.lastIndexOf(' ');
  const clean = lastSpace > 80 ? trimmed.slice(0, lastSpace) : trimmed;
  return `${clean}...`;
}
