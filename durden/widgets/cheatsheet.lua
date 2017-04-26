--
-- Simple "cheat sheet" helper that, based on vim titlebar
-- ident content tries to load the approriate cheat sheet(s)
--
-- should also allow clickable "force spawn new?"
--

local tsupp = system_load("widgets/support/text.lua")();
local sheets = {};

local function reglob()
	local lst = glob_resource("widgets/cheatsheets/*.txt");
	for k,v in ipairs(lst) do
		if (sheets[v] == nil) then
-- open_rawresource, read up to n lines and add to sheets, blocking
			local lines = {};
			if (open_rawresource("widgets/cheatsheets/" .. v)) then
				local line;
				repeat
					line = read_rawresource();
					if (line) then
						table.insert(lines, line);
					end
				until(#lines > 256 or not line);
				close_rawresource();
			end
			if (#lines > 1) then
				sheets[v] = lines;
			end
		end
	end
end

local function probe(ctx, yh)
	local fd = active_display().font_delta;
	local tw, th = text_dimensions(fd .. "(probe)");
	local ul = math.floor(yh / th);

-- divide the cheatsheets across groups, always split on
-- sheet no matter the amount of elements versus vertical space
	local ct = {};
	for k,v in ipairs(ctx.sheetset) do
		local nt = {};
		for i=2,#v do
			local step = false;
			if (string.len(v[i]) == 0) then
				step = #nt > 0;
			else
				table.insert(nt, v[i]);
				step = #nt >= ul;
			end

			if (step) then
				table.insert(ct, nt);
				nt = {};
			end
		end
		table.insert(ct, nt);
	end
	ctx.group_cache = ct;
	return #ct;
end

local function show(ctx, anchor, ofs)
	return tsupp.show(ctx, anchor, ctx.group_cache[ofs], 1, #ctx.group_cache[ofs]);
end

local function destroy()
end

-- for sub-paths, only check path activation. For the root- level,
-- check both the program supplied id and the user- supplied optional tag
local function ident(ctx, pathid, strid, tag)
	local strset = {};
	if (string.len(pathid) > 1) then
		table.insert(strset, pathid);
	else
		if (strid) then
			table.insert(strset, strid);
		end
		if (tag) then
			table.insert(strset, tag);
		end
	end

	ctx.sheetset = {};
	for k,v in pairs(sheets) do
		if (v[1] == "*") then
			table.insert(ctx.sheetset, v);
		else
			for i,j in ipairs(strset) do
				if string.match(j, v[1]) then
					table.insert(ctx.sheetset, v);
					break;
				end
			end
		end
	end
	return #ctx.sheetset > 0;
end

reglob();

return {
	name = "cheatsheet",
	paths = {ident},
	show = show,
	probe = probe,
	destroy = destroy
};