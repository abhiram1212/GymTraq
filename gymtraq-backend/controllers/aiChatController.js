const Anthropic = require('@anthropic-ai/sdk');
const db = require('../db');

const client = new Anthropic();

const sendMessage = async (req, res) => {
  const { message } = req.body;
  if (!message) {
    return res.status(400).json({ error: 'message is required' });
  }
  try {
    // Save the user's message
    await db.query(
      'INSERT INTO ai_chat_messages (message, role, user_id) VALUES ($1, $2, $3)',
      [message, 'user', req.user_id]
    );

    // Fetch full conversation history
    const history = await db.query(
      'SELECT role, message FROM ai_chat_messages WHERE user_id = $1 ORDER BY message_id',
      [req.user_id]
    );

    // Format history for Claude API
    const messages = history.rows.map(row => ({
      role: row.role,
      content: row.message
    }));

    // Call Claude API
    const response = await client.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1024,
      system: 'You are a personal gym coach inside GymTraq, an iOS fitness tracking app. Help users with workout advice, exercise form, nutrition tips, and motivation. Keep responses concise and practical.',
      messages: messages
    });

    const aiReply = response.content[0].text;

    // Save AI reply
    const result = await db.query(
      'INSERT INTO ai_chat_messages (message, role, user_id) VALUES ($1, $2, $3) RETURNING *',
      [aiReply, 'assistant', req.user_id]
    );

    res.status(201).json(result.rows[0]);
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
