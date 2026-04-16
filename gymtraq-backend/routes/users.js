const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const controller = require('../controllers/usersController');

// Public
router.post('/', controller.signup);
router.post('/login', controller.login);
router.post('/forgot-password', controller.forgotPassword);

// Protected
router.get('/:id', auth, controller.getUser);
router.put('/:id', auth, controller.updateUser);
router.put('/:id/password', auth, controller.changePassword);
router.delete('/:id', auth, controller.deleteUser);

module.exports = router;
