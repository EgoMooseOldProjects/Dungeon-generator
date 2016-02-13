--[[
	Dungeon generator
	Dungeon generator module for Roblox.
	@author EgoMoose
	@link N/A
	@date 12/02/2016
--]]

------------------------------------------------------------------------------------------------------------------------------
--// Setup

local cardinal = {
	north = Vector2.new(0, -1);
	east = Vector2.new(1, 0);
	south = Vector2.new(0, 1);
	west = Vector2.new(-1, 0);
};

local enums = {
	empty = 0;
	hall = 1;
	room = 2;
	junction = 3;
};

------------------------------------------------------------------------------------------------------------------------------
--// Functions

function contains(tab, element, keys)
	local focus = keys or tab;
	for key, val in pairs(focus) do
		local index = keys and val or key;
		if tab[index] == element then
			return index;
		end;
	end;
end;

------------------------------------------------------------------------------------------------------------------------------
--// Classes

function class_tile(pos, enum, region)
	local this = {};
	
	-- properties
	
	this.position = pos;
	this.enum = enum;
	this.region = region;
	this.directions = {
		north = false;
		east = false;
		south = false;
		west = false;
	};
	
	-- return
	
	return this;
end;

function class_tiles()
	local this = setmetatable({}, {});
	
	-- private functions
	
	local function init()
		-- this table
		local mt = getmetatable(this);
		mt.__index = function(t, k) return rawget(t, tostring(k)); end;
		mt.__newindex = function(t, k, v) rawset(t, tostring(k), v); end;
	end;
	
	-- public functions
	
	function this:setTiles(origin, enum, region, width, height)
		local width, height = width or 0, height or 0;
		for x = 0, width do
			for y = 0, height do
				local pos = origin + Vector2.new(x, y);
				if not this[pos] then
					this[pos] = class_tile(pos, enum, region);
				else
					this[pos].position = pos;
					this[pos].enum = enum;
					this[pos].region = region;
					this[pos].directions = {
						north = false;
						east = false;
						south = false;
						west = false;
					};
				end;
			end;
		end;
	end;
	
	function this:getEnum(pos)
		local tile = this[pos];
		if tile then
			return tile.enum;
		end;
	end;
	
	function this:getAllTiles(enum)
		local tiles = {};
		for pos, tile in pairs(this) do
			if (type(tile) == "table" and tile.enum == enum) or not enum then
				table.insert(tiles, tile);
			end;
		end;
		return tiles;
	end;
	
	function this:getAllTilesIgnore(enum)
		local tiles = {};
		for pos, tile in pairs(this) do
			if (type(tile) == "table" and tile.enum ~= enum) then
				table.insert(tiles, tile);
			end;
		end;
		return tiles;
	end;
	
	-- return
	
	init();
	return this;
end;

function class_rectangle(x, y, width, height)
	local this = {};
	
	-- properties
	
	this.position = Vector2.new(x, y);
	this.size = Vector2.new(width, height);
	
	this.corners = {
		this.position;
		this.position + Vector2.new(width, 0);
		this.position + Vector2.new(0, height);
		this.position + this.size;
	};
	
	-- private functions	
	
	local function dot2d(a, b)
		return a.x * b.x + a.y * b.y;
	end;
	
	local function getAxis(c1, c2)
		local axis = {};
		axis[1] = c1[2] - c1[1];
		axis[2] = c1[2] - c1[3];
		axis[3] = c2[1] - c2[4];
		axis[4] = c2[1] - c2[2];
		return axis;
	end;
	
	-- public functions
	
	function this:collidesWith(other)
		-- this method of collision is called separating axis theorem
		-- you can read about it here: http://www.dyn4j.org/2010/01/sat/
		-- understanding this requires knowledge of the dot product: 
		-- http://wiki.roblox.com/index.php?title=User:EgoMoose/The_scary_thing_known_as_the_dot_product
		local scalars = {};
		local axis = getAxis(self.corners, other.corners);
		for i = 1, #axis do
			for i2, set in pairs({self.corners, other.corners}) do
				scalars[i2] = {};
				for _, point in pairs(set) do
					local v = dot2d(point, axis[i].unit);
					table.insert(scalars[i2], v);
				end;
			end;
			local s1max, s1min = math.max(unpack(scalars[1])), math.min(unpack(scalars[1]));
			local s2max, s2min = math.max(unpack(scalars[2])), math.min(unpack(scalars[2]));
			if s2min > s1max or s2max < s1min then
				return false;
			end;
		end;
		return true;
	end;
	
	-- return	
	
	return this;
end;

function class_dungeonGen()
	local this = {};
	
	-- properties
	
	this.roomSize = 3; -- potential size of rooms
	this.enums = enums; -- don't change
	this.lastSeed = nil; -- don't change
	this.windingPercent = 0; -- curvy maze? (0 - 100)
	this.attemptRoomNum = 20; -- how many rooms should be attempted to fit in the bounds
	this.loadBuffer = math.huge; -- how many actions between every wait (use this to, y'know, not freeze ur computer)
	this.genMapDirections = true; -- if not needed turn this off! it saves so much script performance
	this.seed = function() return tick(); end; -- returns what's used in randomseed
	this.bounds = { -- size of map
		width = 100;
		height = 100;
	};
	
	
	-- private properties
	
	local currentRegion = 0;
	local tiles = class_tiles();
	
	-- private functions
	
	local function newRegion()
		currentRegion = currentRegion + 1;
	end;
	
	local function boundsContains(pos)
		if pos.x > this.bounds.width or pos.y > this.bounds.height or pos.x < 0 or pos.y < 0 then
			return false;
		end;
		return true;
	end;
	
	local function canCarve(pos, direction)
		if not boundsContains(pos + direction * 3) then
			return false;
		end;
		return tiles:getEnum(pos + direction * 2) == 0;
	end;	
	
	local function createRooms()
		local rooms = {};
		
		-- attempt as many rooms as possible
		for i = 1, this.attemptRoomNum do
			-- randomly shape the room
			local size = math.random(this.roomSize) * 2 + 1;
			local rectangularity = math.random(1 + math.floor(size/2)) * 2;
			local width, height = size, size;
			if math.random(2) == 1 then
				width = width + rectangularity;
			else
				height = height + rectangularity;
			end;
			
			-- build room as rectangle class
			local x = math.random(math.floor((this.bounds.width - width)/2)) * 2 + 1;
			local y = math.random(math.floor((this.bounds.height - height)/2)) * 2 + 1;
			local room = class_rectangle(x, y, width, height);
			
			-- check for collisions
			local overlapping = false;
			for _, other in pairs(rooms) do
				if room:collidesWith(other) then
					overlapping = true;
					break;
				end;
			end;
			
			-- if no overlap then add as a room
			if not overlapping then
				newRegion();
				table.insert(rooms, room);
				tiles:setTiles(room.position, enums.room, currentRegion, room.size.x - 1, room.size.y - 1); -- subtract 1?
			end;
		end;
	end;
	
	local function growMaze(pos)
		tiles:setTiles(pos, enums.hall, currentRegion);
		local c = 0;
		local cells, lastDirection = {tiles[pos]};
		
		-- spanning tree algorithm
		while #cells > 0 do
			c = c + 1;
			local potential = {};
			local cell = cells[#cells];
			
			-- check the 4 cardinal directions
			for name, direction in pairs(cardinal) do
				if canCarve(cell.position, direction) then
					table.insert(potential, direction);
				end;
			end;
			
			-- pick a direction if plausible
			if #potential > 0 then
				local direction;
				if contains(potential, lastDirection) and math.random(100) > this.windingPercent then
					direction = lastDirection
				else
					direction = potential[math.random(#potential)];
				end;
				
				-- set the tile
				tiles:setTiles(cell.position + direction, enums.hall, currentRegion)
				tiles:setTiles(cell.position + direction * 2, enums.hall, currentRegion)
				
				table.insert(cells, tiles[cell.position + direction * 2]);
				
				-- prepare to repeat
				lastDirection = direction;
			else
				table.remove(cells, #cells);
				lastDirection = nil;
			end;
			-- wait buffer
			if c % this.loadBuffer == 0 then
				wait();
			end;
		end;
	end;
	
	local function connectRegions()
		local connectors = {};
		local connectedPoints = {};
		
		-- collect regions that can be connected
		for _, tile in pairs(tiles:getAllTiles(enums.empty)) do
			-- count unqiue regions
			local regions, count = {}, 0;
			for name, direction in pairs(cardinal) do
				local ntile = tiles[tile.position + direction];
				if ntile and ntile.enum > 0 and ntile.region then
					regions[ntile.region] = true;
				end;
			end;
			local open = {};
			for region, _ in pairs(regions) do 
				count = count + 1; 
				table.insert(open, region);
			end;
			-- if two unique regions store as a possible outcome
			if count == 2 then
				table.insert(connectedPoints, tile);
				connectors[tostring(tile.position)] = open;
			end;
		end;
		
		-- place our connections/smooth
		while #connectedPoints > 1 do
			-- pick random junction
			local index = math.random(#connectedPoints)
			local tile = connectedPoints[index];
			local region = connectors[tostring(tile.position)];
			
			tiles:setTiles(tile.position, enums.junction, nil);
			table.remove(connectedPoints, index);
			
			-- don't remove all similar sources
			for i, otile in pairs(connectedPoints) do
				if i ~= index then
					local open = connectors[tostring(otile.position)];
					if contains(open, region[1]) and contains(open, region[2]) then
						table.remove(connectedPoints, i);
					end;
				end;
			end;
			
			-- remove tiles that are side by side
			for i, otile in pairs(tiles:getAllTiles(enums.junction)) do
				if otile.position ~= tile.position then
					if (otile.position - tile.position).magnitude < 1.1 then
						tiles:setTiles(otile.position, enums.empty, nil);
					end;
				end
			end;
		end;
	end;
	
	local function removeDeadEnds()
		-- collect/set initial data
		local done, c = false, 0;
		local maze = tiles:getAllTiles(enums.hall);
		
		-- check as long as is needed
		while not done do
			done = true;
			for i, tile in pairs(maze) do
				c = c + 1;
				local exits = 0;
				
				-- check all potential spaces
				for name, direction in pairs(cardinal) do
					local ntile = tiles[tile.position + direction];
					if ntile and ntile.enum ~= enums.empty then
						exits = exits + 1;
					end;
				end;
				if c % this.loadBuffer == 0 then
					wait();
				end;
				
				-- if only single place to move then it's a dead end
				if exits <= 1 then
					table.remove(maze, i);
					tiles:setTiles(tile.position, enums.empty, nil);
					done = false;
					break;
				end;
			end;
		end;
	end;
	
	local function mapDirections()
		local c = 0;
		for i, tile in pairs(tiles:getAllTilesIgnore(enums.empty)) do
			c = c + 1;
			for name, direction in pairs(cardinal) do
				local ntile = tiles[tile.position + direction];
				if ntile and ntile.enum ~= enums.empty then
					tile.directions[name] = true;
				end;
			end;
			if c % this.loadBuffer == 0 then
				wait();
			end;
		end;
	end;
	
	-- public functions
	
	function this:generate()
		-- set randome seed
		this.lastSeed = this.seed();
		math.randomseed(this.lastSeed);	
			
		-- generate initial
		tiles:setTiles(Vector2.new(0, 0), enums.empty, currentRegion, self.bounds.width, self.bounds.height);
		createRooms();
		newRegion();
		
		-- start maze
		for _, tile in pairs(tiles:getAllTiles(enums.empty)) do
			-- must be odd number position
			local pos = tile.position;
			if pos.x % 2 == 1 and pos.y % 2 == 1 and tile.enum == enums.empty then
				growMaze(pos);
				--break;
			end;
		end;
		
		-- smooth and get find final
		connectRegions();
		removeDeadEnds();
		if this.genMapDirections then
			mapDirections();
		end;
		
		-- return tile set
		return tiles;
	end;
	
	-- return
	
	return this;
end;

------------------------------------------------------------------------------------------------------------------------------
--// Run

return class_dungeonGen;