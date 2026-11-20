/**
 * Regression coverage for the temporary no-OTP registration path used while
 * Brevo email delivery is unresolved. The flag is set before importing the
 * shared harness so config is evaluated with verification disabled.
 */
process.env.EMAIL_VERIFICATION_REQUIRED = 'false';

const { test, before } = await import('node:test');
const assert = (await import('node:assert/strict')).default;
const { api, prisma, resetDb, TEST_PASSWORD } = await import(
  './helpers/setup.js'
);

before(async () => {
  await resetDb();
});

test('registration starts a session without email OTP when verification is disabled', async () => {
  const email = 'open.registration@test.local';
  const res = await api()
    .post('/api/v1/auth/register')
    .send({ name: 'Open Member', email, password: TEST_PASSWORD });

  assert.equal(res.status, 201, JSON.stringify(res.body));
  assert.ok(res.body.accessToken, 'expected an immediate access token');
  assert.ok(res.body.refreshToken, 'expected an immediate refresh token');
  assert.equal(res.body.user.emailVerified, true);
  assert.equal(res.body.verification.required, false);
  assert.equal(res.body.verification.emailSent, false);

  const dbUser = await prisma.user.findUnique({ where: { email } });
  assert.ok(dbUser.emailVerifiedAt, 'user should be marked verified');
  assert.equal(dbUser.emailOtpHash, null, 'no OTP should be generated');

  const me = await api()
    .get('/api/v1/me')
    .set('authorization', `Bearer ${res.body.accessToken}`);
  assert.equal(me.status, 200, JSON.stringify(me.body));

  const signIn = await api()
    .post('/api/v1/auth/login')
    .send({ email, password: TEST_PASSWORD });
  assert.equal(signIn.status, 200, JSON.stringify(signIn.body));
});
