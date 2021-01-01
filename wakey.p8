pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- init tab
-----------
debug = true
assert_durer = debug

version = 0.9

sound = true
s_die = 6
s_enemy_kill = 2
s_key_seq = 14
s_highlow = 12
s_key_pickup = 10
s_drain = 63
s_start = 5
s_menu = 19

die_duration = 60
game_over_delay = 60

t,r,b,l="t","r","b","l"
l_swim="l_swim"
r_swim="r_swim"
idle="idle"
falling="falling"
jump="jump"
die="die"
enemy_die="enemy_die"
enemy_missile="enemy_missile"
-- note: animates from ceil(0.1..<#) 
-- todo pad all > 1 to 4?
anim={
	idle={128,129},
	t={131},
	r={144,145,146,147},
	b={131},
	l={144,145,146,147},
	r_swim={135,136,137,136},
	l_swim={135,136,137,136},
	falling={163,164},
	jump={130},
	die={132,133,134},
	
	["enemy"]={97},
	enemy_die={94,95,112},

	[enemy_missile]={170},  
}

enemy_limit = 3
enemy_die_duration = 15
persist_mass = 2
enemy_chance = 0.99

key_homes = {{12,10},{9,4},{6,4},{3,10},{3,6},{6,8},{9,8},{12,6},{3,8},{6,6},{9,6},{12,8},{12,4},{9,10},{6,10},{3,4}}
drain_rate = 1/8  -- todo relate to w_h and given time?
drain_noise_freq = 8 -- "
key_seq = {
	{10,7},
	{11,6},

	{2,15},
	{3,14},
	
	{16,1},
	{5,12},
	{9,8},
	{4,13},

	-- rows
	{16,3,2,13},
	{5,10,11,8},
	{9,6,7,12},
	{4,15,14,1},

	-- cols
	{16,5,9,4},
	{3,10,6,15},
	{2,11,7,14},
	{13,8,12,1},

	-- diagonals
	{16,10,7,1},
	{4,6,11,13},

	-- pre-corners
	{5,9,8,12},
	{3,2,15,14},

	-- corners	
	{16,13,4,1},

	-- kites	
	{3,5,11,15},
	{15,9,7,3},
	{2,10,8,14},
	{14,6,12,2},

	-- split rows	
	{16,3,14,1},
	{5,10,7,12},
	{9,6,11,8},
	{2,13,4,15},

	-- split cols	
	{16,5,12,1},
	{3,10,7,14},
	{2,11,6,15},
	{9,4,13,8},

	-- cross ways
	{3,8,14,9},
	{2,8,15,9},
	{3,5,12,14},
	{2,5,12,15},

	-- cross diags	
	{3,11,6,14},
	{2,10,7,15},
	{5,6,11,12},
	{9,10,7,8},
	
	-- y
	{16,2,10,6},
	{4,14,6,10},
	{3,13,11,7},
	{15,1,7,11},
		
	-- quadrants
	{16,3,5,10},
	{2,13,11,8},
	{9,6,4,15},
	{7,12,14,1},

	-- centre quad	
	{10,11,6,7},
}
if (assert_durer) printh("durer:"..#key_seq)
key_seq_dur = 0.8  -- seconds each

w_h = 1000
room_margin = 8  -- e.g. 4 -> leave top and bottom 1/4 free of rooms
room_chance = 0.92  -- todo adjust if room_margin or w_h changes
level_size = w_h / 10
level_points = 50
w_default_brick = 59
w_default_row = {w_default_brick,0,0,0,0,0,0,0,0,0,0,0,0,0,0,w_default_brick}
w_water_brick=10
w_default_row_water = {w_default_brick,10,10,10,10,10,10,10,10,10,10,10,10,10,10,w_default_brick}
w_start_brick = 141

pl_start_y = 7
enemy_kill=2
key_points=200
wake_max=16
wake_colour={12,2,1,6,13}
-- todo remove wake_last_y = 0
wake_decay = 16
scroll_dy = 0.2  --note: 0.3 needs better collision resolution
--scroll_dy = 0.1

default_energy = 1
default_energy_use = default_energy/3
recharge_factor = 1/0.6 -- key to feel = difficulty level
default_energy_recharge = default_energy_use * recharge_factor
min_energy = 1
low_energy = min_energy * 10
max_energy_factor = 40
max_energy = default_energy * max_energy_factor

w_g_y = 0.1  -- gravity
max_ledge_gap = max_energy_factor

points_limit = 32000

if debug then
	if true then -- small
		w_h = 100
		room_margin = 20  
  room_chance = 0.05 
	 max_ledge_gap = 10 -- < max_energy = too easy
	end
	if true then -- fast finish
	--key_seq_dur = 0.1
	--drain_rate = 1/2
	end
	enemy_chance = 0.995
--w_g_y = 0
end

durer_sequence_length = (#key_seq+1) * key_seq_dur * 30
key_seq_each = durer_sequence_length/#key_seq


function _init(auto)
 last = time()
 if auto then  -- player restart
		if (sound) sfx(s_start)  
		_update = _update_game
		_draw = _draw_game
 else
		_update = _update_intro
		_draw = _draw_intro
	end

	w = {}	-- shaft world def (sparse)
	actor = {} --all actors in world
	enemy = {} --all active enemies (links to actor)

 wy=(w_h/2)
	wdy = 0
 water_level = wy + pl_start_y+3 
 room_range_start = w_h/room_margin
	room_range_end = (w_h - w_h/room_margin)
	durer_room_y = water_level+3
 wx=0
	last_ledge = 0
 extra_lives=2
 assert(abs(last_ledge - (water_level+3)) > max_ledge_gap*2, "max_ledge_gap needs to be smaller to place key room")
	assert(room_margin > 2)
	 
	make_world(w_h)

	points=0
 highest=wy
 lowest=wy
	wake = {}
 clear_wake()
	wake_last=0
	wake_start=0
	wake[wake_start]={-1,-1,-1}

	pl=make_actor(4,pl_start_y)
	pl.dir=r
 pl.state=idle
 pl.frame=1
 pl.inertia=0.82
 pl.bounce=0.07
 pl.energy = max_energy
 pl.lives = 3
 
 pl.room = nil -- nil = main shaft
	pl.keys = {false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false}
	pl.key_count = 0
	if debug then
		--pl.keys = {true,true,true,true,true,true,true,true,true,true,true,true,true,false,false,true,}
		--pl.key_count = #pl.keys -2  -- 15 and 14 are already in the room
		
		if assert_durer then
		 -- assert key_seq are unique
			local ksc = {}
			for ks in all(key_seq) do
			 local c={}
			 local sum = 0
			 for k,v in pairs(ks) do
				 sum+=v
			 	c[k]=v
			 end
				local kss = strjoin(",",ks)
			 if (#ks == 4)	assert(sum==34, kss.." != 34")
				if (#ks == 2) assert(sum==17, kss.." != 17")
				sort(ks)
				kss = strjoin(",",ks)  -- sorted - normalised
				assert(ksc[kss] == nil, kss.." already in keq_seq")
				ksc[kss]=true
				--printh("s:"..kss)
			end
			--printh("key_seq is unique with #:"..#ksc)
			--assert(#ksc==#key_seq)
		end
	end
	-- collected and placed in durer room - we have 14 key rooms and place 2 already (15 + 14)
	durer_keys = {false,false,false,false,false,false,false,false,false,false,false,false,false,true,true,false}

 durer_sequence = nil
 draining_sequence = nil

	show_credits = false
 
	if debug then
	 printh("mem "..stat(0))  -- in k
	end
	
	if (sound and not auto) music(29)
end


-->8
-- update tab
function control_player(pl)

	if (durer_sequence!=nil and durer_sequence!=-1) return  -- wait

	-- note: +1 for smooth top row upward scrolling
	local in_water = pl.y + wy + pl.dy - w_g_y +1 > water_level 
	--printh("*"..(pl.y + wy + pl.dy - w_g_y) .."..".. water_level )

	if pl.state == die then
	 -- note: dying - no control and no recovery
		if pl.t > die_duration then
		 -- reset for next time
		 -- todo move to new_life
		 -- todo play sound
		 -- todo maybe location reset? or is fall enough?
			pl.state = idle
		end
	else
		-- we are alive and have control
		pl.state = idle	

	 -- how fast to accelerate
	 local accel = 0.20
	 if btn(⬅️) then
	 	pl.dx -= accel/2 
	 	pl.dir = l
	 	pl.state = l
	 end
	 if btn(➡️) then
	  pl.dx += accel/2
	 	pl.dir = r
	 	pl.state = r
	 end
	 if btn(⬆️) then
		 if pl.energy > min_energy then
		  pl.dy -= accel 
		 	if pl.state != t then
			 	if pl.dir != t then
				 	pl.state = jump
			 	else
				 	pl.state = t
			 	end
			 end
		 	pl.dir = t
		 	pl.energy -= default_energy_use
		 end --else --'fall'
	 	--printh("!"..pl.energy)
	 end
	 if btn(⬇️) then
		 if pl.energy > min_energy then
		  pl.dy += accel 
		 	if pl.state != b then
			 	if pl.dir != b then
				 	pl.state = jump
			 	else
				 	pl.state = b
				 end
			 end
	 		pl.dir = b
		 	pl.energy -= default_energy_use
		 end --else --'fall'
	 end
	
	
		if not btn(⬇️) and in_water then
	 	pl.energy += default_energy_recharge
		end
		if not btn(⬆️) and not in_water then
			--printh("!*"..pl.energy)
	 	pl.energy += default_energy_recharge
		end
		if pl.energy > max_energy then
			pl.energy = max_energy
		end
		
		if btn(❎) and pl.energy > min_energy then
			if (pl.dy < 0 and btn(⬆️)) or (pl.dy > 0 and btn(⬇️)) then
				wake_last += 1
				if (wake_last > wake_max) wake_last = 1
				if pl.dy < 0 then
					wake[wake_last] = {pl.x,pl.y+0.5,pl.t}
				else
					wake[wake_last] = {pl.x,pl.y-1.5,pl.t}
				end
				--if btnp(❎) then
				if wake_start == 0 then
					wake_start=wake_last
				end
				-- todo use extra energy?
				--printh("w "..wake_start.." "..wake_last.." "..wake[wake_last][1]..","..wake[wake_last][2])
			end
		else
				--if wake_start != 0 then
				if wake_last != 0 then
					--wake_start=0
					wake_last += 1
					if (wake_last > wake_max) wake_last = 1
			  wake[wake_last] = {-1,-1,-1}
			  wake_last = 0
				 --printh("wend ")
			 end
		end
		--todo remove wake_last_y = pl.y+wy
	
 end
 
	-- todo move to _draw?
	if pl.room == nil then
		wdy = 0
	 if pl.y < 7 then
		 if true then --not solid_pl then
			 wdy-=scroll_dy
			end
		 pl.y=7
	 elseif pl.y > 9 then
		 if true then --not solid_pl then
			 wdy+=scroll_dy
			end
		 pl.y=9
	 end
	 -- todo move_camera(wdy)
	 wy += wdy
	 -- shift everything else to suit
	 for a in all(actor) do
	 	a.y -= wdy
	 end
	 for a in all(wake) do
	 	a[2] -= wdy
	 end
	 -- todo end move_camera
	-- else in a fixed room
	end
	
 -- play a sound if moving
 -- (every 4 ticks)
 
 --if (abs(pl.dx)+abs(pl.dy) > 0.1
 --    and (pl.t%4) == 0) then
 -- sfx(1)
 --end

	--printh(pl.y + wy + pl.dy - w_g_y .. " .. ".. water_level)	
	if in_water and pl.y + wy > water_level then
		--printh("swimming")
	 -- todo idle float anim?
		if pl.state == l then
			pl.state = l_swim
		elseif pl.state == r then
			pl.state = r_swim
		end
	end

	-- todo revisit 
	local solid_pl
	--printh("so far "..pl.state)
	if in_water and pl.y + wy -1 > water_level then
		--printh("falling in water check")
		--printh(pl.dy)
		if pl.dy < -0.1 then
			--printh(" falling up "..pl.dy)
			if pl.state != t and pl.state != jump then
				--solid_pl = solid_a(pl, 0, pl.dy+wdy-w_g_y) 
				solid_pl = solid_a(pl, 0, pl.dy-w_g_y) 
				if not solid_pl and pl.state != die then
				 pl.state = falling
				end
			end
		end
	elseif pl.y + wy + 1 < water_level then
		--printh("falling in air check")
		if pl.dy > 0.1 then
			--printh(" falling down "..pl.dy)
			if pl.state != b and pl.state != jump then
				--solid_pl = solid_a(pl, 0, pl.dy+wdy+w_g_y) 
				solid_pl = solid_a(pl, 0, pl.dy+w_g_y) 
				if not solid_pl and pl.state != die then
				 pl.state = falling
				end
			end
		end
	end
	-- todo fall up (float) if -ve gravity

	-- points? 
	if pl.y+wy < highest - level_size then
	 points+=level_points
	 if (sound) sfx(s_highlow)
	 highest = pl.y+wy 
	elseif pl.y+wy > lowest + level_size then
	 points+=level_points
	 if (sound) sfx(s_highlow)
	 lowest = pl.y+wy
	end

	-- todo move to _draw?
	if pl.state == idle or pl.state == die then
	 pl.frame += 0.1

		if pl.frame >= #anim[pl.state] then
			pl.frame = 0.01
		end
	end
end

function update_enemies()
	for e in all(enemy) do
	  -- note: mostly done by move_actor
	end
end

function update_map()
 -- for dynamic map changes
	if pl.room == nil then  
	 -- note: extra top row for smooth upward scroll
	 for y=0,16 do  
			local y_w = ceil(wy)+y
			local dr = w_default_row
		 if y_w > water_level then
			 dr = w_default_row_water
		 end	
			for x=0,15 do
				if w[y_w] then
					if w[y_w][wx+x] then
					 if draining_sequence !=nil and x==0 and	w[y_w][wx+x] == w_water_brick and y_w < water_level then
							mset(x,y,0)
					 elseif draining_sequence !=nil and x==15 and	w[y_w][wx+x] == w_water_brick and y_w < water_level then
							mset(x,y,0)
					 else
							mset(x,y,w[y_w][wx+x])
						end
					else
						mset(x,y,dr[x+1])
					end
				else
					mset(x,y,dr[x+1])
				end
			end
		 --if (debug and w[y_w] and w[y_w][-1]) mset(7,y,119)  
		 --if (debug and w[y_w] and w[y_w][16]) mset(8,y,121)	 
		end
	else
	 -- if end-game, drain the room
	 if draining_sequence != nil then
		 local rx=pl.room[1]
		 local ry=pl.room[2]
			for iw=0,14 do
				if wy+16-iw < water_level then
				 --printh("d:"..wy+ry-iw.." "..water_level)
					for ix=0,15 do  -- note: includes doorway (l or r)
					 if mget(rx+ix,ry+15-iw) == w_water_brick then
							mset(rx+ix,ry+15-iw,0)
						end
					end
				end
			end
	 end
	end
end

function _update_intro()
	if btnp(❎) then
		if (sound) music(-1)
		if (sound) sfx(s_start)  
		_update = _update_game
		_draw = _draw_game
	end
	if btnp(🅾️) then
	 if (sound) sfx(s_menu)
		show_credits = not show_credits
	end
end

function _update_success()
	if btnp(🅾️) then
	 if (sound) sfx(s_menu)
		show_credits = not show_credits
	end
	if btnp(❎) and pl.t > game_over_delay then
		reload(0x2000, 0x2000, 0x1000)  -- reset doors, key-takes etc.
		-- todo clear room 0,0 to avoid flash of intro
		if (sound) music(-1)
		_init(true)  -- auto start
	end
	pl.t += 1
end

_update_fail = _update_success

function _update_game()
 control_player(pl)
 update_enemies()

 update_map()
 
 purge_enemies()
 spawn_enemies()

 foreach(actor, move_actor)
 
 player_move_room()

 -- todo move to update_map()? 
 if draining_sequence != nil then
  if water_level < w_h then
	 	water_level += drain_rate
			if (sound and flr(water_level%drain_noise_freq)==0) sfx(s_drain)
	 else
	 	-- wait for player to leave via drain
	 	-- todo: new mode + turn off enemies?
			if (sound) sfx(s_drain, -2)
	 end
 end
end


-->8
--draw tab

function draw_actor(a)
 local sx = (a.x * 8) - 4
 local sy = (a.y * 8) - 4
 -- spr(a.spr + a.frame, sx, sy)
 
 local fy
 local fx=a.dir==l or (a.dx < 0 and a.dir != r)
 --todo remove:
	--if a.y + wy > water_level then
	--	-- invert based on gravity 
	-- fy=a.dir==b
	--else
 if a.y + wy > water_level+1 then  -- +1 to stay upright on surface
  fy = (a.dir != t)
 else
		fy=a.dir==b 
	end
	--if (fy) printh("flipy")
	--if (a==pl) printh("*"..a.state)
 if a.state then
	 spr(anim[a.state][ceil(a.frame)],sx,sy,1,1, fx,fy)
	else
		-- todo default per actor
	 spr(122 and debug or 0,sx,sy,1,1, fx,fy)
	end
	
-- if debug then
-- 	rect(sx+a.dx,sy+0,
--    sx+a.dx + a.w*16,
--    sy+0 + a.h*16, 12) 
--    
-- 	rect(sx+0,sy + a.dy, --+ w_g_y,
--    sx+0 + a.w*16,
--    sy+a.dy + w_g_y + a.h*16,10)    
--	end	
end

function draw_wake()
	--todo remove local in_water = pl.y + wy + pl.dy - w_g_y +1 > water_level 
	for i=1,wake_max do
		local wki = wake_start + i
		if (wki > wake_max) wki = wki-wake_max
		local wk = wake[wki]
		if (wk[1] == -1) break
		local age=pl.t-wk[3]
		--printh("wd".." "..wake_start.." "..i..":"..wki..":"..wk[1]..","..wk[2].."-"..wk[3])
		if age < wake_decay then
			local oy = (wk[2] * 8) + 4 
			local ow = (age/4)*2 * 4
			local oh = (age/2)
			local ox = wk[1] * 8 
			if age > wake_decay/2 then
			 if i % 2 == 1 then
			  fillp(0b1110011111100111.1)
			 else
			  fillp(0b1101101111011011.1)
			 end
			else
		  fillp(0b1010010110100101.1)
			end
	  --printh("  "..ox-ow..","..oy-oh..","..ox+ow..","..oy+oh)
	  local c = pl.t - wk[3] 
	  c = wake_colour[c%#wake_colour+1]
	  ovalfill(ox-ow,oy-oh,ox+ow,oy+oh, c)
	  if (debug) rect(ox-ow,oy-oh,ox+ow,oy+oh, 11)
	  -- check if any enemies are killed by this
			for e in all(enemy) do
			 if e.state != enemy_die then
		   local x=ox+ow - ((e.x)*8-4)
		   local y=oy+oh - ((e.y)*8-4)
			  if (debug) rect(e.x*8-(e.w*8),e.y*8-(e.h*8),e.x*8+4,e.y*8+4, 14)
	    --printh("k?:"..x..","..y..":"..ow+e.w.." "..oh+e.h)
		   if ((abs(x) < (ow*1.8+e.w*8)) and
		      (abs(y) < (oh*1.8+e.h*8)))
		   then 
		    if e.mass != persist_mass then
						 kill_enemy(e)
						-- else we can't kill these
						end
		   end	
		  -- else let pass through
	   end
			end
	  fillp()
	 -- else don't draw old ones
	 end
	end
end

function get_key_from_map(x,y)
	local d1 = mget(x,y)
	local d2 = mget(x+1,y)
	local n = 0
	if d1==209 then
		n += 10
	else
		assert(d1==192)
	end
	assert(d2>=208 and d2 <=217)
 n += d2 - 208
	return n
end

function place_key_home(n, yoff)
 local kh = key_homes[n]
 local d1 = n > 9 and 209 or 192
 local d2 = (n % 10) + 208
 mset(kh[1],yoff+kh[2],d1)   
	mset(kh[1]+1,yoff+kh[2],d2)
end

function draw_room()
 pal(3,1)  -- blue water (spr 10)
 
	if durer_sequence == -1 then
  if water_level < w_h then
			scroll_tile(10)
		end
	end
 
	if pl.room == nil then
		-- smooth upward scroll by extra top row with -ve offset
	 map(0,0,0,-(1-(ceil(wy)-wy))*8,16,17)
	else
	 local rx=pl.room[1]
	 local ry=pl.room[2]
	 if rx == 0 and ry==16 then
	  -- key room
	  palt(5,true) -- no shadow
	  for key,got in pairs(durer_keys) do
		  if (got) place_key_home(key, ry)
	 	end
		 map(rx,ry,0,0,16,16)
 		palt()

	 	map(rx,ry+15,0,0,16,1)  -- top row (since scrolling map 0,0 takes this)

			-- title
	 	rectfill(40,7, 88, 17, 0)
	 	rect(40,8, 88, 17, 5)
		 print("durer", 56,11, 15)
		 print(".", 59,5, 15)
		 print(".", 61,5, 15)
		 if durer_sequence == nil then
			 print("bring keys", 48,25, 2)
			elseif durer_sequence == -1 then
 		 -- drained already
		  if water_level < w_h then
				 print("draining...", 48,25, 2)		
					scroll_tile(36)
				else
				 print("drain = exit", 41,25, 2)		
				end
			elseif durer_sequence != -1 then
				-- end game animation
				local t = pl.t - durer_sequence

				local si = t\key_seq_each +1
				--printh(si.." "..t..":"..durer_sequence_length.." "..t%key_seq_each)
				local seq = key_seq[si]

				local ss = si*key_seq_each - t  -- countdown
				
				sum = 0
				for n in all(seq) do
					sum += n
				 kh=key_homes[n]
 				if (sound and flr(t%key_seq_each)==0) sfx(s_key_seq)
				 if #seq ==4 or (#seq == 2 and ss / key_seq_each < 0.6) then
	 				rect(kh[1]*8,kh[2]*8, (kh[1]+2)*8,(kh[2]+1)*8-1, 10)
 				end
				end
				
				--printh(ss.." "..key_seq_each.." = "..ss / key_seq_each)
				if seq != nil then
				 if #seq == 4 then
	 				if ss / key_seq_each < 0.4 then
							print("=34", 73,105, 10)
							scroll_tile(36)
						end
				 elseif #seq == 2 then
		 				if ss / key_seq_each < 0.9 then
								print("17=", 53,105, 10)
							end
							if ss / key_seq_each < 0.6 then
								scroll_tile(36)
							end
					end
				end
				
				if t > durer_sequence_length then
					if (sound) music(24)
					durer_sequence = -1
					-- move to next mode
					draining_sequence = pl.t
					if (sound) sfx(s_drain)
				 print("draining...", 48,25, 9)
				 -- todo give message about finding drain?
					-- open drain in floor
					w[w_h-1][15] = 0
					w[w_h][15] = 126 --indicator
					local room = {0,0}  -- re-use shaft buffer
					link_room(room, w_h, r)				
				end
			end
	 -- todo remove: handled by routines
--	 elseif rx == 0 and ry==0 then
--	  -- final room (was used for shaft scrolling)
--	  -- dynamically draw now
--		 map(rx,ry,0,0,16,16)
--		 rectfill(9,0, 128, 50, 12)  --sky
--		 rectfill(9,51, 128, 128, 11)  --grass
		else
		 map(rx,ry,0,0,16,16)
	 end
	end
 pal()
end

function draw_status()
 -- top row
 rectfill(8,0, 118,5, 0)

	spr(30, 9,0, 1,1,false,true)
	print(pl.key_count, 16,0,10)

 print("score:"..points,28,0,10)  -- in k

	spr(64, 74,-1)
	print(pl.lives, 83,0,10)

 print("e",90,0,10)  
 rectfill(94,1, 94+22,4, 5)
 rectfill(94,2, 94+(pl.energy/max_energy)*22,3, pl.energy < low_energy and 8 or 9)
end

function _draw_intro()
	cls()

 --print("can you reach the extremes?", 6, 6, 10)

 map(0,0,0,0,16,16)

 print("⬅️➡️⬆️⬇️ to move", 28, 80, 9)
 print("❎ for wake", 39, 88, 9)
 print("press 🅾️ for credits", 22, 100, 13)

 print("press ❎ to start", 28, 112, 12)

 scroll_tile(9)
	if time() - last > 0.1 then 
	 pal(4, flr(1+rnd()*#wake_colour), 1)
	 last = time()
	end
	
 if show_credits then
  draw_credits()
 end
end

function draw_credits()
 draw_rwin(12,30,104,80,7,0)		
	print("credits", 50,34,5)
	-- todo underline
	
	-- todo scroll?
	print("written by", 18,44,13)
	print("greg gaughan", 63,44,1)

	print("art/sfx", 18,58,13)
	print("that tom hall", 59,58,1)
	print("lafolie", 83,66,1)

	print("animation", 18,76,13)
	print("toby hefflin", 63,76,1)
	
	print("music by", 18,86,13)
	print("gruber", 87,86,1)

	print("press 🅾️ to close", 32,100,6)
end

function _draw_success()
	cls()
	
 --pal(12,140,1)
 rectfill(0,0, 128, 50, 12)  --sky
 sspr((72%16)*8,(72\16)*8, 8,8, 102,24, 8*3,8*3) -- sun
 --pal(11,139,1)
 rectfill(0,51, 128, 128, 11)  --grass
 sspr((32%16)*8,(32\16)*8, 8,8, 20,68, 8*3,8*3) -- tree
 sspr((32%16)*8,(32\16)*8, 8,8, 94,46, 8*1,8*1) -- tree

 for wall=0,14 do
  spr(59,0,wall*8)
	end
 spr(152,1*8,15*8)

 print("you escaped the tower", 24, 12, 10)
 print("with a score of "..points, 26, 20,7)  
 print("well done!", 46, 30, 10)

 print("press 🅾️ for credits", 28, 100, 12)
 print("press ❎ for restart", 28, 112, 12)
 
 -- todo store high score
 -- todo store in cart memory
 
 if show_credits then
  draw_credits()
 end
end

function _draw_fail()
	cls()
	
 -- todo! pal(12,140,1)
	draw_room()

	draw_status()

 print("you died", 50, 36, 8)

 print("press 🅾️ for credits", 28, 100, 12)
 print("press ❎ for restart", 28, 112, 12)
 
 -- todo store high score
 -- todo store in cart memory
 
 if show_credits then
  draw_credits()
 end
end

function _draw_game()
 cls()

	draw_room()

 foreach(actor,draw_actor)
 draw_wake()

	draw_status()

	if debug then 
	 -- no use?:
	 --local _test_y = solid_a(pl, 0, pl.dy) 
	
	 --print("x "..pl.x,0,120,7)
	 --print("y "..pl.y,48,120,7)
	 --print("wy "..wy,90,120,7)

		----print("c "..ceil(wy)-wy, 10,1,7)
	 
	 --print("t "..pl.t,0,9,7)  -- in k
	 ----print("e "..pl.energy,90,8,7)  -- in k

	 --local wly = (water_level - wy) *8 
	 --line(0, wly, 127, wly, 11)  
	 
	 --printh("pl.y+wy:"..((pl.y+wy)*8).." wl:"..water_level*8)
	 --printh(" "..pl.dy)
 end
end



-->8
-- world building

-- wall and actor collisions
-- by zep

-- make an actor
-- and add to global collection
-- x,y means center of the actor
-- in map tiles (not pixels)
function make_actor(x, y)
 a={}
 a.x = x
 a.y = y
 a.dx = 0
 a.dy = 0
 a.mass = 1
 a.dir = t
 --a.spr = 16
 a.state = nil
 a.frame = 0
 a.t = 0
 a.inertia = 0.6
 a.bounce  = 1
 a.is_enemy = false
 --a.frames=2
 
 -- half-width and half-height
 -- slightly less than 0.5 so
 -- that will fit through 1-wide
 -- holes.
 a.w = 0.4
 a.h = 0.4
 
 add(actor,a)
 
 return a
end

-- for any given point on the
-- map, true if there is wall
-- there.

function solid(x, y, is_player)

 -- grab the cell value
 --val=mget(x, y)
 --camera(0, 8-(ceil(wy)-wy)*10)
 if pl.room == nil then
	 val=mget(x, y)

	 if is_player then
	  -- pick up things - todo move elsewhere?
			if val == 64 then --extra life
				if (sound) sfx(s_key_pickup)  --todo
				local y_w = ceil(wy)+y
				local dr = w_default_row
			 if y_w > water_level then
				 dr = w_default_row_water
		 	end	
				assert(w[flr(y_w)][flr(x)] == 64)
				w[flr(y_w)][flr(x)] = dr[flr(x)+1]
				mset(flr(x),flr(y),dr[flr(x)+1])
				pl.lives += 1
	 	end
		end
	else
		-- offset to a room
	 local rx=pl.room[1]
	 local ry=pl.room[2]	
		-- note: -y to not skip top row
	 val=mget(x + rx, y + ry -1)
	 
	 if is_player then
	  -- pick up things - todo move elsewhere?
		 local key = nil
			if val == 30 then --key
				-- note: +2 digits to right
				key = get_key_from_map(rx+x+1,ry+y -1)
			end
			-- note: we don't detect digits - make them get the key
			
			if key != nil then
				--printh("k="..key)
				assert(not(durer_keys[key] or pl.keys[key]))
				-- hide: pick up
				pl.keys[key] = true
				pl.key_count += 1
				if (sound) sfx(s_key_pickup)
				--printh(wy.." "..y.." "..water_level)
		  local replace = ceil(wy) + y > water_level and w_water_brick or 0		
				mset(rx+x,ry+y-1, replace)
				mset(rx+x+1,ry+y-1, replace)
				mset(rx+x+2,ry+y-1, replace)
	 		-- todo assert: key number expected alongside key
			end
		end 
	end
 --camera()
	--printh(x..","..y) 
 -- check if flag 0 is set (the
 -- red toggle button in the 
 -- sprite editor)
 return fget(val, 0)
end

-- solid_area
-- check if a rectangle overlaps
-- with any walls

--(this version only works for
--actors less than one tile big)

function solid_area(x,y,w,h, is_player)

	if pl.room == nil then
		-- note: +1 for map shift for smooth top row upward scroll
		y = y + 1 - (ceil(wy)-wy)  
	else
		y = y + 1
	end
 
 if debug then
		--rect(x*8-w*16, y*8-h*16, x*6+w*16, y*8+h*16, 9)
		--printh((x*8-w*16)..","..(y*8-h*16)..","..(x*6+w*16)..","..(y*8+h*16))
	end
	
 return 
  solid(x-w,y-h, is_player) or
  solid(x+w,y-h, is_player) or
  solid(x-w,y+h, is_player) or
  solid(x+w,y+h, is_player)
end


-- true if a will hit another
-- actor after moving dx,dy
function solid_actor(a, dx, dy)
 for a2 in all(actor) do
  if a2 != a then
  	-- todo perhaps skip if both mass==0 (i.e. enemy + enemy pass through)
  	-- todo or, just don't call if mass==0 and pl must test enemy hits
  	--        so then if a=pl and a2=enemy = simple?
   local x=(a.x+dx) - a2.x
   local y=(a.y+dy) - a2.y
   if ((abs(x) < (a.w+a2.w)) and
      (abs(y) < (a.h+a2.h)))
   then 
    
    -- moving together?
    -- this allows actors to
    -- overlap initially 
    -- without sticking together    
    if (dx != 0 and abs(x) <
        abs(a.x-a2.x)) then
     v=a.dx + a2.dy
     a.dx = v/2
     a2.dx = v/2
     if a==pl and a2.is_enemy then
	     if (a2.state == enemy_die) return false
      if pl.state!=die then
	      kill_player()
	     -- else already dying
	     end
	     --todo? if (a2.mass == 0) 
	     kill_enemy(a2)  -- don't kill persist
	     -- todo respawn player elsewhere if mass!=0
					 --printh("wend die x")
     	--printh("die")    	
	    end
     return true 
    end
    
    if (dy != 0 and abs(y) <
        abs(a.y-a2.y)) then
     v=a.dy + a2.dy
     a.dy=v/2
     a2.dy=v/2
     if a==pl and a2.is_enemy then
	     if (a2.state == enemy_die) return false
	     if pl.state!=die then
	      kill_player()
	     -- else already dying
	     end
	     -- todo? if (a2.mass == 0) 
	     kill_enemy(a2)  -- don't kill persist
	     -- todo respawn player elsewhere if mass!=0
					 --printh("wend die y")
     	--printh("die")    	
	    end
     return true 
    end
    
    --return true
    
   end
  end
 end
 return false
end


-- checks both walls and actors
function solid_a(a, dx, dy)
 if a.mass > 0 then
  if solid_area(a.x+dx,a.y+dy,a.w,a.h, a==pl) then
	  return true 
	 end
 	return solid_actor(a, dx, dy) 
 end
 return false
end

function move_actor(a)

 -- only move actor along x
 -- if the resulting position
 -- will not overlap with a wall
 if not solid_a(a, a.dx, 0) 
 then
  a.x += a.dx
 else   
  --printh(a.dx.." "..a.y)
  -- otherwise bounce
  a.dx *= -a.bounce 
  --sfx(s_enemy_kill)
 end

 -- ditto for y
 if not solid_a(a, 0, a.dy) then
  a.y += a.dy
	 -- gravity
	 if not a.is_enemy then  -- specifically a.mass==persist_mass
		 if a.y + wy - 1 +1 > water_level then  -- note: +1 for extra row for smooth upward scrolling
		 	a.dy -= w_g_y * a.mass
		 	--if (a==pl) printh("g>"..a.dy)
		 else
		 	a.dy += w_g_y * a.mass
		 	--if (a==pl) printh("g"..a.dy)
		 end	 
		 -- else no gravity for enemies - yet
		end
  --printh(a.dy.."!")
 else
  a.dy *= -a.bounce 
  --printh(a.dy.."!")
  --sfx(s_enemy_kill)
 end

 -- apply inertia
 -- set dx,dy to zero if you
 -- don't want inertia
 
 a.dx *= a.inertia
 a.dy *= a.inertia
 
 --printh(a.dy.." "..a.y)
 
 -- advance one frame every
 -- time actor moves 1/4 of
 -- a tile

	if a.state then
	 a.frame += abs(a.dx) * 1
 	a.frame += abs(a.dy) * 1
	 -- a.frame %= a.frames -- always 2 frames

		if a.frame >= #anim[a.state] then
			a.frame = 0.01
		end
	end
 
 a.t += 1
end

function is_complete()
	-- returns true if complete now

	-- do we have all the keys?
 local	complete = true
	for got in all(durer_keys) do
		if not got then
			complete = false
			break
		end
	end
	
	return complete
end

function enter_durer()
 -- does player have any new key(s) to add?
	for key, got in pairs(pl.keys) do
		if got then
		 -- move to this room
			durer_keys[key] = true
			points+=key_points
			pl.keys[key] = false
			pl.key_count -= 1
			if (sound) sfx(s_highlow)
			-- todo perhaps animate key from player to slot
			-- or flash via new_keys[]
		end
	end
	return true
end

function player_move_room()
	if pl.x < 0.5 or pl.x > 15.5 then
		if (sound) music(-1)
	 if pl.room == nil then
			clear_enemies()
			local in_water = pl.y + wy + pl.dy - w_g_y +1 > water_level 
		 -- note: +1 for extra row for upward scroll
			local y = pl.y + wy +1
			local x = pl.x
			local scroll_y 
 		scroll_y = (14.6-(pl.y))  -- extra 0.1 for collision smoothout
			pl.room_old_y = scroll_y
			if pl.x < 0.5 then
				pl.room = w[flr(y)][-1]
				x = 15.5
			elseif pl.x > 15.5 then
				pl.room = w[flr(y)][16]
				x = 0.5
			end
			if pl.room != nil then
				--printh("> pl.y "..pl.y.." scroll_y "..scroll_y.." pl.dy "..pl.dy.." wy "..wy)
			 local rx=pl.room[1]
			 local ry=pl.room[2]
				pl.y += scroll_y
				wy -= scroll_y
				pl.x = x
				if rx==0 and ry==16 then
					if enter_durer() then
					 if durer_sequence == nil and is_complete() then
					 	-- move to end game animation mode
					  durer_sequence = pl.t  -- freeze player control while we animate
					 elseif durer_sequence != -1 then
								if (sound) music(21)
						end
					end
				elseif rx==0 and ry==0 then
					-- game over
					if (sound) music(0)
					if (debug) printh("enemies:"..#enemy)
					if (debug) printh("actors:"..#actor)
					_draw = _draw_success
					pl.t = 0
					_update = _update_success
				else
				 -- todo skip if already done - set room flag 
				 -- convert items on map into dynamic objects
				 -- e.g. hide keys already collected
				 --      spawn room enemies
				 for xx=0,15 do
				 	for yy=0,15 do
				 	 if mget(rx+xx,ry+yy) == 97 then --enemy
				 	  if xx>0 and yy > 0 and xx < 15 and yy < 15 then
					 	 	--printh(wy.." "..yy.." "..water_level)
			  				local replace = ceil(wy) + yy + 0.5 > water_level and w_water_brick or 0
					 			mset(rx+xx,ry+yy, replace) 
									local e = make_enemy(xx+0.5, yy+0.5)
									e.dx = 0.12
									e.mass = persist_mass  -- bounce around - persist
									e.bounce = 1
									e.inertia = 1
									add(enemy, e)
									--if (debug)	printh("add "..e.x.." "..e.y.." "..e.mass)			 			
								-- else leave borders intact (rounding)
								end
				 		elseif mget(rx+xx,ry+yy) == 30 then --key
				 			-- note: +2 digits to right
				 			local key = get_key_from_map(rx+xx+1,ry+yy)
				 			if key != nil then
				 				--printh("k="..key)
				  			if durer_keys[key] or pl.keys[key] then
										local y_w = ceil(wy)  -- todo remove!
				  				-- hide: already picked up
				  				--local replace = y_w - yy > water_level and w_water_brick or 0
				  				--local replace = y_w + yy > water_level and w_water_brick or 0
				  				local replace = ceil(wy) + yy > water_level and w_water_brick or 0
				  				--printh(replace.." "..y_w.."+"..yy.." "..water_level+1)
						 			mset(rx+xx,ry+yy, replace)
						 			mset(rx+xx+1,ry+yy, replace)
					  			mset(rx+xx+2,ry+yy, replace)
					  		end  
					  	-- todo assert: key number expected alongside key
				  		end
				 		end
				 	end
				 end
				end
 		else
				assert(false, "expected a room at "..flr(y))
			end
		else  -- in a room, return to main shaft
			clear_enemies()
			local x = pl.x
			if pl.x < 0.5 then
				pl.room = nil
				x = 15.5
			elseif pl.x > 15.5 then
				pl.room = nil
				x = 0.5
			end
			if pl.room == nil then
				--printh(wy.." "..water_level)
				--pl.y -= pl.room_old_y  
				pl.y = 14.6 - pl.room_old_y  -- restore absolute y rather than relative to current y - less glitchy under water
				--printh("< pl.y "..pl.y.." pl.room_old_y "..pl.room_old_y.." pl.dy "..pl.dy.." wy "..wy)
				wy += pl.room_old_y
				pl.x = x
			else
				assert(false, "expected a shaft at "..pl.x)
			end
		end
		
		-- note: assume we did change room
	 clear_wake()	
	end
end

function link_room(room, y, d)
 local door_pos = (d==l) and 0 or 15
 local d_offset = (d==l) and -1 or 1  -- off-world link
	-- add door and room and room door
 if w[y-1] == nil then
  w[y-1] = {}
 end
	w[y-1][door_pos] = (y > water_level+1) and w_water_brick or 0
	w[y-1][door_pos+d_offset] = room
	-- modify room to suit: means we can't re-use (unless we dynamically add/remove when entering)
	mset(room[1]+15-door_pos,room[2]+14,(y > water_level+1) and w_water_brick or 0)  
	-- add water if necessary
	for iw=0,14 do
		if y-iw > water_level then
			for ix=1,14 do  --1,14? was 15
			 if mget(room[1]+ix,room[2]+15-iw) == 0 then
					mset(room[1]+ix,room[2]+15-iw,w_water_brick)
				end
			end
		end
	end
	--printh("add "..d.." room "..(y-1).." "..w[y-1][door_pos+d_offset][1]..","..w[y-1][door_pos+d_offset][2])
end

function make_world_row(y)
 if (w[y] != nil) return  -- e.g. initial room

 local need = abs(last_ledge - y) > max_ledge_gap
 local need_room = abs(last_ledge - y) > max_ledge_gap*2  -- one-off for initial room
 if need or rnd() > 0.8 then
  local sp = w_default_brick
  -- ledges
	 if y > water_level+1 or y < water_level-4 then
	  for d in all({r,l}) do
		  -- tood: double-check need: add factor based on recharge_factor to max_ledge_gap
			 if need or rnd() > 0.5 then
			  if w[y] == nil then
			   w[y] = {}
			  end
			 	for i=0,rnd(3)+1 do
				 	if d==r then
						 w[y][15-flr(i)] = sp
						else
						 w[y][flr(i)] = sp
						end
	 		  need = false
					end
					if #rooms > 0 and y-last_ledge > 1 then
		  		if (rnd() > room_chance and y > room_range_start and y < room_range_end and y != durer_room_y+1) or need_room then
		  			--printh(#rooms.." add room at "..y.." "..y-last_ledge.." "..water_level)
							local room = rooms[#rooms]
							rooms[#rooms]=nil
							link_room(room, y, d)
						end
					end				
				 last_ledge = y
				end
	  end
		-- else player start drop area
		end
	end
end

function make_world(h)
	w={}
	
	-- extra rooms hardcoded in map from x=16 (2 16x16 room levels deep)
	-- note: door/water will be placed dynamically depening on depth and left/right linkage
	-- room: x-map-offset-top-left, y-map-offset-top-left
	--					  any keys are expected to have key number to right (2 digits)
	-- note: 14 key rooms
	--        1 final durer room
	--          - starts with 2 keys 
	rooms={
		{16,0},
		{32,0},
		{48,0},
		{64,0},
		{80,0},
		{96,0},
		{112,0},

		{16,16},
		{32,16},
		{48,16},
		{64,16},
		{80,16},
		{96,16},
		{112,16},
		
	 {0,16}, -- end: will be placed near start

		--{32,0},  --temp debug

	}

	w[0] = {}
	w[1] = {}  -- prepare for extra life
	w[h-1] = {}  -- prepare for end drain
	w[h] = {}
	for i=0,15 do
	 w[0][i] = w_default_brick  -- ceiling
	 w[h][i] = w_default_brick  -- floor
	end
	w[h-1][15] = 141  -- closed drain
	if extra_lives > 0 then
		w[1][7] = 64  -- extra life
		extra_lives -= 1
	end
	if extra_lives > 0 then
		w[h-1][7] = 64  -- extra life
		extra_lives -= 1
	end
	
	-- note last_ledge==0 -> need_room
	-- i.e. pops last room and makes it in fixed location
 make_world_row(durer_room_y)  -- above start pipe

	-- main shaft
	for i=1,h-1 do
	 make_world_row(i)
	end

	if #rooms > 0 then
		if (debug) printh("*** rooms not added automatically: "..#rooms)
	
		-- place any leftover rooms - we need them all
		while #rooms > 0 do
			local y = flr(rnd(h-1))+1
		 if y > water_level+1 or y < water_level-4 then
		  -- todo could relax room range here?
		  if w[y] == nil and w[y+1] == nil and y > room_range_start and y < room_range_end then
					--printh(" - suitable gap "..y)
					-- todo check above/below free too?
		   w[y] = {}
					local room = rooms[#rooms]
					rooms[#rooms]=nil
					w[y+1] = {}
			 	for i=0,rnd(3)+1 do
					 w[y+1][flr(i)] = w_default_brick
					end
					link_room(room, y+1, l)
				end
			end
		end
	end
	
	-- starting platform
	w[water_level] = {}
	for i=0,6 do
	 w[water_level][i] = w_start_brick
	end
	-- indicator and better platform for durer room
	if (w[durer_room_y] == nil) w[durer_room_y] = {}
 w[durer_room_y][15] = 126
	for i=1,3 do
	 w[durer_room_y][15-i] = w_start_brick
	end
end

function make_enemy(x, y)
	e = make_actor(x, y)
	e.is_enemy = true
	e.state="enemy"
	e.frame=1
	e.mass = 0.0  -- default = pass through
	e.inertia = 1.0
	e.bounce = -1.0
	return e
end

function spawn_enemies()
 if pl.room == nil then
	 if #enemy < enemy_limit then
		 local accel = 0.2
			local in_water = pl.y + wy + pl.dy - w_g_y +1 > water_level 
	 
			if rnd() > enemy_chance then
			 x = flr(rnd(13)) + 1.5  -- i.e. in lanes (so player can hide at edges)
				e = make_enemy(x, -1)
				e.state = enemy_missile
			 if in_water then
				 e.y = 0
					e.dy += accel 
					e.dir=b
				else
				 e.y = 15 
					e.dy -= accel 
				end
				add(enemy, e)
				--if (debug)	printh("add "..e.dy.." "..e.x.." "..e.mass)
			end
		end
	-- else no enemies in rooms (for now)
	end
end

function purge_enemies()
	for e in all(enemy) do
		-- todo add slack / keep some
		--      and/or add timer deaths
		if e.y < 0 or e.y > 15 or e.x < 0 or e.x > 15 or (e.state==enemy_die and e.t > enemy_die_duration) then
		 --printh("purge "..e.y)
		 del(actor, e)
			del(enemy, e)
		end
	end
end

function clear_enemies()
		for e in all(enemy) do
    if e.mass != 0 then -- todo or ==persist_mass
    	-- persist - put back in room map
 				if pl.room != nil then
					 local rx=pl.room[1]
					 local ry=pl.room[2]
					 --printh("(re)set "..e.x..","..e.y)
			 	 mset(flr(rx+e.x-0.5),flr(ry+e.y-0.5), 97)
 				end
    end
		  -- no points
    e.y=-1  -- disappear (via purge)
		end
end

function kill_enemy(a)
 --printh("k:"..e.y)
 if (points < points_limit) points+=enemy_kill
 if (sound) sfx(s_enemy_kill)
	a.state=enemy_die
	a.t = 0
end

function kill_player()
 if (sound) sfx(s_die)
 pl.state=die
 pl.dy=0
 pl.t=0
 pl.energy=0
 clear_wake()
 pl.lives-=1
 if pl.lives <= 0 then
		-- game over
		if (sound) music(23)
		_draw = _draw_fail
		pl.t = 0
		_update = _update_fail
	end
end

-->8
-- support library

-------------------------------
-- scroll tile
-- see that water tile?
-- this scrolls it down by 1
function scroll_tile(_tile)
 local temp
 local sheetwidth=64 -- bytes
 local spritestart=0 -- starts at mem address 0x0000
 local spritewide=4 -- 8 pixels=four bytes
 local spritehigh=sheetwidth*8 -- how far to jump down
 local startcol=_tile%16
 local startrow=flr(_tile/16)
 
 if (_tile>255) return
 -- save bottom row of sprite
 temp=peek4(spritestart+(startrow*sheetwidth*8)+(7*sheetwidth)+startcol*spritewide) -- 7th row
 for i=6,0,-1 do
  poke4(spritestart+(startrow*sheetwidth*8)+((i+1)*sheetwidth)+startcol*spritewide,peek4(spritestart+(startrow*sheetwidth*8)+(i*sheetwidth)+startcol*spritewide)) 
 end
 --now put bottom row on top!
 poke4(spritestart+(startrow*sheetwidth*8)+startcol*spritewide,temp) 
end 

-------------------------------
-- string width with glyphs
function strwidth(str)
 local px=0
 for i=1,#str do
  px+=(ord(str,i)<128 and 4 or 8)
 end
 --remove px after last char
 return px-1
end
-------------------------------
-- get centered on screen width
function center_x(str)
 return 64 - strwidth(str)/2
end

function draw_rwin(_x,_y,_w,_h,_c1,_c2)
 -- would check screen bounds but may want to scroll window on?
 if (_w<12 or _h<12) return(false) -- min size
 -- okay draw inside
 rectfill(_x+3,_y+1,_x+_w-3,_y+_h-1,_c1) -- x big middle bit
 line(_x+2,_y+3,_x+2,_y+_h-3,_c1) -- x left edge taller
 line(_x+1,_y+5,_x+1,_y+_h-5,_c1) -- x left edge shorter
 line(_x+_w-2,_y+3,_x+_w-2,_y+_h-3,_c1) -- x right edge taller
 line(_x+_w-1,_y+5,_x+_w-1,_y+_h-5,_c1) -- x right edge shorter
 --now the border left side
 line(_x,_y+5,_x,_y+_h-5,_c2) -- x longest leftmost edge
 line(_x+1,_y+3,_x+1,_y+4,_c2) -- x 2 left top
 line(_x+1,_y+_h-4,_x+1,_y+_h-3,_c2) -- x 2 left btm
 pset(_x+2,_y+2,_c2)  -- x 1 top dot
 pset(_x+2,_y+_h-2,_c2)  -- x 1 btm dot
 line(_x+3,_y+1,_x+4,_y+1,_c2)  -- x 2 top curve
 line(_x+3,_y+_h-1,_x+4,_y+_h-1,_c2)  -- x 2 btm curve
 --now the border right side
 line(_x+_w,_y+5,_x+_w,_y+_h-5,_c2) -- x longest leftmost edge
 line(_x+_w-1,_y+3,_x+_w-1,_y+4,_c2) -- x 2 left top
 line(_x+_w-1,_y+_h-4,_x+_w-1,_y+_h-3,_c2) -- x 2 left btm
 pset(_x+_w-2,_y+2,_c2)  -- x 1 top dot
 pset(_x+_w-2,_y+_h-2,_c2)  -- x 1 btm dot
 line(_x+_w-3,_y+1,_x+_w-4,_y+1,_c2)  -- x 2 top curve
 line(_x+_w-3,_y+_h-1,_x+_w-4,_y+_h-1,_c2)  -- x 2 btm curve
 -- top and bottom!
 line(_x+5,_y,_x+_w-5,_y,_c2) -- x top
 line(_x+5,_y+_h,_x+_w-5,_y+_h,_c2) -- x bottom
end

function sort(a)
 for i=1,#a do
  local j = i
  while j > 1 and a[j-1] > a[j] do
   a[j],a[j-1] = a[j-1],a[j]
   j = j - 1
  end
 end
end

function strjoin(delimiter, list)
 local len = #list
 if len == 0 then
  return "" 
 end
 local string = list[1]
 for i = 2, len do 
  string = string .. delimiter .. list[i] 
 end
 return string
end

function clear_wake()
	for i=1,wake_max do
		wake[i]={-1,-1,-1}
	end
end

function wait(a) 
	for i = 1,a do
		flip() 
 end
end

__gfx__
00012000606660666066606660666066606660666066606616666661feeeeee87bbbbbb30000004000000030000300000b0dd030777777674f9f4fff7999a999
07d1257000000000000000000000000000000000007777006d6666d6e8888882b3333331040000000300000003000030d3000b0d76777777fffff9f49999979a
057d57d0666066606660566060333306608888066676d75062444426e8811882b33773310000040000000300000003b0000b030077777677ff4fffff99a99999
22566d11000000000000000000333300008888000077770064222246e8866882b3366531000400000003000000b00bb0b0030000777677779fff9ff999997997
11d6652206660666066605666033330660888806067d675664442446e8877282b3355131400000003000000030b30b003000dd0b677777774fffff9fa9999979
0d75d750000000000000000000331300008818000077770064222a96e8822182b33113310000000400000003003b00030b00000377777776ff4fffff999a9999
07521d70660666066606660660331306608818066605550664424446e8888882b33333310400000003000000030b00000300b00076777777ff9ff9ff99999799
0002100000000000000000000033330000888800000000006422224682222222311111110000400000003000000030000dd030b077776777f9ffff4f979999a9
111c111c7ccc7cc70000000005500550005070500500700000dddd00656565650d0aa000000aa000760000000766660006566650777777500007a90000000070
11c111c177ccc7cc000000000765676005076005000760050dddddd0666666650df99f000df99f0006500000766550000666666576666650000a0000000006d6
1c111c11c77ccc7c00000000076007605076660050766700dddddddd662226650de11e000de11e0700650000664500000659405676565650000aa90000006d60
c111c111cc77ccc7076007600765676050766605007676000555555066666665d55660070d66660200065006650450000009400076666650000a00000006d000
111c111c7cc77ccc07656760076007600766767007667670066666606655566509066602d5d6609200006560650045000009400076565650000a0000076d0000
11c111c1c7cc77cc0760076000000000576676655761166506dd6c6066111665000cc092090cc00200000650600004500009400076565650007aa9007dd6d000
1c111c11cc7cc77c1765676100000000766767667610016606dd6c606611166500c11c0200c11c000000604500000045000940000766650000a00a006d06d000
c111c111ccc7cc771d211d2100000000565655656610016606dd6660cc444ccc044004400440044000060004000000040009400000555000009aa900076d0000
0bb3b3b030bbb0030150051001500510940000499999999994000049000099997667060000065000d777777dd55550000076dc0000999900000000000007d000
bb3b3b350bbb3300157556511575515194544449444444444444444400094444641605000065d650566666657665d650075555d0094444900000000000766d00
b3b33333bb3bbb305757651557576515945555490550055004555550009440006666666065616560566666657661656001c6dc109444444900000000076666d0
b3333335b3b3b33505766650057656509400004904500450045004500944000011111156006176d011111155766176d007cc6d50999aa9990000000000044000
0b4334503bbb3b3505666650056565509400004904500450045004509945400076d176d57661110076d176d57661110007cc6d50955aa5590007d00000094000
0009450033b3b355575665155516551594544449045004500454445094405400656165606161d650656165607661d65007cc6d509544444900766d0000094000
0009450003335550156551511155515194555549444444444455554494000544d650d65064616560d650d6507661656007cc6d5095444449076666d000094000
095454540033350301500510015005109400004999999999940000499400004900000000766176d000000000d55176d00066d500999999990004400000094000
000990000777770000077000007dd500007665000554455000007000067666500007000099999999750705607776777677777776777777767777777677777776
049aa94075666660007667000007500007666650554444550000770000565100007a900090040405565656507665766576666665766666657766665576666665
49a99a940065d56000077000077665507666666545444454000076700067650007aaa90094444445057775007665766576555565766776657676656576666665
9a9aa9a900666660076666707766665576565565455a9554000077770067650007aaa90090004005767766606555655576566765767665657667566576666665
9a9aa9a900655d60765555677666666576666665411a911407007000006765000a99990094444445057665007677767776566765767665657667566576666665
49a99a94006666606500005676666665765565654445544476666667006765007556559095555555565656506576657676577765766556657676656576666665
049aa940006777775650056577666655766666654444444407666670006765000aaaa90000055000750605606576657676666665766666657766665576666665
00499400005555500567765007766550655555555444444500777700067666500000000005064005000000005565556565555555655555556555555565555555
00000000000005d9007a4200000000000000000900009999900a000000000000000000000049400000040000a7a9999900076000000000000001000000000000
0e82e82000555d5507a9942000000000000909aa009999aa09000a900009000009009090049a94000049400004a994400007610000111000001c10000eeeee20
e788888205d6d5550a999940000000000000aaaa09a9aaaa00009000008aa800008aa80049a7a940049a9400097999400007610001ccc10001c7c1007262626c
e88888825d7ddd500a99994000000009090a9a9a099a9909a000000000a77a9009a77a009a777a9449a7a94009a99990707765071c777c1001c7c10015252520
0888882056dddd500a9999400000a09a00a9a9a999a997900090000009a77a0000a77a9049a7a940049a9400099a99407667665601ccc10001c7c10002e50000
0088820055ddd5500ae999400000099a09aa9a7799a970000a000000008aa800008aa800049a940000494000009994007676656500111000001c10005e200000
000820000555550007fe9420000099a70aa9a7779aa090000900000000009000090900900049400000040000000a900007655651000000000001000025200000
0000000000555000007942000009aa779aaa97779aa90000000000000000000000000000000400000000000007a9994000766510000000000000000000000000
000550000005500005677650000550000567765000ddd0000000000000033000060aa05065656565757575751111111111111111111111112888888212888821
00566500005666000567765000566500567777650d666d0003333330033bb33006aa00505dddddd66060606015555555555555555555555188eeee88288ee882
0567765066677760567777650567765067766776d67666d033bbbb3333b77b3306a00a506d5555d5575757571565505050505050505556518ea77ae888eaae88
5677776577777776567777655675576577655677d66666d03b7777b33b7777b30600aa505d5cc6d6060606061555550505050505050555518e7777e88ea77ae8
6777777677777777677557765675576556500565dd666d503b7777b33b7777b3060aa0506d5cc6d5757575751555505050505050505555518e7777e88ea77ae8
77777777666775577777777705677650050000500dddd50033bbbb3333b77b3306aa00505d5666d6606060601555550505050505050555518ea77ae888eaae88
56666665005677505666666500566500000000000055500003333330033bb33006a00a506dddddd55757575715655050505050505055565188eeee88288ee882
05555550000566000555555000055000000000000000000000000000000330000600aa5055555555060606061555555555555555555555512888888212888821
00aaaa000007000000dddd0000dddd000022220050222205bb0bb0bb0b0bb0b00000bbb000000000000990003bb1000000666000000770000076660000766600
0a999940000e00000d7cc7d00d7cc7d0552882550528825003abba30b3abba3b000b1b1ba000bbb000007900b3b3b10006000600007755000712826007282160
a979979400e88000d71cc17dd77cc77d22588522225885220bbbbbb00bbbbbb00a0bbbbbb00b1b1b009a9990bb3bbb1060700060077665500612825006282150
a71991740e111800d77cc77dd71cc17d271881722718817203baab3003baab30b00b3707b00bbbbb0979a99913b3b3b160000060775555550066550000665500
a9999994e8191880dccccccddccccccd2888888228888882b003300b00033000b00bbb00b00b370799a999790bbb3bb160000060775e275507d75d6007d75d60
a992299408111820dcc11ccddcc11ccd28881882288188820b3bb3b00b3bb3b0bb0bbbb0bb0bb3309997aa9901b3b3b106000600775227557d7dd5d67d7dd5d6
b30880d5008882000dccccd00dceecd0028888299288882000bbbb00b0bbbb0b0bb0bbbbbbb0bbbb0999a990001bbb3000666000777776557d7dd5d57d7dd5d5
ff0ee0660008200000dddd0000dddd0099222290092222990bb33bb000b33b0000bbbbb00bbbbbb0009a99000001110b00000000055555500665565006655650
08000080a00700b00056650000077000004aa4000077770000777700000000076776d7765000000000d7cd0009aaaa900000567700a7777d0007700000077000
0000000007a00bba056766500076650044a77a4407666670000666700000007676675665650000000d77ccd09a1aa1a9000567760a6666dd0076670000700700
00880800077bba7b5676666500766500aa7777aa71166117a0776657000007667667566566500000d777cccd9a5aa5a905677775a7777d5d0766667007000070
8008e808b0b7aab067666666007665004aa77aa4712662177a6666660000766676675665666500007777cccc9aaaaaa95677775076666d5d7666666770000007
008ee80000ba7ab0666666660076650004a77a40066116606d666666000766667667566566665000dcccdddd09affa900567777676666d5d0005500000077000
000888000b7b77ab56666665007665004a7aa7a405666650d05661150076666676675665666665000dccddd09a9aa9a95677766576666d5d0006600000700700
000000800ab0b7aa05666650076666504aa44aa4006116000006665007666666766756656666665000dcdd00a900009a6777655076666dd00006600007000070
08008000ab0000a00056650006555550aa4004aa0056650000665000766666666552155666666665000dd0009a9009a9776650006ddddd000006600070000007
2002821000028210202000000006822d02822222020220d000000000000000000000000000000000007665000076650005555555555555555555555055677655
0211111122111111022282100026cdcd1111110002200d0000000000000000000000000000000000075006500750065055666666666666666666665556555565
11ddcdcd01ddcdcd001111110216ddddddcdcddd21ddd00002000000000000000000000000000000065006500650000056676767676767676767766556677665
006ddddd106ddddd66ddcdcd0016dddd66666d0081cddd0022ddd000000000000000000000000000766666657666666556777777777777777777776556677665
006d5ddd006d5ddd600ddddd0015ddd066dddd001ddddd008dddd000002282000202820002222200766166657663666556777676767676767676776555677655
0065111d0065111d0005ddd00052111056d111111c66d1111dddd1000221166600211110002282dd766166657663666556766676666666666767766556555565
00520010005200100552211100520010052200000d6661001d66611100666c10011dddd000111110766666657666666556776756666666667577666556677665
0502001005020010500200100502001000502000000552221d666222666dddc066666666666dddd0655555556555555556766665555555555667766556677665
0028210020000000002821002200000002228200005000000000000000000000c0c6cc0000777700056650000000000056677665555575555566765555555555
02111110222821000211111002282100221116660205002002022210202221000cccccc0071111605600650007a00a7056776665565755665555555556677665
d21ddcd60111111021ddcdcd0111111000666c10022560220022822102282210cdd7d7d071111115607006000a9009a056677665565757676565565655555555
d1dd66660ddddcd0666ddddd0dddcdc0066dddcd101d5682011111111111111006ddddd071100115600006000000000056776665575757777576755757777775
00d66d00066dddd06066dd00066dddd05555dd0011ddd62206ddcdcd0ddcdcd00d665ddd71100115560065000000000056677665575756766557675675555557
202211000066dd00001221000066dd00021dd00000dd661260d5dddd6d5dddd000c5ccc071111115056694500a90000056776665565756666565565655677655
02000010002212000110020000221100200100000dd6dc116552ddd16522dd11005c00c0061111500000094507a0000056677665565755665555555556776665
0000000100012000000000200002100000100000d000c1105220011152220001050c00c000555500000000940000000056776665555575555567665556677665
0028226000000000628210000022000022000000222200001112000006822d0026822d0077777777002820000077770056776675555755555677666556776665
002222600028220026111100081d0000820d0000228110001112800026cdcd0016cdcd0000000000028e8200076566d056676756665575656577666556677665
061221600022222006dcdc00621d0000612d000011dcd00011dc600016dddd0006dddd000600600608e7e8007665666d56777667676575657667766555776655
06d11dd0061221160ddddd00611c0200611c0200d66665d5dddd656506dddd0006dddd000000000008eee8007665556d56677777777575757777766575555557
0dd1d1d00dd11ddd05dddd006cdd52016cdd5201dddd0d00ddd6060005ddd00005ddd00000500500028e82007666666d56667676767575756767666557777775
005111000dd1d1dd522dd0d0d66d5211d6665211211100001112000005221110052211100000000000282000076666d056666666666575656666666555555555
0015000000551110220100000d6652100dd6521020001000100020005002000150020001010100100028200000dddd0055666666665575656666665556677665
00105000001051000110000000dd510000dd51002000010010000200500000005000000000000000002820000000000005555555555755555555555055555555
062281100000000000400000202821000028210000282100000000000000000000000000000000007777777711111100566666660015d0005666666500000000
6d6dcdc00000122240900040111111102111111021111110030100000606330000003300000000007555555717777610655115510015d0006666666600000000
506dddd0000dd18090a040900ddbdbd00ddbdbd01ddbdbd003013300663138300031383000077000756556571777610065155551001d50006000000601111110
506dddd0000ddd11a00090a40666dddd1666dddd0666dddd00313830633313300633133000766700755555571776610051155551000d15006000000605555550
5006ddd000ddddd10405a00900d5dd0000d5dd0000d5dd00003313303331301363313013005665007555555717667610655115110001d5006000000605555550
00021111002d6dd00905004a005111000052110000521100033130131110000011100000000550007565565716116761655551510001d0006000000605155150
000200010222166d0a5000900520001005002000052201001110000010000000100000000000000075555557010016716555515100105d006000000605111150
0002000020011006dd1110a05020000050010000500001001000000000000000000000000000000077777777000001105111111500150d000000000005111150
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
55555555555775555775775557757755555775555775577557777555555775555557755555577555775557755557755555555555555555555555555555555775
55555555555770555770770577777775557777755770770057777055555770555577005555557755577577005557705555555555555555555555555555557700
55555555555770555500500557707700577770005507700555770775555500555577055555557705777777755777777555555555577777755555555555577005
55555555555500555555555577777775550777755577077557707700555555555577055555557705577077005557700055775555550000005555555555770055
55555555555775555555555557707700577777005770077057707705555555555557755555577005770057755557705555770555555555555577555557700555
55555555555500555555555555005005550770055500550055775775555555555555005555550055500555005555005557700555555555555577055555005555
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
55777755555775555777775557777755555777755777777555777755577777755577775555777755555775555557755555557755555555555577555557777755
57700775557770555500077555000775557707705770000057700005550007705770077557700775555770555557705555577005557777555557755555000775
57705770555770555577770055577700577007705777775557777755555577005577770055777770555500555555005555770055555000055555775555577700
57705770555770555770000555550775577777705500077557700775555770055770077555500770555775555557755555577555557777555557700555550005
55777700557777555777777557777700550007705777770055777700555770555577770055777700555770555557705555557755555000055577005555577555
55500005555000055500000055000005555555005500000555500005555500555550000555500005555500555577005555555005555555555550055555550055
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
55777755557777555777775555777755577777555577777555777775557777555775577555777755555577755775577557755555575555755775577555777755
57700775577007755770077557700775577007755770000057700000577000055770577055577005555557705770770057705555577557705777577057700775
57707770577777705777770057705500577057705777775557777755577077755777777055577055555557705777700557705555577777705777777057705770
57705000577007705770077557705775577057705770000557700005577057705770077055577055577557705770775557705555577777705770777057705770
55777775577057705777770055777700577777005577777557705555557777005770577055777755557777005770577555777775577007705770577055777700
55500000550055005500000555500005550000055550000055005555555000055500550055500005555000055500550055500000550055005500550055500005
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
55777755557777555777775555777775577777755775577557755775577557755775577557755775577777755777775557755555577777555557755555555555
57700775577007755770077557700000555770005770577057705770577777705577770055777700550077005770000555775555550077055577775555555555
57777700577057705777770055777755555770555770577057705770577777705557700555577005555770055770555555577555555577055770077555555555
57700005577077005770077555500775555770555770077055777700577007705577775555577055557700555770555555557755555577055500550055555555
57705555557707755770577057777700555770555577770055577005570055705770077555577055577777755777775555555775577777055555555557777775
55005555555005005500550055000005555500555550000555550055550555505500550055550055550000005500000555555500550000055555555555000000
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
__label__
77767776000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000777677767776777677767776
77757665770077707770000000000007700770077077707770000077700000000000000000000000000000000077700055555555555555555555555576657665
77657665070070707070000000000070007000707070707000000070700000000000000000000000000000000070000099999999999999999999999576657665
67556555070070707770000000000077707000707077007700000070700000000000000000000000000000000077000099999999999999999999999565556555
77777677070070707070000000000000707000707070707000000070700000000000000000000000000000000070000055555555555555555555555776777677
67766576777077707770000000000077000770770070707770000077700000000000000000000000000000000077700000000000657665766576657665766576
65766576000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000657665766576657665766576
55655565000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000556555655565556555655565
77767776000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077767776
76657665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000076657665
76657665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000076657665
65556555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065556555
76777677000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000076777677
65766576000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065766576
65766576000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065766576
55655565000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055655565
77767776000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077767776
76657665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000076657665
76657665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000076657665
65556555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065556555
76777677000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000076777677
65766576000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065766576
65766576000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065766576
55655565000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055655565
77767776000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077767776
76657665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000076657665
76657665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000076657665
65556555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065556555
76777677000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000076777677
65766576000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065766576
65766576000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065766576
55655565000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055655565
77767776000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077767776
76657665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000076657665
76657665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000076657665
65556555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065556555
76777677000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000076777677
65766576000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065766576
65766576000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065766576
55655565000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055655565
77767776000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077767776
76657665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000076657665
76657665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000076657665
65556555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065556555
76777677000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000076777677
65766576000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065766576
65766576000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065766576
55655565000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055655565
77767776000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077767776
76657665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000076657665
76657665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000076657665
65556555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065556555
76777677000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000076777677
65766576000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065766576
65766576000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065766576
55655565000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055655565
77767776000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077767776
76657665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000076657665
76657665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000076657665
65556555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065556555
76777677000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000076777677
65766576000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065766576
65766576000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065766576
55655565000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055655565
77767776000000000000000000000002821000000000000000000000000000000000000000000000000000000000000000000000000000000000000077767776
76657665000000000000000000002211111100000000000000000000000000000000000000000000000000000000000000000000000000000000000076657665
766576650000000000000000000001ddcdcd00000000000000000000000000000000000000000000000000000000000000000000000000000000000076657665
6555655500000000000000000000106ddddd00000000000000000000000000000000000000000000000000000000000000000000000000000000000065556555
7677767700000000000000000000006d5ddd00000000000000000000000000000000000000000000000000000000000000000000000000000000000076777677
65766576000000000000000000000065111d00000000000000000000000000000000000000000000000000000000000000000000000000000000000065766576
65766576000000000000000000000052001000000000000000000000000000000000000000000000000000000000000000000000000000000000000065766576
55655565000000000000000000000502001000000000000000000000000000000000000000000000000000000000000000000000000000000000000055655565
55555555555555555555555555555555555555555555555555555555000000000000000000000000000000000000000000000000000000000000000077767776
66666666666666666666666666666666666666666666666666666666000000000000000000000000000000000000000000000000000000000000000076657665
67676767676767676767676767676767676767676767676767676767000000000000000000000000000000000000000000000000000000000000000076657665
77777777777777777777777777777777777777777777777777777777000000000000000000000000000000000000000000000000000000000000000065556555
76767676767676767676767676767676767676767676767676767676000000000000000000000000000000000000000000000000000000000000000076777677
66666666666666666666666666666666666666666666666666666666000000000000000000000000000000000000000000000000000000000000000065766576
66666666666666666666666666666666666666666666666666666666000000000000000000000000000000000000000000000000000000000000000065766576
55555555555555555555555555555555555555555555555555555555000000000000000000000000000000000000000000000000000000000000000055655565
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
76657665010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000076657665
76657665000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010076657665
65556555000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000065556555
76777677100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000076777677
65766576000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000165766576
65766576010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000065766576
55655565000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100055655565
77767776000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001077767776
76657665010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000076657665
76657665000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010076657665
65556555000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000065556555
76777677100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000076777677
65766576000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000165766576
65766576010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000065766576
55655565000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100055655565
77767776000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001077767776
76657665010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000076657665
76657665000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010076657665
65556555000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000065556555
76777677100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000076777677
65766576000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000165766576
65766576010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000065766576
55655565000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100055655565
77767776000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001077767776
76657665010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000076657665
76657665000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010076657665
65556555000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000065556555
76777677100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000076777677
65766576000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000165766576
65766576010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000065766576
55655565000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100055655565
77767776000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001077767776
76657665010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000076657665
76657665000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010076657665
65556555000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000065556555
76777677100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000076777677
65766576000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000165766576
65766576010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000065766576
55655565000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100055655565
77767776707000100000001000000010000000100000001070700010777000107770707070007770000000100070707070000077707770777000001077767776
76757665717000000100000001000000010000000100000071700000717000007100707071000070010000000170707071000070017070707100000076657665
77657665777001000000010000000100000001000000010077700100777001007770777077700170000001000070717770000177707071707000010076657665
75756555007100000001000000010000000100000001000000710000707100000071007070710070000100000077700070010000707170707001000065556555
76777677107000001000000010000000100000001000000077700000777007007770007077700070100000001077707770000077707770777000000076777677
65766576000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000165766576
65766576010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000065766576
55655565000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100055655565

__gff__
000101010181010001000000000101010000000000000000000000000000020000000000000000000000000000000000000000000000000000000001010100010000000000000c0000040400000000000000000000000000000001010101000000000000000000000c0c00000000000000000001000000000000000001000100
0000000000000000000001010001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
00000000000000000000000000000000010101010101010101010101010101010f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e010101010101010101010101010101015a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a
00000000000000000000000000000000010000000000000000000000000000010f00000000000000000000000000000f0d00000000000000000000000000000d3d00000000000000000000000000003d0e00000000000000000000000000000e01001ed1d600000061000000000000015a00000000000000000000000000005a
00000000000000000000000000000000010000000000000000000000000000010f00000000000000000000000000000f0d00000000000000000000000000000d3d61000000000000000000000000003d0e00000000000000000000000000000e010101010101010000010101010101015a00000000000000000000000000005a
00000000000000830000000000000000010000000000000000000000000000010f00000000000000000000001ec0d10f0d0000001ec0d700000000000000000d3d00ba000000ba00000000000000003d0e00000000000000000000000000000e010101010100000000000001010101015a00000000000000000000000000005a
00000000000000090000000000000000010000000000000000000000000000010f000000000000000000000f0f0f0f0f0d00005b5c5c5c5d000000000000000d3d00ba1ed1d1ba00000000000000003d0e00000000000000000000000000000e010101010000000000000000010101015a00000000000000000000000000005a
003f3f3f3f3f3f093f3f3f3f3f3f0000010000010101010000000000000000010f61000000000000000000000000000f0d00000000000000000000000000000d3d00bababababa00000000000000003d0e00000000000000000000000000000e010101000000000000000000000101015a0000000000001ed1d300000000005a
003ff7e1ebe5c0efe6c0f4e8e53f0000010000000000000000000000000000010f00006100000000000000000000000f0d00000000000000000000000000000d3d00000000000000000000000000003d0e00000000000000000000000000000e010100000000000000000000000001015a00000000005a5a5a5a5a000000005a
003f3f3f3feee9eeeae13f3f3f3f0000010000000000000000000000000000010f00000000610000000000000000000f0d00000000000000000000000000000d3d00000000000000000000000000003d0e00000000000000000000000000000e010000000000000000000000000000015a00000000005a5a5a5a5a000000005a
003f3f3f3f3f3f3f3f3f3f3f3f3f0000010000000000000000000000000000010f00000000000061000000000000000f0d00000000000000000000000000000d3d00000000000000000000000000003d0e00000000000000000000000000000e010000000000000000000000000000015a00000000000000000000000000615a
00000000000000000000000000000000010000000000000000000000000000010f00000000000000006100000000000f0d0d0d0d0d0d0d00000d0d0d0d0d0d0d3d00000000000000000000000000003d0e00000000000000000000000000000e010000000000000000000000000000015a00000000000000000000000000005a
000000000000000000000000000000000100000000001ed1d2000000000000010f00000000000000000000610000000f0d00000000000000000000000000610d3d00000000000000000000000000003d0e00000000006100000000000000000e010000000000000000000000000000015a00000000000000000000000000005a
00000000000000000000000000000000010000010101010101010101000000010f00000000000000000000000061000f0d0d0d0d00000d0d0d0d00000d0d0d0d3d00000000000000000000000000003d0e00000000003f0000003f000000000e010000000000000000000000000000015a00000000000000000000000000005a
00000000000000000000000000000000010000000000000000000000000000010f00000000000000000000000000000f0d61000000000000000000000000000d3d00000000000000000000000000003d0e00000000003f0000003f000000000e010000000000000000000000000000015a00000000000000000000000000005a
00000000000000000000000000000000010000000000000000000000000000010f00000000000000000000000000000f0d0d0d0d0d0d0d00000d0d0d0d0d0d0d3d00000000000000000000000000003d0e00000000003f1ec0d93f000000000e010000000000000000000000000000015a00000000000000000000000000005a
00000000000000000000000000000000010000000000000000000000000000010f00000000000000000000000000000f0d00000000000000000000000000000d3d00000000000000000000000000003d0e00000000003f3f3f3f3f000000000e010000000000000000000000000000015a00000000000000000000000000005a
00000000000000000000000000000000010101010101010101010101010101010f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e010101010101010101010101010101015a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a
a9a9a9a9a9a9a9a9a9a9a9a9a9a9a9a90e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
010101010101010101010101010101010e00000000000000000000000000000e3b00000000000000000000000000003b3f00000000000000000000000000003f3c00000000000000000000000000003c0d00000000000000000000000000000d0f00000000000000000000000000000f3d00000000000000000000000000003d
010000bd00000000bd00000000bd00010e00000000000000000000000000000e3b00000000000000000000000000003b3f00000000000000000000000000003f3c00000000000000000000000000003c0d00000000000000000000000000000d0f00000000000000000000000000000f3d00000000000000000000000000003d
01008c8d8d8d8d8d8d8d8d8d8d8d8e010e00000000000000000000000000000e3b00000000000000000000000000003b3f00000000000000000000000000003f3c000000000000000000001ed1d0003c0d00000000000000000000000000000d0f00000000000000000000000000000f3d00000000000000000000000000003d
01009c00009c00009c00009c00009c010e00000000000000000000610e0e0e0e3b00000000000000000000000000003b3f00000000000000000000000000003f3c0000000000000000613c3c3c3c3c3c0d00000000000000000000000000000d0f00000000000000000000000000000f3d00000000000000000000000000003d
01009c8d8d9e8d8d9e8d8d9e8d8d9c010e00000000610000000000000000000e3b00000000000000000000000000003b3f00000000000000000000000000003f3c000000000000000000613c3c3c3c3c0d00000000006100000000000000000d0f00000000000000000000000000000f3d00000000000000000000000000003d
01009c00009c00009c00009c00009c010e000000000000000000001ec0d4000e3b00000000000000000000000000003b3f00000000000000001ec0d60000003f3c00000000000000000000613c3c3c3c0d00000000000d1ec0d80d000000000d0f00000000000000000000000000000f3d00000000000000000000000000003d
01009c8d8d9e8d8d9e8d8d9e8d8d9c010e0000000000000000000e0e0e0e0e0e3b00000000000000000000000000003b3f000000000000003f3f3f3f3f00003f3c0000000000000000000000613c3c3c0d00000000000d0d0d0d0d000000000d0f00000000000000000000000000000f3d00000000000000000000000000003d
01009c00009c00009c00009c00009c010e00000000000000000000000000000e3b00000000000000000000000000003b3f00000000000000000000000000003f3c000000000000000000000000613c3c0d610000000000000d6100000000000d0f61000000000000000000000000000f3d00000000000000000000000000003d
01009c8d8d9e8d8d9e8d8d9e8d8d9c010e00000000000000000000000000000e3b00000000000000000000000000003b3f00000000000000000000000000003f3c00000000000000000000000000613c0d000000000000000d0000000000000d0f000000000000001ec0d5000000000f3d000000000000000000001ec0d3003d
01009c00009c00009c00009c00009c010e00000000000000000000000000000e3b00000000000000000000000000003b3f00000000000000000000000000003f3c00000000000000000000000000003c0d000000000000000d0000000000000d0f0000000000000f0f0f0f0f0000000f3d0000000000000061003c3c3c3c3c3d
0100ac8d8d8d8d8d9c8d8d8d8d8dae010e00000000000000000000000000000e3b00000000000000000000000000003b3f00000000000000000000000000003f3c00000000000000000000000000003c0d0000000000000d0d0d00000000000d0f00000000000000000000000000610f3d6100000000000000003c3c3c3c3c3d
0100000000000000af000000000000010e00000000000000000000000000000e3b00000000001ec0d20000000000003b3f00000000000000000000000000003f3c00000000000000000000000000003c0d00000000000d0d0d0d0d000000000d0f00000000000000000000000000000f3d0000000000000000613c3c3c3c3c3d
01000000000000009c000000000000010e00000000000000000000000000000e3b000000003b3b3b3b3b00000000003b3f00000000000000000000000000003f3c00000000000000000000000000003c0d000000000d0d0d0d0d0d0d0000000d0f00000000000000000000000000000f3d00000000000000000000000000613d
01000000000000249e240000000000010e00000000000000000000000000000e3b000000003b0000003b00000000003b3f00000000000000000000000000003f3c00000000000000000000000000003c0d0000000d0d0d0d0d0d0d0d0d00000d0f00000000000000000000000000000f3d00000000000000000000000000003d
010101010101010101010101010101010e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d
__sfx__
000100002e1502e1502f1502f1502f150351503715000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
000200002e5502e5503555035550166003a5503a55037500345003350034500385000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
000200001c620385503455031550305502e5502d5501d6201d6201d6001d600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000006500065000650006551305014050140501405014050140501405013050110500e0500b0500905008050070500605005050050500505006050070500105001030010230000000000000000000000000
000400000024000231062002100000240002310022100213190001a00023000280000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300002a750267502a7500070032750377003970039700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
0004000036630236701f6711c6511b6511b6511a6511a6511a630176310e631066310463102631016310063100631006110061100611006110061100611006110061101600006000060000300003000030000300
000200000b3240d331103411c341233412634127341293412c3312e32500300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
000700180062307623000000762300623000000000000623076230000007623006230000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00050000307342b751237511d75117751127510d75108751037310271501713007050c7000a700077000670004700027000170000700007000070000700007000070000700017000070000700007000070000700
000200002f3402f3412f33136334363413634136331363313632136321363213631136315383003f3000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
00010000312502b250252502025019250122500e2500e6300e6300e6351520010200072000420000200002000d20009200082000820000200002000120026100121001e100061000d10019100251000c10024100
0006000019150201501c150231502313519130201301c130231302312519120201201c120231202311519110201101c1102311023115001000010000100001000010000100001000010000100001000010000100
000900000b6500b6500b6531c6001c6501c650156300e630096300763005610036100161001615000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400001c6301c630232541c35120353173501b3501935422230246002460025600266002660027600156000f6000b6000760006600056000460004600046000020000200002000020000200002000020000200
0003000028630286301e6501a650186501664014640106400f6400c630096300663005630026100161001610016102750020500235002c5002e50022500295002e500325001f5002a5002d500265002a5001c500
000300000863111631206003365032651306512a651226511a651136410d641086410463101631006110061500000000000000000000000000000000000000000000000000000000000000000000000000000000
0003000017630106300e6500e6301063213652186521e6522a6523663236632306323062221622126220661200612006120161200612006150060000600006000060000600006000060000600006000060000600
010c00201125411255052550000000000112541125505255000000000011254112550525500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000705005050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000205004050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010300000005002050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010f000005135051050c00005135091351c0150c1351d0150a1351501516015021350713500000051350000003135031350013500000021351b015031351a0150513504135000000713505135037153c7001b725
010f00000c03300000300152401524615200150c013210150c003190151a01500000246153c70029515295150c0332e5052e5150c60524615225150000022515297172b71529014297152461535015295151d015
010f000007135061350000009135071351f711000000510505135041350000007135051351c0151d0150313503135021350000005135031350a1050a135000000113502135031350413505135000000a13500000
010f00000c033225152e5153a515246152b7070a145350150c003290153200529005246152501526015220150c0331e0251f0252700524615225051a0152250522015225152201522515246150a7110a0001d005
011400000c0330253502525020450e6150252502045025250c0330253502525020450e6150252502045025250c0330252502045025350e6150204502535025250c0330253502525020450e615025250204502525
011400001051512515150151a5151051512515150151a5151051512515150151a5151051512515150151a5151051512515170151c5151051512515170151c5151051512515160151c5151051512515160151c515
011400001c5151e5151a515150151c5151e5151a015155151c5151e5151a515150151c5151e5151a015155151c5151e51517015230151c5151e51517015230151c5151e515165151c0151c5151e515160151c515
011400000c0330653506525060450e6150652506045065250c0330653506525060450e6150652506045065250c0330952509045095350e6150904509535095250c0330953509525090450e615095250904509525
0114000020515215151c5151901520515215151c0151951520515215151c5151901520515215151c0151951520515215151c0151901520515215151c01525515285152651525515210151c5151a5151901515515
01180000021100211002110021120e1140e1100e1100e1120d1140d1100d1100d1120d1120940509110091120c1100c1100c1100c1120b1110b1100b1100b1120a1100a1100a1100a11209111091100911009112
01180000117201172011722117221d7201d7201d7221d7221c7211c7201c7201c7201c7221c72218720187221b7211b7201b7201b7201b7221b7221d7221d7221a7201a7201a7201a7201a7221a7221672016722
011800001972019720197221972218720187201872018720147201472015720157201f7211f7201d7201d7201c7201c7201c7221c7221a7201a7201a7221a7251a7201a7201a7221a72219721197201972219722
011800001a7201a7201a7221a7221c7201c7201c7221c7221e7201e7202172021720247212472023720237202272022720227202272022722227221f7201f7202272122720227202272221721217202172221722
0118000002114021100211002112091140911009110091120e1140e1100c1100c1120911209110081100811207110071100711007112061110611006110061120111101110011100111202111021100211002112
0118000020720207202072220722217202172021722217222b7212b72029720297202872128720267202672526720267202672026720267222672228721287202672026720267202672225721257202572225722
010e00000c0231951517516195150c0231751519516175150c0231951517516195150c0231751519516175150c023135151f0111f5110c0231751519516175150c0231e7111e7102a7100c023175151951617515
010e000000130070200c51000130070200a51000130070200c51000130070200a5200a5200a5120a5120a51200130070200c51000130070200a51000130070200c510001300b5200a5200a5200a5120a5120a512
010e00000c0231e5151c5161e5150c0231c5151e5161c5150c0231e5151c5161e5150c0231c5151e5161c5150c0230c51518011185110c0231c5151e5161c5150c0231e7111e7102a7100c023175151951617515
010e0000051300c02011010051300c0200f010051300c02011010051300c0200f0200f0200f0120f0120f012061300d02012010071300e02013010081300f0201503012020140101201015030120201401012010
018800000074400730007320073200730007300073200732007300073200730007320073000732007320073200732007300073000730007320073000730007300073200732007300073000732007300073200732
01640020070140801107011060110701108011070110601100013080120701106511070110801707012060110c013080120701106011050110801008017005350053408010070110601100535080170701106011
018800000073000730007320073200730007300073200732007300073200730007320073000732007320073200732007300073000730007320073000730007300073200732007300073000732007300073200732
0164002006510075110851707512060110c0130801207011060110501108017070120801107011060110701108011075110651100523080120701108017005350053408012070110601100535080170701106511
010a000024045270352d02523045260352c02522045250352b02522035250352b02522035250252b01522725257252b71522715257152b71522715257152b7151700017000170001700017000130000c00000000
010a000021705247052a7052072523715297151f72522715287151f71522715287151f71522715287151f71522715287151f71522715287151f70522705287051770017700177001770017700137000c70000700
010c00000f51014510185101b510205102451011510165101a5101d510225102651013510185101c5101f5102451028510285102851028510285102851028515240042450225504255052650426502265050e500
010c000014730187301b730207302473027730167301a7301d730227302673029730187301c7301f73024730287302b730307403073030730307303072030715247042470225704257052670426702267050e700
011200000843508435122150043530615014351221502435034351221508435084353061512215054250341508435084350043501435306150243512215034351221512215084350843530615122151221524615
011200000c033242352323524235202351d2352a5111b1350c0331b1351d1351b135201351d135171350c0330c0332423523235202351d2351b235202352a5110c03326125271162c11523135201351d13512215
0112000001435014352a5110543530615064352a5110743508435115152a5110d43530615014352a511084150d4350d4352a5110543530615064352a5110743508435014352a5110143530615115152a52124615
011200000c033115152823529235282352923511515292350c0332823529216282252923511515115150c0330c033115151c1351d1351c1351d135115151d1350c03323135115152213523116221352013522135
0112000001435014352a5110543530615064352a5110743508435115152a5110d435306150143502435034350443513135141350743516135171350a435191351a1350d4351c1351d1351c1351d1352a5011e131
011200000c033115152823529235282352923511515292350c0332823529216282252923511515115150c0330c033192351a235246151c2351d2350c0331f235202350c033222352323522235232352a50130011
011600000042500415094250a4250042500415094250a42500425094253f2050a42508425094250a425074250c4250a42503425004150c4250a42503425004150c42500415186150042502425024250342504425
011600000c0330c4130f54510545186150c0330f545105450c0330f5450c41310545115450f545105450c0230c0330c4131554516545186150c03315545165450c0330c5450f4130f4130e5450e5450f54510545
0116000005425054150e4250f42505425054150e4250f425054250e4253f2050f4250d4250e4250f4250c4250a4250a42513425144150a4250a42513425144150a42509415086150741007410074120441101411
011600000c0330c4131454515545186150c03314545155450c033145450c413155451654514545155450c0230c0330c413195451a545186150c033195451a5451a520195201852017522175220c033186150c033
010b00200c03324510245102451024512245122751127510186151841516215184150c0031841516215134150c033114151321516415182151b4151d215224151861524415222151e4151d2151c4151b21518415
010200002067021670316602f65031650336503365033650386503f6503f650326502f6502f650006002f6502e6502d650006002b650296502760024650216001e65019600116500a60000630066000161000010
010200000e6510c6530a6520b653056530000000000000000e6510c6530a652000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0110000013535000002b5070000037535000001f507000002b5350000000000000001f53500000000000000013505000002b5070000037535000001f507000002b5350000000000000001f535000000000000000
011000000062200622006220062202622026220262202622006220062200622006220262202622026220262200622006220062200622026220262202622026220062200622006220062202622026220262202622
__music__
00 16174344
00 16174344
01 16174344
00 16174344
00 18194344
02 18194344
00 1a424344
01 1a1b4344
00 1a1b4344
00 1a1c4344
00 1a1c4344
02 1d1e4344
01 1f204344
00 1f214344
00 1f204344
00 1f214344
00 22234344
02 1f244344
01 25264344
00 25264344
02 27284344
00 292a4344
03 2b2c4344
04 2d2e4344
04 2f304344
01 31324344
00 31324344
00 33344344
02 35364344
01 37384344
00 393a4344
00 373b4344
02 393b4344
03 3e424344

