local selected_book = {}
local textlist_bookmark = {}
local selected_bookmark = {}

function write_to_book(itemstack, user)
	selected_book[user:get_player_name()] = itemstack
	local list,bkmrkidx=compassgps.bookmark_loop("L", user:get_player_name())
	if list == "" then
		return nil
	end
	textlist_bookmark[user:get_player_name()] = list
	local formspec = "size[9,10;]"..
			"button_exit[2,2;5,0.5;write;Write to book]"..
			"textlist[0,3.0;9,6;bookmark_list;"..list..";"..bkmrkidx.."]"
	minetest.show_formspec(user:get_player_name(), "compassgps:write", formspec)
end

function read_from_book(itemstack, user, meta) 
	selected_book[user:get_player_name()] = itemstack
	local formspec = "size[9,5]"..
			"button_exit[2,2;5,0.5;read;Read the book]"..
			"field[2,1;5,0.5;name;bookmark name:;"..meta["name"].."]"
	minetest.show_formspec(user:get_player_name(), "compassgps:read", formspec)
end

minetest.register_craftitem("compassgps:book", {
	description = "Book with a bookmark",
	inventory_image = "default_book.png",
	group = {book = 1},
	stack_max = 1,

	on_use = function(itemstack, user, pointed_thing)
		local meta = minetest.deserialize(itemstack:get_metadata())
		if (meta == nil) then
				write_to_book(itemstack, user)
			return
		end
		read_from_book(itemstack, user, meta)
		return nil
	end
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if (formname == "compassgps:write") then
		if not player then
			return
		end
		local playername = player:get_player_name();
		if (playername ~= "") then
			if (selected_book[playername] == nil) then
				return
			end
			if fields["bookmark_list"] then
				-- to get the currently selected 
				local id = minetest.explode_textlist_event(fields["bookmark_list"])
				selected_bookmark[playername] = id.index
			end
			if fields["write"] then
				local list = string.split(textlist_bookmark[playername], ",")
				if selected_bookmark[playername] == nil then
					return nil
				end
				local bkmrk = string.split(list[selected_bookmark[playername]], " : ")
				table.remove(bkmrk)
				local coord = string.split(string.sub(table.remove(bkmrk), 2, -2), " ", false, -1, true)
				print(dump(bkmrk))
				print(dump(coord))
				local write = { ["name"] = table.concat(bkmrk, " : "), 
						x = coord[1],
						y = coord[2],
						z = coord[3]}
				selected_book[playername]:set_metadata(minetest.serialize(write))
				player:set_wielded_item(selected_book[playername])
			end
		end
	end
	if (formname == "compassgps:read") then
		if not player then
			return
		end
		if (fields["read"]) then
			local meta = minetest.deserialize(selected_book[player:get_player_name()]:get_metadata())
			local bkmrkname = fields["name"]
			local pos = {	x = meta["x"] + 0,
					y = meta["y"] + 0,
					z = meta["z"] + 0 }
			local name = player:get_player_name()
			print(bkmrkname)
			compassgps.set_bookmark(name, bkmrkname, "P", pos)
		end
	end

end)
