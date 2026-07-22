const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const nodemailer = require('nodemailer');
const db = require('../db');

const SALT_ROUNDS = 12;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MIN_PASSWORD_LENGTH = 8;
const RESET_CODE_TTL_MIN = 15;
const MAX_CODE_ATTEMPTS = 5;

// Gmail SMTP transport. Requires GMAIL_USER and a Google App Password
// (not the account password) in GMAIL_APP_PASSWORD — see .env.example.
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.GMAIL_USER,
    pass: process.env.GMAIL_APP_PASSWORD,
  },
});

const signup = async (req, res) => {
  const { password, weight, height, age, sex } = req.body;
  // Normalize — iPhone keyboards auto-capitalize, and a case-sensitive match
  // locks users out of their own accounts
  const email = (req.body.email || '').trim().toLowerCase();
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }
  if (!EMAIL_RE.test(email)) {
    return res.status(400).json({ error: 'Invalid email address' });
  }
  if (password.length < MIN_PASSWORD_LENGTH) {
    return res.status(400).json({ error: `Password must be at least ${MIN_PASSWORD_LENGTH} characters` });
  }
  try {
    const hashed = await bcrypt.hash(password, SALT_ROUNDS);
    const result = await db.query(
      `INSERT INTO users (email, password, weight, height, age, sex)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING user_id, email, weight, height, age, sex, profile_pic, created_at`,
      [email, hashed, weight, height, age, sex]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Email already in use' });
    }
    res.status(500).json({ error: 'Server error' });
  }
};

const login = async (req, res) => {
  const { password } = req.body;
  const email = (req.body.email || '').trim().toLowerCase();
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }
  try {
    const result = await db.query('SELECT * FROM users WHERE LOWER(email) = $1', [email]);
    const user = result.rows[0];
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    const match = await bcrypt.compare(password, user.password);
    if (!match) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    const token = jwt.sign({ user_id: user.user_id }, process.env.JWT_SECRET, { expiresIn: '7d' });
    res.json({ token });
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

const getUser = async (req, res) => {
  if (parseInt(req.params.id) !== req.user_id) {
    return res.status(403).json({ error: 'Forbidden' });
  }
  try {
    const result = await db.query(
      'SELECT user_id, email, weight, height, age, sex, profile_pic, created_at FROM users WHERE user_id = $1',
      [req.user_id]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'User not found' });
    res.json(result.rows[0]);
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

const updateUser = async (req, res) => {
  if (parseInt(req.params.id) !== req.user_id) {
    return res.status(403).json({ error: 'Forbidden' });
  }
  // Patch semantics: only columns present in the body are updated (explicit null
  // clears a value; an absent key leaves it untouched). The old version wrote NULL
  // into every omitted column, silently wiping data on partial updates.
  const allowed = ['weight', 'height', 'age', 'sex', 'profile_pic'];
  const sets = [];
  const vals = [];
  for (const field of allowed) {
    if (Object.prototype.hasOwnProperty.call(req.body, field)) {
      vals.push(req.body[field]);
      sets.push(`${field} = $${vals.length}`);
    }
  }
  if (sets.length === 0) {
    return res.status(400).json({ error: 'No fields to update' });
  }
  try {
    vals.push(req.user_id);
    const result = await db.query(
      `UPDATE users SET ${sets.join(', ')}
       WHERE user_id = $${vals.length}
       RETURNING user_id, email, weight, height, age, sex, profile_pic, created_at`,
      vals
    );
    res.json(result.rows[0]);
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

const deleteUser = async (req, res) => {
  if (parseInt(req.params.id) !== req.user_id) {
    return res.status(403).json({ error: 'Forbidden' });
  }
  try {
    await db.query('DELETE FROM users WHERE user_id = $1', [req.user_id]);
    res.status(204).send();
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

const changePassword = async (req, res) => {
  if (parseInt(req.params.id) !== req.user_id) {
    return res.status(403).json({ error: 'Forbidden' });
  }
  const { currentPassword, newPassword } = req.body;
  if (!currentPassword || !newPassword) {
    return res.status(400).json({ error: 'currentPassword and newPassword are required' });
  }
  if (newPassword.length < MIN_PASSWORD_LENGTH) {
    return res.status(400).json({ error: `Password must be at least ${MIN_PASSWORD_LENGTH} characters` });
  }
  try {
    const result = await db.query('SELECT password FROM users WHERE user_id = $1', [req.user_id]);
    const user = result.rows[0];
    if (!user) return res.status(404).json({ error: 'User not found' });

    const match = await bcrypt.compare(currentPassword, user.password);
    if (!match) return res.status(401).json({ error: 'Current password is incorrect' });

    const hashed = await bcrypt.hash(newPassword, SALT_ROUNDS);
    await db.query('UPDATE users SET password = $1 WHERE user_id = $2', [hashed, req.user_id]);
    res.json({ message: 'Password updated successfully' });
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

// Step 1: email a 6-digit code. Response is identical whether or not the
// account exists, so this endpoint can't be used to enumerate emails.
const forgotPassword = async (req, res) => {
  const email = (req.body.email || '').trim().toLowerCase();
  if (!email) {
    return res.status(400).json({ error: 'email is required' });
  }
  const generic = { message: 'If an account exists for that email, a reset code has been sent.' };
  try {
    const result = await db.query('SELECT user_id FROM users WHERE LOWER(email) = $1', [email]);
    const user = result.rows[0];
    if (!user) return res.json(generic);

    const code = crypto.randomInt(100000, 1000000).toString();
    const codeHash = await bcrypt.hash(code, SALT_ROUNDS);

    // One active code per user — a new request invalidates older codes
    await db.query('DELETE FROM password_reset_codes WHERE user_id = $1', [user.user_id]);
    await db.query(
      `INSERT INTO password_reset_codes (user_id, code_hash, expires_at)
       VALUES ($1, $2, NOW() + INTERVAL '${RESET_CODE_TTL_MIN} minutes')`,
      [user.user_id, codeHash]
    );

    await transporter.sendMail({
      from: process.env.GMAIL_USER,
      to: email,
      subject: 'Your GymTraq password reset code',
      text: `Your GymTraq password reset code is ${code}. It expires in ${RESET_CODE_TTL_MIN} minutes.`,
      html: `
        <div style="font-family:-apple-system,Helvetica,Arial,sans-serif;max-width:420px;margin:0 auto;padding:24px">
          <h2 style="margin:0 0 8px">Reset your GymTraq password</h2>
          <p style="color:#555;margin:0 0 20px">Enter this code in the app. It expires in ${RESET_CODE_TTL_MIN} minutes.</p>
          <div style="font-size:36px;font-weight:700;letter-spacing:8px;text-align:center;padding:16px;background:#f4f4f5;border-radius:12px">${code}</div>
          <p style="color:#999;font-size:12px;margin:20px 0 0">If you didn't request this, you can safely ignore this email.</p>
        </div>`
    });

    res.json(generic);
  } catch (err) {
    console.error('forgotPassword:', err);
    res.status(500).json({ error: 'Could not send reset code' });
  }
};

// Step 2: verify the code, set the new password.
const resetPassword = async (req, res) => {
  const email = (req.body.email || '').trim().toLowerCase();
  const { code, newPassword } = req.body;
  if (!email || !code || !newPassword) {
    return res.status(400).json({ error: 'email, code and newPassword are required' });
  }
  if (newPassword.length < MIN_PASSWORD_LENGTH) {
    return res.status(400).json({ error: `Password must be at least ${MIN_PASSWORD_LENGTH} characters` });
  }
  try {
    const userRes = await db.query('SELECT user_id FROM users WHERE LOWER(email) = $1', [email]);
    const user = userRes.rows[0];
    if (!user) return res.status(400).json({ error: 'Invalid or expired code' });

    const rowRes = await db.query(
      `SELECT * FROM password_reset_codes
       WHERE user_id = $1 AND used = FALSE AND expires_at > NOW()
       ORDER BY created_at DESC LIMIT 1`,
      [user.user_id]
    );
    const row = rowRes.rows[0];
    if (!row) return res.status(400).json({ error: 'Invalid or expired code' });
    if (row.attempts >= MAX_CODE_ATTEMPTS) {
      return res.status(429).json({ error: 'Too many attempts — request a new code' });
    }

    const match = await bcrypt.compare(String(code), row.code_hash);
    if (!match) {
      await db.query('UPDATE password_reset_codes SET attempts = attempts + 1 WHERE id = $1', [row.id]);
      return res.status(400).json({ error: 'Incorrect code' });
    }

    const hashed = await bcrypt.hash(newPassword, SALT_ROUNDS);
    await db.query('UPDATE users SET password = $1 WHERE user_id = $2', [hashed, user.user_id]);
    await db.query('UPDATE password_reset_codes SET used = TRUE WHERE id = $1', [row.id]);
    res.json({ message: 'Password reset successfully' });
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

module.exports = { signup, login, getUser, updateUser, deleteUser, changePassword, forgotPassword, resetPassword };
