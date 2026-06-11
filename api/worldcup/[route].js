import {
  handlePredictions,
  handleResults,
  handleWorldCupRoute,
  queryValue,
} from '../_apiFootball.js';

export default async function handler(request, response) {
  const routeName = routeNameFromRequest(request);

  if (routeName === 'results') {
    await handleResults(request, response);
    return;
  }

  if (routeName === 'predictions') {
    await handlePredictions(request, response);
    return;
  }

  await handleWorldCupRoute(request, response, routeName);
}

function routeNameFromRequest(request) {
  const route = queryValue(request, 'route');
  if (route) return route;

  try {
    const url = new URL(request.url, 'https://wcfifa2026.site');
    const segments = url.pathname.split('/').filter(Boolean);
    return segments[segments.length - 1] ?? '';
  } catch (_) {
    return '';
  }
}
