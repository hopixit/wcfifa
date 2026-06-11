import { handleWorldCupRoute } from '../_apiFootball.js';

export default async function handler(request, response) {
  await handleWorldCupRoute(request, response, 'standings');
}
