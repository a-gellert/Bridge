-- Global gameplay and physics constants. Pure Lua (no Defold API): shared by the game and the headless tests.
local M = {}

-- Simulation
M.GRAVITY = -12            -- m/s^2, a bit stronger than real for a punchy feel
M.FIXED_DT = 1 / 60        -- one simulation step
M.SUBSTEPS = 12            -- XPBD substeps per step (one constraint pass each)
M.MAX_STEPS_PER_FRAME = 3  -- avoid the spiral of death on slow devices
M.LIN_DAMPING = 0.03       -- fraction of velocity lost per second (air drag)
M.STRESS_TAU = 0.035       -- seconds: beam stress low-pass (breaks need sustained load, not one spike)
M.NODE_MASS = 6            -- kg added to every free joint (bolts)

-- Building
M.GRID = 1                 -- meters between snap points
M.DECK_HALF = 0.15         -- half thickness of drivable decks (collision and ground flush offset)
M.BUILD_PLANE_Z = 1.3      -- touches are projected on the visible front face of the bridge
M.MIN_BEAM = 0.99          -- shortest allowed beam (one grid step)
M.LENGTH_SLACK = 1.055     -- beams may be 5.5% longer than max_len, so (3,1) fits a 3 m road and (4,1) a 4 m beam
M.UNDO_LIMIT = 60
M.TOUCH_TOLERANCE_PX = 34  -- finger radius used to pick nodes/beams (virtual px)
M.DRAG_THRESHOLD_PX = 10   -- movement before a press becomes a drag

-- Contacts
M.TIRE_COMPLIANCE = 1 / 3.0e5 -- m/N: tire springiness (spreads wheel impacts, ~1-2 cm sink)

-- Surfaces
M.BOUNCE_SPEED = 10.5      -- normal speed given by a bounce pad (m/s)
M.BOOST_ACCEL = 26         -- extra forward acceleration on boost pads (m/s^2)

-- Run rules
M.RUN_TIME_LIMIT = 50      -- seconds before a run counts as stuck
M.STUCK_TIME = 4.5         -- seconds without forward progress
M.STUCK_PROGRESS = 0.35    -- meters needed to reset the stuck timer
M.FLIP_TIME = 1.3          -- seconds upside down before failing
M.PORTAL_RADIUS = 1.25
M.PORTAL_COOLDOWN = 0.6
M.PORTAL_FLOOR = 1.2       -- portal ring center height above the floor it stands on

-- Camera
M.CAM_FOV = math.rad(34)
M.CAM_PITCH = math.rad(9)  -- looking slightly down
M.CAM_YAW = math.rad(-7)   -- looking slightly from the front-left
M.CAM_MIN_VIEW = 7         -- min visible world height (zoomed in)
M.CAM_MAX_VIEW = 60        -- max visible world height (zoomed out)
M.CAM_DRIVE_SPAN = 20      -- world width the drive camera keeps visible

return M
