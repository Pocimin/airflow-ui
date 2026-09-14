-- nznt Native-CompKiller -> Airflow-UI adapter
-- Replicates the CompKiller surface used by de.lua / dds_premium.lua / dds_free.lua / blox_fruits.lua
-- on top of Airflow-UI (Pocimin/airflow-ui). Brand icon: 75353810328300.
-- API provided:
--   Native.new({Name, Keybind, Logo, Scale}) -> window
--   window:DrawContainerTab({Name, Icon}) -> container
--   container:DrawTab({Name, Type, EnableScrolling}) -> tab
--   tab:DrawSection({Name, Position}) -> section
--   section:AddToggle/AddSlider/AddButton/AddDropdown/AddTextBox/AddParagraph({...}) -> handle
--   window:AddToggle/... (direct shortcuts)
--   handle:SetContent / :Set / :SetValue(old CompKiller paragraph/control update)
--   Native.Scale.Window
--   Native.newNotify() -> { Notify = function(cfg) end }

local Airflow = loadstring(game:HttpGet("https://raw.githubusercontent.com/Pocimin/airflow-ui/main/Source.luau", true))()
local Native = {}

local function norm(c)
    if type(c) ~= "table" then return { Name = tostring(c or "Control") } end
    return c
end
local function cb(c) return c.Callback or c.Function or function() end end

-- handle proxies -------------------------------------------------------------
local function wrapControl(ctrl, kind)
    local h = { Control = ctrl }
    function h:SetContent(v) pcall(function() ctrl:Set(tostring(v or "")) end) end
    function h:Set(v) pcall(function() ctrl:Set(v) end) end
    function h:SetValue(v) h:Set(v) end
    function h:SetText(v) h:SetContent(v) end
    function h:Get() if ctrl and ctrl.Get then return ctrl:Get() end end
    return h
end

-- an Airflow raw paragraph handle maps to SetContent directly
local function wrapParagraph(ctrl)
    local h = { Paragraph = ctrl }
    function h:SetContent(v) pcall(function() ctrl:Set(tostring(v or "")) end) end
    h.Set = h.SetContent
    return h
end

-- section builder over an airflow tab ----------------------------------------
local function buildSection(airTab, pos)
    local sec = {}
    function sec:AddToggle(c) c = norm(c); return wrapControl(airTab:CreateToggle({ Name = c.Name, Desc = c.ValueName or c.Desc, CurrentValue = c.Default == true, Callback = cb(c) })) end
    function sec:AddSlider(c) c = norm(c); return wrapControl(airTab:CreateSlider({ Name = c.Name, Desc = c.ValueName or c.Desc, Range = { c.Min or 0, c.Max or 100 }, Increment = c.Increment or 1, Suffix = c.ValueName or "", CurrentValue = c.Default or c.Min or 0, Callback = cb(c) })) end
    function sec:AddDropdown(c) c = norm(c); return wrapControl(airTab:CreateDropdown({ Name = c.Name, Desc = c.ValueName or c.Desc, Options = c.Options or c.Values or {}, CurrentOption = c.Default, Callback = cb(c) })) end
    function sec:AddTextBox(c) c = norm(c); return wrapControl(airTab:CreateInput({ Name = c.Name, Desc = c.ValueName or c.Desc, PlaceholderText = c.Placeholder or "", CurrentValue = c.Default or c.Value or "", Callback = cb(c) })) end
    function sec:AddButton(c) c = norm(c); return wrapControl(airTab:CreateButton({ Name = c.Name, Desc = c.ValueName or c.Desc, Callback = cb(c) })) end
    function sec:AddParagraph(c) c = norm(c); return wrapParagraph(airTab:CreateParagraph({ Title = c.Title or c.Name or "Info", Content = c.Content or "" })) end
    function sec:AddKeybind(c) c = norm(c); return wrapControl(airTab:CreateKeybind({ Name = c.Name, CurrentKeybind = c.Default, Callback = cb(c) })) end
    function sec:AddLabel(c) c = norm(c); return wrapParagraph(airTab:CreateLabel({ Text = c.Content or c.Name or "" })) end
    -- aliases
    sec.AddButton_SL = sec.AddButton
    return sec
end

-- the window proxy -----------------------------------------------------------
local function newWindow(o)
    o = o or {}
    local airWindow = Airflow:CreateWindow({
        Name = o.Name or "nznt's hub",
        LoadingSubtitle = o.Subtitle or "by nznt",
        Icon = typeof(o.Logo) == "string" and o.Logo or ((getgenv and getgenv()).NZNT_BRAND_LOGO) or "rbxassetid://75353810328300",
        ToggleUIKeybind = o.Keybind or "RightControl",
    })
    local w = { _W = airWindow }
    function w:DrawContainerTab(o) o = norm(o); return { _W = airWindow, _TabName = o.Name, _Icon = o.Icon }
    end
    function w:DrawTabList() return w end
    function w:AddToggle(c) return buildSection(airWindow:CreateTab({ Name = "Controls" })):AddToggle(c) end
    function w:AddButton(c) return buildSection(airWindow:CreateTab({ Name = "Controls" })):AddButton(c) end
    function w:Destroy() if w._W and w._W.Destroy then pcall(function() w._W:Destroy() end) end end
    return w
end

-- container:DrawTab -> airWindow tab page, then DrawSection -> section
local containerMeta = {}
containerMeta.__index = containerMeta
function containerMeta:DrawTab(o)
    o = norm(o)
    local airTab = self._W:CreateTab({ Name = o.Name or self._TabName or "Tab", Icon = self._Icon })
    local t = { _Tab = airTab, _W = self._W }
    function t:DrawSection(o)
        o = norm(o)
        return buildSection(airTab, tonumber(o.Position) == 2 and "right" or "left")
    end
    function t:AddToggle(c) return buildSection(airTab):AddToggle(c) end
    function t:AddSlider(c) return buildSection(airTab):AddSlider(c) end
    function t:AddButton(c) return buildSection(airTab):AddButton(c) end
    function t:AddParagraph(c) return buildSection(airTab):AddParagraph(c) end
    function t:AddDropdown(c) return buildSection(airTab):AddDropdown(c) end
    function t:AddTextBox(c) return buildSection(airTab):AddTextBox(c) end
    return t
end

function Native.new(o)
    local w = newWindow(o)
    -- patch DrawContainerTab to return the container metatable-based object
    function w:DrawContainerTab(co)
        co = norm(co)
        return setmetatable({ _W = w._W, _TabName = co.Name, _Icon = co.Icon }, containerMeta)
    end
    return w
end

Native.Scale = { Window = 1 }
Native.Window = Native.new
Native.theme = {}

function Native:newNotify()
    return { Notify = function(cfg) cfg = norm(cfg); local w = self._lastWindow or self._W; if w and w.Notify then pcall(function() w:Notify({ Title = cfg.Title, Content = cfg.Content, Icon = cfg.Icon }) end) end end }
end

-- expose the last created window on the lib for notifications
local _realNew = Native.new
function Native.new(o)
    local w = _realNew(o)
    Native._lastWindow = w
    Native._W = w
    return w
end

return Native