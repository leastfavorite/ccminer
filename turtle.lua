-- preconditions:
-- turtle has chunk controller equipped on its left,
-- pick equipped on its right

-- configurable params
-- number of blocks between send_progress updates when moving
UPDATE_FREQUENCY = 16
LISTEN_CHANNEL = 98
STATUS_CHANNEL = 97

-- the blocks this turtle will try to use to fill gaps
FILLER_BLOCKS = {
    "minecraft:cobblestone",
    "minecraft:cobbled_deepslate"
}


-- constants
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
    shaft = "createdeco:red_brass_lamp",
    ender_modem = "computercraft:wireless_modem_advanced"
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

-- a wrapper that selects a modem before executing a function.
-- after completing execution, the old equip is returned.
-- the function can access the wrapped peripheral as an argument.
function with_modem(func)
    local using_pickaxe = turtle.getItemDetail(SLOTS.modem).name == IDS.ender_modem
    if using_pickaxe then
        turtle.select(SLOTS.modem)
        turtle.equipRight()
    end

    func(peripheral.wrap("right"))

    using_pickaxe = turtle.getItemDetail(SLOTS.modem).name == IDS.ender_modem
    if using_pickaxe then
        turtle.select(SLOTS.modem)
        turtle.equipRight()
    end
end

function send_message(message)
    print("sending: "..message)
    with_modem(function (modem)
        modem.transmit(STATUS_CHANNEL, LISTEN_CHANNEL,
            os.getComputerID() .. ": " .. message)
    end)
end

-- send progress. shows a progress bar on screen. 0 max to clear
function send_progress(amt, max)
    send_message("progress " .. amt .. " of " .. max)
end

function crash(message)
    print("turtle crashed :(")
    print(message)
    send_message("crashed ("..message..")")
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

function until_above(name, func)
    while (type(turtle.inspectDown()) == string) or
        (turtle.inspectDown().name ~= name)
    do
        func()
    end
end

function until_below(name, func)
    while (type(turtle.inspectUp()) == string) or
        (turtle.inspectUp().name ~= name)
    do
        func()
    end
end

-- selects the first compatible slot for a list of items
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

function get_shaft()
    -- send await
    local shaft, shaft_length
    with_modem(function (modem)
        modem.open(LISTEN_CHANNEL)
        send_message("awaiting command")
        while true do
            local message = os.pullEvent("modem_message").message
            local success
            _, _, shaft, shaft_length =
                string.find(message, "^"..os.getComputerID().." go to shaft %d of length %d")
            if shaft ~= nil then
                break
            end
        end
    end)

    return shaft, shaft_length
end

function main()
    -- restock
    restock()

    -- request shaft information from controller
    local shaft, shaft_length = get_shaft()

    -- go to correct mineshaft
    turtle.turnRight()
    send_message("navigating to mineshaft")
    send_progress(0, shaft)
    for i = 1, shaft do
        until_below(IDS.shaft, function()
            turtle.forward()
        end)
        send_progress(i, shaft)
    end

    -- navigate through mineshaft
    turtle.turnLeft()
    send_message("entering mineshaft")
    send_progress(0, shaft_length)
    local travel_distance = 0
    while true do
        if not turtle.forward() then
            break
        end

        travel_distance = travel_distance + 1
        if travel_distance % UPDATE_FREQUENCY == 0 then
            send_progress(travel_distance, shaft_length)
        end
    end

    -- clear end state
    send_message("extending mineshaft")
    send_progress(0, DIG_SIZE)
    turtle.down()
    turtle.digDown()
    turtle.up()
    turtle.back()


    -- dig some number of chunks
    for i=1,DIG_SIZE do
        extend(i)
        send_progress(i, DIG_SIZE)
    end

    -- build end state
    turtle.down()
    turtle.select(SLOTS.powered_rail)
    turtle.placeDown()
    turtle.up()

    -- return from shaft
    send_message("returning from mineshaft")
    send_progress(0, shaft_length + DIG_SIZE)
    travel_distance = 0
    until_below(IDS.shaft, function()
        turtle.back()

        travel_distance = travel_distance + 1
        if travel_distance % UPDATE_FREQUENCY == 0 then
            send_progress(travel_distance, shaft_length + DIG_SIZE)
        end
    end)
    send_message("shaft" .. shaft .. " has length " .. travel_distance)

    -- return home
    turtle.turnRight()
    until_below(IDS.home, turtle.back)

end

main()
