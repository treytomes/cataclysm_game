
local windmill_entity = {
	physical = true,
	collisionbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
	visual = "mesh",
	mesh = "windmills_windmill.x",
	visual_size = {x=1, y=1},
	textures = {"windmills_windmill_3.png"},

	driver = nil,
	punched = false, -- used to re-send velocity and position
	velocity = {x=0, y=0, z=0}, -- only used on punch

    --old_dir = {x=0, y=0, z=0},
	--old_pos = nil,
	--old_switch = 0,
	--railtype = nil,
    --attached_items = {}
    
    --[[actions = {
        {
            name = "spin",
            start = 0,end = 100,
            rate = 24,
        },
    },]]
}

function windmill_entity:on_rightclick(clicker)
	--[[if not clicker or not clicker:is_player() then
		return
	end
	local player_name = clicker:get_player_name()
	if self.driver and player_name == self.driver then
		self.driver = nil
		carts:manage_attachment(clicker, nil)
	elseif not self.driver then
		self.driver = player_name
		carts:manage_attachment(clicker, self.object)
	end]]
end

function windmill_entity:on_activate(staticdata, dtime_s)
    local start = 1
    local finish = 100
    local frame_speed = 24
    local frame_blend = 0
    local frame_loop = true
    self.object:set_animation({x = start, y = finish}, frame_speed, frame_blend, frame_loop)
    minetest.chat_send_all("Animating!!!")

    --self.object:set_action("spin")

	--[[self.object:set_armor_groups({immortal=1})
	if string.sub(staticdata, 1, string.len("return")) ~= "return" then
		return
	end
	local data = minetest.deserialize(staticdata)
	if not data or type(data) ~= "table" then
		return
	end
	self.railtype = data.railtype
	if data.old_dir then
		self.old_dir = data.old_dir
	end
	if data.old_vel then
		self.old_vel = data.old_vel
	end]]
end

function windmill_entity:get_staticdata()
	return nil --[[minetest.serialize({
		railtype = self.railtype,
		old_dir = self.old_dir,
		old_vel = self.old_vel
	})]]
end

function windmill_entity:on_punch(puncher, time_from_last_punch, tool_capabilities, direction)
    local inv = puncher:get_inventory()
    if not (creative and creative.is_enabled_for and creative.is_enabled_for(puncher:get_player_name())) or not inv:contains_item("main", "windmills:windmill") then
        local leftover = inv:add_item("main", "windmills:windmill")
        -- If no room in inventory add a replacement windmill to the world
        if not leftover:is_empty() then
            minetest.add_item(self.object:getpos(), leftover)
        end
    end
    self.object:remove()
    return
end

function windmill_entity:on_step(dtime)
    --minetest.chat_send_all("windmill_entity:on_step")
end

minetest.register_entity("windmills:windmill", windmill_entity)

function round(num, numDecimalPlaces)
    return math.floor(num + 0.5)

    --local mult = 10^(numDecimalPlaces or 0)
    --return math.floor(num * mult + 0.5) / mult
end

minetest.register_craftitem("windmills:hemp", {
	description = "Hemp",
	inventory_image = "windmills_hemp.png",
    wield_image = "windmills_hemp.png"
})

minetest.register_craftitem("windmills:hempfiber", {
	description = "Hemp Fiber",
	inventory_image = "windmills_hemp_fiber.png",
    wield_image = "windmills_hemp_fiber.png"
})

minetest.register_craftitem("windmills:fabric", {
	description = "Fabric",
	inventory_image = "windmills_fabric.png",
    wield_image = "windmills_fabric.png"
})

minetest.register_craftitem("windmills:sail", {
	description = "Sail",
	inventory_image = "windmills_sail.png",
    wield_image = "windmills_sail.png"
})

minetest.register_craftitem("windmills:windmill", {
	description = "Windmill (punch to pick up)",
	inventory_image = "windmills_windmill_item.png", --minetest.inventorycube("carts_cart_top.png", "carts_cart_side.png", "carts_cart_side.png"),
	wield_image = "windmills_windmill_item.png",
	on_place = function(itemstack, placer, pointed_thing)
		local under = pointed_thing.under
		local node = minetest.get_node(under)
		local udef = minetest.registered_nodes[node.name]
		if udef and udef.on_rightclick and not (placer and placer:is_player() and placer:get_player_control().sneak) then
			return udef.on_rightclick(under, node, placer, itemstack, pointed_thing) or itemstack
		end

		if not pointed_thing.type == "node" then
			return
        end
        
        --local place_pos = minetest.get_pointed_thing_position(pointed_thing, false)
        local place_pos = minetest.pointed_thing_to_face_pos(placer, pointed_thing)
        --place_pos.x = round(place_pos.x * 10 / 5, 0) * 5 / 10
        --place_pos.y = round(place_pos.y * 10 / 5, 0) * 5 / 10
        --place_pos.z = round(place_pos.z * 10 / 5, 0) * 5 / 10

        minetest.chat_send_all("Before: x="..place_pos.x..", y="..place_pos.y..", z="..place_pos.z)

        local rotate = false
        if (place_pos.x - round(place_pos.x, 0) < 0.5) then
            place_pos.z = math.floor(place_pos.z) + 0.5
            place_pos.x = math.floor(place_pos.x + 0.5) --round(place_pos.z * 10 / 5, 0) * 5 / 10
            minetest.chat_send_all("After: x="..place_pos.x..", y="..place_pos.y..", z="..place_pos.z)
        elseif (round(place_pos.x, 0) - place_pos.x < 0.5) then
            -- TODO: This block is never being hit.  How to toggle "rotate"?
            place_pos.x = round(place_pos.x, 0) + 0.5
            place_pos.z = round(place_pos.z, 0) --round(place_pos.z * 10 / 5, 0) * 5 / 10
            rotate = true
        elseif (place_pos.z - round(place_pos.z, 0) < 0.5) then
            place_pos.z = round(place_pos.z, 0) - 0.5
            place_pos.x = round(place_pos.x, 0) --round(place_pos.x * 10 / 5, 0) * 5 / 10
        elseif (round(place_pos.z, 0) - place_pos.z < 0.5) then
            place_pos.z = round(place_pos.z, 0) + 0.5
            place_pos.x = round(place_pos.x, 0) --round(place_pos.x * 10 / 5, 0) * 5 / 10
        end
        place_pos.y = round(place_pos.y, 0) -- + 0.5

        minetest.add_entity(place_pos, "windmills:windmill")

		minetest.sound_play({name = "default_place_node_metal", gain = 0.5}, {pos = pointed_thing.above})

		if not (creative and creative.is_enabled_for and creative.is_enabled_for(placer:get_player_name())) then
			itemstack:take_item()
		end
		return itemstack
	end,
})

-- TODO: Register a hemp seed / plant.

--[[
    TODO: Hemp should be ground up somehow to get the fibers out.
    The process of generating fibers would also generate oil.
]]
minetest.register_craft({
    output = "windmills:hempfiber 4",
    recipe = {
        { "windmills:hemp" }
    }
})

minetest.register_craft({
    output = "windmills:fabric",
    recipe = {
        { "windmills:hempfiber", "windmills:hempfiber", "windmills:hempfiber" },
        { "windmills:hempfiber", "windmills:hempfiber", "windmills:hempfiber" },
        { "windmills:hempfiber", "windmills:hempfiber", "windmills:hempfiber" },
    }
})

minetest.register_craft({
    output = "windmills:sail",
    recipe = {
        { "windmills:fabric", "windmills:fabric", "windmills:fabric" },
        { "windmills:fabric", "windmills:fabric", "windmills:fabric" },
        { "group:wood", "group:wood", "group:wood" },
    }
})

minetest.register_craft({
	output = "windmills:windmill",
	recipe = {
		{ "", "windmills:sail", "" },
		{ "windmills:sail", "", "windmills:sail" },
		{ "", "windmills:sail", "" },
	},
})
