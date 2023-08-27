-- lifecycle:
-- state:
--   awaiting turtle
--   awaiting minecart
--   awaiting trigger

LISTEN_CHANNEL = 97
STATUS_CHANNEL = 98

TURTLE_ID = settings.get("turtle_id")

BUTTON_SIDE = "left"
MINECART_SEND_SIDE = "top"
MINECART_RECV_SIDE = "right"

SHAFT_COUNT = 3
CURRENT_SHAFT = 1

function main()
    if TURTLE_ID == nil then
        printError("Please set turtle_id in the settings")
        return
    end
    local modem = peripheral.find("modem")
    local monitor = peripheral.find("monitor")

    print("Initializing with " .. SHAFT_COUNT .. " shafts")
    local shaft_lengths = {}
    for i=1,SHAFT_COUNT do
        shaft_lengths[i] = 0
    end

    local turtle_home = true
    local minecart_home = true

    -- message: {
    --  text = string,
    --  amount = number,
    --  time = number
    -- }
    local turt = {
        MAX_SIZE = 20,
        _start = 1,
        _end = 0,
        push = function(self, message)
            -- update previous last entry
            if self._end >= self._start then
                self[self._end].time = math.ceil(os.clock() - self[self._end].time)
            end

            -- insert new entry
            self._end = self._end + 1
            self[self._end] = {
                text = message,
                time = os.clock(),
                current_progress = 0,
                max_progress = 0
            }

            -- remove overflow
            if (self._end - self._start) > self.MAX_SIZE then
                self[self._start] = nil
                self._start = self._start + 1
            end
        end,
        len = function(self) return self._end - self._start + 1 end,
        get = function(self, i) return self[self._start + i - 1] end,
        update_progress = function(self, current, max)
            self[self._end].current_progress = current
            self[self._end].max_progress = max
        end
    }

    local signals = {
        button = redstone.getInput(BUTTON_SIDE),
        minecart = redstone.getInput(MINECART_RECV_SIDE)
    }

    function redraw()
        -- there are many things in this world that you can make very pretty.
        -- lots of code, as well. design patterns, beautiful algorithms, you
        -- could write books of the stuff.
        -- but drawing a TUI without building a framework is always gonna
        -- be ugly as hell.
        monitor.setBackgroundColor(colors.black)
        monitor.setTextScale(0.5)
        monitor.clear()

        local PUNCTUATION_COLOR = colors.lightGray
        local TEXT_COLOR = colors.white
        local NUMBER_COLOR = colors.lightBlue

        -- just to clean up some of the recoloring spam
        function write(str, color, pos_x, pos_y)
            -- reposition
            local old_x, old_y = monitor.getCursorPos()
            local old_color = monitor.getTextColor()
            pos_x = pos_x or old_x
            pos_y = pos_y or old_y
            color = color or old_color
            monitor.setCursorPos(pos_x, pos_y)
            monitor.setTextColor(color)
            monitor.write(str)
            monitor.setTextColor(old_color)
        end

        if turt.len(turt) > 0 then
            for i=1,turt.len(turt) do
                local cy = turt.MAX_SIZE - turt.len(turt) + i
                local message = turt.get(turt, i)
                write(message.text, TEXT_COLOR, 1, cy)

                -- write time taken and operation size
                if i < turt.len(turt) then
                    -- [3914|23s]
                    local time_str = tostring(message.time)
                    local cx, _ = monitor.getSize()
                    -- account for "s]"
                    cx = cx - string.len(time_str) - 2

                    write("[", PUNCTUATION_COLOR, cx, cy)
                    write(time_str.."s", NUMBER_COLOR)
                    write("]", PUNCTUATION_COLOR)

                    if message.max_progress ~= nil and message.max_progress > 0 then
                        local prog_str = tostring(message.max_progress)
                        local cxx = cx - string.len(prog_str) - 1
                        write("[", PUNCTUATION_COLOR, cxx, cy)
                        write(prog_str, NUMBER_COLOR)
                        write("|", PUNCTUATION_COLOR)
                    end
                end

            end
        end

        local current_message = turt.get(turt, turt.len(turt))
        if current_message ~= nil then
            if current_message.max_progress ~= nil and current_message.max_progress > 0 then
                -- draw progress bar
                local prog_str = tostring(current_message.current_progress)
                local max_str = tostring(current_message.max_progress)
                local cx = monitor.getSize() - 2 - string.len(prog_str) - string.len(max_str)
                local cy = turt.MAX_SIZE + 1

                write("[", PUNCTUATION_COLOR, 1, cy)

                local bar_size = cx - 2
                for i=1, math.floor(bar_size * current_message.current_progress / current_message.max_progress) do
                    monitor.write("#", TEXT_COLOR)
                end

                write("|", PUNCTUATION_COLOR, cx, cy)
                write(prog_str, NUMBER_COLOR)
                write("/", PUNCTUATION_COLOR)
                write(max_str, NUMBER_COLOR)
                write("]", PUNCTUATION_COLOR)
            end
        end
    end

    modem.open(LISTEN_CHANNEL)
    redraw()
    while true do
        local event_data = {os.pullEvent()}
        local event = event_data[1]

        if event == "modem_message" then
            print(event_data[5])
            local message, success = string.gsub(event_data[5], "^"..TURTLE_ID..": ", "")
            if success > 0 then
                -- parse progress update
                if string.find(message, "^progress") then
                    local _, _, current, max = string.find(message, "^progress (%d+) of (%d+)")
                    current = tonumber(current)
                    max = tonumber(max)
                    turt.update_progress(turt, current, max)
                    print("updating progress: " .. current .. " of " .. max)
                    redraw()
                else
                    turt.push(turt, message)
                    local _, _, shaft, length = string.find(message, "^shaft (%d+) has length (%d+)")
                    if shaft ~= nil then
                        shaft_lengths[shaft] = length
                    end

                    if string.find(message, "^awaiting command") then
                        turtle_home = true
                    else
                        turtle_home = false
                    end

                    if string.find(message, "^returned") then
                        redstone.setAnalogOutput(MINECART_SEND_SIDE, CURRENT_SHAFT)
                    end
                    redraw()
                end
                -- parse awaiting command
                -- parse shaft has length
            end
        elseif event == "redstone" then
            local button = redstone.getInput(BUTTON_SIDE)
            local minecart = redstone.getInput(MINECART_RECV_SIDE)

            if button and not signals.button then
                if turtle_home and minecart_home then
                    local min_shaft_len = 1000000
                    local min_shaft = 1
                    for i=1,SHAFT_COUNT do
                        if shaft_lengths[i] < min_shaft_len then
                            min_shaft_len = shaft_lengths[i]
                            min_shaft = i
                        end
                    end
                    CURRENT_SHAFT = min_shaft
                    modem.transmit(STATUS_CHANNEL, LISTEN_CHANNEL, TURTLE_ID..": go to shaft " .. CURRENT_SHAFT .. " of length " .. shaft_lengths[CURRENT_SHAFT])
                end
            end
            if minecart ~= signals.minecart then
                if minecart then
                    redstone.setAnalogOutput(MINECART_SEND_SIDE, 0)
                end
            end

            signals.button = button
            signals.minecart = minecart
        end
    end
    -- turtle messages:
    -- FROM:
    -- ||||||||||||||||||
    -- awaiting command
    -- crashed ([])
    -- shaft [] has length []
    -- progress [] of []
    -- TO:
    -- "go to shaft [] of length []"
end

main()
