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
