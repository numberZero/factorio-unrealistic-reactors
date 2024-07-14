game.reload_script()

for index, force in pairs(game.forces) do
	force.reset_recipes()
	force.reset_technologies()
	if force.technologies["nuclear-power"].researched then
		force.recipes["rr-cooling-tower"].enabled = true
	end
end
