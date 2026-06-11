import { handlePredictions } from '../_apiFootball.js';

export default async function handler(request, response) {
  await handlePredictions(request, response);
}
