import config from '../../config/index.js';
import { logger } from '../../lib/logger.js';

/**
 * Email provider abstraction. The default `console` adapter never sends
 * anything — it logs the message/link for local development. The `resend`
 * adapter activates when EMAIL_PROVIDER=resend and RESEND_API_KEY is set.
 */
export function verificationEmail(to, link) {
  return {
    to,
    subject: 'Verify your email — MyGrowth Diet App',
    text: `Welcome to MyGrowth Diet App (Healings Erhuvwuigho Azuike Ministry).\n\nVerify your email address by opening this link:\n${link}\n\nIf you did not create this account, you can ignore this message.`,
    html: `<p>Welcome to <strong>MyGrowth Diet App</strong> — Healings Erhuvwuigho Azuike Ministry.</p><p>Verify your email address:</p><p><a href="${link}">${link}</a></p><p>If you did not create this account, you can ignore this message.</p>`,
  };
}

export function passwordResetEmail(to, link) {
  return {
    to,
    subject: 'Reset your password — MyGrowth Diet App',
    text: `We received a request to reset your password.\n\nOpen this link to choose a new password (valid for 60 minutes):\n${link}\n\nIf you did not request this, you can safely ignore this message.`,
    html: `<p>We received a request to reset your password.</p><p><a href="${link}">Reset your password</a> (valid for 60 minutes).</p><p>Link: ${link}</p><p>If you did not request this, you can safely ignore this message.</p>`,
  };
}

export function notificationEmail(to, title, body) {
  return {
    to,
    subject: `${title} — MyGrowth Diet App`,
    text: `${title}\n\n${body || ''}\n\n— MyGrowth Diet App, Healings Erhuvwuigho Azuike Ministry`,
    html: `<h2>${title}</h2><p>${body || ''}</p><hr/><p><em>MyGrowth Diet App — Healings Erhuvwuigho Azuike Ministry</em></p>`,
  };
}

async function sendConsole(message) {
  // Console adapter: logs the message (including links) and never sends.
  logger.info(`[email:console] to=${message.to} subject="${message.subject}"`);
  return { ok: true, provider: 'console' };
}

async function sendResend(message) {
  if (!config.email.resendApiKey) {
    logger.warn('[email:resend] RESEND_API_KEY not configured — email skipped');
    return { ok: false, error: 'RESEND_API_KEY not configured' };
  }
  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${config.email.resendApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: config.email.from,
        to: [message.to],
        subject: message.subject,
        text: message.text,
        html: message.html,
      }),
    });
    if (!res.ok) {
      const text = await res.text();
      logger.error(`[email:resend] failed status=${res.status}`);
      return { ok: false, error: `Resend returned ${res.status}` };
    }
    return { ok: true, provider: 'resend' };
  } catch (err) {
    logger.error('[email:resend] transport error', err?.message);
    return { ok: false, error: err?.message || 'transport error' };
  }
}

/**
 * Send an email through the configured provider.
 * @returns {{ok:boolean, provider?:string, error?:string}}
 */
export async function sendEmail(message) {
  const provider = config.email.provider;
  if (provider === 'resend') return sendResend(message);
  return sendConsole(message);
}

export default { sendEmail, verificationEmail, passwordResetEmail, notificationEmail };
