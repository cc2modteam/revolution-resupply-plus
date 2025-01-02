

if g_rev_mods ~= nil then
	table.insert(g_rev_mods, "Resupply+")
end

g_last_resuply_call = 0
g_barge_bay = 17
g_crr_barge_interval = 240

function custom_unload_barge(barge, carrier)
	local wpc = barge:get_waypoint_count()
	-- if the first waypoint is an unload, then do nothing
	if wpc == 1 then
		local first = barge:get_waypoint(0)
		if first then
			local waypoint_type = first:get_type()
			if waypoint_type == e_waypoint_type.barge_unload_carrier then
				return
			end
		end
	end
	barge:clear_waypoints()
	local pos = carrier:get_position_xz()
	local waypoint_id = barge:add_waypoint(pos:x(), pos:y())
	barge:set_waypoint_type_barge_unload_carrier(waypoint_id, carrier:get_id())
end

function custom_pickup_barge(barge, carrier, tile)
	-- if there are not two waypoints, then wipe and add collect and drop
	local wpc = barge:get_waypoint_count()
	if wpc ~= 2 then
		barge:clear_waypoints()
		local tile_pos = get_command_center_position(tile:get_id())
		local waypoint_id = barge:add_waypoint(tile_pos:x(), tile_pos:y())
		barge:set_waypoint_type_barge_load_tile(waypoint_id, tile:get_id())
		local pos = carrier:get_position_xz()
		waypoint_id = barge:add_waypoint(pos:x(), pos:y())
		barge:set_waypoint_type_barge_unload_carrier(waypoint_id, carrier:get_id())
	end
end


function custom_inventory_update(screen_w, screen_h, ticks)
	if g_screen_name == "screen_inv_r_large" then
		_update(screen_w, screen_h, ticks)
		update_ui_text(screen_w - 60, screen_h - 13, "Resupply+", 64, 0, color_status_dark_yellow, 0)
		local now = update_get_logic_tick()
		local elapsed = now - g_last_resuply_call
		if elapsed >= g_crr_barge_interval and get_is_lead_team_peer() then
			g_last_resuply_call = now
			local screen_vehicle = update_get_screen_vehicle()
			if screen_vehicle and screen_vehicle:get() then
				local barge_id = screen_vehicle:get_attached_vehicle_id(g_barge_bay)
				local barge = nil
				if barge_id then
					barge = update_get_map_vehicle_by_id(barge_id)
				end
				local pos = screen_vehicle:get_position_xz()
				local tile = get_nearest_island_tile(pos:x(), pos:y())
				local tile_pos = tile:get_position_xz()
				local dist = vec2_dist(pos, tile_pos)
				-- print(g_screen_name, tile:get_name(), get_ship_name(screen_vehicle), dist, elapsed, ticks)
				if dist < 1900 then
					-- we are in resupply range
					-- attach the barge if there are resupply requests and this island has anything

					if barge and barge:get() then
						local payload = barge:get_inventory_weight()
						-- if barge has anything aboard, set a drop waypoint
						if payload > 0 then
							--print("unload")
							custom_unload_barge(barge, screen_vehicle)
						else
							--print("load")
							-- does the island have anything that this carrier wants,
							-- set a pickup and a drop
							custom_pickup_barge(barge, screen_vehicle, tile)
						end
					else
						-- attach a barge
						screen_vehicle:set_attached_vehicle_chassis(g_barge_bay, e_game_object_type.chassis_sea_barge)
					end
				else
					-- out of range, remove the barge when the barge is empty
					if barge and barge:get() then
						local payload = barge:get_inventory_weight()
						if payload == 0 then
							-- remove the barge
							screen_vehicle:set_attached_vehicle_chassis(g_barge_bay, -1)
						else
							-- make sure the barge has a drop off waypoint to this carrier
							custom_unload_barge(barge, screen_vehicle)
						end
					end
				end
			end
		end
		return true
	end
	return false
end