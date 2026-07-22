const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const { authLimiter } = require('../middleware/rateLimit');
const controller = require('../controllers/usersController');

// Public
router.post('/', authLimiter, controller.signup);
router.post('/login', authLimiter, controller.login);
router.post('/forgot-password', authLimiter, controller.forgotPassword);
router.post('/reset-password', authLimiter, controller.resetPassword);

// Protected
router.get('/:id', auth, controller.getUser);
router.put('/:id', auth, controller.updateUser);
router.put('/:id/password', auth, controller.changePassword);
router.delete('/:id', auth, controller.deleteUser);

module.exports = router;
