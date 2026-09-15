-- nznt Airflow-UI migration smoke test
-- Paste into your executor console/script box and run. It reports PASS/FAIL lines.
-- Does NOT modify anything; just loads the adapters and exercises the API surface.

local Results = {}
local function ok(name, detail)
    table.insert(Results, { name = name, pass = true, detail = detail or "ok" })
    print("[PASS] " .. name .. (detail and (" | " .. tostring(detail)) or ""))
end
local function fail(name, detail)
    table.insert(Results, { name = name, pass = false, detail = detail })
    warn("[FAIL] " .. name .. " | " .. tostring(detail))
end
local function get(url)
    local ok, res = pcall(function() return game:HttpGet(url, true) end)
    if ok and typeof(res) == "string" and #res > 0 then return res end
    local req = (syn and syn.request) or request or http_request
    if req then
        local r2, r = pcall(function() return req({ Url = url, Method = "GET" }) end)
        if r2 and r and r.Body and #r.Body > 0 then return tostring(r.Body) end
    end
    return nil
end

local BASE = "https://raw.githubusercontent.com/Pocimin/airflow-ui/main"
local function stripBom(x) if type(x)=="string" and x:sub(1,1)=="\239\187\191" then return x:sub(2) end return x end

print("===== NZNT AIRFLOW-UI SMOKE TEST =====")

-- 1. Source.luau (raw Airflow) loads + brand icon baked in
local src = get(BASE .. "/Source.luau")
if not src then
    fail("Source.luau fetch", "could not fetch")
else
    if src:find("75353810328300", 1, true) then
        ok("Source.luau contains brand icon", "75353810328300 present")
    else
        fail("Source.luau brand icon", "75353810328300 NOT found in fork")
    end
    -- capture loadstring's 2nd return = error message
    local loader = loadstring or load
    local fn, err = loader(stripBom(src))
    if type(fn) == "function" and fn then
        local okc, Airflow = pcall(fn)
        if okc and type(Airflow) == "table" and Airflow.CreateWindow then
            ok("Source.luau compiles & runs", "Airflow API ok")
        else
            fail("Source.luau run", tostring(Airflow))
        end
    else
        fail("Source.luau compile", tostring(err))
    end
end

-- 2. Bridge.luau loads
local bridgeSrc = get(BASE .. "/Bridge.luau")
if not bridgeSrc then
    fail("Bridge.luau fetch", "could not fetch")
else
    local loader = loadstring or load
    local fn, err = loader(stripBom(bridgeSrc))
    if type(fn) == "function" and fn then
        local okc, Bridge = pcall(fn)
        if okc and type(Bridge) == "table" and Bridge.CreateWindow then
            ok("Bridge.luau compiles & runs", "Bridge API ok")
        else
            fail("Bridge.luau run", tostring(Bridge))
        end
    else
        fail("Bridge.luau compile", tostring(err))
    end
end

-- 3. Native.luau loads
local natSrc = get(BASE .. "/Native.luau")
if not natSrc then
    fail("Native.luau fetch", "could not fetch")
else
    local loader = loadstring or load
    local fn, err = loader(stripBom(natSrc))
    if type(fn) == "function" and fn then
        local okc, Native = pcall(fn)
        if okc and type(Native) == "table" and Native.new then
            ok("Native.luau compiles & runs", "Native API ok")
        else
            fail("Native.luau run", tostring(Native))
        end
    else
        fail("Native.luau compile", tostring(err))
    end
end

print("===== DONE =====")
-- Summary
local pass = 0
for _, r in ipairs(Results) do if r.pass then pass = pass + 1 end end
print(("Summary: %d/%d checks passed"):format(pass, #Results))
if pass == #Results then print("ALL GREEN - migration should be OK. Paste this output back if anything is off.") end