-- preconditions:
-- turtle has chunk controller equipped on its left,
-- pick equipped on its right
INVENTORY_SIZE = 16

SLOTS = {
    modem          = 1,
    rail           = 2,
    powered_rail   = 3,
    torch          = 4,
    redstone_torch = 5,
    iron_bar       = 6
}

IDS = {
    charcoal = "minecraft:charcoal",
    rail = "minecraft:rail",
    powered_rail = "minecraft:powered_rail",
    torch = "minecraft:torch",
    redstone_torch = "minecraft:redstone_torch",
    iron_bar = "minecraft:iron_bar",
    home = "createdeco:yellow_brass_lamp",
    shaft = "createdeco:red_brass_lamp"
}

LISTEN_CHANNEL = 98
ENDER_CHANNEL = 97

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
-- must be a factor of both TORCH and POWERED_RAIL spacings
IRON_BAR_SPACING = 2
POWERED_RAIL_SPACING = 16

-- utility functions
function send_message(message)
    turtle.select(SLOTS.modem)
    turtle.equipRight()
    ender_modem = peripheral.wrap("right")
    ender_modem.transmit(ENDER_CHANNEL, 0, message)
    turtle.equipRight()
end

function crash(message)
    print("turtle crashed :(")
    print(message)
    send_message("crashed: " .. message)
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
        turtle.select(SLOTS.powered_rail)
        turtle.placeDown()
        turtle.up()
        turtle.select(SLOTS.redstone_torch)
        turtle.placeDown()
    else
        turtle.select(SLOTS.rail)
        turtle.placeDown()
        if index % IRON_BAR_SPACING == 1 then
            turtle.select(SLOTS.iron_bar)
            turtle.turnLeft()
            turtle.dig()
            turtle.place()
            turtle.turnRight()
            turtle.turnRight()
            turtle.dig()
            turtle.place()
            turtle.turnLeft()
        end
        turtle.up()
        if index % TORCH_SPACING == 0 then
            turtle.select(SLOTS.torch)
            turtle.placeDown()
        end
    end

    turtle.forward()
end

function restock()
    -- get fuel
    -- get items
end

function main()
    -- restock
    restock()

    -- signal readiness 
    turtle.select(SLOTS.modem)
    turtle.equipRight()
    local ender_modem = peripheral.wrap("right")
    ender_modem.open(LISTEN_CHANNEL)
    ender_modem.transmit(ENDER_CHANNEL, LISTEN_CHANNEL,
        "awaiting" .. os.getComputerID())
    
    -- await send
    while true do
        local message = os.pullEvent("modem_message").message
        local shaft, success = string.gsub(message, "^send " .. os.getComputerID() .. " to ", "")
        if success > 0 then
            print(shaft)
            return
        end
    end
    turtle.equipRight()

    -- go to correct mineshaft

    -- dig some number of chunks
    for i=1,64 do
        print(i)
        extend(i)
    end
    -- build end state
    turtle.down()
    select_items(FILLER_BLOCKS)
    turtle.placeDown()
    turtle.up()
    turtle.back()
    turtle.place()
    -- return 
    while (type(turtle.inspectUp()) == string) or 
        (turtle.inspectUp().name ~= "minecraft:iron_block")
    do
        turtle.back()
    end
end

main()
