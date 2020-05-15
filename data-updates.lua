-- returns the array of items that exists in both arrays
function get_overlap(array1, array2)
    local result = {}
    for _, item1 in pairs(array1) do
        for _, item2 in pairs(array2) do
            if item1 == item2 then
                table.insert(result, item1)
            end
        end
    end
    return result
end

-- returns an array of the resultant / products of the recipe
function recipe_results(recipe)
    local results = {}
    if recipe.normal ~= nil then
        table.insert(results, recipe.normal.result)
    elseif recipe.results ~= nil then
        for _, result in pairs(recipe.results) do
            table.insert(results, result.name)
        end
    else
        table.insert(results, recipe.result)
    end
    return results
end

-- Overall plan
-- first we need a complete list of recipes
-- we'll remove stuff that we don't went to randomize from the list
--   aka iron and copper plate

-- TODO: what about fluids
--   the problem is if we randomize a recipe to have too many fluid ingrendients,
--    the recipe will become impossible to make
--    so we need to limit the number of fluids to be <= originial recipe
-- TODO: what about items with multiple recipes
--    it will be possible for one recipe to have circular dependency,
--    or even self-referencial
--      aka the same item is both the ingredient and product of a recipe
--    as long as there is a escape hatch in some sense

-- >> we want it so that all items are producable, and consumable  (placable) <<
-- this is getting so compicated NotLikeThis

-- first of all, the recipes need to be researched
-- so most recipes depend of science bottles (whatever they're called)
--[[ NOTE: the type "custom dictionary string → LuaTechnologyPrototype"
actually means a custom dictionary, with keys of type string,
indexing values of type LuaTechnologyPrototype
]]

-- dependency_table have type custom dictionary string -> array of strings
-- where keys are strings of the product item name,
-- and the indexed value is an array of the string names of the ingredients
dependency_table = {}
reverse_dependency_table = {}
-- TODO: split off functions, too much indentation
for tech_name, tech_prototype in pairs(data.raw.technology) do
    -- TODO: we assume that the prerequisite tech need no more
    -- research vial types than the current research
    -- aka if optics requires automation unlocked, then
    -- the research bottles than automation need must a subset of
    -- the research bottles that optics need
    -- otherwise we have to loop through all prerequisit tech
    -- and gather all required research ingredients

    -- TODO: is there a better way of writing this?
    --   eg tech_prototype.blah.map(|t| t.x)
    science_dependencies = {}
    for _, ingredient in pairs(tech_prototype.unit.ingredients) do
        table.insert(science_dependencies, ingredient.name)
    end
    -- if the recipe needs to be researched, it also requires the science lab
    table.insert(science_dependencies, "lab")

    -- for each tech we see which recipe the tech unlocks
    -- log("tech_prototype: " .. serpent.block(tech_prototype))
    if tech_prototype.effects ~= nil then
        for _, unlock in pairs(tech_prototype.effects) do
            if unlock["type"] == "unlock-recipe" then
                log(serpent.line(unlock))
                local recipe_name = unlock["recipe"]
                -- and for each product of the recipe
                -- we add the science bottles required to the
                -- recipe product's dependency
                local recipe = data.raw.recipe[recipe_name]
                log(serpent.block(recipe))

                -- actually do we want to arbitrarily only change one
                -- shouldn't we change both normal and expensive
                -- ye it's too complicated I'm tired screw it

                local results = recipe_results(recipe)

                -- then for each resultant we add the science dependency
                -- but what if there are multiple recipes for an item
                -- instead of adding a new entry, we remove non-overlapping science dependencies 
                -- well what if recipe A requires (red, green),
                -- and recipe B requires (red, blue)
                -- if that's the case, go kill the mod author
                for _, result in pairs(results) do
                    if dependency_table[result] == nil then
                        dependency_table[result] = science_dependencies
                    else
                        overlap = get_overlap(dependency_table[result], science_dependencies)
                        dependency_table[result] = overlap
                    end
                end 
            end
        end
    end
end

log("science dependencies: " .. serpent.block(dependency_table))

-- now we actually randomize the ingredients,
--   we get the list of all ingredients
--   remove ingredients that depends on our current item
--   and randomly select from the new list
--     is there a possibility of dead end, where no suitable ingredient exists?
--       no: we can always fall back onto iron + copper plate, or
--       other raw materials (ores)
for _, recipe in pairs(data.raw.recipe) do
    log("recipe: " .. serpent.block(recipe))
    local results = recipe_results(recipe)
    local acceptable_ingredients = data.raw.item
    -- if an item depends on any of the resultant of the recipe,
    -- then the item is not acceptable as an ingredient of the recipe
    for _, result in pairs(results) do
        local tmp_acceptable_ingredients = {}
        for _, ingredient in pairs(acceptable_ingredients) do
            for product, ingredient_list in pairs(dependency_table) do
                local acceptable = true
                --[[for _, dependency in pairs(ingredient_list) do
                    if dependency == item then acceptable = false end
                end]]
                if acceptable then
                    table.insert(tmp_acceptable_ingredients, product)
                end
            end
        end

        acceptable_ingredients = tmp_acceptable_ingredients
    end

    -- now that we have a list of acceptable ingredients,
    -- we randomly choose from this list to generate our new recipe

    -- err how do I change the recipe again?
end
log(data.raw.recipe[1])
--[[for item, _ in pairs(dependency_table) do
    -- we get a list of items, that are not depended on our target item
    -- so we don't have a circular dependency
    -- RAGE: I hate a lack of static typing -> no type hint >:(
    local acceptable_ingredients = {}
    for _, ingredient in pairs(data.raw.item) do
        for product, ingredient_list in pairs(dependency_table) do
            local acceptable = true
            for _, dependency in pairs(ingredient_list) do
                if dependency == item then acceptable = false end
            end
            if acceptable then
                table.insert(acceptable_ingredients, product)
            end
        end
    end
    
    log("acceptable ingredients of " .. item .. ": " .. serpent.line(acceptable_ingredients))

    -- ah so this doesn't work
    -- ...
    -- we can't index recipe_prototypes with item name
    -- ok, so we should always look at recipes, instead of ingredients


    -- we get the original recipe to see how many ingredients
    -- should the recipe have
    -- TODO: what to do with fluids?
    if data.raw.recipe[item] == nil then
        log("what do you mean" .. item)
    else
        local num_ingredients = #data.raw.recipe[item].ingredients
        log("wtf .. " .. num_ingredients)
    end
end]]
