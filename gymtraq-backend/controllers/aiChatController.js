const Anthropic = require('@anthropic-ai/sdk');
const db = require('../db');

const client = new Anthropic();

const MAX_MESSAGE_LENGTH = 4000; // chars — caps a single user turn
const HISTORY_TURNS = 20;        // most-recent messages sent as context

const BASE_SYSTEM = 'You are a personal gym coach inside GymTraq, an iOS fitness tracking app. Help users with workout advice, exercise form, nutrition tips, and motivation. Keep responses concise and practical.';

// Personalize the coach: recent training + body stats go into the system prompt
// so advice references the user's actual numbers. Failures fall back silently —
// a generic coach beats a broken chat.
async function buildUserContext(userId) {
  try {
    const [profileRes, recentRes] = await Promise.all([
      db.query('SELECT weight, height, age, sex FROM users WHERE user_id = $1', [userId]),
      db.query(
        `SELECT s.date, s.name, ex.exercise_name, en.reps, en.weight
         FROM sessions s
         JOIN entries en ON en.session_id = s.session_id
         JOIN exercises ex ON ex.exercise_id = en.exercise_id
         WHERE s.user_id = $1
         ORDER BY s.date DESC, en.exercise_id, en.set_number
         LIMIT 80`,
        [userId]
      ),
    ]);

    const lines = [];
    const p = profileRes.rows[0] || {};
    const body = [
      p.weight && `${p.weight}kg`,
      p.height && `${p.height}cm`,
      p.age && `age ${p.age}`,
      p.sex,
    ].filter(Boolean).join(', ');
    if (body) lines.push(`Body stats: ${body}`);

    // Group set rows into "date (name): Exercise 8x60kg, 8x60kg; ..." lines
    const byDate = new Map();
    for (const r of recentRes.rows) {
      const key = r.name ? `${r.date} (${r.name})` : r.date;
      if (!byDate.has(key)) byDate.set(key, new Map());
      const exMap = byDate.get(key);
      if (!exMap.has(r.exercise_name)) exMap.set(r.exercise_name, []);
      exMap.get(r.exercise_name).push(`${r.reps}x${r.weight}kg`);
    }
    const sessionLines = [...byDate].slice(0, 6).map(([key, exMap]) => {
      const exs = [...exMap].map(([name, sets]) => `${name} ${sets.join(', ')}`).join('; ');
      return `${key}: ${exs}`;
    });
    if (sessionLines.length) {
      lines.push('Recent workouts (newest first):', ...sessionLines);
    }

    if (!lines.length) return '';
    return `\n\nThe user's current data (reference it to personalize advice — cite their actual numbers, spot trends and plateaus):\n${lines.join('\n')}`;
  } catch {
    return '';
  }
}

const sendMessage = async (req, res) => {
  const { message } = req.body;
  if (!message || typeof message !== 'string' || !message.trim()) {
    return res.status(400).json({ error: 'message is required' });
  }
  if (message.length > MAX_MESSAGE_LENGTH) {
    return res.status(400).json({ error: `message must be ${MAX_MESSAGE_LENGTH} characters or fewer` });
  }
  try {
    // Fetch only the most recent turns — bounds token cost and context size.
    // The incoming message is NOT inserted yet: if the Claude call fails we must
    // not leave an orphaned user message with no reply in the history.
    const history = await db.query(
      'SELECT role, message FROM ai_chat_messages WHERE user_id = $1 ORDER BY message_id DESC LIMIT $2',
      [req.user_id, HISTORY_TURNS]
    );

    // Chronological order; the window can cut mid-pair and Claude requires the
    // first message to be from the user, so drop any leading assistant rows
    const past = history.rows.reverse();
    while (past.length && past[0].role !== 'user') past.shift();

    const messages = [
      ...past.map(row => ({ role: row.role, content: row.message })),
      { role: 'user', content: message }
    ];

    // Call Claude API — thinking disabled to keep coach replies fast and cheap
    const userContext = await buildUserContext(req.user_id);
    const response = await client.messages.create({
      model: 'claude-sonnet-5',
      max_tokens: 1024,
      thinking: { type: 'disabled' },
      system: BASE_SYSTEM + userContext,
      messages: messages
    });

    const textBlock = response.content.find(block => block.type === 'text');
    const aiReply = textBlock ? textBlock.text : 'Sorry, I could not generate a response.';

    // Persist user message + reply atomically, only after Claude succeeded
    const dbc = await db.connect();
    let saved;
    try {
      await dbc.query('BEGIN');
      await dbc.query(
        'INSERT INTO ai_chat_messages (message, role, user_id) VALUES ($1, $2, $3)',
        [message, 'user', req.user_id]
      );
      saved = await dbc.query(
        'INSERT INTO ai_chat_messages (message, role, user_id) VALUES ($1, $2, $3) RETURNING *',
        [aiReply, 'assistant', req.user_id]
      );
      await dbc.query('COMMIT');
    } catch (err) {
      await dbc.query('ROLLBACK');
      throw err;
    } finally {
      dbc.release();
    }

    res.status(201).json(saved.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
};

const getChatHistory = async (req, res) => {
  try {
    const result = await db.query(
      'SELECT * FROM ai_chat_messages WHERE user_id = $1 ORDER BY message_id',
      [req.user_id]
    );
    res.json(result.rows);
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

const deleteMessage = async (req, res) => {
  try {
    const result = await db.query(
      'DELETE FROM ai_chat_messages WHERE message_id = $1 AND user_id = $2 RETURNING message_id',
      [req.params.id, req.user_id]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'Message not found' });
    res.status(204).send();
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
};

module.exports = { sendMessage, getChatHistory, deleteMessage };
