-- sopcast hook for mpv
--
-- How to use this script:
-- 1. Move this script to ~/.config/mpv/scripts
-- 2. Make sure sp-sc-auth/sp-sc is in your $PATH or in ~/.config/mpv

local utils = require 'mp.utils'
local msg = require 'mp.msg'

local vars = {
    sopcast = "sp-sc-auth",
    sopcast_names = {"sp-sc-auth", "sp-sc"},
    sopcast_args = "",
    sopcast_running = false,
    url = "",
    process_id = "",
    port = 8902,
    wait_time = 5
}

local function sleep(s)
    local ntime = os.time() + s
    repeat until os.time() > ntime
end

local function exec(args)
    local ret = utils.subprocess({args = args})
    return ret.status, ret.stdout
end

local function find_unused_port()
    local command = { "ps", "-o", "command" }
    local status, processes = exec(command)
    
    local result = vars.port
    for i in string.gmatch(processes, "[^\r\n]+") do
        for j, name in ipairs(vars.sopcast_names) do
            if not (string.find(i, name .. " sop://", 1, true) == nil) then
                local port = tonumber(i:sub(i:match(".* ()")))
                if (port >= result) then
                    result = port+1
                end
            end
        end 
    end
    return result
end

local function on_start()
    vars.url = mp.get_property("stream-open-filename")
    
    if (vars.url:find("sop://") == 1) then
        -- find sopcast binary, search various names
        for i, name in ipairs(vars.sopcast_names) do
            local sopcast_bin = mp.find_config_file(name)
            if not (sopcast_bin == nil) then
                msg.verbose("found sopcast at: " .. sopcast_bin)
                vars.sopcast = sopcast_bin
                break
            end
        end
        
        -- find an unused port, needed for simultaneous streams
        vars.port = find_unused_port()
        
        -- start sopcast
        vars.sopcast_running = true
        msg.verbose("starting sopcast on port " .. vars.port)
        vars.sopcast_args = vars.url .. " 3908 " .. vars.port
        io.popen(vars.sopcast .. " " .. vars.sopcast_args .. " &")
        
        -- wait a few seconds, this is not nice but can't read output of sp-sc-auth
        sleep(vars.wait_time)
        
        -- check if sopcast is running
        local command = { "pgrep", "-f", vars.sopcast .. " " .. vars.sopcast_args }
        local status, id = exec(command)

        if (status < 0) or (id == nil) or (id == "") then
            msg.warn("sopcast process not found. unresponsive or unuvailable channel.")
            mp.command("quit")
            return
        else
            msg.verbose("sopcast process found. channel available.")
            vars.process_id = id
        end
        
        -- open the local sopcast stream
        mp.set_property("stream-open-filename", "http://localhost:" .. vars.port)
    end
end

function on_end(event)
    if (vars.sopcast_running) then
        os.execute("pkill -f \"".. vars.sopcast .. " " .. vars.sopcast_args .. "\"" )
        msg.verbose("sopcast terminated.")
    end
end

mp.add_hook("on_load", 50, on_start)
mp.add_hook("on_unload", 50, on_end)