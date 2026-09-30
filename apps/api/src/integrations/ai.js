const env = require('../config/env');
const { HttpError } = require('../utils/errors');

const BLOCK = [/\bkill yourself\b/i, /\bkys\b/i, /child\s*porn/i, /\bfree\s+crypto\s+giveaway\b/i];
async function claude(system, user, maxTokens = 400) {
  const r = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST', headers: { 'x-api-key': env.ANTHROPIC_API_KEY, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
    body: JSON.stringify({ model: env.AI_MODEL, max_tokens: maxTokens, system, messages: [{ role: 'user', content: user }] }),
    signal: AbortSignal.timeout(8000),
  });
  if (!r.ok) throw new Error(`AI provider ${r.status}`);
  return (await r.json()).content?.[0]?.text || '';
}
const enabled = () => env.AI_PROVIDER === 'anthropic' && !!env.ANTHROPIC_API_KEY;

module.exports = {
  enabled,
  /** -> { flagged, score 0..1, reason }. Rule-based floor always runs; the model adds nuance when configured. Fails open on provider errors (queued for human review by the caller). */
  async moderateText(text) {
    const hit = BLOCK.find((re) => re.test(text));
    if (hit) return { flagged: true, score: 1, reason: 'blocked_phrase' };
    if (!enabled()) return { flagged: false, score: 0, reason: 'rules_only' };
    try {
      const out = await claude('You are a content moderator. Reply with ONLY JSON {"score":0-1,"reason":"none|hate|harassment|sexual|violence|spam|self_harm"} for the user text. score>=0.8 means clearly violating.', text.slice(0, 4000), 60);
      const j = JSON.parse(out.match(/\{[\s\S]*\}/)[0]);
      return { flagged: j.score >= 0.8, score: j.score, reason: j.reason };
    } catch { return { flagged: false, score: 0, reason: 'provider_error' }; }
  },
  async translate(text, target) {
    if (!enabled()) throw new HttpError(501, 'AI_NOT_CONFIGURED', 'Translation is not configured');
    return (await claude(`Translate the user text into ${target}. Output only the translation.`, text.slice(0, 4000), 1000)).trim();
  },
};
