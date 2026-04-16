const db = require('../db');

const createExercise = async (req, res) => {
  const { exercise_name, muscle_group } = req.body;
  if (!exercise_name) {
    return res.status(400).json({ error: 'exercise_name is required' });
  }
  try {
    const result = await db.query(
      'INSERT INTO exercises (exercise_name, muscle_group) VALUES ($1, $2) RETURNING *',
      [exercise_name, muscle_group ?? null]
    );
    res.status(201).json(result.rows[0]);
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

const getAllExercises = async (req, res) => {
  try {
    const result = await db.query('SELECT * FROM exercises ORDER BY exercise_name');
    res.json(result.rows);
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

module.exports = { createExercise, getAllExercises };
