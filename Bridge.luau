-- nznt Bridge -> Airflow-UI adapter (rewritten against the official Airflow-UI README API)
local function grab(url)
    local raw = game:HttpGet(url, true)
    if raw:sub(1, 1) == "\239\187\191" then raw = raw:sub(2) end
    return raw
end
local Airflow = loadstring(grab("https://raw.githubusercontent.com/Pocimin/airflow-ui/main/Source.luau"))()
local BRAND_LOGO = ((getgenv and getgenv()) or _G).NZNT_BRAND_LOGO or "rbxassetid://75353810328300"

local Bridge = {}

local function norm(c) if type(c) ~= "table" then return { Name = tostring(c or "Control") } end return c end
local function cb(c) return c.Callback or c.Function or c.OnChanged or function() end end

-- wrapped control handle with Set/Get adapting to Airflow's Set(value, skipCallback?)
local function handle(ctrl, setFn, getFn)
    local h = { _ctrl = ctrl }
    function h:Set(v) pcall(function() (setFn or ctrl.Set)(ctrl, v) end) end
    function h:SetValue(v) self:Set(v) end
    function h:Get() return getFn and getFn(ctrl) or (ctrl.Get and ctrl.Get()) or ctrl.Value end
    function h:SetText(v) self:Set(v) end
    function h:SetContent(v) self:Set(v) end
    function h:SetDesc(v) self:Set(v) end
    return h
end

function Bridge:CreateWindow(config)
    config = norm(config)
    local UIS = game:GetService("UserInputService")
    local screen = game:GetService("GuiService"):GetScreenResolution()
    local airWindow = Airflow:CreateWindow({
        Name = config.Name or "nznt's hub",
        LoadingSubtitle = config.Subtitle or "by nznt",
        Icon = BRAND_LOGO,
        ToggleUIKeybind = nil,                     -- we hide with Shift+U+Ctrl only
        Size = UDim2.fromScale(1, 1),              -- cover the whole screen
        MinSize = Vector2.new(screen.X, screen.Y),
        MaxSize = Vector2.new(screen.X, screen.Y),
        KeepOnScreen = true,
        OpenButton = { Title = "nznt's hub", Icon = BRAND_LOGO },
        ConfigurationSaving = config.ConfigurationSaving,
        Home = config.Home,
    })
    local w = { _W = airWindow }

    -- Shift + U + Ctrl to hide/show (our save-for-hide)
    task.spawn(function()
        UIS.InputBegan:Connect(function(inp, gp)
            if gp or not inp or inp.UserInputType ~= Enum.UserInputType.Keyboard or inp.KeyCode ~= Enum.KeyCode.U then return end
            if UIS:IsKeyDown(Enum.KeyCode.LeftShift) and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
                pcall(function() airWindow:Toggle() end)
            end
        end)
    end)

    function w:CreateTab(config)
        config = norm(config)
        local airTab = airWindow:CreateTab({ Name = config.Name or "Main", Desc = config.Description or config.Desc, Icon = config.Icon })
        local tab = {}
        local activeSection
        local function use(name)
            local fn = activeSection
            if fn then return fn end
            fn = {}
            pcall(function() airTab:CreateSection(name) end)
            activeSection = fn
            return fn
        end
        -- section heading
        function tab:CreateSection(name)
            local n = type(name) == "table" and (name.Name or name[1]) or tostring(name or "Features")
            pcall(function() airTab:CreateSection(n) end)
            return tab
        end
        function tab:CreateGroupbox(c) c = norm(c); return self:CreateSection(c.Name or c.Title or "Features") end
        tab.CreateGroupBox = tab.CreateGroupbox
        tab.AddSection = tab.CreateSection
        tab.AddLeftGroupbox = tab.CreateGroupbox
        tab.AddRightGroupbox = tab.CreateGroupbox
        -- element constructors render on the airTab (Airflow appends to the tab, current section is just a heading)
        function tab:CreateToggle(c)
            c = norm(c)
            local t = airTab:CreateToggle({ Name = c.Name or c.Title or "Toggle", Desc = c.Description or c.Desc, CurrentValue = c.Default == true or c.CurrentValue == true or c.Value == true, Flag = c.Flag, Callback = cb(c) })
            return handle(t)
        end
        function tab:CreateButton(c)
            c = norm(c)
            local b = airTab:CreateButton({ Name = c.Name or c.Title or "Button", Desc = c.Description or c.Desc, Icon = c.Icon, Callback = cb(c) })
            return handle(b)
        end
        function tab:CreateSlider(c)
            c = norm(c); local r = c.Range or {}
            local s = airTab:CreateSlider({ Name = c.Name or c.Title or "Slider", Desc = c.Description or c.Desc, Range = { c.Min or r[1] or 0, c.Max or r[2] or 100 }, Increment = c.Round or c.Decimals or c.Increment or 1, Suffix = c.Suffix or c.Unit or "", CurrentValue = c.Default or c.CurrentValue or c.Value or c.Min or r[1] or 0, Flag = c.Flag, Callback = cb(c) })
            return handle(s)
        end
        function tab:CreateDropdown(c)
            c = norm(c)
            local d = airTab:CreateDropdown({ Name = c.Name or c.Title or "Dropdown", Desc = c.Description or c.Desc, Options = c.Values or c.Options or c.Items or {}, CurrentOption = c.Default or c.CurrentOption or c.Value, MultipleOptions = c.Multi == true, Flag = c.Flag, Callback = cb(c) })
            return handle(d)
        end
        function tab:CreateInput(c)
            c = norm(c)
            local i = airTab:CreateInput({ Name = c.Name or c.Title or "Input", Desc = c.Description or c.Desc, PlaceholderText = c.Placeholder or c.PlaceholderText or "", CurrentValue = c.Default or c.CurrentValue or c.Value or "", Numeric = c.Numeric == true, Flag = c.Flag, Callback = cb(c) })
            return handle(i)
        end
        function tab:CreateParagraph(c)
            c = norm(c)
            local p = airTab:CreateParagraph({ Title = c.Title or c.Name or "Info", Content = c.Content or c.Text or c.Desc or "" })
            return handle(p, nil, function() return p.Value end)
        end
        function tab:CreateLabel(c)
            c = norm(c); local v = c.Text or c.Content or c.Name or ""
            local l = airTab:CreateLabel({ Text = (type(v) == "table" and v[1]) or v })
            return handle(l)
        end
        function tab:CreateDivider() return handle(airTab:CreateDivider()) end
        function tab:CreateKeybind(c)
            c = norm(c)
            local k = airTab:CreateKeybind({ Name = c.Name or c.Title or "Keybind", Desc = c.Description or c.Desc, CurrentKeybind = c.Default or c.CurrentKeybind or c.Value, Flag = c.Flag, Callback = c.Callback, OnChanged = c.OnChanged })
            return handle(k)
        end
        function tab:CreateColorPicker(c)
            c = norm(c)
            local cp = airTab:CreateColorPicker({ Name = c.Name or c.Title or "Color", Desc = c.Description or c.Desc, Color = c.Value or c.Color or Color3.fromRGB(235,199,246), Flag = c.Flag, Callback = cb(c) })
            return handle(cp)
        end
        function tab:CreateProgress(c)
            c = norm(c)
            local p = airTab:CreateProgress({ Name = c.Name or c.Title, Desc = c.Description, CurrentValue = c.Value or c.CurrentValue or nil, Color = c.Color, Format = c.Format, Callback = c.Callback })
            return handle(p)
        end
        function tab:CreateStepper(c)
            c = norm(c); local r = c.Range or {}
            local st = airTab:CreateStepper({ Name = c.Name or c.Title, Desc = c.Description or c.Desc, Range = { c.Min or r[1] or 0, c.Max or r[2] or 100 }, Increment = c.Increment or 1, Suffix = c.Suffix or "", CurrentValue = c.Default or c.CurrentValue or c.Value or r[1] or 0, Flag = c.Flag, Callback = cb(c) })
            return handle(st)
        end
        tab.CreateTextBox = tab.CreateInput
        tab.AddToggle = tab.CreateToggle
        tab.AddButton = tab.CreateButton
        tab.AddSlider = tab.CreateSlider
        tab.AddDropdown = tab.CreateDropdown
        tab.AddTextBox = tab.CreateInput
        tab.AddInput = tab.CreateInput
        tab.AddParagraph = tab.CreateParagraph
        tab.AddLabel = tab.CreateLabel
        tab.AddKeybind = tab.CreateKeybind
        tab.AddKeyPicker = tab.CreateKeybind
        tab.AddColorpicker = tab.CreateColorPicker
        tab.AddProgress = tab.CreateProgress
        tab.AddStepper = tab.CreateStepper
        tab.BuildThemeSection = function() end
        tab.BuildConfigSection = function() end
        function tab:Select() return tab end
        return tab
    end
    w.MakeTab = w.CreateTab

    function w:CreateHomeTab(c) return self:CreateTab({ Name = "Home", Icon = "home" }) end
    w.MakeHomeTab = w.CreateHomeTab
    function w:Notification(c) c = norm(c); pcall(function() airWindow:Notify({ Title = c.Title, Content = c.Content or c.Description or c.Message, Icon = c.Icon }) end) end
    w.Notify = w.Notification
    function w:Toggle(open) pcall(function() airWindow:Toggle(open) end) end
    function w:SetKeybind(k) pcall(function() airWindow:SetKeybind(k) end) end
    function w:Destroy() pcall(function() airWindow:Destroy() end) end
    function w:SaveConfig() pcall(function() airWindow:SaveConfig() end) end
    function w:LoadConfig() pcall(function() airWindow:LoadConfig() end) end
    function w:SelectTab(t) pcall(function() airWindow:SelectTab(t) end) end
    function w:Confirm(c) c = norm(c); pcall(function() airWindow:Confirm({ Title = c.Title, Content = c.Content, Icon = c.Icon, Callback = c.Callback, OnCancel = c.OnCancel }) end) end
    w.Dialog = w.Confirm
    function w:GetWindow() return airWindow end
    return w
end
Bridge.MakeWindow = Bridge.CreateWindow
function Bridge:Notification(c) c = norm(c); warn("[nznt's hub] " .. tostring(c.Content or c.Message or c.Title or "Notification")) end
Bridge.Notify = Bridge.Notification
return Bridge