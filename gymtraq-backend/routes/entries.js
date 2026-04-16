const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const controller = require('../controllers/entriesController');

// Bulk operations — must be defined BEFORE /:id to avoid Express matching
// "by-exercise" or "replace" as an :id param
router.delete('/by-exercise', auth, controller.deleteEntriesByExercise);
router.put('/replace', auth, controller.replaceExercise);

router.post('/', auth, controller.createEntry);
router.get('/', auth, controller.getEntries);
router.put('/:id', auth, controller.updateEntry);
router.delete('/:id', auth, controller.deleteEntry);

module.exports = router;
