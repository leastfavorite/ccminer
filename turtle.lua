-- preconditions:
-- turtle has chunk controller equipped on its left,
-- pick equipped on its right

-- configurable params
-- number of blocks between send_progress updates when moving
UPDATE_FREQUENCY = 16
LISTEN_CHANNEL = 98
STATUS_CHANNEL = 97

-- the direction of the turtle relative to the bridge
BRIDGE_DIRECTION = "west"

-- the blocks this turtle will try to use to fill gaps
FILLER_BLOCKS = {
    "minecraft:cobblestone",
    "minecraft:cobbled_deepslate"
}

-- the items this turtle will attempt to use for fuel
FUEL = "minecraft:charcoal"
FUEL_AMT = 80 -- one piece of charcoal provides 80 fuel

-- the blocks the turtle will use for locating
HOME_BLOCK = "createdeco:yellow_brass_lamp"
SHAFT_BLOCK = "createdeco:red_brass_lamp"

-- desired inventory before leaving
INVENTORY = {
    modem = {
        id = "computercraft:wireless_modem_advanced",
        slot = 1,
        count = 1
    },
    rail = {
        id = "minecraft:rail",
        slot = 2,
        count = 64
    },
    powered_rail = {
        id = "minecraft:powered_rail",
        slot = 3,
        count = 16
    },
    torch = {
        id = "minecraft:torch",
        slot = 4,
        count = 64
    },
    redstone_torch = {
        id = "minecraft:redstone_torch",
        slot = 5,
        count = 16
    },
    iron_bars = {
        id = "minecraft:iron_bars",
        slot = 6,
        count = 64
    }
}
function select(str)
    turtle.select(INVENTORY[str].slot)
end


-- constants
INVENTORY_SIZE = 16

-- mineshaft options
DIG_SIZE = 64

-- spacing between blocks in the mineshaft
TORCH_SPACING = 4
-- must be a factor of both TORCH and POWERED_RAIL spacings
IRON_BAR_SPACING = 2
POWERED_RAIL_SPACING = 16

-- utility functions

-- a wrapper that selects a modem before executing a function.
-- after completing execution, the old equip is returned.
-- the function can access the wrapped peripheral as an argument.
function with_modem(func)
    local using_pickaxe = turtle.getItemDetail(INVENTORY.modem.slot).name == INVENTORY.modem.id
    if using_pickaxe then
        select("modem")
        turtle.equipRight()
    end

    func(peripheral.wrap("right"))

    local still_using_pickaxe = turtle.getItemDetail(INVENTORY.modem.slot).name == INVENTORY.modem.id
    if using_pickaxe ~= still_using_pickaxe then
        select("modem")
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

function until_below(name, func)
    while true do
        func()
        local is_block, block = turtle.inspectUp()
        if is_block and block.name == name then
            return
        end
    end
end

-- selects the first compatible slot for a list of items
function select_items(blocks)
    for i=1,INVENTORY_SIZE do
        local item =  turtle.getItemDetail(i)
        if item ~= nil and contains(blocks, item.name) then
            turtle.select(i)
            return
        end
    end
    crash("could not select required blocks")
end

-- precondition: turtle must be at end of mineshaft
--   and at the top space
function extend(index)
    function dig(gravel, iron_bars)
        gravel = gravel or false
        iron_bars = iron_bars or false
        if gravel then
            while turtle.dig() do
                sleep(0.5)
            end
        else
            turtle.dig()
        end

        turtle.forward()
        turtle.turnLeft()
        if gravel then
            while turtle.dig() do
                sleep(0.5)
            end
        end
        if not turtle.detect() then
            select_items(FILLER_BLOCKS)
            turtle.place()
        end
        if (iron_bars) then
            select("iron_bars")
            turtle.dig()
            turtle.place()
        end

        turtle.turnRight()
        if not turtle.detect() then
            select_items(FILLER_BLOCKS)
            turtle.place()
        end

        turtle.turnRight()
        if gravel then
            while turtle.dig() do
                sleep(0.5)
            end
        end
        if not turtle.detect() then
            select_items(FILLER_BLOCKS)
            turtle.place()
        end
        if (iron_bars) then
            select("iron_bars")
            turtle.dig()
            turtle.place()
        end

        turtle.turnLeft()
    end

    dig(true)
    if not turtle.detectUp() then
        select_items(FILLER_BLOCKS)
        turtle.placeUp()
    end
    turtle.back()
    turtle.down()

    local iron_bars = index % IRON_BAR_SPACING == 0
    dig(false, iron_bars)
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
        select("powered_rail")
        turtle.placeDown()
        turtle.up()
        select("redstone_torch")
        turtle.placeDown()
    else
        select("rail")
        turtle.placeDown()
        turtle.up()
        if index % TORCH_SPACING == 0 then
            select("torch")
            turtle.placeDown()
        end
    end

    turtle.forward()
end

function restock()
    -- remove all items
    local bridge = peripheral.find("meBridge")
    if bridge == nil then
        crash("couldnt find bridge")
        return
    end

    for i=2,INVENTORY_SIZE do
        local detail = turtle.getItemDetail(i)
        if detail ~= nil then
            bridge.importItem({name=detail.name}, BRIDGE_DIRECTION)
        end
    end

    -- get fuel
    local fuel_required = math.floor((turtle.getFuelLimit() - turtle.getFuelLevel()) / FUEL_AMT)
    local fuel_filled = 0
    send_message("refueling")
    send_progress(0, fuel_required)
    while fuel_filled < fuel_required do
        local function get_fuel()
            return bridge.exportItem({
                    name=FUEL,
                    count=math.min(64, (fuel_required - fuel_filled))
                }, BRIDGE_DIRECTION)
        end
        local count = get_fuel()
        select_items({FUEL})
        turtle.refuel(count)
        fuel_filled = fuel_filled + count
        send_progress(fuel_filled, fuel_required)
        if fuel_filled < fuel_required then
            sleep(30)
        end
    end

    -- get items
    local function get_item(item, count)
        send_message("restocking " .. item)
        send_progress(0, count)
        local pulled = 0
        local function pull_items()
            return bridge.exportItem({
                    name=item,
                    count=(count - pulled)
                }, BRIDGE_DIRECTION)
        end
        while pulled < count do
            pulled = pulled + pull_items()
            send_progress(pulled, count)
            if pulled < count then
                sleep(30)
            end
        end
    end

    local inventory_sorted = {}
    for _, i in pairs(INVENTORY) do
        inventory_sorted[i.slot] = i
    end

    for i=1,#inventory_sorted do
        local item = inventory_sorted[i]
        if item.slot ~= 1 then
            get_item(item.id, item.count)
        end
    end

    for _, i in pairs(FILLER_BLOCKS) do
        if bridge.getItem({name=i}).amount ~= nil then
            get_item(i, 64)
        end
    end
end

function get_shaft()
    -- send await
    local shaft, shaft_length
    with_modem(function (modem)
        modem.open(LISTEN_CHANNEL)
        send_message("awaiting command")
        while true do
            local _, _, _, _, message = os.pullEvent("modem_message")
            print("recv: "..message)
            print(string.find(message, "^") ~= nil)
            _, _, shaft, shaft_length =
                string.find(message, "^"..os.getComputerID()..": go to shaft (%d+) of length (%d+)")
            shaft = tonumber(shaft)
            shaft_length = tonumber(shaft_length)
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
        until_below(SHAFT_BLOCK, function()
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


    -- dig some number of chunks
    for i=1,DIG_SIZE do
        extend(i)
        send_progress(i, DIG_SIZE)
    end

    -- build end state
    turtle.down()
    select("powered_rail")
    turtle.placeDown()
    turtle.up()

    -- return from shaft
    send_message("returning from mineshaft")
    send_progress(0, shaft_length + DIG_SIZE)
    travel_distance = 0
    until_below(SHAFT_BLOCK, function()
        turtle.back()

        travel_distance = travel_distance + 1
        if travel_distance % UPDATE_FREQUENCY == 0 then
            send_progress(travel_distance, shaft_length + DIG_SIZE)
        end
    end)
    send_message("shaft " .. shaft .. " has length " .. travel_distance)

    -- return home
    turtle.turnRight()
    until_below(HOME_BLOCK, turtle.back)
    turtle.turnLeft()
    send_message("returned")
end

-- main()
while true do
    main()
end
