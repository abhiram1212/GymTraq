const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const controller = require('../controllers/exercisesController');

router.post('/', auth, controller.createExercise);
router.get('/', auth, controller.getAllExercises);

module.exports = router;
