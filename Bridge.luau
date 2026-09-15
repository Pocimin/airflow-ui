-- nznt Bridge -> Airflow-UI adapter
-- Maps the Airflow-style Bridge API (used by nznt bundles/game scripts) onto Airflow-UI
-- fetched from Pocimin/airflow-ui/main/Source.luau. Brand icon: 75353810328300.
-- Every constructor also works without the Create/Add prefix (Tab:Toggle == Tab:CreateToggle).

local BRAND_LOGO = ((getgenv and getgenv()) or _G).NZNT_BRAND_LOGO or "rbxassetid://75353810328300"

local function grab(url)
    local raw = game:HttpGet(url, true)
    -- strip UTF-8 BOM if GitHub raw added one (breaks loadstring :1)
    if raw:sub(1, 1) == "\239\187\191" then raw = raw:sub(2) end
    return raw
end
local Airflow = loadstring(grab("https://raw.githubusercontent.com/Pocimin/airflow-ui/main/Source.luau"))()

local Bridge = {}

local function normalize(config)
    if type(config) ~= "table" then return { Name = tostring(config or "Control") } end
    return config
end

local function cb(config)
    return config.Callback or config.Function or config.OnChanged or function() end
end

local function proxySet(c, setter)
    local p = { Control = c }
    function p:Set(v) pcall(function() setter(c, v) end) end
    p.SetValue = p.Set
    p.SetText = p.Set
    function p:Get() return p.Value end
    return p
end

-- Airflow Toggle
local function toggleProxy(t)
    local p = proxySet(t, function(el, v) el:Set(v == true) end)
    function p:Set(v) pcall(function() t:Set(v == true) end) end
    function p:Get() return t.Value end
    return p
end

-- Airflow Slider
local function sliderProxy(s)
    local p = proxySet(s, function(el, v) el:Set(v) end)
    function p:Set(v) pcall(function() s:Set(v) end) end
    function p:Get() return s.Value end
    return p
end

-- Airflow Button
local function buttonProxy(b)
    local p = proxySet(b, function() end)
    return p
end

-- Airflow Dropdown
local function dropdownProxy(d)
    local p = proxySet(d, function(el, v) el:Set(v) end)
    function p:Set(v) pcall(function() d:Set(v) end) end
    function p:Get() return d.Value end
    function p:Refresh(values) pcall(function() d:Refresh(values) end) end
    return p
end

-- Airflow Input
local function inputProxy(inp)
    local p = proxySet(inp, function(el, v) el:Set(tostring(v or "")) end)
    function p:Set(v) pcall(function() inp:Set(tostring(v or "")) end) end
    function p:Get() return inp.Value end
    return p
end

-- Airflow paragraph/label
local function textProxy(el)
    local p = proxySet(el, function(pg, v) pg:Set(tostring(v or "")) end)
    function p:Set(v) pcall(function() el:Set(tostring(v or "")) end) end
    function p:SetContent(v) p:Set(v) end
    function p:SetText(v) p:Set(v) end
    function p:SetDesc(v) p:Set(v) end
    return p
end

local function keybindProxy(k)
    local p = proxySet(k, function(el, v) el:Set(v) end)
    function p:Set(v) pcall(function() k:Set(v) end) end
    function p:Get() return k.Value end
    return p
end

local function colorProxy(col)
    local p = proxySet(col, function(el, v) el:Set(v) end)
    function p:Set(v) pcall(function() col:Set(v) end) end
    function p:Get() return col.Value end
    return p
end

-- Build a Section (airflow page section) wrapper.
-- Airflow requires CreateSection(<name>) BEFORE controls so they render in a named group
-- (controls created with no active section render as blank/no-name "misc" items).
local function wrapSection(airTab, sectionName)
    if sectionName and sectionName ~= "" then
        pcall(function() airTab:CreateSection(tostring(sectionName)) end)
    end
    local section = {}
    local controls = {}

    function section:Add(name, buildFn)
        controls[name or ("Control" .. #controls + 1)] = buildFn()
        return controls[name]
    end

    function section:CreateToggle(config)
        config = normalize(config)
        return airTab:CreateToggle({
            Name = config.Name or config.Title or "Toggle",
            Desc = config.Description or config.Desc,
            CurrentValue = config.Default == true or config.CurrentValue == true or config.Value == true,
            Flag = config.Flag,
            Callback = cb(config)
        })
    end
    function section:CreateButton(config)
        config = normalize(config)
        return airTab:CreateButton({
            Name = config.Name or config.Title or "Button",
            Desc = config.Description or config.Desc,
            Callback = cb(config)
        })
    end
    function section:CreateSlider(config)
        config = normalize(config)
        local range = config.Range or {}
        return airTab:CreateSlider({
            Name = config.Name or config.Title or "Slider",
            Desc = config.Description or config.Desc,
            Range = { config.Min or range[1] or 0, config.Max or range[2] or 100 },
            Increment = config.Round or config.Decimals or 1,
            Suffix = config.Suffix or config.Unit or "",
            CurrentValue = config.Default or config.CurrentValue or config.Value or config.Min or range[1] or 0,
            Flag = config.Flag,
            Callback = cb(config)
        })
    end
    function section:CreateDropdown(config)
        config = normalize(config)
        return airTab:CreateDropdown({
            Name = config.Name or config.Title or "Dropdown",
            Desc = config.Description or config.Desc,
            Options = config.Values or config.Options or config.Items or {},
            CurrentOption = config.Default or config.CurrentOption or config.Value,
            MultipleOptions = config.Multi == true,
            Flag = config.Flag,
            Callback = cb(config)
        })
    end
    function section:CreateInput(config)
        config = normalize(config)
        return airTab:CreateInput({
            Name = config.Name or config.Title or "Input",
            Desc = config.Description or config.Desc,
            PlaceholderText = config.Placeholder or config.PlaceholderText or "",
            CurrentValue = config.Default or config.CurrentValue or config.Value or "",
            Flag = config.Flag,
            Callback = cb(config)
        })
    end
    section.CreateTextBox = section.CreateInput
    function section:CreateParagraph(config)
        config = normalize(config)
        return airTab:CreateParagraph({
            Title = config.Title or config.Name or "Info",
            Content = config.Content or config.Text or config.Desc or ""
        })
    end
    function section:CreateLabel(config)
        config = normalize(config)
        return airTab:CreateLabel({
            Text = config.Text or config.Content or config.Name or ""
        })
    end
    function section:CreateKeybind(config)
        config = normalize(config)
        return airTab:CreateKeybind({
            Name = config.Name or config.Title or "Keybind",
            Desc = config.Description or config.Desc,
            CurrentKeybind = config.Default or config.CurrentKeybind or config.Value,
            Flag = config.Flag,
            Callback = cb(config),
            OnChanged = config.OnChanged
        })
    end
    function section:CreateColorPicker(config)
        config = normalize(config)
        return airTab:CreateColorPicker({
            Name = config.Name or config.Title or "Color",
            Desc = config.Description or config.Desc,
            Color = config.Value or config.Color or Color3.fromRGB(235, 199, 246),
            Flag = config.Flag,
            Callback = cb(config)
        })
    end
    function section:CreateProgress(config)
        return airTab:CreateProgress(normalize(config))
    end
    function section:CreateDivider() return airTab:CreateDivider() end

    -- Add*/Create* aliases
    section.AddToggle = section.CreateToggle
    section.AddButton = section.CreateButton
    section.AddSlider = section.CreateSlider
    section.AddDropdown = section.CreateDropdown
    section.AddTextBox = section.CreateInput
    section.AddInput = section.CreateInput
    section.AddParagraph = section.CreateParagraph
    section.AddLabel = section.CreateLabel
    section.AddKeybind = section.CreateKeybind
    section.AddKeyPicker = section.CreateKeybind
    section.AddColorpicker = section.CreateColorPicker
    section.AddProgress = section.CreateProgress
    return section
end

function Bridge:CreateTab(config)
    config = normalize(config)
    local airTab = self._Window:CreateTab({
        Name = config.Name or config.Title or "Main",
        Desc = config.Description or config.Desc,
        Icon = config.Icon or config.IconContact
    })
    local tab = {}

    function tab:CreateSection(name)
        local n = type(name) == "table" and (name.Name or name.Title or name[1]) or tostring(name or "Features")
        return wrapSection(airTab, n)
    end
    function tab:CreateGroupbox(config)
        config = normalize(config)
        return wrapSection(airTab, config.Name or config.Title or "Features")
    end
    tab.CreateGroupBox = tab.CreateGroupbox
    tab.AddSection = tab.CreateSection
    tab.AddLeftGroupbox = tab.CreateGroupbox
    tab.AddRightGroupbox = tab.CreateGroupbox
    tab.AddLeftTabbox = function(config) config = normalize(config); return { AddTab = function(cfg) cfg = normalize(cfg); return wrapSection(airTab, cfg.Name or cfg.Title or "Features") end } end
    tab.AddRightTabbox = function(config) config = normalize(config); return { AddTab = function(cfg) cfg = normalize(cfg); return wrapSection(airTab, cfg.Name or cfg.Title or "Features") end } end
    tab.AddTab = function(config) config = normalize(config); return wrapSection(airTab, config.Name or config.Title or "Features") end

    local function current()
        return wrapSection(airTab, "Features")
    end
    tab.CreateToggle = function(c) return current():CreateToggle(c) end
    tab.CreateButton = function(c) return current():CreateButton(c) end
    tab.CreateSlider = function(c) return current():CreateSlider(c) end
    tab.CreateDropdown = function(c) return current():CreateDropdown(c) end
    tab.CreateInput = function(c) return current():CreateInput(c) end
    tab.CreateTextBox = tab.CreateInput
    tab.CreateParagraph = function(c) return current():CreateParagraph(c) end
    tab.CreateLabel = function(c) return current():CreateLabel(c) end
    tab.CreateDivider = function() return current():CreateDivider() end
    tab.CreateKeybind = function(c) return current():CreateKeybind(c) end
    tab.CreateColorPicker = function(c) return current():CreateColorPicker(c) end
    tab.CreateProgress = function(c) return current():CreateProgress(c) end

    tab.AddToggle = tab.CreateToggle
    tab.AddButton = tab.CreateButton
    tab.AddSlider = tab.CreateSlider
    tab.AddDropdown = tab.CreateDropdown
    tab.AddTextBox = tab.CreateInput
    tab.AddParagraph = tab.CreateParagraph
    tab.AddLabel = tab.CreateLabel
    tab.AddKeybind = tab.CreateKeybind
    tab.AddKeyPicker = tab.CreateKeybind
    tab.AddColorpicker = tab.CreateColorPicker

    tab.BuildThemeSection = function() end
    tab.BuildConfigSection = function() end
    function tab:Select() return self end
    return tab
end

function Bridge:CreateWindow(config)
    config = normalize(config)
    local airWindow = Airflow:CreateWindow({
        Name = config.Name or config.Title or "nznt's hub",
        LoadingSubtitle = config.Subtitle or "by nznt",
        Icon = config.Icon and (type(config.Icon) == "string" and config.Icon or BRAND_LOGO) or BRAND_LOGO,
        ToggleUIKeybind = config.Keybind or "RightControl",
        ConfigurationSaving = config.ConfigurationSaving,
        Home = config.Home
    })

    -- Fullscreen cover: fill the whole screen so nothing behind is visible.
    pcall(function()
        local UIS = game:GetService("UserInputService")
        local screen = UIS:GetScreenResolution()
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
    -- Disable the default single-keybind toggle to avoid two ways of hiding.
    pcall(function() airWindow.Keybind = nil end)
    local proxy = { _Window = airWindow }
    proxy.CreateTab = Bridge.CreateTab
    proxy.MakeTab = Bridge.CreateTab
    function proxy:CreateHomeTab(cfg) return self:CreateTab({ Name = "Home", Icon = "home" }) end
    proxy.MakeHomeTab = proxy.CreateHomeTab
    function proxy:Notification(cfg) cfg = normalize(cfg); airWindow:Notify({ Title = cfg.Title, Content = cfg.Content or cfg.Description or cfg.Message, Icon = cfg.Icon }) end
    proxy.Notify = proxy.Notification
    function proxy:NotifyContent(cfg) self:Notification(cfg) end
    function proxy:Toggle(open) airWindow:Toggle(open) end
    function proxy:SetKeybind(k) airWindow:SetKeybind(k) end
    function proxy:Destroy() airWindow:Destroy() end
    function proxy:SaveConfig() pcall(function() airWindow:SaveConfig() end) end
    function proxy:LoadConfig() pcall(function() airWindow:LoadConfig() end) end
    function proxy:SelectTab(t) pcall(function() airWindow:SelectTab(t) end) end
    function proxy:Confirm(cfg) cfg = normalize(cfg); airWindow:Confirm({ Title = cfg.Title, Content = cfg.Content, Icon = cfg.Icon, Callback = cfg.Callback, OnCancel = cfg.OnCancel }) end
    proxy.Dialog = proxy.Confirm
    function proxy:GetWindow() return airWindow end
    return proxy
end

Bridge.MakeWindow = Bridge.CreateWindow
Bridge.MakeTab = Bridge.CreateTab

function Bridge:Notification(cfg) cfg = normalize(cfg); warn("[nznt] " .. tostring(cfg.Content or cfg.Description or cfg.Message or cfg.Title or "Notification")) end
Bridge.Notify = Bridge.Notification

return Bridge