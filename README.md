# GM-A-Pathfinder
Lua coded A* pathfinder for Garry's Mod

Usage:

``` lua

local p = Pathfinder( startpos, endpos )

p:setFinishFunc( function( path )
	-- what to do when finished, with path being table of vectors going from start to end
end )

p:setStuckFunc( function( path )
        -- what to do when stuck, with path being table of vectors going from start to "closest" to end node
end )

p:start()

```

There're many more functions to affect how the pathfinder works and what should be considered walkable, like changing hull size, changing gridsize etc. You can find these functions in the lua file, and the functions are commented.

WARNING:

Stuff gets realllly weird when running more than one pathfinder at a time (on server at least, not sure about client)
