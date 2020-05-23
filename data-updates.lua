function keys(t)
    local result = {}
    for key, _ in pairs(t) do
        table.insert(result, key)
    end
    return result
end

-- check whether array contains item
function contains(array, item)
    for _, array_item in pairs(array) do
        if array_item == item then
            return true
        end
    end
    return false
end

-- removes items in sub_array from array
-- doing what stackoverflow tells me to do
function remove_items(array, sub_array)
    local j = 1
    for i = 1, table_size(array) do
        if not contains(sub_array, array[i]) then
            if i ~= j then
                array[j] = array[i]
                array[i] = nil
            end
            j = j + 1
        else
            array[i] = nil
        end
    end
    return array
end

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
-- used to normalize the type of the return value
function recipe_products(recipe)
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

function random_choose(t)
    local i = math.random(1, table_size(t))
    return t[keys(t)[i]]
end

-- randomly choose n different items in table t
function random_choose_n(t, n)
    local indicies = {}
    while table_size(indicies) < n do
        local i = math.random(1, table_size(t))
        if not contains(indicies, i) then
            table.insert(indicies, i)
        end
    end
    local result = {}
    for _, i in pairs(indicies) do
        table.insert(result, t[keys(t)[i]])
    end
    return result
end

-- we walk down the tech tree, to get the order that the recipes are unlocked at

-- array of array of tech, where tech at [i] is unlocked by [1..=i-1]
tech_layers = {}
recipe_layers = {}
locked_techs = util.table.deepcopy(data.raw.technology)

-- we initialize with techs that don't have prerequisit tech
-- because we're lazy, we presume these techs don't have extra
--   science bottle requirements
free_techs = {}
for tech_name, tech in pairs(locked_techs) do
    if tech.prerequisites == nil then
        free_techs[tech_name] = tech
        locked_techs[tech_name] = nil
    end
end
table.insert(tech_layers, free_techs)

-- we need to keep track whether the science bottles have been unlocked
free_products = {}
for _, recipe in pairs(data.raw.recipe) do
    if recipe.normal == nil then
        if recipe.enabled == nil or recipe.enabled then
            for _, product in pairs(recipe_products(recipe)) do
                table.insert(free_products, product)
            end
        end
    elseif recipe.normal.enabled then
        for _, product in pairs(recipe_products(recipe)) do
            table.insert(free_products, product)
        end
    end
end
log(serpent.block(free_products))
unlocked_products = util.table.deepcopy(free_products)

-- these were moved outside here because tech.prerequisit for these free techs does not exist (is nil)
-- but now these techs and their associated recipes are not in tech_layers and recipe_layers
local new_recipes = {}
for _, tech in pairs(free_techs) do
    if tech.effects ~= nil then
        for _, effect in pairs(tech.effects) do
            if effect.type == "unlock-recipe" then
                table.insert(unlocked_products, effect.recipe)
                table.insert(new_recipes, effect.recipe)
            end
        end
    end
end
table.insert(recipe_layers, new_recipes)
log(serpent.block(unlocked_products))

local tier = 1
-- we keep looping and take out techs that are unlocked,
--   until there are no more techs to remove
while table_size(locked_techs) ~= 0 do
    -- find all techs in locked_techs that are unlocked
    local new_techs = {}
    for tech_name, tech in pairs(locked_techs) do
        local unlocked = true
        -- tech is locked if there are locked prereq tech, ...
        for _, prereq_tech_name in pairs(tech.prerequisites) do
            if contains(keys(locked_techs), prereq_tech_name) then
                unlocked = false
                break
            end
        end
        -- ... or required science pack is not available
        for _, science_bottle in pairs(tech.unit.ingredients) do
            if not contains(unlocked_products, science_bottle[1]) then
                unlocked = false
                break
            end
        end
        if unlocked then
            new_techs[tech_name] = tech
        end
    end
    -- we remove unlocked tech from locked_techs,
    -- and put unlocked products / recipes into unlocked_products
    -- so we can know whether a science pack can be made
    local new_recipes = {}
    for tech_name, tech in pairs(new_techs) do
        locked_techs[tech_name] = nil
        if tech.effects ~= nil then
            for _, effect in pairs(tech.effects) do
                if effect.type == "unlock-recipe" then
                    table.insert(new_recipes, effect.recipe)
                    for _, product in pairs(recipe_products(data.raw.recipe[effect.recipe])) do
                        table.insert(unlocked_products, product)
                    end
                end
            end
        end
        if tech_name == "space-science-pack" then
            -- we have to manually insert space science pack, because idk
            table.insert(unlocked_products, "space-science-pack")
        end
    end
    table.insert(tech_layers, new_techs)
    table.insert(recipe_layers, new_recipes)
    tier = tier + 1
    log("new unlocked techs " .. tier .. ": " .. serpent.block(keys(new_techs)))
end

-- now that we have the (rough) order that the tech are unlocked at, we can...

function change_recipe(original_recipe, new_ingredients)
    local new_recipe = {type = "recipe", name = original_recipe.name}
    if original_recipe.normal ~= nil then
        new_recipe.normal = {}
        local ingredients = {}
        for i, ingredient in pairs(new_ingredients) do
            local new_ingredient = original_recipe.normal.ingredients[i]
            if new_ingredient.type == "item" then
                new_ingredient.name = ingredient
            elseif new_ingredient.type == nil then
                new_ingredient[1] = ingredient
            end
            table.insert(ingredients, new_ingredient)
        end
        new_recipe.normal.ingredients = ingredients
        new_recipe.normal.energy_required = original_recipe.normal.energy_required
        new_recipe.normal.result = original_recipe.normal.result
        new_recipe.normal.result_count = original_recipe.normal.result_count
        new_recipe.normal.enabled = original_recipe.normal.enabled

        new_recipe.expensive = {}
        local ingredients = {}
        for i, ingredient in pairs(new_ingredients) do
            local new_ingredient = original_recipe.expensive.ingredients[i]
            if new_ingredient.type == "item" then
                new_ingredient.name = ingredient
            elseif new_ingredient.type == nil then
                new_ingredient[1] = ingredient
            end
            table.insert(ingredients, new_ingredient)
        end
        new_recipe.expensive.ingredients = ingredients
        new_recipe.expensive.energy_required = original_recipe.expensive.energy_required
        new_recipe.expensive.result = original_recipe.expensive.result
        new_recipe.expensive.result_count = original_recipe.expensive.result_count
        new_recipe.expensive.enabled = original_recipe.expensive.enabled

        new_recipe.category = original_recipe.category
    else
        local ingredients = {}
        -- TODO: randomize the amount of each ingredients needed
        for i, ingredient in pairs(new_ingredients) do
            local new_ingredient = original_recipe.ingredients[i]
            if new_ingredient.type == "item" then
                new_ingredient.name = ingredient
            elseif new_ingredient.type == nil then
                new_ingredient[1] = ingredient
            end
            table.insert(ingredients, new_ingredient)
        end
        new_recipe.ingredients = ingredients
        -- TODO: randomize energy required
        new_recipe.energy_required = original_recipe.energy_required
        new_recipe.result = original_recipe.result
        new_recipe.result_count = original_recipe.result_count
        new_recipe.enabled = original_recipe.enabled

        new_recipe.category = original_recipe.category
        new_recipe.results = original_recipe.results
        new_recipe.icon = original_recipe.icon
        new_recipe.icons = original_recipe.icons
        new_recipe.icon_size = original_recipe.icon_size
        new_recipe.icon_mipmaps = original_recipe.icon_mipmaps
        new_recipe.subgroup = original_recipe.subgroup
        new_recipe.main_product = original_recipe.main_product
    end
    if original_recipe.name == "basic-oil-processing" then
        log("HERE")
    end
    data:extend {new_recipe}
end

local unlocked_ingredients = free_products
for tier, recipes in pairs(recipe_layers) do
    local new_ingredients = {}
    for _, recipe_name in pairs(recipes) do
        local recipe = data.raw.recipe[recipe_name]
        local ingredients = {}
        if recipe.normal ~= nil then
            ingredients = random_choose_n(unlocked_ingredients, table_size(recipe.normal.ingredients))
        else
            ingredients = random_choose_n(unlocked_ingredients, table_size(recipe.ingredients))
        end
        -- how do I replace the ingredients of the recipe again?
        --
        change_recipe(recipe, ingredients)

        -- We batch the new products in new_ingredients,
        -- before adding them to unlocked_ingredients,
        -- otherwise other recipes of the same layer will use
        -- each other
        -- Actually, is this a problem?
        for _, product in pairs(recipe_products(recipe)) do
            table.insert(new_ingredients, product)
        end
    end

    for _, ingredient in pairs(new_ingredients) do
        -- TODO: What do we do with fluids?
        if contains(keys(data.raw.item), ingredient) and not contains(unlocked_ingredients, ingredient) then
            table.insert(unlocked_ingredients, ingredient)
        end
    end
end
