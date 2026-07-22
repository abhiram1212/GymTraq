-- Seed the shared exercise catalog + apply pending column migrations.
-- Safe to run on an existing database. Exercises inserted with user_id = NULL
-- are the shared catalog visible to every user (see exercisesController.getAllExercises).

-- 1. Ensure the columns the current backend expects exist
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS muscle_group TEXT;
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES users(user_id) ON DELETE CASCADE;
ALTER TABLE sessions  ADD COLUMN IF NOT EXISTS name TEXT;

-- 2. Seed common exercises (only if the catalog is empty, so re-running is safe)
INSERT INTO exercises (exercise_name, muscle_group, user_id)
SELECT name, grp, NULL
FROM (VALUES
    -- Chest
    ('Barbell Bench Press',        'Chest'),
    ('Incline Barbell Bench Press','Chest'),
    ('Dumbbell Bench Press',       'Chest'),
    ('Incline Dumbbell Press',     'Chest'),
    ('Chest Fly',                  'Chest'),
    ('Cable Crossover',            'Chest'),
    ('Push-Up',                    'Chest'),
    -- Back
    ('Deadlift',                   'Back'),
    ('Barbell Row',                'Back'),
    ('Bent-Over Dumbbell Row',     'Back'),
    ('Lat Pulldown',               'Back'),
    ('Pull-Up',                    'Back'),
    ('Seated Cable Row',           'Back'),
    ('T-Bar Row',                  'Back'),
    ('Shrug',                      'Back'),
    -- Legs
    ('Back Squat',                 'Legs'),
    ('Front Squat',                'Legs'),
    ('Leg Press',                  'Legs'),
    ('Romanian Deadlift',          'Legs'),
    ('Leg Curl',                   'Legs'),
    ('Leg Extension',              'Legs'),
    ('Walking Lunge',              'Legs'),
    ('Bulgarian Split Squat',      'Legs'),
    ('Calf Raise',                 'Legs'),
    ('Hip Thrust',                 'Legs'),
    -- Shoulders
    ('Overhead Press',             'Shoulders'),
    ('Seated Dumbbell Press',      'Shoulders'),
    ('Arnold Press',               'Shoulders'),
    ('Lateral Raise',              'Shoulders'),
    ('Front Raise',                'Shoulders'),
    ('Rear Delt Fly',              'Shoulders'),
    ('Upright Row',                'Shoulders'),
    -- Biceps
    ('Barbell Curl',               'Biceps'),
    ('Dumbbell Curl',              'Biceps'),
    ('Hammer Curl',                'Biceps'),
    ('Preacher Curl',              'Biceps'),
    ('Concentration Curl',         'Biceps'),
    -- Triceps
    ('Tricep Pushdown',            'Triceps'),
    ('Overhead Tricep Extension',  'Triceps'),
    ('Skull Crusher',              'Triceps'),
    ('Close-Grip Bench Press',     'Triceps'),
    ('Tricep Kickback',            'Triceps'),
    ('Dip',                        'Triceps'),
    -- Core
    ('Plank',                      'Core'),
    ('Crunch',                     'Core'),
    ('Hanging Leg Raise',          'Core'),
    ('Russian Twist',              'Core'),
    ('Cable Crunch',               'Core'),
    ('Ab Rollout',                 'Core')
) AS seed(name, grp)
WHERE NOT EXISTS (SELECT 1 FROM exercises);
