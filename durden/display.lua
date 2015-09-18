-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: The display- set of functions tracks connected displays
-- and respond to plug/unplug events. They are also responsible for the
-- creation of tiler- window managers and manual or automatic migration
-- between window managers and their corresponding display.
--

local displays = {
	simulate_md = false
};

local function get_disp(name)
	local found, foundi;
	for k,v in ipairs(displays) do
		if (v.name == name) then
			found = v;
			foundi = k;
			break;
		end
	end
	return found, foundi;
end

local function autohome_spaces(ndisp)
	for disp in all_displays() do
		local tiler = disp.tiler;
		if (tiler and tiler ~= ndisp.tiler) then
			for i=1,10 do
				if (tiler.spaces[i] and tiler.spaces[i].home and
					tiler.spaces[i].home == ndisp.name) then
					tiler.spaces[i]:migrate(ndisp.tiler);
				end
			end
		end
	end
end


function durden_display_state(action, id)
	if (displays[1].tiler.debug_console) then
		displays[1].tiler.debug_console:system_event("display event: " .. action);
	end

-- display subsystem and input subsystem are connected when it comes
-- to platform specific actions e.g. virtual terminal switching, assume
-- keystate change between display resets.
	if (action == "reset") then
		warning("reset");
		dispatch_meta_reset();
		return;
	end

	if (action == "added") then
		local ids = {};

		for k,v in pairs(id) do
			if (not table.find_i(ids, v.displayid)) then
				table.insert(ids, v.displayid);
			end
		end

		for k,v in ipairs(ids) do
			local data, hash = video_displaydescr(v);
			if (data) then
				print("hash is", hash);
			else
				print("no data on", v);
			end
		end

		if (displays[id] == nil) then
			displays[id] = {};
-- find out if there is a known profile for this display, activate
-- corresponding desired resolution, set mapping, create tiler, color
-- correction profile, RGB tuning etc.
		end
	elseif (action == "removed") then
		warning("removed " .. tostring(id));
		if (displays[id] == nil) then
			warning("lost unknown display: " .. tostring(id));
			return;
		end

-- sweep workspaces and migrate back to previous display (and toggle
-- rendertarget output on/off), destroy tiler, save settings, if workspace slot
-- is occupied, add to "orphan-" list.
	end
end

function display_manager_init()
	displays[1] = {
		tiler = tiler_create(VRESW, VRESH, {});
		w = VRESW,
		h = VRESH,
		name = "default"
	};

	displays.simple = gconfig_get("display_simple");
	displays.main = 1;
	displays[1].tiler.name = "default";

	if (not displays.simple) then
		displays[1].rt = displays[1].tiler:set_rendertarget(true);
		set_context_attachment(displays[1].rt);
		mouse_querytarget(displays[1].rt);
		show_image(displays[1].rt);
	end
end

-- if we're in "simulated" multidisplay- mode, for development and testing,
-- there's the need to dynamically add and remove to see that workspace
-- migration works smoothly.
local function redraw_simulate()
	if (not displays.simulate_md) then
		return;
	end

	local ac = 0;
	for i=1,#displays do
		if (not displays[i].orphan) then
			ac = ac + 1;
		end
	end

	if (valid_vid(displays.txt_anchor)) then
		delete_image(displays.txt_anchor);
	end
	displays.txt_anchor = null_surface(1,1);
	show_image(displays.txt_anchor);

	set_context_attachment(WORLDID);
	local font_sz = gconfig_get("font_sz");

	if (ac == 0) then
		for i=1,#displays do
			hide_image(displays[i].rt);
		end
	else
		local w = VRESW / ac;
		local x = 0;

		for i=1,#displays do
			move_image(displays[i].rt, x, 0);
			resize_image(displays[i].rt, w, VRESH - font_sz);
			show_image(displays[i].rt);
			local rstr = string.format("%s%d @ %d * %d- %s",
				i == displays.main and "\\#00ff00" or "\\#ffffff", i,
				displays[i].w, displays[i].h,
				displays[i].name and displays[i].name or "no name"
			);
			local text = render_text(rstr);
			show_image(text);
			link_image(text, displays.txt_anchor);
			move_image(text, x, VRESH - font_sz);
			x = x + w;
		end
	end
	set_context_attachment(displays[displays.main].rt);
end

function display_add(name, width, height)
	local found = get_disp(name);

-- for each workspace, check if they are homed to the display
-- being added, and, if space exists, migrate
	if (found) then
		found.orphan = false;
		image_resize_storage(found.rt, found.w, found.h);
	else
		set_context_attachment(WORLDID);
		local nd = {tiler = tiler_create(width, height, {})};
		table.insert(displays, nd);
		nd.w = width;
		nd.h = height;
		nd.name = name;
		nd.tiler.name = name;
		nd.rt = nd.tiler:set_rendertarget(true);
-- in the real case, we'd switch to the last known resolution
-- and then set the display to match the rendertarget
		show_image(nd.rt);
		found = nd;
		set_context_attachment(displays[displays.main].rt);
	end

	autohome_spaces(found);
	redraw_simulate();
end

-- linear search all spaces in all displays except disp and
-- return the first empty one that is found
local function find_free_display(disp)
	for i,v in ipairs(displays) do
		if (not v.orphan and v ~= disp) then
			for j=1,10 do
				if (v.tiler:empty_space(j)) then
					return v;
				end
			end
		end
	end
end

-- sweep all used workspaces of the display and find new parents
local function autoadopt_display(disp)
	for i=1,10 do
		if (not disp.tiler:empty_space(i)) then
			local ddisp = find_free_display(disp);
			local space = disp.tiler.spaces[i];
			space:migrate(ddisp.tiler);
			space.home = disp.name;
		end
	end
end

function display_remove(name)
	local found, foundi = get_disp(name);

	if (not found) then
		warning("attempt remove unknown display");
		return;
	end

	found.orphan = true;
	image_resize_storage(found.rt, 32, 32);
	hide_image(found.rt);

	if (gconfig_get("ws_autoadopt") and autoadopt_display(found)) then
		found.orphan = false;
	end

	if (foundi == displays.main) then
		display_cycle_active(ws);
	end

	redraw_simulate();
end

-- should only be used for debugging, disables normal multidisplay
-- and adds simulated ones on the main rendertarget
function display_simulate()
	displays.simulate_md = true;
end

function display_cycle_active()
	local nd = displays.main;
	repeat
		nd = (nd + 1 > #displays) and 1 or (nd + 1);
	until (nd == displays.main or not displays[nd].orphan);
	displays.main = nd;
	set_context_attachment(displays[displays.main].rt);
	mouse_querytarget(displays[displays.main].rt);
	redraw_simulate();
end

function display_migrate_wnd(wnd, dstname)
	local dsp2 = get_disp(dstname);
	if (not dsp2) then
		return;
	end

	wnd:migrate(dsp2.tiler);
end

-- migrate the ownership of a single workspace to another display
function display_migrate_ws(disp, dstname)
	local dsp2 = get_disp(dstname);
	if (not dsp2) then
		return;
	end

	if (#disp.spaces[disp.space_ind].children > 0) then
		disp.spaces[disp.space_ind]:migrate(dsp2.tiler);
	end
end

-- the active displays is the rendertarget that will (initially) create new
-- windows, though they can be migrated immediately afterwards. This is because
-- both mouse_ implementation and new object attachment points are a global
-- state.
function active_display()
	return displays[displays.main].tiler;
end

function all_displays()
	local i = 0;
	local c = #displays;
	return function()
		i = i + 1;
		return (i <= c) and displays[i] or nil;
	end
end

function all_windows()
	local tbl = {};
	for i,v in ipairs(displays) do
		for j,k in ipairs(v.tiler.windows) do
			table.insert(tbl, k);
		end
	end

	local i = 0;
	local c = #tbl;
	return function()
		i = i + 1;
		return (i <= c) and tbl[i] or nil;
	end
end

function displays_alive(filter)
	local res = {};

	for k,v in ipairs(displays) do
		if (not v.orphan and (not filter or k ~= displays.main)) then
			table.insert(res, v.name);
		end
	end
	return res;
end

function display_tick()
	for k,v in ipairs(displays) do
		if (not v.orphan) then
			v.tiler:tick();
		end
	end
end
