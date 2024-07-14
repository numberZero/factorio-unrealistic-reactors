local rpath = (...):match("(.-)[^%.]+$")
local Setting = require(rpath .. "setting")
local network = require(rpath .. "heat.network")
local technology = require(rpath .. "technology")
local union_tables = require(rpath .. "util").union_tables
local splitty = require(rpath .. "gui.util").splitty
local Setting = require(rpath .. "setting")


local function on_settings_changed()
	for _,reactor in pairs(global.reactors) do --updating signals for removed fuel cell mods
		if reactor.entity.valid == true then
			if reactor.entity.get_fuel_inventory().is_empty() then
				reactor.signals.parameters["uranium-fuel-cells"].signal = {type="item", name="uranium-fuel-cell"}
				reactor.signals.parameters["uranium-fuel-cells"].count = 0
			end
		end
		reactor.signals.parameters["used-uranium-fuel-cells"] = nil
		--if reactor.entity.get_burnt_result_inventory().is_empty() then
		--	reactor.signals.parameters["used-uranium-fuel-cells"].signal = {type="item", name="used-up-uranium-fuel-cell"}
		--	reactor.signals.parameters["used-uranium-fuel-cells"].count = 0
		--end
		reactor.signals.parameters["neighbour-bonus"] = {signal=SIGNAL_NEIGHBOUR_BONUS, count=0, index=13}
	end
	technology.init()
end



local function migration()
	--msg("RealisticReactors - current mod version: "..global.version)
	--game.players[1].print("on_configuration_changed. global.version: "..global.version)
	if not global.version or global.version < 1 then
		for i,reactor in pairs(global.reactors) do
			reactor.signals.parameters["coolant-temperature"] = nil
			reactor.signals.parameters["neighbour-bonus"] = nil
			--fluid signal removal
			--reactor.signals.parameters["coolant-amount"] = nil
			
			if not reactor.efficiency then
				reactor.efficiency = 100
			end
			if not reactor.signals.parameters["power-output"] then
				reactor.signals.parameters["power-output"] = {signal=SIGNAL_REACTOR_POWER_OUTPUT,count=0,index=7}
			end
			if not reactor.signals.parameters["efficiency"] then
				reactor.signals.parameters["efficiency"] = {signal=SIGNAL_REACTOR_EFFICIENCY,count=0,index=10}
			end
			
			--2
			reactor.displayer = reactor.core.surface.create_entity{name = "realistic-reactor-normal", position = {reactor.core.position.x, reactor.core.position.y}, force = reactor.core.force.name, create_build_effect_smoke = false}
			if not reactor.core.get_fuel_inventory().is_empty() then
				reactor.displayer.get_fuel_inventory().insert(reactor.core.get_fuel_inventory()[1])
			end
			
			--3
			reactor.fuel_last_tick = reactor.core.burner.remaining_burning_fuel
			if reactor.core.get_fuel_inventory().is_empty() then
				reactor.cells_last_tick = 0
			else
				reactor.cells_last_tick = reactor.core.get_fuel_inventory()[1].count
			end
			reactor.displayer.active = reactor.core.active
			reactor.displayer.minable = reactor.core.minable
			
			--4
			reactor.power = reactor.core.surface.create_entity{
				name = REACTOR_POWER_NAME,
				position = reactor.core.position,
				force = reactor.core.force,
				create_build_effect_smoke = false,
			}
			reactor.power.destructible=false
			reactor.power.energy = 17000000
			reactor.signals.parameters["coolant-amount"] = {signal=SIGNAL_COOLANT_AMOUNT, count=0, index=6}
			
			--5 (removed, was the old implementation of bonus cells)
			--6
			reactor.signals.parameters["cell-bonus"] = {signal=SIGNAL_REACTOR_CELL_BONUS, count=0, index=11}
			
			--7
			reactor.interface.operable = true

			--8
			reactor.cooling_history = 0
			local color = "black"
			if reactor.state == "starting" then
				color = "yellow"
			elseif reactor.state == "running" then
				color = "green"
			elseif reactor.state == "scramed" then
				color = "red"
			end
			reactor.lamp = reactor.core.surface.create_entity{name = "rr-"..color.."-lamp", position = {reactor.core.position.x-0.62,reactor.core.position.y+0.6}, force = reactor.core.force.name, create_build_effect_smoke = false}
			reactor.lamp.destructible = false
			reactor.light = reactor.core.surface.create_entity{name = "rr-"..color.."-light", position = {reactor.core.position.x-0.62,reactor.core.position.y+0.6}, force = reactor.core.force.name, create_build_effect_smoke = false}
			reactor.light.destructible = false
			reactor.interface_warning_tick = 0
			reactor.interface_warning = nil
			reactor.cooling_warning_tick = 0
			reactor.cooling_warning = nil
			reactor.power_usage = {starting = 0,cooling = 0, interface = 0}
			reactor.neighbours = 0
			reactor.bonus_cells = {}
			reactor.core.destructible = false
			
			--9
			reactor.signals.parameters["electric-power"] = {signal=SIGNAL_REACTOR_ELECTRIC_POWER, count=0, index=12}
			reactor.fluid_amount_last_tick = 0
			reactor.power_output_last_tick = 0
			if reactor.core.get_burnt_result_inventory().is_empty() then
				reactor.used_cells_last_tick = 0
			else
				reactor.used_cells_last_tick = reactor.core.get_burnt_result_inventory()[1].count
			end
			
		end
		
		--7
		gui.init()
		
		--9
		global.fallout = {}
		global.falloutclouds = {}
		global.geigers = {}
		

		
		global.version=1
	end
	
	if global.version < 2 then
		
		--10
		global.ruins = {}
		global.sarcophagus = {}
		game.create_force("radioactivity")
		game.create_force("radioactivity-strong")
		
		--11
		local reactor_state = {}
		reactor_state["stopped"] = 0
		reactor_state["starting"] = 1
		reactor_state["running"] = 2
		reactor_state["scramed"] = 3
		
		--12
		global.delayed_fallout={}
		global.tick_delayer = 0
		for _, stats in pairs (global.stats) do
			stats.max = 999
		end
		
		for i,reactor in pairs(global.reactors) do
			--11
			reactor.state = reactor_state[reactor.state]
			reactor.last_temp_update = game.tick
			reactor.signals.parameters["uranium-fuel-cells"].signal = {type="item", name="uranium-fuel-cell"}
			--reactor.signals.parameters["used-uranium-fuel-cells"].signal = {type="item", name="used-up-uranium-fuel-cell"}
			reactor.signals.parameters["used-uranium-fuel-cells"] = nil
			reactor.core.destructible = false
			reactor.max_power = 155
			
			reactor.interface.destructible = false
			reactor.interface.minable = false
		end
		global.version = 2
	end
	
	if global.version <3 then

		--for _, stats in pairs (global.stats) do
		--	stats.max = 999
		--end
		global.all_heat_pipes = {}
		global.underground_heat_pipes = {}
		for _, surface in pairs(game.surfaces) do
			global.all_heat_pipes[surface.name] = {}
			local heat_pipes = surface.find_entities_filtered{type='heat-pipe'}
			
			for _, hp in pairs (heat_pipes) do
				if hp.name == "rr-underground-heat-pipe" then
					table.insert(global.underground_heat_pipes, hp)
				end
			--function get_connected_heat_pipes(heat_pipe)
				local result = {}	
				
				for i,heatpipe in pairs(heat_pipes) do
					
					if hp.position.x == heatpipe.position.x then
						if hp.position.y == heatpipe.position.y + 1 or hp.position.y == heatpipe.position.y - 1 then
							----logging("--> connected to heat pipe, ID: " .. heatpipe.unit_number)
							table.insert(result, heatpipe)
						end
					end
					
					if hp.position.y == heatpipe.position.y then
						if hp.position.x == heatpipe.position.x + 1 or hp.position.x == heatpipe.position.x - 1 then
							----logging("--> connected to heat pipe, ID: " .. heatpipe.unit_number)
							table.insert(result, heatpipe)
						end
					end		
					
				end
				global.all_heat_pipes[surface.name][hp.unit_number] = {hp,result,{}}
			end
		end
		
		for i,reactor in pairs(global.reactors) do
			reactor.max_efficiency = 210
			local hp_neighbour_entities_ew = reactor.core.surface.find_entities_filtered{area = {{reactor.position.x-2,reactor.position.y-1},{reactor.position.x+2,reactor.position.y}}, type='heat-pipe'} --east and west
			local hp_neighbour_entities_n = reactor.core.surface.find_entities_filtered{area = {{reactor.position.x-1,reactor.position.y-2},{reactor.position.x+1,reactor.position.y}}, type='heat-pipe'} -- north
			local table_of_heat_pipes_to_check = union_tables(hp_neighbour_entities_ew,hp_neighbour_entities_n)
			for _, hp in pairs(table_of_heat_pipes_to_check) do
				table.insert(global.all_heat_pipes[reactor.core.surface.name][hp.unit_number][3],reactor)
			end
				
		end
		global.version = 3
	end
	
	if global.version <4 then
		for i,reactor in pairs(global.reactors) do
			reactor.last_states_update = game.tick
		end
		global.version = 4
	end
	
	if global.version <5 then
		for key, gui in pairs (global.guis) do
			if gui.graph then gui.graph.destroy() end
		end
		global.version = 5
	end
	
	if global.version <6 then
		for key, force in pairs (game.forces) do
			if force.technologies["nuclear-power"].researched then
				force.recipes["nuclear-reactor"].enabled = true
			end
		end
		global.version = 6
	end
	if global.version <7 then
		for i,reactor in pairs(global.reactors) do
			reactor.light.teleport{reactor.core.position.x+0.017,reactor.core.position.y+0.88}
			reactor.lamp.teleport{reactor.core.position.x+0.017,reactor.core.position.y+0.88}
		end
		global.version = 7
	end
	if global.version <10 then
		for i,reactor in pairs(global.reactors) do
			reactor.core.get_fuel_inventory().clear()
			reactor.core.get_burnt_result_inventory().clear()
			reactor.core.get_fuel_inventory().insert{name="rr-dummy-fuel-cell", count = 50}
			reactor.core.burner.currently_burning = "rr-dummy-fuel-cell"
			reactor.core.burner.remaining_burning_fuel = 9223372035000000000
		end
		global.version = 10
	end
	if global.version <11 then
		global.random = game.create_random_generator()
		global.lightEffects = global.lightEffects or {}
		global.interfaces = {}
		network.init()

		local towers = {}
		global.iterate_cooling_towers = nil -- not needed anymore
		for _,tower in pairs(global.towers) do
			if tower.entity.valid then
				towers[tower.id] = tower -- use unit_number as index
			end
		end
		global.towers = towers

		local ruins = {}
		for _,ruin in pairs(global.ruins) do
			if ruin.entity.valid then
				ruins[ruin.id] = ruin -- use unit_number as index
				ruin.entity.destructible = false
				ruin.entity.minable = true
			end
		end
		global.ruins = ruins

		local fallouts = {}
		for _,fallout in pairs(global.fallout) do
			if fallout.surface.valid then
				fallout.id = fallout.surface.index
				fallout.positions = {[fallout.tick] = fallout.position}
				fallout.position = nil
				fallout.tick = nil
				fallout.clouds = {}
				fallouts[fallout.id] = fallout -- use surface.index as index
			end
		end
		for _,cloud in pairs(global.falloutclouds) do
			if cloud.valid then
				local fallout = fallouts[cloud.surface.index] or {
					id = cloud.surface.index,
					surface = cloud.surface,
					positions = {},
					clouds = {},
				}
				fallouts[fallout.id] = fallout
				table.insert(fallout.clouds, cloud)
			end
		end
		global.falloutclouds = nil
		global.fallout = fallouts

		local sarcophagus = {}
		for _,entity in pairs(global.sarcophagus) do
			if entity.valid then
				sarcophagus[entity.unit_number] = entity
			end
		end
		global.sarcophagus = sarcophagus

		local lookup = {}
		for key,reactor in pairs(global.reactors) do
			lookup[key] = reactor.displayer.unit_number
		end

		local reactors = {}
		global.iterate_reactor_temp_signals = nil
		global.iterate_reactor_states = nil
		global.iterate_reactor_temp = nil
		global.skip_temp_iteration = nil
		global.tick_delayer = nil
		for _,reactor in pairs(global.reactors) do
			if reactor.displayer.valid then
				reactor.connected_neighbours_IDs = nil
				reactor.entity = reactor.displayer
				reactor.displayer = nil
				reactor.id = reactor.entity.unit_number
				reactors[reactor.id] = reactor -- use unit_number as index
			end
		end
		global.reactors = reactors

		global.all_heat_pipes = nil
		global.connected_reactors = nil
		global.underground_heat_pipes = nil

		local stats = {}
		for key,stat in pairs(global.stats) do
			stats[lookup[key]] = stat
		end
		global.stats = stats

		local guis = {}
		global.worker_key = nil
		for key, gui in pairs(global.guis) do
			local reactor_key, playerid = splitty(key,"-")
			if gui.valid then
				local id = lookup[reactor_key]
				guis[id .. "-" .. playerid] = gui
				gui.name = "rr_gui_" .. id
			end
		end
		global.guis = guis

		global.version = 11
	end
	if global.version <12 then
		network.init() -- fixed a bug there, see the π release
		global.version = 12
	end
	--msg("RealisticReactors - current mod version (after migration): "..global.version)
end

local function on_configuration_changed()
	migration()
	on_settings_changed()
end

return on_configuration_changed -- exports
