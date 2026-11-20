import { Router } from 'express';
import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import prisma from '../../db/index.js';
import config from '../../config/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { requireAuth } from '../../middleware/auth.js';

const router = Router();

// Donations may be made by guests, while a valid member session is attached
// when one is supplied so the transaction appears in that member's history.
const optionalAuth = (req, res, next) => {
  if (req.get('authorization')) return requireAuth(req, res, next);
  next();
};

// ---------------------------------------------------------------------------
// Monnify helpers (same pattern as subscription module)
// ---------------------------------------------------------------------------
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

function nextDueDate(frequency, fromDate = new Date()) {
  const d = new Date(fromDate);
  switch (frequency) {
    case 'WEEKLY': d.setDate(d.getDate() + 7); break;
    case 'MONTHLY': d.setMonth(d.getMonth() + 1); break;
    case 'QUARTERLY': d.setMonth(d.getMonth() + 3); break;
    case 'ANNUALLY': d.setFullYear(d.getFullYear() + 1); break;
  }
  return d;
}

// ---------------------------------------------------------------------------
// Public routes (no auth required)
// ---------------------------------------------------------------------------

/** GET /categories — list active giving categories */
router.get('/categories', asyncHandler(async (req, res) => {
  const categories = await prisma.givingCategory.findMany({
    where: { isActive: true },
    orderBy: { sortOrder: 'asc' },
  });
  res.json({ data: categories });
}));

/** POST /webhook — Monnify webhook for giving transactions */
router.post('/webhook', asyncHandler(async (req, res) => {
  if (!configured()) throw errors.internal('Giving payments are not configured', 'PAYMENT_NOT_CONFIGURED');
  const signature = req.get('monnify-signature');
  const isSandbox = new URL(config.monnify.baseUrl).hostname === 'sandbox.monnify.com';
  if (!isSandbox) {
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
    const tx = await prisma.givingTransaction.findUnique({ where: { paymentReference: reference } });
    if (tx?.status === 'PENDING') {
      const result = await verifyWithMonnify(reference);
      const amountPaid = Number(result.amountPaid);
      if (result.paymentStatus === 'PAID' && amountPaid >= Number(tx.amount)) {
        const paidAtRaw = result.paidOn || result.paymentDate;
        const paidAt = paidAtRaw ? new Date(paidAtRaw) : new Date();
        const receiptNumber = `RCP-${Date.now()}-${randomUUID().slice(0, 4).toUpperCase()}`;
        await prisma.givingTransaction.update({
          where: { id: tx.id },
          data: {
            status: 'PAID',
            monnifyReference: result.transactionReference,
            paidAt: Number.isNaN(paidAt.getTime()) ? new Date() : paidAt,
            receiptNumber,
          },
        });
      }
    }
  }
  res.sendStatus(200);
}));

/** POST /initialize — start a Monnify checkout for a donation */
router.post('/initialize', optionalAuth, asyncHandler(async (req, res) => {
  if (!configured()) throw errors.internal('Giving payments are not configured', 'PAYMENT_NOT_CONFIGURED');
  const { categoryId, amount, note, donorName, donorEmail, donorPhone, isGuest } = req.body || {};

  if (!categoryId) throw errors.badRequest('A giving category is required');
  const amountValue = Number(amount);
  if (!Number.isFinite(amountValue) || amountValue <= 0 || amountValue > 9_999_999_999.99) {
    throw errors.badRequest('Enter a valid amount within the supported range');
  }

  const category = await prisma.givingCategory.findUnique({ where: { id: categoryId } });
  if (!category || !category.isActive) throw errors.notFound('Giving category not found');

  // Determine donor info from auth or body
  const userId = req.user?.id || null;
  const email = req.user?.email || donorEmail;
  const name = req.user ? `${req.user.firstName} ${req.user.lastName}` : donorName;
  if (!email || !name) throw errors.badRequest('Donor name and email are required for guest giving');

  const paymentReference = `MGDP-GIVE-${randomUUID()}`;
  const tx = await prisma.givingTransaction.create({
    data: {
      userId,
      categoryId,
      amount: amountValue,
      paymentReference,
      donorName: name,
      donorEmail: email,
      donorPhone: donorPhone || req.user?.phone || null,
      isGuest: !req.user || Boolean(isGuest),
      note: note?.slice(0, 500) || null,
    },
  });

  const token = await monnifyToken();
  const response = await fetch(`${config.monnify.baseUrl}/api/v1/merchant/transactions/init-transaction`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      amount: amountValue,
      customerEmail: email,
      customerName: name,
      paymentReference,
      paymentDescription: `${category.name} — MyGrowth Ministry`,
      currencyCode: 'NGN',
      contractCode: config.monnify.contractCode,
      redirectUrl: `${config.frontendUrl}/giving?ref=${encodeURIComponent(paymentReference)}`,
      metadata: { userId, categoryId, categoryName: category.name },
    }),
  });
  const result = await response.json().catch(() => ({}));
  const checkoutUrl = result.responseBody?.checkoutUrl;
  if (!response.ok || !result.requestSuccessful || !checkoutUrl) {
    await prisma.givingTransaction.update({ where: { id: tx.id }, data: { status: 'FAILED' } });
    throw errors.internal('Could not start the payment checkout', 'PAYMENT_PROVIDER_ERROR');
  }

  res.status(201).json({ data: { checkoutUrl, paymentReference } });
}));

/** POST /verify/:reference — verify a giving payment */
router.post('/verify/:reference', asyncHandler(async (req, res) => {
  const tx = await prisma.givingTransaction.findUnique({
    where: { paymentReference: req.params.reference },
    include: { category: { select: { name: true } } },
  });
  if (!tx) throw errors.notFound('Transaction not found');

  if (tx.status === 'PAID') {
    return res.json({ data: {
      paid: true,
      receiptNumber: tx.receiptNumber,
      receipt: {
        receiptNumber: tx.receiptNumber, donorName: tx.donorName, amount: tx.amount,
        currency: tx.currency, paidAt: tx.paidAt, status: tx.status,
        category: tx.category,
      },
    } });
  }

  const result = await verifyWithMonnify(tx.paymentReference);
  const amountPaid = Number(result.amountPaid);
  if (result.paymentStatus === 'PAID' && amountPaid >= Number(tx.amount)) {
    const paidAtRaw = result.paidOn || result.paymentDate;
    const paidAt = paidAtRaw ? new Date(paidAtRaw) : new Date();
    const receiptNumber = `RCP-${Date.now()}-${randomUUID().slice(0, 4).toUpperCase()}`;
    const updated = await prisma.givingTransaction.update({
      where: { id: tx.id },
      data: {
        status: 'PAID',
        monnifyReference: result.transactionReference,
        paidAt: Number.isNaN(paidAt.getTime()) ? new Date() : paidAt,
        receiptNumber,
      },
    });
    return res.json({ data: {
      paid: true,
      receiptNumber: updated.receiptNumber,
      receipt: {
        receiptNumber: updated.receiptNumber, donorName: updated.donorName,
        amount: updated.amount, currency: updated.currency, paidAt: updated.paidAt,
        status: updated.status, category: tx.category,
      },
    } });
  }

  if (['FAILED', 'EXPIRED', 'REVERSED'].includes(result.paymentStatus)) {
    await prisma.givingTransaction.updateMany({
      where: { id: tx.id, status: 'PENDING' },
      data: { status: 'FAILED' },
    });
  }
  res.json({ data: { paid: false, status: result.paymentStatus } });
}));

// ---------------------------------------------------------------------------
// Authenticated member routes
// ---------------------------------------------------------------------------
router.use(requireAuth);

/** GET /history — user's giving history */
router.get('/history', asyncHandler(async (req, res) => {
  const page = Math.max(1, parseInt(req.query.page) || 1);
  const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));
  const skip = (page - 1) * limit;

  const [transactions, total] = await Promise.all([
    prisma.givingTransaction.findMany({
      where: { userId: req.user.id },
      include: { category: { select: { name: true, type: true } } },
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
    }),
    prisma.givingTransaction.count({ where: { userId: req.user.id } }),
  ]);

  res.json({ data: { transactions, total, page, totalPages: Math.ceil(total / limit) } });
}));

/** GET /receipt/:id — get receipt for a transaction */
router.get('/receipt/:id', asyncHandler(async (req, res) => {
  const tx = await prisma.givingTransaction.findUnique({
    where: { id: req.params.id },
    include: { category: true },
  });
  if (!tx || tx.userId !== req.user.id) throw errors.notFound('Transaction not found');
  if (tx.status !== 'PAID') throw errors.badRequest('Receipt is only available for completed payments');
  res.json({ data: tx });
}));

/** GET /partner — user's ministry partner status */
router.get('/partner', asyncHandler(async (req, res) => {
  const partner = await prisma.givingPartner.findUnique({ where: { userId: req.user.id } });
  res.json({ data: { partner } });
}));

/** POST /partner — become a ministry partner */
router.post('/partner', asyncHandler(async (req, res) => {
  const existing = await prisma.givingPartner.findUnique({ where: { userId: req.user.id } });
  if (existing) throw errors.conflict('You already have a ministry partnership');

  const { amount, frequency, note } = req.body || {};
  const amountValue = Number(amount);
  if (!Number.isFinite(amountValue) || amountValue <= 0 || amountValue > 9_999_999_999.99) {
    throw errors.badRequest('A valid amount is required');
  }
  const validFrequencies = ['WEEKLY', 'MONTHLY', 'QUARTERLY', 'ANNUALLY'];
  if (!validFrequencies.includes(frequency)) throw errors.badRequest('Choose a valid giving frequency');

  const today = new Date();
  const partner = await prisma.givingPartner.create({
    data: {
      userId: req.user.id,
      amount: amountValue,
      frequency,
      startDate: today,
      nextDueDate: nextDueDate(frequency, today),
      note: note?.slice(0, 500) || null,
    },
  });
  res.status(201).json({ data: { partner } });
}));

/** PATCH /partner — update ministry partnership */
router.patch('/partner', asyncHandler(async (req, res) => {
  const existing = await prisma.givingPartner.findUnique({ where: { userId: req.user.id } });
  if (!existing) throw errors.notFound('No active ministry partnership found');

  const { amount, frequency, status, note } = req.body || {};
  const data = {};
  if (amount !== undefined) {
    const amountValue = Number(amount);
    if (!Number.isFinite(amountValue) || amountValue <= 0 || amountValue > 9_999_999_999.99) {
      throw errors.badRequest('A valid amount is required');
    }
    data.amount = amountValue;
  }
  if (frequency !== undefined) {
    const validFrequencies = ['WEEKLY', 'MONTHLY', 'QUARTERLY', 'ANNUALLY'];
    if (!validFrequencies.includes(frequency)) throw errors.badRequest('Choose a valid giving frequency');
    data.frequency = frequency;
    data.nextDueDate = nextDueDate(frequency);
  }
  if (status !== undefined) {
    const validStatuses = ['ACTIVE', 'PAUSED', 'CANCELLED'];
    if (!validStatuses.includes(status)) throw errors.badRequest('Invalid partnership status');
    data.status = status;
  }
  if (note !== undefined) data.note = note?.slice(0, 500) || null;

  const partner = await prisma.givingPartner.update({ where: { userId: req.user.id }, data });
  res.json({ data: { partner } });
}));

export default router;
