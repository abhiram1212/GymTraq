const db = require('../db');

const createEntry = async (req, res) => {
  const { set_number, reps, weight, session_id, exercise_id } = req.body;
  if (!set_number || !reps || weight == null || !session_id || !exercise_id) {
    return res.status(400).json({ error: 'set_number, reps, weight, session_id, and exercise_id are required' });
  }
  try {
    const sessionCheck = await db.query(
      'SELECT session_id FROM sessions WHERE session_id = $1 AND user_id = $2',
      [session_id, req.user_id]
    );
    if (!sessionCheck.rows[0]) return res.status(403).json({ error: 'Forbidden' });

    const result = await db.query(
      'INSERT INTO entries (set_number, reps, weight, session_id, exercise_id) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [set_number, reps, weight, session_id, exercise_id]
    );
    res.status(201).json(result.rows[0]);
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

const getEntries = async (req, res) => {
  const { session_id } = req.query;
  try {
    let query, params;
    if (session_id) {
      const sessionCheck = await db.query(
        'SELECT session_id FROM sessions WHERE session_id = $1 AND user_id = $2',
        [session_id, req.user_id]
      );
      if (!sessionCheck.rows[0]) return res.status(403).json({ error: 'Forbidden' });
      query = 'SELECT * FROM entries WHERE session_id = $1 ORDER BY exercise_id, set_number';
      params = [session_id];
    } else {
      query = `SELECT e.* FROM entries e
               JOIN sessions s ON s.session_id = e.session_id
               WHERE s.user_id = $1
               ORDER BY s.date DESC, e.set_number`;
      params = [req.user_id];
    }
    const result = await db.query(query, params);
    res.json(result.rows);
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

const updateEntry = async (req, res) => {
  const { set_number, reps, weight, exercise_id } = req.body;
  try {
    const result = await db.query(
      `UPDATE entries e SET
         set_number = COALESCE($1, e.set_number),
         reps = COALESCE($2, e.reps),
         weight = COALESCE($3, e.weight),
         exercise_id = COALESCE($4, e.exercise_id)
       FROM sessions s
       WHERE e.entry_id = $5
         AND e.session_id = s.session_id
         AND s.user_id = $6
       RETURNING e.*`,
      [set_number, reps, weight, exercise_id, req.params.id, req.user_id]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'Entry not found' });
    res.json(result.rows[0]);
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

const deleteEntry = async (req, res) => {
  try {
    const result = await db.query(
      `DELETE FROM entries e
       USING sessions s
       WHERE e.entry_id = $1
         AND e.session_id = s.session_id
         AND s.user_id = $2
       RETURNING e.entry_id`,
      [req.params.id, req.user_id]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'Entry not found' });
    res.status(204).send();
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

// Delete all entries for a specific exercise within a session
const deleteEntriesByExercise = async (req, res) => {
  const { session_id, exercise_id } = req.body;
  if (!session_id || !exercise_id) {
    return res.status(400).json({ error: 'session_id and exercise_id are required' });
  }
  try {
    const sessionCheck = await db.query(
      'SELECT session_id FROM sessions WHERE session_id = $1 AND user_id = $2',
      [session_id, req.user_id]
    );
    if (!sessionCheck.rows[0]) return res.status(403).json({ error: 'Forbidden' });

    await db.query(
      'DELETE FROM entries WHERE session_id = $1 AND exercise_id = $2',
      [session_id, exercise_id]
    );
    res.status(204).send();
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

// Replace one exercise with another across all sets in a session
const replaceExercise = async (req, res) => {
  const { session_id, old_exercise_id, new_exercise_id } = req.body;
  if (!session_id || !old_exercise_id || !new_exercise_id) {
    return res.status(400).json({ error: 'session_id, old_exercise_id, new_exercise_id are required' });
  }
  try {
    const sessionCheck = await db.query(
      'SELECT session_id FROM sessions WHERE session_id = $1 AND user_id = $2',
      [session_id, req.user_id]
    );
    if (!sessionCheck.rows[0]) return res.status(403).json({ error: 'Forbidden' });

    await db.query(
      'UPDATE entries SET exercise_id = $1 WHERE session_id = $2 AND exercise_id = $3',
      [new_exercise_id, session_id, old_exercise_id]
    );
    res.status(204).send();
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

module.exports = { createEntry, getEntries, updateEntry, deleteEntry, deleteEntriesByExercise, replaceExercise };
