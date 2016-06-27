--
-- Default touch-pad profile, without this script available,
-- the touchpad support will be disabled. Copy and change 'label',
-- name and 'matchflt' to support customized profiles for different
-- devices.
--

return {
	label = "Wacom Intuos S 2",
	name = "wacom_s2",

-- device string pattern or explicit string for auto- selecting profile,
-- not needed for the special 'default' name
	matchflt = "Wacom Intuos S 2 Pen",

-- track / remember sample values to figure out device range
	autorange = false,

-- invalid default range due to "autorange"
	range = {0, 0, 15200, 9500},

-- other option is 'absmouse'
		classifier = "relmouse",

-- ignore samples until we get one inside (>= [1,2] <= [3,4])
	activation = {0.0, 0.0, 1.0, 1.0},

-- "pre-mouse" acceleration
	scale_x = 1.0,
	scale_y = 1.0,

-- mask to disable certain button indices for digital events
	submask = 0xffff,

-- ignore samples between state changes for a number of ticks
	default_cooldown = 2,

-- window for drag-vs-swipe evaluation
	mt_eval = 5,

-- useful when combining touch displays, track pad and regular mouse,
-- motion block stops cursor movement (gestures only) and warp_press
-- makes digital events warp to last known device-specific x,y, send a
-- press and then jump back
	motion_block = false,
	warp_press = false,

-- reset touch- tracking after n ticks of no input samples
	timeout = 1,

-- minimum weighted normalized distance to move for gesture to register
	swipe_threshold = 0.2,
	drag_threshold = 0.2,

-- menu path to trigger on gestures, valid are:
-- swipe(n)_(dir) where (n) == 2,3,4... and (dir) == up,down,left,right
-- drag(n)_(dir) where (n) == 2,3,4... and (dir) == up,down,left,right
	gestures = {
	}
};
