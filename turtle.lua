-- preconditions:
-- turtle has chunk controller equipped on its left,
-- pick equipped on its right
INVENTORY_SIZE = 16

ENDER_MODEM_SLOT = 1
RAIL_SLOT = 2
POWERED_RAIL_SLOT = 3
TORCH_SLOT = 4
REDSTONE_TORCH_SLOT = 5

-- mineshaft options
DIG_SIZE = 64
TORCH_SPACING = 4
POWERED_RAIL_SPACING = 16

function crash(message)
    print("turtle crashed :(")
    print(message)
    while true do
        sleep(60)
    end
end

-- precondition: turtle must be at end of mineshaft
--   and at the top space
function extend(index)
    -- break new row
    function get_filler()
        function predicate()
            local item = turtle.getItemDetail().name
            if item == "minecraft:cobblestone" or item == "minecraft:cobbled_deepslate" then
                return true
            end
        end
        -- just check current item
        if predicate() then return end

        -- search thru all items
        for i=1,INVENTORY_SIZE do
            turtle.select(i)
            if predicate() then return end
        end

        crash("out of filler material")
    end

    function dig()
        turtle.dig()
        turtle.forward()
        turtle.turnLeft()
        if not turtle.detect() then
            get_filler() 
            turtle.place()
        end
        turtle.turnRight()
        if not turtle.detect() then
            get_filler() 
            turtle.place()
        end
        turtle.turnRight()
        if not turtle.detect() then
            get_filler() 
            turtle.place()
        end
        turtle.turnLeft()
    end

    dig()
    if not turtle.detectUp() then
        get_filler() 
        turtle.placeUp()
    end
    turtle.back()
    turtle.down()

    dig()
    turtle.back()
    turtle.down()

    dig()
    if not turtle.detectDown() then
        get_filler() 
        turtle.placeDown()
    end
    turtle.back()
    turtle.down()

    -- place rails
end

function main()
    -- collect items
    -- select path
    -- dig some number of chunks
    for i=1,64 do
        extend(i)
    end
    -- build end state
    -- return 
end
