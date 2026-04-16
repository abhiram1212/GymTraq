require('dotenv').config();
const express = require('express');

const usersRouter = require('./routes/users');
const exercisesRouter = require('./routes/exercises');
const sessionsRouter = require('./routes/sessions');
const entriesRouter = require('./routes/entries');
const aiChatRouter = require('./routes/aiChat');

const app = express();
app.use(express.json());

app.use('/users', usersRouter);
app.use('/exercises', exercisesRouter);
app.use('/sessions', sessionsRouter);
app.use('/entries', entriesRouter);
app.use('/ai-chat', aiChatRouter);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`GymTraq server running on port ${PORT}`));
