const rateLimit = require('express-rate-limit');

// Tight limiter for auth endpoints — blunts brute-force on login / forgot-password
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 min
  max: 20,
  message: { error: 'Too many attempts, try again later' },
  standardHeaders: true,
  legacyHeaders: false,
});

// AI chat limiter — caps Claude API spend per user
const aiLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 min
  max: 15,
  message: { error: 'Slow down — too many messages' },
  standardHeaders: true,
  legacyHeaders: false,
});

// General limiter for everything else
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
});

module.exports = { authLimiter, aiLimiter, generalLimiter };
