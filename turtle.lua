-- preconditions:
-- turtle has chunk controller equipped on its left,
-- pick equipped on its right
INVENTORY_SIZE = 16

ENDER_MODEM_SLOT = 1
RAIL_SLOT = 2
POWERED_RAIL_SLOT = 3
TORCH_SLOT = 4
REDSTONE_TORCH_SLOT = 5

FILLER_BLOCKS = {
    "minecraft:cobblestone",
    "minecraft:cobbled_deepslate"
}
REFUEL_ITEMS = {
    "minecraft:coal",
    "minecraft:charcoal",
    "minecraft:coal_block"
}

-- mineshaft options
DIG_SIZE = 64
TORCH_SPACING = 4
POWERED_RAIL_SPACING = 16

-- utility functions
function crash(message)
    print("turtle crashed :(")
    print(message)
    while true do
        sleep(60)
    end
end

function contains(tbl, elem)
    for _, value in pairs(tbl) do
        if value == elem then return true end
    end
    return false
end

function select_items(blocks)
    for i=1,INVENTORY_SIZE do
        local item =  turtle.getItemDetail(i)
        if item ~= nil and contains(FILLER_BLOCKS, item.name) then
            turtle.select(i)
            return
        end
    end
    crash("could not select required blocks")
end

-- precondition: turtle must be at end of mineshaft
--   and at the top space
function extend(index)
    function dig()
        while turtle.dig() do end
        turtle.forward()
        turtle.turnLeft()
        if not turtle.detect() then
            select_items(FILLER_BLOCKS) 
            turtle.place()
        end
        turtle.turnRight()
        if not turtle.detect() then
            select_items(FILLER_BLOCKS) 
            turtle.place()
        end
        turtle.turnRight()
        if not turtle.detect() then
            select_items(FILLER_BLOCKS) 
            turtle.place()
        end
        turtle.turnLeft()
    end

    dig()
    if not turtle.detectUp() then
        select_items(FILLER_BLOCKS) 
        turtle.placeUp()
    end
    turtle.back()
    turtle.down()

    dig()
    turtle.back()
    turtle.down()

    dig()
    if not turtle.detectDown() then
        select_items(FILLER_BLOCKS) 
        turtle.placeDown()
    end
    -- place rails
    turtle.back()
    turtle.up()
    if index % POWERED_RAIL_SPACING == 0 then
        turtle.select(POWERED_RAIL_SLOT)
        turtle.placeDown()
        turtle.up()
        turtle.select(REDSTONE_TORCH_SLOT)
        turtle.placeDown()
    else
        turtle.select(RAIL_SLOT)
        turtle.placeDown()
        turtle.up()
        if index % TORCH_SPACING == 0 then
            turtle.select(TORCH_SLOT)
            turtle.placeDown()
        end
    end

    turtle.forward()
end

function main()
    -- collect items
    -- select path
    -- dig some number of chunks
    for i=1,64 do
        print(i)
        extend(i)
    end
    -- build end state
    -- return 
end

main()
