import { Router } from 'express';
import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import prisma from '../../db/index.js';
import config from '../../config/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { requireAuth, requireApprovedMember } from '../../middleware/auth.js';

const router = Router();
const ACCESS_DAYS = 30;
let cachedToken = null;
let tokenExpiresAt = 0;

function configured() {
  return config.monnify.apiKey && config.monnify.secretKey && config.monnify.contractCode;
}

async function monnifyToken() {
  if (cachedToken && tokenExpiresAt > Date.now() + 60_000) return cachedToken;
  const basic = Buffer.from(`${config.monnify.apiKey}:${config.monnify.secretKey}`).toString('base64');
  const response = await fetch(`${config.monnify.baseUrl}/api/v1/auth/login`, {
    method: 'POST',
    headers: { Authorization: `Basic ${basic}` },
  });
  const result = await response.json().catch(() => ({}));
  if (!response.ok || !result.requestSuccessful || !result.responseBody?.accessToken) {
    throw errors.internal('Payment provider authentication failed', 'PAYMENT_PROVIDER_ERROR');
  }
  cachedToken = result.responseBody.accessToken;
  tokenExpiresAt = Date.now() + Number(result.responseBody.expiresIn || 3600) * 1000;
  return cachedToken;
}

async function verifyWithMonnify(paymentReference) {
  const token = await monnifyToken();
  const url = new URL(`${config.monnify.baseUrl}/api/v2/merchant/transactions/query`);
  url.searchParams.set('paymentReference', paymentReference);
  const response = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  const result = await response.json().catch(() => ({}));
  if (!response.ok || !result.requestSuccessful || !result.responseBody) {
    throw errors.internal('Could not verify payment with provider', 'PAYMENT_PROVIDER_ERROR');
  }
  return result.responseBody;
}

async function grantAccess(payment, transactionReference, paidAt = new Date()) {
  return prisma.$transaction(async (tx) => {
    const claimed = await tx.subscriptionPayment.updateMany({
      where: { id: payment.id, status: 'PENDING' },
      data: { status: 'PAID', transactionReference, paidAt },
    });
    if (claimed.count === 0) return tx.monthlyAccess.findUnique({ where: { userId: payment.userId } });

    const existing = await tx.monthlyAccess.findUnique({ where: { userId: payment.userId } });
    const base = existing?.expiresAt && existing.expiresAt > paidAt ? existing.expiresAt : paidAt;
    const expiresAt = new Date(base.getTime() + ACCESS_DAYS * 24 * 60 * 60 * 1000);
    await tx.monthlyAccess.upsert({
      where: { userId: payment.userId },
      create: { userId: payment.userId, expiresAt },
      update: { expiresAt },
    });
    await tx.subscriptionPayment.update({
      where: { id: payment.id },
      data: { accessExpiresAt: expiresAt },
    });
    return { expiresAt };
  }, { isolationLevel: 'Serializable' });
}

async function verifyAndApply(payment) {
  const result = await verifyWithMonnify(payment.paymentReference);
  const amountPaid = Number(result.amountPaid);
  const currency = result.currencyCode || result.currency;
  if (result.paymentReference !== payment.paymentReference || currency !== 'NGN') {
    throw errors.conflict('Payment details did not match this subscription', 'PAYMENT_MISMATCH');
  }
  if (result.paymentStatus === 'PAID' && amountPaid >= Number(payment.amount)) {
    const paidAtValue = result.paidOn || result.paymentDate;
    const paidAt = paidAtValue ? new Date(paidAtValue) : new Date();
    const access = await grantAccess(payment, result.transactionReference, Number.isNaN(paidAt.getTime()) ? new Date() : paidAt);
    return { paid: true, accessExpiresAt: access?.expiresAt ?? null };
  }
  if (['FAILED', 'EXPIRED', 'REVERSED'].includes(result.paymentStatus)) {
    await prisma.subscriptionPayment.updateMany({
      where: { id: payment.id, status: 'PENDING' },
      data: { status: 'FAILED' },
    });
  }
  return { paid: false, status: result.paymentStatus };
}

router.get('/status', requireAuth, asyncHandler(async (req, res) => {
  const [access, latestPayment] = await Promise.all([
    prisma.monthlyAccess.findUnique({ where: { userId: req.user.id } }),
    prisma.subscriptionPayment.findFirst({
      where: { userId: req.user.id },
      orderBy: { createdAt: 'desc' },
      select: { status: true, createdAt: true },
    }),
  ]);
  const active = Boolean(access?.expiresAt && access.expiresAt > new Date());
  res.json({
    active,
    expiresAt: access?.expiresAt ?? null,
    price: config.monnify.amount,
    currency: 'NGN',
    periodDays: ACCESS_DAYS,
    latestPayment,
    paymentConfigured: Boolean(configured()),
  });
}));

router.post('/checkout', requireAuth, requireApprovedMember, asyncHandler(async (req, res) => {
  if (!configured()) throw errors.internal('Subscription payments are not configured yet', 'PAYMENT_NOT_CONFIGURED');
  const paymentReference = `MGDP-${req.user.id.slice(0, 8)}-${randomUUID()}`;
  const payment = await prisma.subscriptionPayment.create({
    data: {
      userId: req.user.id,
      paymentReference,
      amount: config.monnify.amount,
    },
  });

  const token = await monnifyToken();
  const response = await fetch(`${config.monnify.baseUrl}/api/v1/merchant/transactions/init-transaction`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      amount: config.monnify.amount,
      customerEmail: req.user.email,
      paymentReference,
      paymentDescription: 'MyGrowth monthly content access (30 days)',
      currencyCode: 'NGN',
      contractCode: config.monnify.contractCode,
      redirectUrl: `${config.frontendUrl}/subscription?paymentReference=${encodeURIComponent(paymentReference)}`,
      metadata: { userId: req.user.id, product: 'monthly-content-access' },
    }),
  });
  const result = await response.json().catch(() => ({}));
  const checkoutUrl = result.responseBody?.checkoutUrl;
  if (!response.ok || !result.requestSuccessful || !checkoutUrl) {
    await prisma.subscriptionPayment.update({ where: { id: payment.id }, data: { status: 'FAILED' } });
    throw errors.internal('Could not start the payment checkout', 'PAYMENT_PROVIDER_ERROR');
  }
  await prisma.subscriptionPayment.update({ where: { id: payment.id }, data: { checkoutUrl } });
  res.status(201).json({ checkoutUrl, paymentReference });
}));

router.post('/verify/:reference', requireAuth, requireApprovedMember, asyncHandler(async (req, res) => {
  const payment = await prisma.subscriptionPayment.findUnique({ where: { paymentReference: req.params.reference } });
  if (!payment || payment.userId !== req.user.id) throw errors.notFound('Payment not found', 'NOT_FOUND');
  const result = await verifyAndApply(payment);
  res.json(result);
}));

// Monnify webhooks are public callbacks. Signature verification protects the
// production endpoint; sandbox does not attach the signature header.
router.post('/webhook', asyncHandler(async (req, res) => {
  if (!configured()) throw errors.internal('Subscription payments are not configured yet', 'PAYMENT_NOT_CONFIGURED');
  const signature = req.get('monnify-signature');
  if (config.env === 'production' || signature) {
    const expected = createHmac('sha512', config.monnify.secretKey)
      .update(req.rawBody || Buffer.from(JSON.stringify(req.body)))
      .digest('hex');
    const providedBuffer = Buffer.from(signature || '', 'hex');
    const expectedBuffer = Buffer.from(expected, 'hex');
    if (providedBuffer.length !== expectedBuffer.length || !timingSafeEqual(providedBuffer, expectedBuffer)) {
      throw errors.unauthorized('Invalid payment webhook signature', 'INVALID_WEBHOOK_SIGNATURE');
    }
  }
  const reference = req.body?.eventData?.paymentReference;
  if (reference && req.body?.eventType === 'SUCCESSFUL_TRANSACTION') {
    const payment = await prisma.subscriptionPayment.findUnique({ where: { paymentReference: reference } });
    if (payment?.status === 'PENDING') await verifyAndApply(payment);
  }
  res.sendStatus(200);
}));

export default router;
