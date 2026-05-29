---@meta

-- Hyprland 0.55 Lua API type stubs
-- https://wiki.hypr.land/Configuring/Start/

---@class HL.BindOptions
---@field repeating? boolean
---@field locked? boolean
---@field mouse? boolean
---@field release? boolean
---@field non_consuming? boolean
---@field description? string

---@class HL.FocusTarget
---@field direction? "left"|"right"|"up"|"down"
---@field workspace? string|integer
---@field monitor? string

---@class HL.WindowMoveTarget
---@field direction? "left"|"right"|"up"|"down"
---@field workspace? integer
---@field monitor? string

---@class HL.WindowFloatOpts
---@field action? "toggle"|"set"|"unset"
---@field window? string|integer

---@class HL.WindowFullscreenOpts
---@field mode? "maximized"|"fullscreen"
---@field action? "toggle"|"set"|"unset"
---@field window? string|integer

---@class HL.MonitorSpec
---@field output string
---@field mode? string
---@field position? string
---@field scale? string|number
---@field transform? integer
---@field vrr? integer
---@field mirror? string
---@field enabled? boolean

---@class HL.WindowRuleMatch
---@field class? string
---@field title? string
---@field fullscreen? boolean
---@field xwayland? boolean
---@field浮? boolean
---@field pinned? boolean

---@class HL.WindowRuleSpec
---@field name? string
---@field match HL.WindowRuleMatch
---@field workspace? integer|string
---@field monitor? string
---@field float? boolean
---@field pin? boolean
---@field pseudo? boolean
---@field no_focus? boolean
---@field no_blur? boolean
---@field center? boolean
---@field opacity? number
---@field move? string
---@field size? string
---@field min_size? string
---@field max_size? string
---@field rounding? integer
---@field border_color? string
---@field dim_around? boolean
---@field dim_around? boolean
---@field scrolling_width? number

---@class HL.LayerRuleMatch
---@field namespace? string

---@class HL.LayerRuleSpec
---@field name? string
---@field match HL.LayerRuleMatch
---@field blur? boolean
---@field ignore_alpha? number
---@field dim_around? boolean
---@field animation? string

---@class HL.WorkspaceRuleSpec
---@field workspace integer|string
---@field monitor string
---@field default? boolean
---@field layout_opts? table

---@class HL.DeviceSpec
---@field name string
---@field enabled? boolean
---@field sensitivity? number
---@field kb_layout? string
---@field kb_variant? string
---@field kb_model? string
---@field kb_options? string
---@field kb_rules? string
---@field natural_scroll? boolean
---@field tap_button_map? string
---@field middle_button_emulation? boolean
---@field resolve_binds_by_sym? boolean

---@class HL.AnimationSpec
---@field leaf string
---@field enabled? boolean
---@field speed? number
---@field curve? string
---@field style? string

---@class HL.PermissionSpec
---@field binary string
---@field type "screencopy"|"keyboard"|"plugin"
---@field mode "allow"|"ask"|"deny"

---@class HL.NotificationOpts
---@field text string
---@field icon? string
---@field timeout? number
---@field urgency? "low"|"normal"|"critical"
---@field group? string

---@class HL.Window
---@field address string
---@field title string
---@field class string
---@field workspace HL.Workspace
---@field monitor HL.Monitor
---@field floating boolean
---@field pid integer
---@field pinned boolean
---@field fullscreen integer
---@field focus_history_id integer
---@field hidden boolean
---@field mapped boolean
---@field x11 boolean

---@class HL.Workspace
---@field id integer
---@field name string
---@field monitor HL.Monitor
---@field windows integer
---@field is_special boolean
---@field tiled_layout string
---@field last_window HL.Window|nil
---@field fullscreen_window HL.Window|nil
---@field is_empty boolean
---@field config_name string
---@field groups integer

---@class HL.Monitor
---@field id integer
---@field name string
---@field width integer
---@field height integer
---@field refresh_rate number
---@field active_workspace HL.Workspace
---@field x integer
---@field y integer
---@field scale number
---@field transform integer
---@field disabled boolean
---@field vrr integer

---@class HL.DspWindow
---@field close fun(...:any): HL.Dispatcher
---@field kill fun(...:any): HL.Dispatcher
---@field signal fun(...:any): HL.Dispatcher
---@field float fun(opts: HL.WindowFloatOpts): HL.Dispatcher
---@field fullscreen fun(opts: HL.WindowFullscreenOpts): HL.Dispatcher
---@field fullscreen_state fun(opts: table): HL.Dispatcher
---@field pseudo fun(...:any): HL.Dispatcher
---@field move fun(opts: HL.WindowMoveTarget): HL.Dispatcher
---@field swap fun(...:any): HL.Dispatcher
---@field center fun(): HL.Dispatcher
---@field cycle_next fun(): HL.Dispatcher
---@field tag fun(...:any): HL.Dispatcher
---@field clear_tags fun(...:any): HL.Dispatcher
---@field toggle_swallow fun(...:any): HL.Dispatcher
---@field pin fun(...:any): HL.Dispatcher
---@field bring_to_top fun(): HL.Dispatcher
---@field alter_zorder fun(...:any): HL.Dispatcher
---@field set_prop fun(...:any): HL.Dispatcher
---@field deny_from_group fun(...:any): HL.Dispatcher
---@field drag fun(): HL.Dispatcher
---@field resize fun(): HL.Dispatcher

---@class HL.DspCursor
---@field move fun(...:any): HL.Dispatcher
---@field move_to_corner fun(...:any): HL.Dispatcher

---@class HL.DspGroup
---@field toggle fun(...:any): HL.Dispatcher
---@field next fun(...:any): HL.Dispatcher
---@field prev fun(...:any): HL.Dispatcher
---@field active fun(...:any): HL.Dispatcher
---@field move_window fun(...:any): HL.Dispatcher
---@field lock fun(...:any): HL.Dispatcher
---@field lock_active fun(...:any): HL.Dispatcher

---@class HL.LayoutTarget
---@field index integer
---@field window HL.Window|nil
---@field box HL.Box
---@field place fun(self: HL.LayoutTarget, box: HL.Box): nil
---@field set_box fun(self: HL.LayoutTarget, box: HL.Box): nil

---@class HL.LayoutContext
---@field area HL.Box
---@field targets HL.LayoutTarget[]
---@field grid_cell fun(self: HL.LayoutContext, i: integer, cols: integer, rows?: integer): HL.Box
---@field column fun(self: HL.LayoutContext, i: integer, n: integer): HL.Box
---@field row fun(self: HL.LayoutContext, i: integer, n: integer): HL.Box
---@field split fun(self: HL.LayoutContext, box: HL.Box, side: "left"|"right"|"top"|"bottom"|"up"|"down", ratio: number): HL.Box

---@class HL.LayoutProvider
---@field recalculate fun(ctx: HL.LayoutContext): nil
---@field layout_msg? fun(ctx: HL.LayoutContext, msg: string): boolean|string|nil

---@class HL.Box
---@field x integer
---@field y integer
---@field w integer
---@field h integer

---@class HL.Dispatcher

---@class HL.DspNamespace
---@field window HL.DspWindow
---@field cursor HL.DspCursor
---@field group HL.DspGroup
---@field layout fun(msg: string): HL.Dispatcher
---@field global fun(cmd: string): HL.Dispatcher
---@field exec_cmd fun(cmd: string): HL.Dispatcher

---@class HL.LayoutModule
---@field register fun(name: string, provider: HL.LayoutProvider): nil

---@class HL.NotificationModule
---@field create fun(opts: HL.NotificationOpts): nil

---@class HL.ConfigValueTypes

---@class HL.API
---@field dsp HL.DspNamespace
---@field layout HL.LayoutModule
---@field notification HL.NotificationModule
---@field env fun(name: string, value: string): nil
---@field config fun(opts: table): nil
---@field bind fun(keys: string, handler: HL.Dispatcher|fun():nil, options?: HL.BindOptions): nil
---@field exec_cmd fun(cmd: string): nil
---@field monitor fun(spec: HL.MonitorSpec): nil
---@field window_rule fun(spec: HL.WindowRuleSpec): nil
---@field layer_rule fun(spec: HL.LayerRuleSpec): nil
---@field workspace_rule fun(spec: HL.WorkspaceRuleSpec): nil
---@field device fun(spec: HL.DeviceSpec): nil
---@field animation fun(spec: HL.AnimationSpec): nil
---@field permission fun(spec: HL.PermissionSpec): nil
---@field on fun(event: string, callback: fun():nil): nil
---@field version fun(): string
---@field get_config fun(path: string): any
---@field get_active_window fun(): HL.Window|nil
---@field get_active_workspace fun(): HL.Workspace|nil
---@field get_monitors fun(): HL.Monitor[]

---@type HL.API
hl = {}
