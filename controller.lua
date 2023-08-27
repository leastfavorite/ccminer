-- lifecycle:
-- state:
--   awaiting turtle
--   awaiting minecart
--   awaiting trigger

LISTEN_CHANNEL = 97
STATUS_CHANNEL = 98

TURTLE_ID = settings.get("turtle_id")

function main()
    if TURTLE_ID == nil then
        printError("Please set turtle_id in the settings");
        return
    end
    local modem = peripheral.find("modem")
    local monitor = peripheral.find("monitor")

    -- message: {
    --  text = string,
    --  amount = number,
    --  time = number
    -- }
    local turt = {
        MAX_SIZE = 5,
        _start = 1,
        _end = 0,
        push = function(self, message)
            -- update previous last entry
            if self._end >= self._start then
                self[self._end].time = os.clock() - self[self._end].time
            end

            -- insert new entry
            self._end = self._end + 1
            self[self._end] = {
                text = message,
                time = os.clock()
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

    function redraw()
        monitor.setBackgroundColor(colors.black)
        monitor.setTextScale(0.5)
        monitor.clear()

        if turt.len(turt) > 0 then
            for i=1,turt.len(turt) do
                local cy = turt.MAX_SIZE - turt.len(turt) + i
                local message = turt.get(turt, i)
                monitor.setCursorPos(1, i)
                monitor.setTextColor(colors.white)
                monitor.write(message.text)

                -- [3914|23s]
                local time_str = tostring(message.time)
                local cx = monitor.getSize()[1]
                -- account for "s]"
                cx = cx - string.len(time_str) - 2

                monitor.setCursorPos(cx, i)
                monitor.setTextColor(colors.gray)
                monitor.write("[")
                monitor.setTextColor(colors.lightBlue)
                monitor.write(time_str.."s")
                monitor.setTextColor(colors.gray)
                monitor.write("]")

                if message.max_progress ~= nil then
                    local prog_str = tostring(message.max_progress)
                    local cxx = cx - string.len(prog_str) - 1
                    monitor.setCursorPos(cxx, i)
                    monitor.setTextColor(colors.gray)
                    monitor.write("[")
                    monitor.setTextColor(colors.lightBlue)
                    monitor.write(prog_str)
                    monitor.setTextColor(colors.gray)
                    monitor.write("|")
                end

            end
        end
    end


    modem.open(LISTEN_CHANNEL)
    while true do
        local event_data = {os.pullEvent()}
        local event = event_data[1]

        if event == "modem_message" then
            print(event_data[5])
            local message, success = string.gsub(event_data[5], "^"..TURTLE_ID..": ", "")
            if success > 0 then
                -- parse progress update
                if string.find(message, "^progress") then
                    local _, _, current, max = string.find(message, "^progress %d of %d")
                    turt.update_progress(turt, current, max)
                    redraw()
                else
                    turt.push(turt, message)
                    redraw()
                end
                -- parse awaiting command
                -- parse shaft has length
            end
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
