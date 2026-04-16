const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const db = require('../db');

const SALT_ROUNDS = 12;

const signup = async (req, res) => {
  const { email, password, weight, height, age, sex } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }
  try {
    const hashed = await bcrypt.hash(password, SALT_ROUNDS);
    const result = await db.query(
      `INSERT INTO users (email, password, weight, height, age, sex)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING user_id, email, weight, height, age, sex`,
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
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }
  try {
    const result = await db.query('SELECT * FROM users WHERE email = $1', [email]);
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
      'SELECT user_id, email, weight, height, age, sex FROM users WHERE user_id = $1',
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
  const { weight, height, age, sex } = req.body;
  try {
    const result = await db.query(
      `UPDATE users SET weight = $1, height = $2, age = $3, sex = $4
       WHERE user_id = $5
       RETURNING user_id, email, weight, height, age, sex`,
      [weight, height, age, sex, req.user_id]
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

const forgotPassword = async (req, res) => {
  const { email, newPassword } = req.body;
  if (!email || !newPassword) {
    return res.status(400).json({ error: 'email and newPassword are required' });
  }
  try {
    const result = await db.query('SELECT user_id FROM users WHERE LOWER(email) = LOWER($1)', [email]);
    if (!result.rows[0]) return res.status(404).json({ error: 'No account found with that email' });
    const hashed = await bcrypt.hash(newPassword, SALT_ROUNDS);
    await db.query('UPDATE users SET password = $1 WHERE user_id = $2', [hashed, result.rows[0].user_id]);
    res.json({ message: 'Password reset successfully' });
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

module.exports = { signup, login, getUser, updateUser, deleteUser, changePassword, forgotPassword };
