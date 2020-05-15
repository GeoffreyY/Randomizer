function randomize_main() 
    -- Overall plan
    -- first we need a complete list of recipes
    -- we'll remove stuff that we don't went to randomize from the list
    --   aka iron and copper plate
    recipe_list = game.recipe_prototypes
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
    for tech_name, tech_prototype in pairs(game.technology_prototypes) do
        -- TODO: we assume that the prerequisite tech need no more
        -- research vial types than the current research
        -- aka if optics requires automation unlocked, then
        -- the research bottles than automation need must a subset of
        -- the research bottles that optics need
        -- otherwise we have to loop through all prerequisit tech
        -- and gather all required research ingredients

        -- TODO: is there a better way of writing this?
        --   eg tech_prototype.blah.map(|t| t.x)
        ingredients = {}
        for _, ingredient in pairs(tech_prototype.research_unit_ingredients) do
            table.insert(ingredients, ingredient.name)
        end
        -- if the recipe needs to be researched, it also requires the science lab
        table.insert(ingredients, "lab")

        --log(tech_name ..": " .. serpent.line(ingredients))

        -- for each tech we see which recipe the tech unlocks
        for _, unlock in pairs(tech_prototype.effects) do
            if unlock["type"] == "unlock-recipe" then
                log(serpent.line(unlock))
                local recipe_name = unlock["recipe"]
                -- and for each product of the recipe
                for _, recipe_product in pairs(game.recipe_prototypes[recipe_name].products) do
                    -- lua why you do this
                    local product_name = recipe_product.name
                    local new_dependency = {}
                    dependency_table[product_name] = ingredients
                end
            end 
        end
    end

    log(serpent.block(dependency_table))

    -- then for each recipe, we randomize the ingredients,
    --   we get the list of all ingredients
    --   remove ingredients that depends on our current item
    --   and randomly select from the new list
    --     is there a possibility of dead end, where no suitable ingredient exists?
    --       no: we can always fall back onto iron + copper plate, or
    --       other raw materials (ores)
    for item, _ in pairs(dependency_table) do
        -- we get a list of items, that are not depended on our target item
        -- so we don't have a circular dependency
        -- RAGE: I hate a lack of static typing -> no type hint >:(
        local acceptable_ingredients = {}
        for _, ingredient in pairs(game.item_prototypes) do
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
        if game.recipe_prototypes[item] == nil then
            log("what do you mean" .. item)
        else
            local num_ingredients = #game.recipe_prototypes[item].ingredients
            log("wtf .. " .. num_ingredients)
        end
    end
end

script.on_init(randomize_main)