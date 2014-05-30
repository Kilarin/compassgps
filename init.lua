--compassgps 1.2

--fixed bug that caused compass to jump around in inventory
--fixed bug causing removed bookmarks not to be saved
--expanded bookmark list from dropdown to textlist
--added pos and distance to display list
--added hud showing current pos -> target pos : distance


local compassgps = { }

local activewidth=8 --until I can find some way to get it from minetest

local player_hud = { };

local bookmarks = { }

print("compasgps reading bookmarks")
local file = io.open(minetest.get_worldpath().."/bookmarks", "r")
if file then
	bookmarks = minetest.deserialize(file:read("*all"))
	file:close()
end


local point_to = {}
local point_name = {}
local sort_function = {}
local distance_function ={}
local hud_pos = {}


--the sort functions and distance functions have to be defined ABOVE the
--"main" block or will be nil

function compassgps.sort_by_distance(table,a,b,player)
  --print("sort_by_distance a="..compassgps.pos_to_string(table[a]).." b="..pos_to_string(table[b]))
  local playerpos = player:getpos()
  local name=player:get_player_name()
  --return compassgps.distance3d(playerpos,table[a]) < compassgps.distance3d(playerpos,table[b])
  if distance_function[name] then
    return distance_function[name](playerpos,table[a]) <
           distance_function[name](playerpos,table[b])
  else
    return false  --this should NEVER happen
  end
end --sort_by_distance

function compassgps.sort_by_name(table,a,b,player)
  return a < b
end --sort_by_name


function compassgps.distance2d(pos1in,pos2in)
local pos1=compassgps.round_digits_vector(pos1in,0)
local pos2=compassgps.round_digits_vector(pos2in,0)
return math.sqrt((pos2.x-pos1.x)^2+(pos2.z-pos1.z)^2)
end --distance2d


--calculate distance between two points
function compassgps.distance3d(pos1in,pos2in)
--round to nearest node
--print("  pos1in="..compassgps.pos_to_string(pos1in).." pos2in="..compassgps.pos_to_string(pos2in))
local pos1=compassgps.round_digits_vector(pos1in,0)
local pos2=compassgps.round_digits_vector(pos2in,0)
return math.sqrt((pos2.x-pos1.x)^2+(pos2.z-pos1.z)^2+(pos2.y-pos1.y)^2)
end --distance3d





-- **********************************************************
print("compasgps reading settings")
local settings = { }
local file = io.open(minetest.get_worldpath().."/compassgps_settings", "r")
if file then
	settings = minetest.deserialize(file:read("*all"))
	file:close()
end
--now transfer these to the correct variables
for name,stng in pairs(settings) do
  if settings[name].point_name then
    point_name[name]=settings[name].point_name
  end
  if settings[name].point_to then
    point_to[name]=settings[name].point_to
  end
  if settings[name].sort_function then
    if settings[name].sort_function == "name" then
      sort_function[name]=compassgps.sort_by_name
    else
      sort_function[name]=compassgps.sort_by_distance
    end
  end
  if settings[name].distance_function then
    if settings[name].distance_function == "2d" then
      distance_function[name]=compassgps.distance2d
    else
      distance_function[name]=compassgps.distance3d
    end
  end
  if settings[name].hud_pos then
    hud_pos[name]=settings[name].hud_pos
  end
end --for


local textlist_clicked = {}
local hud_default_x=0.4
local hud_default_y=0.01


function compassgps.bookmark_from_idx(name,idx)
  --this is a darn stupid way to do this, but I can't seem to get lua
  --to give me bookmarks[idx] directly
  --print("bookmark_from_idx name="..name.." idx="..idx)
  player = minetest.get_player_by_name(name)
  if idx==1 then
    return "default"
  else
    i=1
    --for k,v in pairs(bookmarks) do
    for k,v in spairs(bookmarks,sort_function[name],player) do
      i=i+1
      if i==idx then
        local pos1, pos2 = string.find(k, name, 0)
    		if pos2 then
  			  return string.sub(k,pos2+1)
        end --pos2
      end --i==idx
    end --for
  end --if idx=1 else
return "default" --just in case
end --bookmark_from_idx




--function compassgps.get_confirm_formspec(name,bkmrk)
--  print("get_confirm_formspec")
--	return "compassgps:confirm", "size[8,8;]"..
--		--"field[0,0.2;5,1;confirm_bookmarkname;Remove "..bkmark.."?;]"..
--    "field[0,0.2;7,1;confirm_bookmarkname;Remove selected bookmark?;]"..
--		"button[0,0.7;4,1;confirm_yes;Yes]"..
--    "button[4,0.7;4,1;confirm_no;No]"
--end



minetest.register_on_player_receive_fields(function(player,formname,fields)
	if (not player) then
		return false;
	end
	local name = player:get_player_name();
	if (name ~= "" and formname == "compassgps:bookmarks") then
    --"bookmark" field is set EVERY time.  I would like to detect someone hitting
    --enter in that field, but the problem is, if someone types something into
    --the bookmark field, and then clicks on a bookmark in the textlist,
    --I would get back bookmark as set.  So, the only way to detect that
    --enter has been hit in the bookmark field is to check bookmark, and ensure
    --every other field is NOT set.
    --this leaves open the possibility of someone typing in the hudx or hudy
    --field and hitting enter after typing in the bookmark field.  Not likely
		if (fields["new_bookmark"] and fields["bookmark"]) --hit the bookmark button
      or ( (fields["bookmark"]) and (fields["bookmark"]~="")   --bookmark field not blank
          and (not fields["remove_bookmark"]) and (not fields["find_bookmark"])
          and (not fields["bookmark_list"]) and (not fields["sort_type"])
          and (not fields["distance_type"]) and (not fields["hud_pos"])
          and (not fields["teleport"]) )
      then
			compassgps.set_bookmark(name, fields["bookmark"])
  	  minetest.show_formspec(name, compassgps.get_compassgps_formspec(name))
    elseif fields["remove_bookmark"] and textlist_clicked[name] then
   	  --minetest.show_formspec(name,"compassgps:confirm", "size[8,8;]"..
	  	--  "field[0,0.2;5,1;confirmtext;Remove bookmark:"..textlist_clicked[name]..";]"..
  	  --	"button[0,0.7;4,1;remove_yes;Yes]"..
  	  --	"button[4,0.7;4,1;remove_no;No]")
      --minetest.show_formspec(name,compassgps.get_confirm_formspec(name,textlist_clicked[name]))
      --seems you can reshow THIS formspec, but not pop up another
      compassgps.remove_bookmark(name, textlist_clicked[name])
  		minetest.show_formspec(name, compassgps.get_compassgps_formspec(name))
    elseif fields["find_bookmark"] and textlist_clicked[name] then
      --if fields["bookmark_list"] then
      --  print("find bookmark clicked, bookmark_list = "..fields["bookmark_list"])
      --else
      --  print("find bookmark clicked, bookmark_list nil")
      --end
      --local tlc="nil"
      --if textlist_clicked[name] then tlc=textlist_clicked[name] end
      --print("find bookmark hit tlc="..tlc)
 			compassgps.find_bookmark(name, textlist_clicked[name])
 		elseif fields["bookmark_list"] then
      local idx=tonumber(string.sub(fields["bookmark_list"],5))
      textlist_clicked[name]=compassgps.bookmark_from_idx(name,idx)
      --print("textlist idx="..idx.." tlc="..textlist_clicked[name])
    elseif fields["sort_type"] then
      local idx=tonumber(string.sub(fields["sort_type"],5))
      if idx==1 then
        sort_function[name]=compassgps.sort_by_name
      else
        sort_function[name]=compassgps.sort_by_distance
      end --if name else distance
  		minetest.show_formspec(name, compassgps.get_compassgps_formspec(name))
    elseif fields["distance_type"] then
      local idx=tonumber(string.sub(fields["distance_type"],5))
      if idx==1 then
        distance_function[name]=compassgps.distance3d
      else
        distance_function[name]=compassgps.distance2d
      end --if 2d else 3d
  		minetest.show_formspec(name, compassgps.get_compassgps_formspec(name))
    elseif fields["teleport"] then
   		-- Teleport player.
      compassgps.teleport_bookmark(name, textlist_clicked[name])
    elseif fields["hud_pos"] and fields["hudx"] and fields["hudy"] then
      --minetest.chat_send_all("hud_pos triggered")
      if tonumber(fields["hudx"]) and tonumber(fields["hudy"]) then
        hud_pos[name].x=fields["hudx"]
        hud_pos[name].y=fields["hudy"]
        if tonumber(hud_pos[name].x)<0 or tonumber(hud_pos[name].x)>1
           or tonumber(hud_pos[name].y)<0 or tonumber(hud_pos[name].y)>1 then
        minetest.chat_send_player(name,"compassgps: hud coords out of range, hud will not be displayed.  Change to between 0 and 1 to restore")
        --compassgps.write_settings() --no need to save until you quit
        end
      else --not numbers
        minetest.chat_send_player(name,"compassgps: hud coords are not numeric.  Change to between 0 and 1")
      end --if numbers
		end
	end
end)


--saves the bookmark list in minetest/words/<worldname>/bookmarks
function compassgps.write_bookmarks()
	local file = io.open(minetest.get_worldpath().."/bookmarks", "w")
	if file then
		file:write(minetest.serialize(bookmarks))
		file:close()
	end
end --write_bookmarks


--saves the settings in minetest/words/<worldname>/compassgps_settings
function compassgps.write_settings()
  --loop through players and set settings
  --(less error prone than trying to keep settings in sync all the time
  print("compassgps writing settings")
  local players  = minetest.get_connected_players()
	for i,player in ipairs(players) do
    local name = player:get_player_name();
    local sort_short="name"
    --if you save the actual sort_function or distance_function, it saves the
    --whole function in the serialized file!  not what I wanted, and doesn't work right.
    if sort_function[name] and sort_function[name]==compassgps.sort_by_distance then
      sort_short="distance"
    end
    local dist_short="2d"
    if distance_function[name] and distance_function[name]==compassgps.distance3d then
      dist_short="3d"
    end
    settings[name]={point_to=point_to[name],
                    point_name=point_name[name],
                    hud_pos=hud_pos[name],
                    sort_function=sort_short,
                    distance_function=dist_short}
	end
  --now write to file
	local file = io.open(minetest.get_worldpath().."/compassgps_settings", "w")
	if file then
		file:write(minetest.serialize(settings))
		file:close()
	end
end --write_settings


minetest.register_on_leaveplayer(function(player)
  compassgps.write_settings()
  end)

minetest.register_on_shutdown(compassgps.write_settings)


function compassgps.set_bookmark(name, param)
	local player = minetest.get_player_by_name(name)
	if not player then
		return
	end
	local pos = player:getpos()
  --we are marking a NODE, no need to keep all those fractions
  pos=compassgps.round_pos(pos)

  --remove dangerous characters that will mess up the bookmark
  --the file can handle these fine, but the LIST for the textlist
  --will interpret these as seperators
  param=string.gsub(param,",",".")
  param=string.gsub(param,";",".")
  param=string.gsub(param,"%[","(")
  param=string.gsub(param,"%]",")")

	if param == "" then
		minetest.chat_send_player(name, "Give the bookmark a name.")
		return
	end
	if param == "default" or param == "bed" or param == "sethome" then
		minetest.chat_send_player(name, "A bookmark with the name '"..param.."' can't be created.")
		return
	end
	if bookmarks[name..param] then
		minetest.chat_send_player(name, "You already have a bookmark with that name.")
		return
	end

	bookmarks[name..param] = pos
  print("compassgps set bookmark player="..name.." pos="..compassgps.pos_to_string(pos))
  compassgps.write_bookmarks()
	minetest.chat_send_player(name, "Bookmark "..param.." added at "..compassgps.pos_to_string(pos)..".")
end


minetest.register_chatcommand("set_bookmark", {
	params = "<bookmark_name>",
	description = "set_bookmark: Sets a location bookmark for the player",
	func = function (name, param)
		compassgps.set_bookmark(name, param)
	end,
})


--[
--truncates a number
function compassgps.trunc(num)
	if num >= 0 then return math.floor(num)
  else return math.ceil(num)
  end
end --trunc

--returns a vector that is a position without fractions.
--y is dealt with specially so that it is the correct location to teleport to
function compassgps.trunc_pos(pos)
  pos.x=compassgps.trunc(pos.x)
  pos.y=compassgps.trunc(pos.y+0.5)
  --for y, height 20.5 should return 21, height -20.5 should return 20
  pos.z=compassgps.trunc(pos.z)
  return pos
end --trunc_pos
--]

--returns a pos that is rounded special case.  round 0 digits for X and Z,
--round 1 digit for Y
function compassgps.round_pos(pos)
  pos.x=compassgps.round_digits(pos.x,0)
  pos.y=compassgps.round_digits(pos.y,1)
  pos.z=compassgps.round_digits(pos.z,0)
  return pos
end --round_pos



function compassgps.round_digits(num,digits)
	if num >= 0 then return math.floor(num*(10^digits)+0.5)/(10^digits)
  else return math.ceil(num*(10^digits)-0.5)/(10^digits)
  end
end --round_digits

function compassgps.round_digits_vector(vec,digits)
	return {x=compassgps.round_digits(vec.x,digits),y=compassgps.round_digits(vec.y,digits),
	        z=compassgps.round_digits(vec.z,digits)}
end --round_digits_vector


--because built in pos_to_string doesn't handle nil, and commas mess up textlist
--this rounds same rules as for setting bookmark or teleporting
--that way what you see in the hud matches where you teleport or bookmark
function compassgps.pos_to_string(pos)
	if pos==nil then return "(nil)"
	else
    pos=compassgps.round_pos(pos)
    return "("..pos.x.." "..pos.y.." "..pos.z..")"
	end --pos==nill
end --pos_to_string


function compassgps.list_bookmarks(name, param)
	local player = minetest.get_player_by_name(name)
	if not player then
		return
	end
	local k
	local v
	--for k,v in pairs(bookmarks) do
  for k,v in spairs(bookmarks,sort_function[name],player) do
		local pos1, pos2 = string.find(k, name, 0)
		if pos2 then
			minetest.chat_send_player(name, string.sub(k,pos2+1)..": "..compassgps.pos_to_string(v))
		end
	end
end

minetest.register_chatcommand("list_bookmarks", {
	params = "",
	description = "list_bookmarks: Lists all bookmarks of a player",
	func = function(name, param)
		compassgps.list_bookmarks(name,param)
	end,
})

function compassgps.remove_bookmark(name, param)
	local player = minetest.get_player_by_name(name)
	if not player then
		return
	end
	if param == "" then
		minetest.chat_send_player(name, "No bookmark was specified.")
		return
	end
	if not bookmarks[name..param] then
		minetest.chat_send_player(name, "You have no bookmark with this name.")
		return
	end
	bookmarks[name..param] = nil
  compassgps.write_bookmarks()
	minetest.chat_send_player(name, "The bookmark "..param.." has been successfully removed.")
end


minetest.register_chatcommand("remove_bookmark", {
	params = "<bookmark_name>",
	description = "Removes the bookmark specified by <bookmark_name>",
	func = function(name, param)
		compassgps.remove_bookmark(name,param)
	end,
})


function compassgps.teleport_bookmark(name, param)
	local player = minetest.get_player_by_name(name)
  print("compassgps teleporting player "..name.." to "..param)
	if not player then
		return
	end
	if not param or param == "" then
		minetest.chat_send_player(name, "No bookmark was specified.")
		return
	end
	if param == "default" then
		minetest.chat_send_player(name, "Teleporting to default location.")
		player:setpos(compassgps.get_default_pos_and_name(name))
		return
	end
	if not bookmarks[name..param] then
		minetest.chat_send_player(name, "You have no bookmark with this name.")
		return
	end
	minetest.chat_send_player(name, "Teleport to "..param..".")
  player:setpos(bookmarks[name..param])
end --teleport_bookmark


function compassgps.find_bookmark(name, param)
  --print("find_bookmark name="..name.." param="..param)
	local player = minetest.get_player_by_name(name)
	if not player then
		return
	end
	if not param or param == "" then
		minetest.chat_send_player(name, "No bookmark was specified.")
		return
	end
	if param == "default" then
		minetest.chat_send_player(name, "Pointing at default location.")
		point_to[name] = nil
    point_name[name] = "default"
		return
	end
	if not bookmarks[name..param] then
		minetest.chat_send_player(name, "You have no bookmark with this name.")
		return
	end
	point_to[name] = bookmarks[name..param]
  point_name[name] = param
	minetest.chat_send_player(name, "Pointing at "..param..".")
end

minetest.register_chatcommand("find_bookmark", {
	params = "<bookmark_name>",
	description = "Lets the compassgps point to the bookmark",
	func = function(name, param)
		find_bookmark(name,param)
	end,
})





-- compassgps mod




-- default to 0/0/0
local default_spawn = {x=0, y=0, z=0}
-- default to static spawnpoint (overwrites 0/0/0)
local default_spawn_settings = minetest.setting_get("static_spawnpoint")
if (default_spawn_settings) then
	pos1 = string.find(default_spawn_settings, ",", 0)
	default_spawn.x = tonumber(string.sub(default_spawn_settings, 0, pos1 - 1))
	pos2 = string.find(default_spawn_settings, ",", pos1 + 1)
	default_spawn.y = tonumber(string.sub(default_spawn_settings, pos1 + 1, pos2 - 1))
	default_spawn.z = tonumber(string.sub(default_spawn_settings, pos2 + 1))
end

local last_time_spawns_read = "default"
local pilzadams_spawns = {}
local sethome_spawns = {}
function read_spawns()
	-- read PilzAdams bed-mod positions
	local pilzadams_file = io.open(minetest.get_worldpath().."/beds_player_spawns", "r")
	if pilzadams_file then
		pilzadams_spawns = minetest.deserialize(pilzadams_file:read("*all"))
		pilzadams_file:close()
	end
	-- read sethome-mod positions
	if minetest.get_modpath('sethome') then
		local sethome_file = io.open(minetest.get_modpath('sethome')..'/homes', "r")
		if sethome_file then
			while true do
				local x = sethome_file:read("*n")
				if x == nil then
					break
				end
				local y = sethome_file:read("*n")
				local z = sethome_file:read("*n")
				local name = sethome_file:read("*l")
				sethome_spawns[name:sub(2)] = {x = x, y = y, z = z}
			end
			io.close(sethome_file)
		end
	end
end


function compassgps.get_default_pos_and_name(name)
	-- try to get position from PilzAdams bed-mod spawn
	local pos = pilzadams_spawns[name]
  local posname="bed"
	-- fallback to sethome position
	if pos == nil then
		pos = sethome_spawns[name]
    posname="sethome"
	end
	-- fallback to default
	if pos == nil then
		pos = default_spawn;
    posname="default"
	end
return pos,posname
end --get_compassgps_target_pos


minetest.register_globalstep(function(dtime)

	if last_time_spawns_read ~= os.date("%M") then
		last_time_spawns_read = os.date("%M")
		read_spawns()
	end
	local players  = minetest.get_connected_players()
	for i,player in ipairs(players) do
    local name = player:get_player_name();

    local gotacompass=false
    local wielded=false
    local activeinv=nil
    local stackidx=0
    --first check to see if the user has a compass, because if they don't
    --there is no reason to waste time calculating bookmarks or spawnpoints.
		local wielded_item = player:get_wielded_item():get_name()
		if string.sub(wielded_item, 0, 11) == "compassgps:" then
      --if the player is wielding a compass, change the wielded image
      wielded=true
      stackidx=1
      gotacompass=true
		else
      --check to see if compass is in active inventory
			if player:get_inventory() then
        --is there a way to only check the activewidth items instead of entire list?
        --problem being that arrays are not sorted in lua
				for i,stack in ipairs(player:get_inventory():get_list("main")) do
					if i<=activewidth and string.sub(stack:get_name(), 0, 11) == "compassgps:" then
						--player:get_inventory():remove_item("main", stack:get_name())
						--player:get_inventory():add_item("main", "compassgps:"..compass_image)
            activeinv=stack  --store the stack so we can update it later with new image
            stackidx=i --store the index so we can add image at correct location
            gotacompass=true
					end --if i<=activewidth
				end --for loop
			end -- get_inventory
		end --if wielded else


    --dont mess with the rest of this if they don't have a compass
    if gotacompass then
      -- try to get the bookmark position
    	local spawn = point_to[name]
      if spawn==nil then
        spawn,point_name[name]= compassgps.get_default_pos_and_name(name)
      end

      --print("globalstep spawn="..compassgps.pos_to_string(spawn))
  		pos = player:getpos()
  		dir = player:get_look_yaw()
  		local angle_north = math.deg(math.atan2(spawn.x - pos.x, spawn.z - pos.z))
  		if angle_north < 0 then angle_north = angle_north + 360 end
  		angle_dir = 90 - math.deg(dir)
  		local angle_relative = (angle_north - angle_dir) % 360
  		local compass_image = math.floor((angle_relative/30) + 0.5)%12

      --update compass image to point at target
  		if wielded then
      	player:set_wielded_item("compassgps:"..compass_image)
  		elseif activeinv then
				player:get_inventory():remove_item("main", activeinv:get_name())
        player:get_inventory():set_stack("main",stackidx,"compassgps:"..compass_image)
      end --if wielded elsif activin


      --update the hud with playerpos -> target pos : distance to target
      if distance_function[name]==nil then
        distance_function[name]=compassgps.distance3d
      end


      local hudx=tonumber(hud_default_x)
      local hudy=tonumber(hud_default_y)
      if hud_pos[name] then
        hudx=tonumber(hud_pos[name].x)
        hudy=tonumber(hud_pos[name].y)
      else
        hud_pos[name]={x=hud_default_x, y=hud_default_y}
      end

      local h=nil
      if hudx>=0 and hudx<=1 and hudy>=0 and hudy<=1 then
        h = player:hud_add({
          hud_elem_type = "text";
          --position = {x=0.4, y=0.01}
          position = {x=hudx, y=hudy};
          --text = "compassgps: "..compassgps.pos_to_string(pos).." -> "..point_name[name]..
          text = compassgps.pos_to_string(pos).." -> "..point_name[name]..
                 " "..compassgps.pos_to_string(spawn).." : "..
                 compassgps.round_digits(distance_function[name](pos,spawn),2);
          number = 0xFFFF00;
      		scale = 20;
          });
        end --if x and y in range
      if (player_hud[name]) then
        --remove the previous element
        player:hud_remove(player_hud[name]);
        --minetest.chat_send_player(player:get_player_name(),dtime.." remove old hud")
      end
      player_hud[name] = h; --store this element for removal next time
    --this elseif is triggered if gotacompass=false
    elseif (player_hud[name]) then  --remove the hud if player no longer has compass
      player:hud_remove(player_hud[name]);
      player_hud[name]=nil
    end --if gotacompass
	end --for i,player in ipairs(players)
end) -- register_globalstep



local images = {
	"compass_0.png",
	"compass_1.png",
	"compass_2.png",
	"compass_3.png",
	"compass_4.png",
	"compass_5.png",
	"compass_6.png",
	"compass_7.png",
	"compass_8.png",
	"compass_9.png",
	"compass_10.png",
	"compass_11.png",
}






function compassgps.sort_by_coords(table,a,b)
    if table[a].x==table[b].x then
       if table[a].z==table[b].z then
         return table[a].y<table[b].y
       else
         return table[a].z<table[b].z
       end
    else
      return table[a].x < table[b].x
    end
end --sort_by_coords


--this handy bit of code modified from Michal Kottman
--http://stackoverflow.com/questions/15706270/sort-a-table-in-lua
function spairs(t, order, player)
    --print("spairs top")
    --print("spairs top player="..player:get_player_name())
    --if order==compassgps.sort_by_distance then print("spairs order=sort_by_distance")
    --else print("spairs order=sort_by_name")
    --end
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end
    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys
    if order then
        table.sort(keys, function(a,b) return order(t, a, b, player) end)
    else
        table.sort(keys)
    end
    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end--spairs






function compassgps.get_compassgps_formspec(name)
	local player = minetest.get_player_by_name(name)
  local playerpos = player:getpos()
  --print("get_compassgps_formspec spawn="..compassgps.pos_to_string(store_spawn[name]))
  local list = "default "..compassgps.pos_to_string(compassgps.get_default_pos_and_name(name))
      .." : "..
      compassgps.round_digits(distance_function[name](playerpos,
           compassgps.get_default_pos_and_name(name)),2)
	local k
	local v
  --print("get_compassgps_formspec player "..name)

  local sortdropdown=1
  if sort_function[name] then
    if sort_function[name]==compassgps.sort_by_distance then
      sortdropdown=2
    end
  else
    sort_function[name]=compassgps.sort_by_name
  end

  local distdropdown=1
  if distance_function[name] then
    if distance_function[name]==compassgps.distance2d then
      distdropdown=2
    end
  else
    distance_function[name]=compassgps.distance3d
  end


  --textlist triggers register_on_recieve_fields whenever you click on an item in
  --the list, but returns nil if you check it after a button is clicked.
  --so we use textlist_clicked[name] to store the currently selected item in the
  --list  so we can have it when a button is clicked
  textlist_clicked[name]="default"
  local bkmrkidx=1  --this is what we will send to textlist
  --so if we don't find point_name in the bookmarks, we will point to default
  local i=1  --its is the index in the bookmarks
  for k,v in spairs(bookmarks,sort_function[name],player) do
		local pos1, pos2 = string.find(k, name, 0)
		if pos2 then
      i=i+1
      local bkmrkname=string.sub(k,pos2+1)
      if bkmrkname==point_name[name] then
        bkmrkidx=i
        textlist_clicked[name]=point_name[name]
      end
			list = list..","..bkmrkname.." : "..compassgps.pos_to_string(v)..
         " : "..compassgps.round_digits(distance_function[name](playerpos,v),2)
		end
	end


  --check to see if the player has teleport privliges
  local player_privs
  if core then player_privs = core.get_player_privs(name)
  else player_privs = minetest.get_player_privs(name)
  end
  local telepriv=false
  if player_privs["teleport"] then
    telepriv=true
  end



	return "compassgps:bookmarks", "size[9,10;]"..
		"field[0,0.2;5,1;bookmark;bookmark:;]"..
		"button[0,0.7;4,1;new_bookmark;create bookmark]"..
    "button[4,0.7;4,1;remove_bookmark;remove bookmark]"..
    "label[0,1.75;Sort by:]"..
    "textlist[1,1.75;1.2,1;sort_type;name,distance;"..sortdropdown.."]"..
    "label[2.4,1.75;Dist:]"..
    "textlist[3,1.75;.5,1;distance_type;3d,2d;"..distdropdown.."]"..
    "button[4,1.9;2.25,1;hud_pos;Change hud Pos:]"..
    "field[6.6,2.2;1.2,1;hudx;X:("..hud_default_x..");"..hud_pos[name].x.."]"..
    "field[7.8,2.2;1.2,1;hudy;Y:("..hud_default_y..");"..hud_pos[name].y.."]"..
    "textlist[0,3.0;9,6;bookmark_list;"..list..";"..bkmrkidx.."]"..
		"button[0,9.3;3,1;find_bookmark;find selected bookmark]"..
    "button[4,9.3;3,1;teleport;teleport to bookmark]"

		--"dropdown[0,1.5;8;bookmark_list;"..list..";1]"..
--{"textlist", x=<X>, y=<Y>, w=<Width>, h=<Height>, name="<name>", list=<array of string/number/boolean>}
--"textlist[0.1,1.2;5.7,3.6;travelpoint;" .. tp_string .. ";" .. tp_index .. "]"

end

local i
for i,img in ipairs(images) do
	local inv = 1
	if i == 1 then
		inv = 0
	end
	minetest.register_tool("compassgps:"..(i-1), {
		description = "compassgps",
		inventory_image = img,
		wield_image = img, --.."^[transformR90"  didn't work
		on_use = function (itemstack, user, pointed_thing)
				local name = user:get_player_name()
				if (name ~= "") then
					minetest.show_formspec(name, compassgps.get_compassgps_formspec(name))
				end
			end,
		groups = {not_in_creative_inventory=inv}
	})
end

minetest.register_craft({
	output = 'compassgps:1',
	recipe = {
		{'', 'default:steel_ingot', ''},
		{'default:steel_ingot', 'default:mese_crystal_fragment', 'default:steel_ingot'},
		{'', 'default:steel_ingot', ''}
	}
})
