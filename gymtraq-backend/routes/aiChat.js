const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const controller = require('../controllers/aiChatController');

router.post('/', auth, controller.sendMessage);
router.get('/', auth, controller.getChatHistory);
router.delete('/:id', auth, controller.deleteMessage);

module.exports = router;
