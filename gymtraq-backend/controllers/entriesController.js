const db = require('../db');

const createEntry = async (req, res) => {
  const { set_number, reps, weight, session_id, exercise_id } = req.body;
  if (set_number == null || reps == null || weight == null || !session_id || !exercise_id) {
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

// Delete a set and renumber the exercise's remaining sets (1..n) in one transaction.
// Renumbering used to be N separate PUTs fired from the client — racy and unreliable.
const deleteEntry = async (req, res) => {
  const dbc = await db.connect();
  try {
    await dbc.query('BEGIN');
    const del = await dbc.query(
      `DELETE FROM entries e
       USING sessions s
       WHERE e.entry_id = $1
         AND e.session_id = s.session_id
         AND s.user_id = $2
       RETURNING e.session_id, e.exercise_id`,
      [req.params.id, req.user_id]
    );
    if (!del.rows[0]) {
      await dbc.query('ROLLBACK');
      return res.status(404).json({ error: 'Entry not found' });
    }
    const { session_id, exercise_id } = del.rows[0];
    await dbc.query(
      `UPDATE entries SET set_number = sub.rn
       FROM (SELECT entry_id, ROW_NUMBER() OVER (ORDER BY set_number) AS rn
             FROM entries WHERE session_id = $1 AND exercise_id = $2) sub
       WHERE entries.entry_id = sub.entry_id`,
      [session_id, exercise_id]
    );
    await dbc.query('COMMIT');
    res.status(204).send();
  } catch {
    await dbc.query('ROLLBACK');
    res.status(500).json({ error: 'Server error' });
  } finally {
    dbc.release();
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

// Replace one exercise with another across all sets in a session.
// If the target exercise already has sets in the session, the merged group
// would end up with duplicate set numbers — renumber 1..n in the same transaction.
const replaceExercise = async (req, res) => {
  const { session_id, old_exercise_id, new_exercise_id } = req.body;
  if (!session_id || !old_exercise_id || !new_exercise_id) {
    return res.status(400).json({ error: 'session_id, old_exercise_id, new_exercise_id are required' });
  }
  const dbc = await db.connect();
  try {
    const sessionCheck = await dbc.query(
      'SELECT session_id FROM sessions WHERE session_id = $1 AND user_id = $2',
      [session_id, req.user_id]
    );
    if (!sessionCheck.rows[0]) {
      dbc.release();
      return res.status(403).json({ error: 'Forbidden' });
    }

    await dbc.query('BEGIN');
    await dbc.query(
      'UPDATE entries SET exercise_id = $1 WHERE session_id = $2 AND exercise_id = $3',
      [new_exercise_id, session_id, old_exercise_id]
    );
    await dbc.query(
      `UPDATE entries SET set_number = sub.rn
       FROM (SELECT entry_id, ROW_NUMBER() OVER (ORDER BY set_number, entry_id) AS rn
             FROM entries WHERE session_id = $1 AND exercise_id = $2) sub
       WHERE entries.entry_id = sub.entry_id`,
      [session_id, new_exercise_id]
    );
    await dbc.query('COMMIT');
    res.status(204).send();
  } catch {
    await dbc.query('ROLLBACK');
    res.status(500).json({ error: 'Server error' });
  } finally {
    dbc.release();
  }
};

module.exports = { createEntry, getEntries, updateEntry, deleteEntry, deleteEntriesByExercise, replaceExercise };
