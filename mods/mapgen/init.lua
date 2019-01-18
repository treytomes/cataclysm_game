mapgen = {}

-- Load files
local default_path = minetest.get_modpath("mapgen")

--dofile(default_path.."/functions.lua")

local function get_content_id(name)
	name = minetest.registered_aliases[name] or name
	return minetest.get_content_id(name)
end


c_cobble = get_content_id("default:cobble")
c_air = get_content_id("air")

c_ignore  = get_content_id("ignore")
c_water  = get_content_id("default:water_source")
c_grass  = get_content_id("default:dirt_with_grass")
c_dry_grass  = get_content_id("mg:dirt_with_dry_grass")
c_dirt_snow  = get_content_id("default:dirt_with_snow")
c_snow  = get_content_id("default:snow")
c_sapling  = get_content_id("default:sapling")
c_tree  = get_content_id("default:tree")
c_leaves  = get_content_id("default:leaves")
c_junglesapling  = get_content_id("default:junglesapling")
c_jungletree  = get_content_id("default:jungletree")
c_jungleleaves  = get_content_id("default:jungleleaves")
c_savannasapling  = get_content_id("mg:savannasapling")
c_savannatree  = get_content_id("mg:savannatree")
c_savannaleaves  = get_content_id("mg:savannaleaves")
c_pinesapling  = get_content_id("mg:pinesapling")
c_pinetree  = get_content_id("mg:pinetree")
c_pineleaves  = get_content_id("mg:pineleaves")
c_dirt  = get_content_id("default:dirt")
c_stone  = get_content_id("default:stone")
c_water  = get_content_id("default:water_source")
c_ice  = get_content_id("default:ice")
c_sand  = get_content_id("default:sand")
c_sandstone  = get_content_id("default:sandstone")
c_desert_sand  = get_content_id("default:desert_sand")
c_desert_stone  = get_content_id("default:desert_stone")
c_snowblock  = get_content_id("default:snowblock")
c_cactus  = get_content_id("default:cactus")
c_grass_1  = get_content_id("default:grass_1")
c_grass_2  = get_content_id("default:grass_2")
c_grass_3  = get_content_id("default:grass_3")
c_grass_4  = get_content_id("default:grass_4")
c_grass_5  = get_content_id("default:grass_5")
c_grasses = {c_grass_1, c_grass_2, c_grass_3, c_grass_4, c_grass_5}
c_jungle_grass  = get_content_id("default:junglegrass")
c_dry_shrub  = get_content_id("default:dry_shrub")
c_papyrus  = get_content_id("default:papyrus")

c_wood = get_content_id("default:wood")

local cache = {}

function get_biome_table(minp, humidity, temperature, range)
	if range == nil then range = 1 end
	local l = {}
	for xi = -range, range do
        for zi = -range, range do
            local mnp, mxp = {x=minp.x+xi*80,z=minp.z+zi*80}, {x=minp.x+xi*80+80,z=minp.z+zi*80+80}
            local pr = PseudoRandom(get_bseed(mnp))
            local bxp, bzp = pr:next(mnp.x, mxp.x), pr:next(mnp.z, mxp.z)
            local h, t = humidity:get2d({x=bxp, y=bzp}), temperature:get2d({x=bxp, y=bzp})
            l[#l+1] = {x=bxp, z=bzp, h=h, t=t}
        end
	end
	return l
end

local function get_perlin_map(seed, octaves, persistance, scale, minp, maxp)
	local sidelen = maxp.x - minp.x + 1
	local pm = minetest.get_perlin_map(
        {offset=0, scale=1, spread={x=scale, y=scale, z=scale}, seed=seed, octaves=octaves, persist=persistance},
        {x=sidelen, y=sidelen, z=sidelen}
    )
    return pm:get2dMap_flat({x = minp.x, y = minp.z, z = 0})
end

local function get_base_surface_at_point(x, z, vnoise, villages, ni, noise1, noise2, noise3, noise4)
	local index = 65536*x+z
	if cache[index] ~= nil then return cache[index] end
	cache[index] = 25*noise1[ni]+noise2[ni]*noise3[ni]/3
	if noise4[ni] > 0.8 then
		cache[index] = cliff(cache[index], noise4[ni]-0.8)
	end
	local s = 0
	local t = 0
    local noise = vnoise[ni]
    --[[
	for _, village in ipairs(villages) do
		local vn = get_vn(x, z, noise, village)
		if vn < 40 then
			cache[index] = village.vh
			return village.vh
		elseif vn < 200 then
			s = s + ((cache[index] * (vn - 40) + village.vh * (200 - vn)) / 160) / (vn - 40)
			t = t + 1 / (vn - 40)
		end
    end
    --]]
	if t > 0 then
		cache[index] = s / t
	end
	return cache[index]
end

local function surface_at_point(x, z, ...)
	return get_base_surface_at_point(x, z, unpack({...}))
end

local function get_distance(x1, x2, z1, z2)
	return (x1-x2)*(x1-x2)+(z1-z2)*(z1-z2)
end

function get_nearest_biome(biome_table, x, z)
	local m = math.huge
	local k = 0
	for key, bdef in ipairs(biome_table) do
		local dist = get_distance(bdef.x, x, bdef.z, z)
		if dist<m then
			m=dist
			k=key
		end
	end
	return biome_table[k]
end

local function mg_generate(minp, maxp, emin, emax, vm)
	local a = VoxelArea:new{
		MinEdge={x=emin.x, y=emin.y, z=emin.z},
		MaxEdge={x=emax.x, y=emax.y, z=emax.z},
	}
	
	local treemin = {x=emin.x, y=minp.y, z=emin.z}
	local treemax = {x=emax.x, y=maxp.y, z=emax.z}
	
	local sidelen = maxp.x-minp.x+1
	
	local noise1 = get_perlin_map(12345, 6, 0.5, 256, minp, maxp)
	local noise2 = get_perlin_map(56789, 6, 0.5, 256, minp, maxp)
	local noise3 = get_perlin_map(42, 3, 0.5, 32, minp, maxp)
	local noise4 = get_perlin_map(8954, 8, 0.5, 1024, minp, maxp)
	
	local noise1raw = minetest.get_perlin(12345, 6, 0.5, 256)
    
    --[[
	local vcr = VILLAGE_CHECK_RADIUS
	local villages = {}
	for xi = -vcr, vcr do
        for zi = -vcr, vcr do
            for _, village in ipairs(villages_at_point({x = minp.x + xi * 80, z = minp.z + zi * 80}, noise1raw)) do
                village.to_grow = {}
                villages[#villages+1] = village
            end
        end
    end
    --]]
	
	
	local pr = PseudoRandom(get_bseed(minp))
	
	--local village_noise = minetest.get_perlin(7635, 3, 0.5, 16)
	local village_noise_map = get_perlin_map(7635, 3, 0.5, 16, minp, maxp)
	
	local noise_top_layer = get_perlin_map(654, 6, 0.5, 256, minp, maxp)
	local noise_second_layer = get_perlin_map(123, 6, 0.5, 256, minp, maxp)
	
	local noise_temperature_raw = minetest.get_perlin(763, 7, 0.5, 512)
	local noise_humidity_raw = minetest.get_perlin(834, 7, 0.5, 512)
	local noise_temperature = get_perlin_map(763, 7, 0.5, 512, minp, maxp)
	local noise_humidity = get_perlin_map(834, 7, 0.5, 512, minp, maxp)
	local noise_beach = get_perlin_map(452, 6, 0.5, 256, minp, maxp)
	
	local biome_table = get_biome_table(minp, noise_humidity_raw, noise_temperature_raw)
	
	local data = vm:get_data()
	local param2_data = vm:get_param2_data()

	--local villages_to_grow = {}
	local ni = 0
	for z = minp.z, maxp.z do
	for x = minp.x, maxp.x do
		ni = ni + 1
		local y = math.floor(surface_at_point(x, z, village_noise_map, villages, ni, noise1, noise2, noise3, noise4))
		local humidity = noise_humidity[ni]
		local temperature = noise_temperature[ni] - math.max(y, 0) / 50
		local biome = get_nearest_biome(biome_table, x, z)
		local biome_humidity = biome.h
		local biome_temperature = biome.t
		local liquid_top
		if biome_temperature < -0.4 then
			liquid_top = c_ice
		else
			liquid_top = c_water
		end
		local above_top, top, top_layer, second_layer
		if y < -1 then
			above_top = c_air
			top = c_dirt
			top_layer = c_dirt
			second_layer = c_stone
		elseif y < 3 and noise_beach[ni] < 0.2 then
			above_top = c_air
			top = c_sand
			top_layer = c_sand
			second_layer = c_sandstone
		else
			above_top = c_air
			if biome_temperature > 0.4 then
				if biome_humidity < -0.4 then
					top = c_desert_sand
					top_layer = c_desert_sand
					second_layer = c_desert_stone
				elseif biome_humidity < 0.4 then
					top = c_dry_grass
					top_layer = c_dirt
					second_layer = c_stone
				else
					top = c_grass
					top_layer = c_dirt
					second_layer = c_stone
				end
			elseif biome_temperature < -0.4 then
				above_top = c_snow
				top = c_dirt_snow
				top_layer = c_dirt
				second_layer = c_stone
			else
				top = c_grass
				top_layer = c_dirt
				second_layer = c_stone
			end
		end
		if y >= 100 then
			above_top = c_air
			top = c_snow
			top_layer = c_snowblock
		end
		if y < 0 then
			above_top = c_air
		end
		if y <= maxp.y and y >= minp.y then
				local vi = a:index(x, y, z)
				if y >= 0 then
					data[vi] = top
				else
					data[vi] = top_layer
				end
		end
        local add_above_top = true
        --[[
		for id, tree in ipairs(mg.registered_trees) do
			if tree.min_humidity <= humidity and humidity <= tree.max_humidity
				and tree.min_temperature <= temperature and temperature <= tree.max_temperature
				and tree.min_biome_humidity <= biome_humidity and biome_humidity <= tree.max_biome_humidity
				and tree.min_biome_temperature <= biome_temperature and biome_temperature <= tree.max_biome_temperature
				and tree.min_height <= y + 1 and y + 1 <= tree.max_height
				and ((not tree.grows_on) or tree.grows_on == top)
				and pr:next(1, tree.chance) == 1 then
					local in_village = false
					for _, village in ipairs(villages) do
						if inside_village(x, z, village, village_noise) and not tree.can_be_in_village then
							village.to_grow[#village.to_grow+1] = {x = x, y = y + 1, z = z, id = id}
							in_village = true
							break
						end
					end
					if not in_village then
						tree.grow(data, a, x, y + 1, z, minp, maxp, pr)
					end
					add_above_top = false
					break
			end
        end
        --]]
		if add_above_top and y + 1 <= maxp.y and y + 1 >= minp.y then
			local vi = a:index(x, y + 1, z)
			data[vi] = above_top
		end
		if y < 0 and minp.y <= 0 and maxp.y > y then
			for yy = math.max(y + 1, minp.y), math.min(0, maxp.y) do
				local vi = a:index(x, yy, z)
				data[vi] = c_water
			end
			if maxp.y >= 0 then
				data[a:index(x, 0, z)] = liquid_top
			end
		end
		local tl = math.floor((noise_top_layer[ni] + 2.5) * 2)
		if y - tl - 1 <= maxp.y and y - 1 >= minp.y then
			for yy = math.max(y - tl - 1, minp.y), math.min(y - 1, maxp.y) do
				local vi = a:index(x, yy, z)
				data[vi] = top_layer
			end
		end
		local sl = math.floor((noise_second_layer[ni] + 5) * 3)
		if y - sl - 1 <= maxp.y and y - tl - 2 >= minp.y then
			for yy = math.max(y - sl - 1, minp.y), math.min(y - tl - 2, maxp.y) do
				local vi = a:index(x, yy, z)
				data[vi] = second_layer
			end
		end
		if y - sl - 2 >= minp.y then
			for yy = minp.y, math.min(y - sl - 2, maxp.y) do
				local vi = a:index(x, yy, z)
				data[vi] = c_stone
			end
		end
	end
    end
    --]]
	
	local va = VoxelArea:new{MinEdge=minp, MaxEdge=maxp}
    
    --[[
	for _, ore_sheet in ipairs(mg.registered_ore_sheets) do
		local sidelen = maxp.x - minp.x + 1
		local np = copytable(ore_sheet.noise_params)
		np.seed = np.seed + minp.y
		local pm = minetest.get_perlin_map(np, {x = sidelen, y = sidelen, z = 1})
		local map = pm:get2dMap_flat({x = minp.x, y = minp.z})
		local ni = 0
		local trh = ore_sheet.threshhold
		local wherein = minetest.get_content_id(ore_sheet.wherein)
		local ore = minetest.get_content_id(ore_sheet.name)
		local hmin = ore_sheet.height_min
		local hmax = ore_sheet.height_max
		local tmin = ore_sheet.tmin
		local tmax = ore_sheet.tmax
		for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			ni = ni + 1
			local noise = map[ni]
			if noise > trh then
				local thickness = pr:next(tmin, tmax)
				local y0 = math.floor(minp.y + (noise - trh) * 4)
				for y = math.max(y0, hmin), math.min(y0 + thickness - 1, hmax) do
					local vi = a:index(x, y, z)
					if data[vi] == wherein or wherein == c_ignore then
						data[vi] = ore
					end
				end
			end
		end
		end
    end
	for _, ore in ipairs(mg.registered_ores) do
		generate_vein(minetest.get_content_id(ore.name), minetest.get_content_id(ore.wherein), minp, maxp, ore.seeddiff, ore, data, a, va)
	end
	
	for _, village in ipairs(villages) do
		village.to_add = generate_village(village, minp, maxp, data, param2_data, a, village_noise)
    end
    --]]

	vm:set_data(data)
	vm:set_param2_data(param2_data)

	vm:calc_lighting(
		{x = minp.x - 16, y = minp.y, z = minp.z - 16},
		{x = maxp.x + 16, y = maxp.y, z = maxp.z + 16}
	)

	vm:write_to_map()

    --[[
	local meta
	for _, village in ipairs(villages) do
	for _, n in pairs(village.to_add) do
		minetest.set_node(n.pos, n.node)
		if n.meta ~= nil then
			meta = minetest.get_meta(n.pos)
			meta:from_table(n.meta)
			if n.node.name == "default:chest" then
				local inv = meta:get_inventory()
				local items = inv:get_list("main")
				for i = 1, inv:get_size("main") do
					inv:set_stack("main", i, ItemStack(""))
				end
				local numitems = pr:next(3, 20)
				for i = 1, numitems do
					local ii = pr:next(1, #items)
					local prob = items[ii]:get_count() % 2 ^ 8
					local stacksz = math.floor(items[ii]:get_count() / 2 ^ 8)
					if pr:next(0, prob) == 0 and stacksz>0 then
						local stk = ItemStack({
							name = items[ii]:get_name(),
							count = pr:next(1, stacksz),
							wear = items[ii]:get_wear(),
							metadata = items[ii]:get_metadata()
						})
						local ind = pr:next(1, inv:get_size("main"))
						while not inv:get_stack("main", ind):is_empty() do
							ind = pr:next(1, inv:get_size("main"))
						end
						inv:set_stack("main", ind, stk)
					end
				end
			end
		end
	end
    end
    --]]
end

local function spawnplayer(player)
    local min_pos = {x = 0, y = 3, z = 0}
    player:setpos(min_pos)

    --if minetest.setting_get("static_spawnpoint") then return end
    
    -- Looks like this will put the player near a village, which I don't have defined now.
    --[[
	local noise1 = minetest.get_perlin(12345, 6, 0.5, 256)
	local min_dist = math.huge
	local min_pos = {x = 0, y = 3, z = 0}
	for bx = -20, 20 do
        for bz = -20, 20 do
            local minp = {x = -32 + 80 * bx, y = -32, z = -32 + 80 * bz}
            for _, village in ipairs(villages_at_point(minp, noise1)) do
                if math.abs(village.vx) + math.abs(village.vz) < min_dist then
                    min_pos = {x = village.vx, y = village.vh + 2, z = village.vz}
                    min_dist = math.abs(village.vx) + math.abs(village.vz)
                end
            end
        end
    end
    player:setpos(min_pos)
    --]]
end

minetest.register_on_mapgen_init(function(mgparams)
    minetest.set_mapgen_params({mgname = "singlenode"}) --, flags = "nolight"})
end)

--[[
local wseed
minetest.register_on_mapgen_init(function(mgparams)
	wseed = math.floor(mgparams.seed/10000000000)
end)
function get_bseed(minp)
	return wseed + math.floor(5*minp.x/47) + math.floor(873*minp.z/91)
end
--]]

local function cobbleworld(minp, maxp, blockseed)
    -- Do nothing if the area is above 30
    if minp.y > 30 then
        return
    end

    -- Get the vmanip mapgen object and the nodes and VoxelArea
    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local data = vm:get_data()
    local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}

    -- Replace air with cobble
    for i in area:iter(
        minp.x, minp.y, minp.z,
        maxp.x, math.min(maxp.y, 30), maxp.z
    ) do
        if data[i] == c_air then
            data[i] = c_cobble
        end
    end

    -- Return the changed nodes data, fix light and change map
    vm:set_data(data)
    vm:set_lighting{day=0, night=0}
    vm:calc_lighting()
    vm:write_to_map()

    return
end

minetest.register_on_generated(function(minp, maxp, blockseed)
    minetest.log("warning", "Generating the map.")

    -- Get the vmanip mapgen object and the nodes and VoxelArea
    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local data = vm:get_data()
    local param2_data = vm:get_param2_data()
    local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax} --[[VoxelArea:new{
		MinEdge={x=emin.x, y=emin.y, z=emin.z},
		MaxEdge={x=emax.x, y=emax.y, z=emax.z},
    }]]

    -- Replace air with cobble
    for x = minp.x, maxp.x do
        for z = minp.z, maxp.z do
            local i = area:index(x, 0, z)
            data[i] = c_wood
        end
    end

    -- Return the changed nodes data, fix light and change map
    vm:set_data(data)
    vm:set_param2_data(param2_data)
    vm:set_lighting{day=0, night=0}
    vm:calc_lighting()
    vm:write_to_map()
    vm:update_liquids()
    return
    
    --[[for i in area:iter(minp.x, minp.y, minp.z, maxp.x, math.min(maxp.y, -8), maxp.z) do
    --for x = minp.x, maxp.x do
    --    for z = minp.z, maxp.z do
    --        local y = -32

            --minetest.log("warning", "@ ("..x..","..y..","..z..")")
            --for y = minp.y, maxp.y do
            --local i = area:index(x, y, z)
            --data[i] = c_sandstone
            if data[i] == c_air then
                data[i] = c_sandstone
            end

            --[[if y > -8 then
                data[i] = c_air
            else --if minp.y > 0 then
                data[i] = c_sandstone --c_wood
            end--]]
    --    end
    --end
end)

--[[
minetest.register_chatcommand("mg_regenerate", {
	privs = {server = true},
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if player then
			local pos = player:getpos()
			local minp, maxp = mg_regenerate(pos, name)
			if minetest.get_modpath("biome_lib") and minp and maxp then
				biome_lib.blocklist_aircheck[#biome_lib.blocklist_aircheck + 1] = {minp, maxp}
				biome_lib.blocklist_no_aircheck[#biome_lib.blocklist_no_aircheck + 1] = {minp, maxp}
			end
		end
	end,
})
--]]

minetest.register_on_newplayer(function(player)
	spawnplayer(player)
end)

minetest.register_on_respawnplayer(function(player)
	spawnplayer(player)
	return true
end)