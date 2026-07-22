require('dotenv').config();
const express = require('express');
const helmet = require('helmet');

const { generalLimiter } = require('./middleware/rateLimit');

const usersRouter = require('./routes/users');
const exercisesRouter = require('./routes/exercises');
const sessionsRouter = require('./routes/sessions');
const entriesRouter = require('./routes/entries');
const aiChatRouter = require('./routes/aiChat');

const app = express();
app.use(helmet());
app.use(express.json({ limit: '1mb' }));
app.use(generalLimiter);

// Health check — open this in a browser to confirm the server is reachable
app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.use('/users', usersRouter);
app.use('/exercises', exercisesRouter);
app.use('/sessions', sessionsRouter);
app.use('/entries', entriesRouter);
app.use('/ai-chat', aiChatRouter);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`GymTraq server running on port ${PORT}`));
