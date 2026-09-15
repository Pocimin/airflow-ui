-- nznt Native-CompKiller -> Airflow-UI adapter (rewritten against official Airflow-UI API)
local function grab(url)
    local raw = game:HttpGet(url, true)
    if raw:sub(1, 1) == "\239\187\191" then raw = raw:sub(2) end
    return raw
end
local Airflow = loadstring(grab("https://raw.githubusercontent.com/Pocimin/airflow-ui/main/Source.luau"))()
local Native = {}
local BRAND_LOGO = ((getgenv and getgenv()) or _G).NZNT_BRAND_LOGO or "rbxassetid://75353810328300"

local function norm(c) if type(c) ~= "table" then return { Name = tostring(c or "Control") } end return c end
local function cb(c) return c.Callback or c.Function or function() end end

local function wrap(ctrl)
    local h = { _ctrl = ctrl }
    function h:Set(v) pcall(function() ctrl:Set(v) end) end
    function h:SetContent(v) pcall(function() ctrl:Set(v) end) end
    function h:SetText(v) h:SetContent(v) end
    function h:SetValue(v) h:Set(v) end
    function h:Get() return ctrl.Value end
    return h
end
local function wrapParagraph(ctrl)
    local h = { _ctrl = ctrl }
    function h:SetContent(v) pcall(function() ctrl:Set(v) end) end
    h.Set = h.SetContent
    return h
end

local function buildSection(airTab, sectionName)
    pcall(function() airTab:CreateSection(tostring(sectionName or "Features")) end)
    local sec = {}
    function sec:AddToggle(c) c = norm(c); return wrap(airTab:CreateToggle({ Name = c.Name, Desc = c.ValueName or c.Desc, CurrentValue = c.Default == true or c.Value == true, Callback = cb(c) })) end
    function sec:AddSlider(c) c = norm(c); local r = c.Range or {}; return wrap(airTab:CreateSlider({ Name = c.Name, Desc = c.ValueName or c.Desc, Range = { c.Min or r[1] or 0, c.Max or r[2] or 100 }, Increment = c.Increment or 1, Suffix = c.ValueName or "", CurrentValue = c.Default or c.Min or 0, Callback = cb(c) })) end
    function sec:AddDropdown(c) c = norm(c); return wrap(airTab:CreateDropdown({ Name = c.Name, Desc = c.ValueName or c.Desc, Options = c.Options or c.Values or {}, CurrentOption = c.Default, Callback = cb(c) })) end
    function sec:AddTextBox(c) c = norm(c); return wrap(airTab:CreateInput({ Name = c.Name, Desc = c.ValueName or c.Desc, PlaceholderText = c.Placeholder or "", CurrentValue = c.Default or c.Value or "", Callback = cb(c) })) end
    function sec:AddButton(c) c = norm(c); return wrap(airTab:CreateButton({ Name = c.Name, Desc = c.ValueName or c.Desc, Icon = c.Icon, Callback = cb(c) })) end
    function sec:AddParagraph(c) c = norm(c); return wrapParagraph(airTab:CreateParagraph({ Title = c.Title or c.Name or "Info", Content = c.Content or "" })) end
    function sec:AddKeybind(c) c = norm(c); return wrap(airTab:CreateKeybind({ Name = c.Name, CurrentKeybind = c.Default, Callback = cb(c) })) end
    function sec:AddLabel(c) c = norm(c); return wrapParagraph(airTab:CreateLabel({ Text = c.Content or c.Name or "" })) end
    sec.AddButton_SL = sec.AddButton
    return sec
end

local containerMeta = {}
containerMeta.__index = containerMeta
function containerMeta:DrawTab(o)
    o = norm(o)
    local airTab = self._W:CreateTab({ Name = o.Name or self._TabName or "Tab", Icon = self._Icon })
    local t = { _Tab = airTab, _W = self._W }
    local activeSection
    local function use(name)
        if activeSection then return activeSection end
        activeSection = buildSection(airTab, name)
        return activeSection
    end
    function t:DrawSection(o)
        o = norm(o)
        activeSection = buildSection(airTab, o.Name or o.Title or (tonumber(o.Position) == 2 and "Statistic" or "Features"))
        return activeSection
    end
    function t:AddToggle(c) return use():AddToggle(c) end
    function t:AddSlider(c) return use():AddSlider(c) end
    function t:AddButton(c) return use():AddButton(c) end
    function t:AddParagraph(c) return use():AddParagraph(c) end
    function t:AddDropdown(c) return use():AddDropdown(c) end
    function t:AddTextBox(c) return use():AddTextBox(c) end
    return t
end

function Native.new(o)
    o = norm(o)
        local airWindow = Airflow:CreateWindow({
        Name = o.Name or "nznt's hub",
        LoadingSubtitle = o.Subtitle or "by nznt",
        Icon = typeof(o.Logo) == "string" and o.Logo or BRAND_LOGO,
        ToggleUIKeybind = nil,
        KeepOnScreen = true,
        OpenButton = { Title = "nznt's hub", Icon = BRAND_LOGO },
    })
    local w = { _W = airWindow }
    function w:DrawContainerTab(co) co = norm(co); return setmetatable({ _W = airWindow, _TabName = co.Name, _Icon = co.Icon }, containerMeta) end
    function w:DrawTabList() return w end
    function w:AddToggle(c) return buildSection(airWindow:CreateTab({ Name = "Controls" })):AddToggle(c) end
    function w:AddButton(c) return buildSection(airWindow:CreateTab({ Name = "Controls" })):AddButton(c) end
    function w:Notify(c) c = norm(c); pcall(function() airWindow:Notify({ Title = c.Title, Content = c.Content or c.Description, Icon = c.Icon or c.Image }) end) end
    function w:Destroy() if airWindow and airWindow.Destroy then pcall(function() airWindow:Destroy() end) end end
    function w:Toggle(open) pcall(function() airWindow:Toggle(open) end) end
    function w:SelectTab(t) pcall(function() airWindow:SelectTab(t) end) end
    function w:SetFullScreen(on)
        pcall(function()
            local scr = game:GetService("GuiService"):GetScreenResolution()
            if on then
                airWindow.MinSize = Vector2.new(scr.X, scr.Y)
                airWindow.MaxSize = Vector2.new(scr.X, scr.Y)
                airWindow.Root.Size = UDim2.fromScale(1, 1)
                airWindow.Root.Position = UDim2.new(0, 0, 0, 0)
            else
                airWindow.MinSize = Vector2.new(480, 360)
                airWindow.MaxSize = Vector2.new(100000, 100000)
                airWindow.Root.Size = UDim2.fromOffset(640, 480)
            end
            if airWindow._fitToScreen then airWindow:_fitToScreen() end
            if airWindow._clampToScreen then airWindow:_clampToScreen() end
        end)
    end
    return w
end
Native.Scale = { Window = 1 }
Native.Window = Native.new
Native.theme = {}
Native.Window = Native.new
local function yieldNoop() end
function Native:Loader() return { yield = yieldNoop } end
function Native:GetConfig() return nil end
function Native:SetConfig() return nil end
function Native:Destroy() if Native._W then pcall(function() Native._W:Destroy() end) end end
function Native:newNotify()
    return { Notify = function(c) c = norm(c)
        local win = Native._W
        if win and win.Notify then pcall(function() win:Notify({ Title = c.Title, Content = c.Content }) end) end
    end }
end
Native.new = (function(orig)
    local _realNew = orig
    Native.new = nil
    return function(o)
        local w = _realNew(o)
        Native._W = w
        return w
    end
end)(Native.new)
return Native