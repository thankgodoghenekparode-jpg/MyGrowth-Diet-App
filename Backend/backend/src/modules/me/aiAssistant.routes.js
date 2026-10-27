import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate } from '../../lib/validate.js';
import { aiAssistantLimiter } from '../../middleware/rateLimiters.js';

const router = Router();
const schema = z.object({
  messages: z.array(z.object({
    role: z.enum(['user', 'assistant']),
    content: z.string().trim().min(1).max(3000),
  })).min(1).max(12),
});

router.post('/ai-assistant', aiAssistantLimiter, validate({ body: schema }), asyncHandler(async (req, res) => {
  const apiKey = process.env.OPENAI_API_KEY;
  const model = process.env.OPENAI_MODEL || 'gpt-4.1-mini';
  if (!apiKey) throw errors.internal('AI assistant is not configured yet', 'AI_NOT_CONFIGURED');

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30000);
  let upstream;
  try {
    upstream = await fetch('https://api.openai.com/v1/responses', {
      method: 'POST', signal: controller.signal,
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model, store: false, max_output_tokens: 600,
        instructions: 'You are the MyGrowth faith and wellbeing assistant. Be kind, practical, concise, and respectful of Christian beliefs. Offer general encouragement and Bible study help. Do not claim to be a pastor, therapist, or doctor; encourage appropriate professional help for medical, mental health, or urgent safety needs. Do not invent Bible quotations; identify references when possible.',
        input: req.valid.body.messages.map(({ role, content }) => ({ role, content })),
      }),
    });
  } catch (error) {
    if (error.name === 'AbortError') throw errors.internal('The assistant took too long to respond', 'AI_TIMEOUT');
    throw errors.internal('The assistant is temporarily unavailable', 'AI_UNAVAILABLE');
  } finally {
    clearTimeout(timeout);
  }
  if (!upstream.ok) {
    const status = upstream.status;
    if (status === 401 || status === 403) throw errors.internal('AI provider credentials need attention', 'AI_PROVIDER_AUTH');
    throw errors.internal('The assistant is temporarily unavailable', 'AI_UNAVAILABLE');
  }
  const payload = await upstream.json();
  const answer = (payload.output || [])
    .flatMap((item) => item.content || [])
    .filter((item) => item.type === 'output_text')
    .map((item) => item.text || '')
    .join('\n').trim();
  if (!answer) throw errors.internal('The assistant returned an empty response', 'AI_EMPTY_RESPONSE');
  res.json({ answer });
}));

export default router;
