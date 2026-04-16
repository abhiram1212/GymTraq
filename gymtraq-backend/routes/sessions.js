const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const controller = require('../controllers/sessionsController');

router.post('/', auth, controller.createSession);
router.get('/', auth, controller.getSessions);
router.put('/:id', auth, controller.updateSession);
router.delete('/:id', auth, controller.deleteSession);

module.exports = router;
