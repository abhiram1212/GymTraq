const db = require('../db');

const createSession = async (req, res) => {
  const { date, notes, name } = req.body;
  if (!date) {
    return res.status(400).json({ error: 'date is required' });
  }
  try {
    const result = await db.query(
      'INSERT INTO sessions (date, notes, name, user_id) VALUES ($1, $2, $3, $4) RETURNING *',
      [date, notes, name, req.user_id]
    );
    res.status(201).json(result.rows[0]);
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

const getSessions = async (req, res) => {
  try {
    const result = await db.query(
      'SELECT * FROM sessions WHERE user_id = $1 ORDER BY date DESC',
      [req.user_id]
    );
    res.json(result.rows);
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

const updateSession = async (req, res) => {
  const { date, notes, name } = req.body;
  try {
    const result = await db.query(
      `UPDATE sessions SET date = COALESCE($1, date), notes = $2, name = $3
       WHERE session_id = $4 AND user_id = $5
       RETURNING *`,
      [date, notes, name, req.params.id, req.user_id]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'Session not found' });
    res.json(result.rows[0]);
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

const deleteSession = async (req, res) => {
  try {
    const result = await db.query(
      'DELETE FROM sessions WHERE session_id = $1 AND user_id = $2 RETURNING session_id',
      [req.params.id, req.user_id]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'Session not found' });
    res.status(204).send();
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

module.exports = { createSession, getSessions, updateSession, deleteSession };
