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

local function grab(url)
    local raw = game:HttpGet(url, true)
    -- strip UTF-8 BOM if GitHub raw added one (breaks loadstring :1)
    if raw:sub(1, 1) == "\239\187\191" then raw = raw:sub(2) end
    return raw
end
local Airflow = loadstring(grab("https://raw.githubusercontent.com/Pocimin/airflow-ui/main/Source.luau"))()
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
local function buildSection(airTab, pos, sectionName)
    -- Airflow requires CreateSection(<name>) before controls (else they render blank/no-name)
    local name = sectionName or (pos == "right" and "Statistic" or "Features")
    pcall(function() airTab:CreateSection(tostring(name)) end)
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

    -- Fullscreen cover: fill the whole screen so nothing behind is visible.
    pcall(function()
        local UIS2 = game:GetService("UserInputService")
        local screen = UIS2:GetScreenResolution()
        if airWindow and airWindow.Root and airWindow.Gui then
            airWindow.MaxSize = Vector2.new(screen.X + 32, screen.Y + 32)
            airWindow.MainSize = Vector2.new(screen.X, screen.Y)
            airWindow.Root.Size = UDim2.fromOffset(screen.X, screen.Y)
            airWindow.Root.Position = UDim2.new(0, 0, 0, 0)
            airWindow.KeepOnScreen = true
        end
    end)
    -- Only hide it with Shift + U + Ctrl.
    pcall(function()
        local UIS = game:GetService("UserInputService")
        UIS.InputBegan:Connect(function(inp, gp)
            if gp or not inp or inp.UserInputType ~= Enum.UserInputType.Keyboard or inp.KeyCode ~= Enum.KeyCode.U then return end
            if UIS:IsKeyDown(Enum.KeyCode.LeftShift) and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
                task.spawn(function() pcall(function() airWindow:Toggle() end) end)
            end
        end)
    end)
    pcall(function() airWindow.Keybind = nil end)
    -- Floating open/close button for mobile (own ScreenGui, stays on top of fullscreen window)
    pcall(function()
        local Players = game:GetService("Players")
        local screen = Instance.new("ScreenGui")
        screen.Name = "NZNT_OpenButton"
        screen.ResetOnSpawn = false
        screen.DisplayOrder = 100
        screen.Parent = Players.LocalPlayer and Players.LocalPlayer:WaitForChild("PlayerGui") or game:GetService("CoreGui")
        local btn = Instance.new("TextButton")
        btn.Name = "NZNT_OpenButton_Button"
        btn.BackgroundColor3 = Color3.fromRGB(24, 19, 24)
        btn.BorderSizePixel = 0
        btn.Text = "nznt's hub"
        btn.TextColor3 = Color3.fromRGB(233, 229, 234)
        btn.TextSize = 14
        btn.Size = UDim2.new(0, 120, 0, 34)
        btn.Position = UDim2.new(0.5, -60, 0, 10)
        btn.ZIndex = 100
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = btn
        btn.Parent = screen
        local dragging, dragStart, dragPos
        btn.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = inp.Position
                dragPos = btn.Position
            end
        end)
        local UIS2 = game:GetService("UserInputService")
        UIS2.InputChanged:Connect(function(inp)
            if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
                local delta = inp.Position - dragStart
                btn.Position = UDim2.fromOffset(dragPos.X.Offset + delta.X, dragPos.Y.Offset + delta.Y)
            end
        end)
        UIS2.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        btn.Activated:Connect(function()
            if not dragging then
                task.spawn(function() pcall(function() airWindow:Toggle() end) end)
            end
        end)
        task.spawn(function()
            repeat task.wait(1) until not airWindow or not airWindow.Gui or not airWindow.Gui.Parent
            pcall(function() screen:Destroy() end)
        end)
    end)
    local w = { _W = airWindow }
    function w:DrawContainerTab(o) o = norm(o); return { _W = airWindow, _TabName = o.Name, _Icon = o.Icon }
    end
    function w:DrawTabList() return w end
    function w:AddToggle(c) return buildSection(airWindow:CreateTab({ Name = "Controls" })):AddToggle(c) end
    function w:AddButton(c) return buildSection(airWindow:CreateTab({ Name = "Controls" })):AddButton(c) end
    function w:Destroy() if w._W and w._W.Destroy then pcall(function() w._W:Destroy() end) end end
    function w:Notify(cfg) cfg = norm(cfg); pcall(function() airWindow:Notify({ Title = cfg.Title, Content = cfg.Content or cfg.Description, Icon = cfg.Icon or cfg.Image }) end) end
    function w:SelectTab(t) pcall(function() airWindow:SelectTab(t) end) end
    return w
end

-- container:DrawTab -> airWindow tab page, then DrawSection -> section
local containerMeta = {}
containerMeta.__index = containerMeta
function containerMeta:DrawTab(o)
    o = norm(o)
    local iceTab = self._W:CreateTab({ Name = o.Name or self._TabName or "Tab", Icon = self._Icon })
    local t = { _Tab = iceTab, _W = self._W }
    local activeSection
    local function setActive(s) activeSection = s; return s end
    local function build(name)
        if not activeSection then
            setActive(buildSection(iceTab, nil, name or "Features"))
        end
        return activeSection
    end
    function t:DrawSection(o)
        o = norm(o)
        return setActive(buildSection(iceTab, tonumber(o.Position) == 2 and "right" or "left", o.Name or o.Title))
    end
    function t:AddToggle(c) return build():AddToggle(c) end
    function t:AddSlider(c) return build():AddSlider(c) end
    function t:AddButton(c) return build():AddButton(c) end
    function t:AddParagraph(c) return build():AddParagraph(c) end
    function t:AddDropdown(c) return build():AddDropdown(c) end
    function t:AddTextBox(c) return build():AddTextBox(c) end
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

-- CompKiller loader surface: no-op (Airflow has its own loading card).
local function yieldNoop() end
function Native:Loader(logo, duration)
    return { yield = yieldNoop }
end
function Native:GetConfig(name) return nil end
function Native:SetConfig(name) return nil end
function Native:Destroy() if Native._lastWindow then pcall(function() Native._lastWindow:Destroy() end) end end

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