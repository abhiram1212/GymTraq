const db = require('../db');

const createExercise = async (req, res) => {
  const { exercise_name, muscle_group } = req.body;
  if (!exercise_name) {
    return res.status(400).json({ error: 'exercise_name is required' });
  }
  try {
    // Reject duplicates against everything this user can see (own + shared catalog)
    const dup = await db.query(
      `SELECT exercise_id FROM exercises
       WHERE LOWER(exercise_name) = LOWER($1) AND (user_id = $2 OR user_id IS NULL)`,
      [exercise_name.trim(), req.user_id]
    );
    if (dup.rows[0]) {
      return res.status(409).json({ error: 'An exercise with that name already exists' });
    }
    const result = await db.query(
      'INSERT INTO exercises (exercise_name, muscle_group, user_id) VALUES ($1, $2, $3) RETURNING *',
      [exercise_name.trim(), muscle_group ?? null, req.user_id]
    );
    res.status(201).json(result.rows[0]);
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

// Rename / re-categorize — own exercises only, shared catalog is read-only
const updateExercise = async (req, res) => {
  const { exercise_name, muscle_group } = req.body;
  if (!exercise_name) {
    return res.status(400).json({ error: 'exercise_name is required' });
  }
  try {
    const dup = await db.query(
      `SELECT exercise_id FROM exercises
       WHERE LOWER(exercise_name) = LOWER($1)
         AND (user_id = $2 OR user_id IS NULL)
         AND exercise_id <> $3`,
      [exercise_name.trim(), req.user_id, req.params.id]
    );
    if (dup.rows[0]) {
      return res.status(409).json({ error: 'An exercise with that name already exists' });
    }
    // Own exercises + the shared catalog (user_id IS NULL) are editable.
    // NOTE: catalog rows predate per-user ownership; before a real multi-user
    // launch, make them read-only again or copy-on-write per user.
    const result = await db.query(
      `UPDATE exercises SET exercise_name = $1, muscle_group = $2
       WHERE exercise_id = $3 AND (user_id = $4 OR user_id IS NULL)
       RETURNING *`,
      [exercise_name.trim(), muscle_group ?? null, req.params.id, req.user_id]
    );
    if (!result.rows[0]) {
      return res.status(404).json({ error: 'Exercise not found or not editable' });
    }
    res.json(result.rows[0]);
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

// Delete — own exercises only, and only if no logged sets reference it
const deleteExercise = async (req, res) => {
  try {
    const owned = await db.query(
      'SELECT exercise_id FROM exercises WHERE exercise_id = $1 AND (user_id = $2 OR user_id IS NULL)',
      [req.params.id, req.user_id]
    );
    if (!owned.rows[0]) {
      return res.status(404).json({ error: 'Exercise not found or not deletable' });
    }
    const used = await db.query(
      'SELECT 1 FROM entries WHERE exercise_id = $1 LIMIT 1',
      [req.params.id]
    );
    if (used.rows[0]) {
      return res.status(409).json({ error: 'This exercise is used in logged workouts and cannot be deleted' });
    }
    await db.query('DELETE FROM exercises WHERE exercise_id = $1', [req.params.id]);
    res.status(204).send();
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

const getAllExercises = async (req, res) => {
  try {
    // Return the shared seed catalog (user_id IS NULL) plus this user's own exercises
    const result = await db.query(
      'SELECT * FROM exercises WHERE user_id = $1 OR user_id IS NULL ORDER BY exercise_name',
      [req.user_id]
    );
    res.json(result.rows);
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

module.exports = { createExercise, getAllExercises, updateExercise, deleteExercise };
