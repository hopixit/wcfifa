import { handleResults } from '../_apiFootball.js';

export default async function handler(request, response) {
  await handleResults(request, response);
}
