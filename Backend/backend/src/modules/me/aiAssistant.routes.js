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
  const geminiKey = process.env.GEMINI_API_KEY;
  const openaiKey = process.env.OPENAI_API_KEY;

  if (!geminiKey && !openaiKey) {
    throw errors.internal('AI assistant is not configured yet', 'AI_NOT_CONFIGURED');
  }

  const systemInstructions =
    'You are the MyGrowth faith and spiritual growth assistant for the MyGrowth Diet Plan app (Healings Erhuvwuigho Azuike Ministry). ' +
    'Be kind, uplifting, biblically grounded, practical, concise, and respectful of Christian beliefs. ' +
    'Offer spiritual encouragement, guidance on daily spiritual diets, Scripture reflection, and prayer support. ' +
    'Always cite relevant Scripture references accurately. Do not invent Bible verses. ' +
    'Clarify that you are an AI assistant and encourage speaking with the Pastor in Shape Space for personal pastoral counselling. ' +
    'Format your responses with clean, easy-to-read markdown (bullet points, bold text for key Bible verses, short paragraphs).';

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 35000);

  try {
    if (geminiKey) {
      // Google Gemini implementation
      const model = process.env.GEMINI_MODEL || 'gemini-1.5-flash';
      const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(geminiKey)}`;

      const contents = req.valid.body.messages.map(({ role, content }) => ({
        role: role === 'assistant' ? 'model' : 'user',
        parts: [{ text: content }],
      }));

      const upstream = await fetch(endpoint, {
        method: 'POST',
        signal: controller.signal,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          systemInstruction: {
            parts: [{ text: systemInstructions }],
          },
          contents,
          generationConfig: {
            temperature: 0.7,
            maxOutputTokens: 800,
          },
        }),
      });

      if (!upstream.ok) {
        const status = upstream.status;
        if (status === 400 || status === 401 || status === 403) {
          throw errors.internal('Google Gemini credentials or model configuration need attention', 'AI_PROVIDER_AUTH');
        }
        throw errors.internal('The AI assistant is temporarily unavailable', 'AI_UNAVAILABLE');
      }

      const payload = await upstream.json();
      const answer = (payload.candidates?.[0]?.content?.parts || [])
        .map((part) => part.text || '')
        .filter(Boolean)
        .join('\n')
        .trim();

      if (!answer) throw errors.internal('The assistant returned an empty response', 'AI_EMPTY_RESPONSE');
      return res.json({ answer, provider: 'gemini', model });
    }

    // OpenAI fallback implementation
    const model = process.env.OPENAI_MODEL || 'gpt-4.1-mini';
    const upstream = await fetch('https://api.openai.com/v1/responses', {
      method: 'POST',
      signal: controller.signal,
      headers: { Authorization: `Bearer ${openaiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model,
        store: false,
        max_output_tokens: 800,
        instructions: systemInstructions,
        input: req.valid.body.messages.map(({ role, content }) => ({ role, content })),
      }),
    });

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
      .join('\n')
      .trim();

    if (!answer) throw errors.internal('The assistant returned an empty response', 'AI_EMPTY_RESPONSE');
    return res.json({ answer, provider: 'openai', model });
  } catch (error) {
    if (error.name === 'AbortError') throw errors.internal('The assistant took too long to respond', 'AI_TIMEOUT');
    if (error.status) throw error;
    throw errors.internal('The assistant is temporarily unavailable', 'AI_UNAVAILABLE');
  } finally {
    clearTimeout(timeout);
  }
}));

export default router;
