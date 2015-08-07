-- Localizing
local floor = math.floor
local metatable = setmetatable

local Node = {}
Node.__index = Node
Node.__tostring = function( tab )
	local vec = tab._pos
	return floor( vec.x ) .. "," .. floor( vec.y ) .. "," .. floor( vec.z )
end

function Node:new( pos )
	return metatable( { _pos = pos }, Node )
end

metatable( Node, { __call = function( self, ... ) return self:new( ... ) end } )

function Node:setParent( node )
	self._p = node
	return self
end

function Node:getParent()
	return self._p
end

function Node:setFcost( ... )
	if !... then
		self._f = self._g + self._h
		return self
	end
	self._f = ...
	return self
end

function Node:getFcost()
	return self._f or math.huge
end

function Node:setGcost( g )
	self._g = g
	return self
end

function Node:getGcost()
	return self._g or 0
end

function Node:setHcost( h )
	self._h = h
	return self
end

function Node:getHcost()
	return self._h or math.huge
end

function Node:setClosed( bool )
	self._closed = bool
	return self
end

function Node:getClosed()
	return self._closed or false
end

local function euclideanH( v, v2 )
	return v:DistToSqr( v2 )
	-- I assume that the engine function will perform faster than doing the arithmetic in lua, please correct me if I'm wrong
	/*
	local deltaX = v2.x - v.x
	local deltaY = v2.y - v.y
	local deltaZ = v2.z - v.z
	-- shamelessly copied from some stackoverflow post
	return math.sqrt( deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ )
	*/
	-- return math.abs( v.x - v2.x ) + math.abs( v.y - v2.y ) + math.abs( v.z - v2.z )
end

local function snapTo( grid, num, func )
	return func( num / grid ) * grid
end

local vmet = FindMetaTable( "Vector" )

function vmet:snapTo( grid, ... )
	local func = ( {...} or {} )[1] or math.Round
	local vec = Vector( snapTo( grid, self.x, func ), snapTo( grid, self.y, func ), /*snapTo( grid, self.z, func )*/self.z )
	//self.x, self.y/*, self.z*/ = vec.x, vec.y//, vec.z
	return vec
end

function Node:getPos()
	return self._pos
end

local Heap = {}
Heap.__index = Heap

function Heap:new()
	return metatable( { _t = {}, _sortfunc = function( a, b, ... )
		if ... then return a:getFcost() <= b:getFcost() end
		return a:getFcost() >= b:getFcost()
	end }, Heap )
end

metatable( Heap, { __call = function( self, ... ) return self:new( ... ) end } )

function Heap:setSortFunc( func )
	self._sortfunc = func
	return self
end

function Heap:pop()
	local popval = self._t[1]
	self._t[1] = self._t[ #self._t ]
	self._t[ #self._t ] = nil
	local sfunc = self._sortfunc
	local v = 1
	while true do
		local heap = self._t
		local u = v
		local u_2 = 2 * u
		local u_2_1 = u_2 + 1
		if u_2_1 <= #heap then
			if sfunc( heap[u], heap[ u_2 ] ) then v = u_2 end
			if sfunc( heap[v], heap[ u_2_1 ] ) then v = u_2_1 end
		elseif u_2 <= #heap then
			if sfunc( heap[u], heap[ u_2 ] ) then v = u_2 end
		end
		if u != v then
			local temp = heap[u]
			self._t[u] = heap[v]
			self._t[v] = temp
		else
			break
		end
	end
	return popval
end

function Heap:resort( num )
	local heapind = num
	local sfunc = self._sortfunc
	while heapind > 1 do
		local heap = self._t
		local half = floor( heapind * 0.5 )
		if sfunc( heap[ heapind ], heap[ half ], true ) then
			local par = half
			local temp = heap[ par ]
			self._t[ par ] = heap[ heapind ]
			self._t[ heapind ] = temp
			heapind = par
		else
			break
		end
	end
	return self
end

function Heap:push( val )
	self._t[ #self._t + 1 ] = val
	local heapind = #self._t
	local sfunc = self._sortfunc
	while heapind > 1 do
		local heap = self._t
		local half = floor( heapind * 0.5 )
		if sfunc( heap[ heapind ], heap[ half ], true ) then
			local par = half
			local temp = heap[ par ]
			self._t[ par ] = heap[ heapind ]
			self._t[ heapind ] = temp
			heapind = par
		else
			break
		end
	end
	return self
end

Pathfinder = {}
Pathfinder.__index = Pathfinder

-- function: Creates a new Pathfinder object
-- arguments: start vector, end vector
-- returns: Pathfinder object

function Pathfinder:new( v, v2 )
	local m = { _weight = 10, _gridsize = 16, _step = 18, _mask = MASK_PLAYERSOLID, _avoidwater = true, _dropheight = 13, _target = v2, _min = Vector( -16, -16, 0 ), _max = Vector( 16, 16, 72 ), _open = Heap():push( Node( v ) ), _vars = {}, _closed = {}, _taken = {}, _fincallback = function( path ) return end, _stkcallback = function( partpath ) print( "Pathfinder stuck!" ) end, _filter = function( ent ) return !ent:IsPlayer() end }
	return metatable( m, Pathfinder )
end

-- This is here to allow for you to call Pathfinder() which is a shortened version of Pathfinder:new()

metatable( Pathfinder, { __call = function( self, ... ) return self:new( ... ) end } )

-- function: Gets target position of a pathfinder
-- arguments: nil
-- returns: target vector

function Pathfinder:getTarget()
	return self._target	
end

-- function: Sets callback function which is called on path completion
-- arguments: function which is called with one argument, which is a table of vectors which is the path
-- returns: Pathfinder object to allow chaining functions

function Pathfinder:setFinishFunc( func )
	self._fincallback = func
	return self
end

-- function: Sets filter used in pathing process
-- arguments: filter function/table/entity to be used to ignore in traces
-- returns: Pathfinder object to allow chaining functions

function Pathfinder:setFilter( func )
	self._filter = func
	return self
end

-- function: Sets callback function which is called when the pathfinder gets stuck
-- arguments: function which is valled with one argument, which is a table of vectors (or an empty table at times) which is a partial path leading to the lowest fcost node
-- returns: Pathfinder object to allow chaining functions

function Pathfinder:setStuckFunc( func )
	self._stkcallback = func
	return self
end

-- function: Sets step size, telling the pathfinder what objects it can scale
-- arguments: number step size
-- returns: Pathfinder object to allow chaining functions

function Pathfinder:setStepSize( size )
	self._step = size
	return self
end

-- function: Gets step size used with the pathfinder
-- arguments: nil
-- returns: number step size

function Pathfinder:getStepSize()
	return self._step
end

-- function: Sets mask used with the traces checking collisions between two nodes
-- arguments: MASK_ enum
-- returns: Pathfinder object to allow chaining functions

function Pathfinder:setMask( enum )
	self._mask = enum
	return self
end

-- function: Gets mask used by the pathfinder
-- arguments: nil
-- returns: MASK_ enum

function Pathfinder:getMask()
	return self._mask
end

-- function: Sets distance between each node
-- arguments: number distance between nodes
-- returns: Pathfinder object to allow chaining functions

function Pathfinder:setGridSize( size )
	self._gridsize = size
	return self
end

-- function: Gets spacing between nodes
-- arguments: nil
-- returns: number spacing between nodes

function Pathfinder:getGridSize()
	return self._gridsize
end

-- function: Sets the amount that the gcost of a node effects the pathfinders decisions
-- the gcost is a culmative number stored on each node, and every nodes gcost is it's parents gcost plus the weight
-- arguments: number weight
-- returns: Pathfinder object to allow chaining functions

function Pathfinder:setWeight( n )
	self._weight = n
	return self
end

-- function: Gets the weight used, see above for explanation
-- arguments: nil
-- returns: number weight

function Pathfinder:getWeight()
	return self._weight
end

-- function: Sets the lower corner of the hull used in detecting obstacles between nodes
-- arguments: vector in local coordinates
-- returns: Pathfinder object to allow chaining functions

function Pathfinder:setHullMin( vec )
	self._min = vec
	return self
end

-- function: Gets the lower corner of the hull in local coords
-- arguments: nil
-- returns: vector in local coordinates

function Pathfinder:getHullMin()
	return self._min
end

-- function: Sets the upper corner of the hull used in detecting obstacles between nodes
-- arguments: vector in local coordinates
-- returns: Pathfinder object to allow chaining functions

function Pathfinder:setHullMax( vec )
	self._max = vec
	return self
end

-- function: Gets the upper corner of the hull in local coords
-- arguments: nil
-- returns: vector in local coordinates

function Pathfinder:getHullMax()
	return self._max
end

-- function: Sets whether the pathfinder should avoid water which is > 40 units deep
-- arguments: boolean
-- returns: Pathfinder object to allow chaining functions

function Pathfinder:setAvoidWater( bool )
	self._avoidwater = bool
	return self
end

-- function: Gets whether or not the pathfinder is avoiding water
-- arguments: nil
-- returns: boolean

function Pathfinder:getAvoidWater()
	return self._avoidwater
end

-- function: Sets how far the pathfinder can drop down something, drop height you input * step size for pathfinder = amount it's willing to fall
-- arguments: number
-- returns: Pathfinder object to allow chaining functions

function Pathfinder:setDropHeight( num )
	self._dropheight = num
	return self
end

-- function: Gets how far the pathfinder can drop down something
-- arguments: nil
-- returns: number

function Pathfinder:getDropHeight()
	return self._dropheight
end

-- function: Internal function used in the pathing process which gets the open table in the form of a binary heap
-- arguments: nil
-- returns: binary heap

function Pathfinder:getOpen()
	return self._open
end

-- function: Internal function used in the pathing process which gets the closed table
-- arguments: nil
-- returns: table

function Pathfinder:getClosed()
	return self._closed
end

function Pathfinder:findWalkablePosition( vec )
	local min = self:getHullMin()
	local max = self:getHullMax()
	local mask = self:getMask()
	local gsize = self:getGridSize()
	local filter = self._filter
	local svec = Vector( 0, 0, self:getStepSize() )
	local attempts = {
		vec:snapTo( gsize ),
		vec:snapTo( gsize, floor ),
		vec:snapTo( gsize, math.ceil ),
		Vector( snapTo( gsize, vec.x, math.floor ), snapTo( gsize, vec.y, math.Round ), vec.z  ),
		Vector( snapTo( gsize, vec.x, math.ceil ), snapTo( gsize, vec.y, math.Round ), vec.z  ),
		Vector( snapTo( gsize, vec.x, math.Round ), snapTo( gsize, vec.y, math.floor ), vec.z  ),
		Vector( snapTo( gsize, vec.x, math.Round ), snapTo( gsize, vec.y, math.ceil ), vec.z  ),
		Vector( snapTo( gsize, vec.x, math.floor ), snapTo( gsize, vec.y, math.ceil ), vec.z  ),
		Vector( snapTo( gsize, vec.x, math.ceil ), snapTo( gsize, vec.y, math.floor ), vec.z  ),
	}
	for i = 1, #attempts do
		local pos = attempts[i]
		local down = util.TraceHull( { mins = Vector( min.x, min.y, 0 ), maxs = Vector( max.x, max.y, 0 ), start = pos + svec, endpos = pos - svec * self:getDropHeight(), mask = mask, filter = filter } ) 
		if !down.Hit then continue end
		if down.StartSolid then continue end
		pos = down.HitPos
		if util.TraceHull( { mins = min, maxs = max, start = pos, endpos = pos, mask = mask, filter = filter } ).Hit then continue end
		vec.x, vec.y, vec.z = pos.x, pos.y, pos.z
		return pos
	end
end

-- Pathfinder:start documented at end of file

local is_hooked = false
local running = {}

local function UnHookThink()
	hook.Remove( "Think", "DoPathfinding" )
	is_hooked = false
end

local groundnodes = {
	Vector(  0,  1, 0 ),
	Vector(  1,  0, 0 ),
	Vector(  0, -1, 0 ),
	Vector( -1,  0, 0 ),
	Vector(  1,  1, 0 ),
	Vector(  1, -1, 0 ),
	Vector( -1, -1, 0 ),
	Vector( -1,  1, 0 ),
}
local speccosts = {}
for k, v in pairs( groundnodes ) do
	if v.x != 0 and v.y != 0 then
		speccosts[k] = 5
		continue
	end
end

local function HookThink()
	hook.Add( "Think", "DoPathfinding", function()
		local count = #running
		if count < 1 then UnHookThink() return end
		local accel = math.ceil( 30/count )
		for u, v in pairs( running ) do
			local path = v
			local min = path:getHullMin()
			local max = path:getHullMax()
			local mask = path:getMask()
			local gsize = path:getGridSize()
			local step = path:getStepSize()
			local target = path:getTarget()
			local filter = path._filter
			local weight = path:getWeight()
			local svec = Vector( 0, 0, step )
			local dropheight = path:getDropHeight()
			local nodecount = 0
			local bsize = math.abs( min.x ) + max.x -- this assumes that the hull is square shaped two dimensionally
			while nodecount <= accel do
				local open = path:getOpen()
				local closed = path:getClosed()
				local parent = open:pop()
				if !parent then
					table.remove( running, u )
					local btnode
					local lowf = math.huge
					for i = 1, #closed do
						local node = closed[i]
						if node:getFcost() < lowf then
							btnode = node
							lowf = node:getFcost()
						end
					end
					local pathnodes = {}
					if btnode then
						while btnode != closed[1] do
							table.insert( pathnodes, 1, btnode:getPos() )
							btnode = btnode:getParent()
						end
					end
					path._stkcallback( pathnodes )
					table.Empty( path )
					break
				end
				closed[ #closed + 1 ] = parent
				parent:setClosed( true )
				parent:setHcost( nil )
				local ppos = parent:getPos()
				local breakout = false
				for i = 1, #groundnodes do
					local pos = groundnodes[i] * gsize + ppos
					local down = util.TraceHull( { mins = Vector( min.x, min.y, 0 ), maxs = Vector( max.x, max.y, 0 ), start = pos + svec, endpos = pos - svec * dropheight, mask = mask, filter = filter } )
					-- if down.MatType == MAT_SNOW then cost = cost + 5 end
					if !down.Hit then continue end
					if down.StartSolid then continue end
					if down.HitNormal.z < 0.7 /*math.NormalizeAngle( down.HitNormal:Angle().p ) >= -44*/ then continue end
					local child = Node( down.HitPos + Vector( 0, 0, 1 ) )
					pos = child:getPos()
					local cost = speccosts[i] or 0
					if !util.TraceHull( { start = pos + svec, endpos = pos - svec, mins = Vector( min.x, min.y, 0 ) * 0.5, maxs = Vector( max.x, max.y, 0 ) * 0.5, mask = mask, filter = filter } ).Hit then
						cost = cost + 100
					end
					-- ^ is here so that it doesn't get too close to an edge
					child:setParent( parent )
					down = nil -- saves memory maybe?
					local p = parent:getParent()
					if p then
						local pd = p:getPos() - ppos
						local d = ppos - pos
						if pd.x != d.x or pd.y != d.y then cost = cost + 10 end -- penalize direction changes
					end
					p = nil -- saves memory maybe?
					cost = cost + weight + parent:getGcost()
					child:setGcost( cost )
					child:setHcost( euclideanH( pos, target ) )
					child:setFcost()
					cost = nil -- saves memory maybe?
					if util.TraceHull( { mins = min, maxs = max, start = pos, endpos = pos, mask = mask, filter = filter } ).Hit then continue end
					if path:getAvoidWater() and util.TraceLine( { start = pos + Vector( 0, 0, 40 ), endpos = pos + Vector( 0, 0, max.z ), mask = MASK_WATER, filter = filter } ).Hit then continue end
					local take = path._taken[ tostring( child ) ]
					if take then
						if take:getClosed() then continue end
						if child:getGcost() < take:getGcost() then
							take:setParent( parent )
							take:setGcost( child:getGcost() )
							take:setFcost()
							for i = 1, #open do
								if open[i] == take then
									open:resort( i )
									break
								end
							end
						end
						continue
					end
					if bsize > gsize then -- skip seeing if the two nodes can see eachother if the gsize is less than bbox size as the check if the node can actually occupy the space should do the same thing
						local retry = { start = pos, endpos = ppos, mask = mask, filter = filter, mins = min + svec, maxs = max }
						if util.TraceHull( retry ).Hit then
							retry.start = pos
							retry.endpos = ppos + svec
							if util.TraceHull( retry ).Hit then
								continue
							end
						end
					end
					if math.abs( ppos.z - pos.z ) > step then
						local retry = { start = ppos, endpos = Vector( pos.x, pos.y, ppos.z ), mask = mask, filter = filter, mins = min + svec, maxs = max }
						if util.TraceHull( retry ).Hit then -- falloff detection
							continue
						end
					end
					nodecount = nodecount + 1
					open:push( child )
					local vec = Vector( floor( pos.x ), floor( pos.y ), floor( pos.z ) )
					for i = -step, step do
						local vec = Vector( vec.x, vec.y, vec.z + i )
						path._taken[ vec.x .. "," .. vec.y .. "," .. vec.z ] = child
					end
					if target.x != pos.x or target.y != pos.y or math.abs( target.z - pos.z ) > step * dropheight then continue end
					if util.TraceHull( { start = pos, endpos = target, mask = mask, filter = filter, mins = min + svec, maxs = max } ).Hit then continue end -- check if node can actually go to end node
					local btnode = parent
					local pathnodes = {}
					table.insert( pathnodes, target )
					while btnode != closed[1] do
						table.insert( pathnodes, 1, btnode:getPos() )
						btnode = btnode:getParent()
					end
					path._fincallback( pathnodes )
					table.Empty( path )
					table.remove( running, u )
					breakout = true
					break
				end
				if breakout then break end
			end
		end
	end )

	is_hooked = true
end

-- function: Starts the pathfinder with the configured settings
-- arguments: nil
-- returns: nil

function Pathfinder:start()
	self:findWalkablePosition( self._open._t[1]._pos )
	self:findWalkablePosition( self._target )
	table.insert( running, self )
	if !is_hooked then HookThink() end
end

function Pathfinder:stop()
	table.remove( running, table.KeyFromValue( self ) )
	table.Empty( self )
end