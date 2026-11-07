import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate } from '../../lib/validate.js';
import { aiAssistantLimiter } from '../../middleware/rateLimiters.js';
import { buildAssistantInstructions } from './aiAssistantKnowledge.js';
import { logger } from '../../lib/logger.js';

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

  const systemInstructions = buildAssistantInstructions(req.user.role, req.user.adminAccess);

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 60000);

  try {
    if (geminiKey) {
      // Google Gemini implementation
      let model = process.env.GEMINI_MODEL || 'gemini-3.8-flash';
      const fallbackModel = process.env.GEMINI_FALLBACK_MODEL || 'gemini-3.7-flash';

      const contents = req.valid.body.messages.map(({ role, content }) => ({
        role: role === 'assistant' ? 'model' : 'user',
        parts: [{ text: content }],
      }));

      const requestModel = (targetModel) => fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(targetModel)}:generateContent?key=${encodeURIComponent(geminiKey)}`,
        {
          method: 'POST',
          signal: controller.signal,
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            systemInstruction: {
              parts: [{ text: systemInstructions }],
            },
            contents,
            generationConfig: {
              maxOutputTokens: 1200,
              thinkingConfig: { thinkingLevel: 'low' },
            },
          }),
        }
      );

      let upstream = await requestModel(model);
      if (upstream.status === 503 && fallbackModel !== model) {
        logger.warn(`AI Gemini primary model unavailable; retrying with model=${fallbackModel}`);
        model = fallbackModel;
        upstream = await requestModel(model);
      }

      if (!upstream.ok) {
        const status = upstream.status;
        const providerError = await upstream.json().catch(() => ({}));
        const providerCode = providerError.error?.status || providerError.error?.code || `HTTP_${status}`;
        logger.warn(`AI Gemini request failed: HTTP ${status}, code=${providerCode}, model=${model}`);
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
        max_output_tokens: 1200,
        instructions: systemInstructions,
        input: req.valid.body.messages.map(({ role, content }) => ({ role, content })),
      }),
    });

    if (!upstream.ok) {
      const status = upstream.status;
      const providerError = await upstream.json().catch(() => ({}));
      const providerCode = providerError.error?.code || providerError.error?.type || `HTTP_${status}`;
      logger.warn(`AI OpenAI request failed: HTTP ${status}, code=${providerCode}, model=${model}`);
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
    logger.warn(`AI provider network/response error: ${error.name || 'Error'}`);
    throw errors.internal('The assistant is temporarily unavailable', 'AI_UNAVAILABLE');
  } finally {
    clearTimeout(timeout);
  }
}));

export default router;
