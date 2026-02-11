local addonName, ns = ...

ns:RegisterLocale("enUS", {
    ---------------------------------------------------------------------------
    -- HOME PAGE
    ---------------------------------------------------------------------------
    HOME_SUBTITLE = "Select a module from the sidebar to configure",

    ---------------------------------------------------------------------------
    -- COMMON: UI Actions
    ---------------------------------------------------------------------------
    COMMON_UNLOCK = "Unlock",
    COMMON_SAVE = "Save",
    COMMON_CANCEL = "Cancel",
    COMMON_ADD = "Add",
    COMMON_EDIT = "Edit",
    COMMON_RELOAD_UI = "Reload UI",
    COMMON_LATER = "Later",
    COMMON_YES = "Yes",
    COMMON_NO = "No",
    COMMON_RESET_DEFAULTS = "Reset to Defaults",

    ---------------------------------------------------------------------------
    -- COMMON: Section Headers
    ---------------------------------------------------------------------------
    COMMON_SECTION_APPEARANCE = "APPEARANCE",
    COMMON_SECTION_BEHAVIOR = "BEHAVIOR",
    COMMON_SECTION_DISPLAY = "DISPLAY",
    COMMON_SECTION_SETTINGS = "SETTINGS",
    COMMON_SECTION_SOUND = "SOUND",
    COMMON_SECTION_AUDIO = "AUDIO",

    ---------------------------------------------------------------------------
    -- COMMON: Form Labels
    ---------------------------------------------------------------------------
    COMMON_LABEL_NAME = "Name:",
    COMMON_LABEL_SPELLID = "Spell ID:",
    COMMON_LABEL_ICON_SIZE = "Icon Size",
    COMMON_LABEL_FONT_SIZE = "Font Size",
    COMMON_LABEL_TEXT_SIZE = "Text Size",
    COMMON_LABEL_TEXT_COLOR = "Text Color",
    COMMON_LABEL_COLOR = "Color",
    COMMON_LABEL_ENABLE_SOUND = "Enable Sound",
    COMMON_LABEL_PLAY_SOUND = "Play Sound",
    COMMON_LABEL_ALERT_SOUND = "Alert Sound:",
    COMMON_LABEL_ALERT_COLOR = "Alert Color",
    COMMON_MATCH_BY = "Match by:",
    COMMON_BUFF_NAME = "Buff Name",
    COMMON_ENTRIES_COMMA = "Entries (comma-separated):",

    ---------------------------------------------------------------------------
    -- COMMON: Difficulty Filters
    ---------------------------------------------------------------------------
    COMMON_DIFF_NORMAL_DUNGEON = "Normal Dungeon",
    COMMON_DIFF_HEROIC_DUNGEON = "Heroic Dungeon",
    COMMON_DIFF_MYTHIC_DUNGEON = "Mythic Dungeon",
    COMMON_DIFF_LFR = "LFR",
    COMMON_DIFF_NORMAL_RAID = "Normal Raid",
    COMMON_DIFF_HEROIC_RAID = "Heroic Raid",
    COMMON_DIFF_MYTHIC_RAID = "Mythic Raid",
    COMMON_DIFF_OTHER = "Other",

    ---------------------------------------------------------------------------
    -- COMMON: Thresholds
    ---------------------------------------------------------------------------
    COMMON_THRESHOLD_DUNGEON = "Dungeon",
    COMMON_THRESHOLD_RAID = "Raid",
    COMMON_THRESHOLD_OTHER = "Other",

    ---------------------------------------------------------------------------
    -- COMMON: Status/States
    ---------------------------------------------------------------------------
    COMMON_ON = "ON",
    COMMON_OFF = "OFF",
    COMMON_ENABLED = "Enabled",
    COMMON_DISABLED = "Disabled",
    COMMON_EXPIRED = "EXPIRED",
    COMMON_MISSING = "MISSING",

    ---------------------------------------------------------------------------
    -- COMMON: Errors
    ---------------------------------------------------------------------------
    COMMON_ERR_ENTRY_REQUIRED = "Entry required.",
    COMMON_ERR_SPELLID_REQUIRED = "Spell ID required.",

    ---------------------------------------------------------------------------
    -- COMMON: TTS Labels
    ---------------------------------------------------------------------------
    COMMON_TTS_MESSAGE = "TTS Message:",
    COMMON_TTS_VOICE = "TTS Voice:",
    COMMON_TTS_VOLUME = "TTS Volume",
    COMMON_TTS_SPEED = "TTS Speed",

    ---------------------------------------------------------------------------
    -- COMMON: Hints
    ---------------------------------------------------------------------------
    COMMON_HINT_PARTIAL_MATCH = "Partial, case-insensitive matching.",
    COMMON_DRAG_TO_MOVE = "Drag to move",

    ---------------------------------------------------------------------------
    -- SIDEBAR
    ---------------------------------------------------------------------------
    SIDEBAR_GROUP_COMBAT = "COMBAT",
    SIDEBAR_GROUP_HUD = "HUD",
    SIDEBAR_GROUP_TRACKING = "TRACKING",
    SIDEBAR_GROUP_REMINDERS = "REMINDERS/MISC",
    SIDEBAR_GROUP_SYSTEM = "SYSTEM",
    SIDEBAR_TAB_COMBAT_TIMER = "Combat Timer",
    SIDEBAR_TAB_COMBAT_ALERT = "Combat Alert",
    SIDEBAR_TAB_COMBAT_LOGGER = "Combat Logger",
    SIDEBAR_TAB_GCD_TRACKER = "GCD Tracker",
    SIDEBAR_TAB_MOUSE_RING = "Mouse Ring",
    SIDEBAR_TAB_CROSSHAIR = "Crosshair",
    SIDEBAR_TAB_FOCUS_CASTBAR = "Focus Cast Bar",
    SIDEBAR_TAB_DRAGONRIDING = "Dragonriding",
    SIDEBAR_TAB_BUFF_MONITOR = "Buff Monitor",
    SIDEBAR_TAB_BUFF_TRACKER = "Buff Tracker",
    SIDEBAR_TAB_CONSUMABLES = "Consumables",
    SIDEBAR_TAB_STEALTH = "Stealth / Stance",
    SIDEBAR_TAB_RANGE_CHECK = "Range Check",
    SIDEBAR_TAB_TALENT_REMINDER = "Talent Reminder",
    SIDEBAR_TAB_EMOTE_DETECTION = "Emote Detection",
    SIDEBAR_TAB_EQUIPMENT_REMINDER = "Equipment Reminder",
    SIDEBAR_TAB_RAID_ALERTS = "Raid Alerts",
    SIDEBAR_TAB_OPTIMIZATIONS = "Optimizations",
    SIDEBAR_TAB_MISC = "Misc",
    SIDEBAR_TAB_PROFILES = "Profiles",
    SIDEBAR_TAB_SLASH_COMMANDS = "Slash Commands",

    ---------------------------------------------------------------------------
    -- BUFF MONITOR
    ---------------------------------------------------------------------------
    BUFFMONITOR_TITLE = "BUFF MONITOR",
    BUFFMONITOR_SUBTITLE = "Buff & aura tracking",
    BUFFMONITOR_ENABLE = "Enable Buff Monitor",
    BUFFMONITOR_NOTE = "Note:",
    BUFFMONITOR_DISCLAIMER = "The game hides buff data during active encounters. Trackers may not update mid-combat.",
    BUFFMONITOR_SECTION_RAIDBUFFS = "RAID BUFFS",
    BUFFMONITOR_RAIDBUFF_DESC = "Tracks missing raid buffs based on group composition. Alerts when buffs are absent.",
    BUFFMONITOR_ENABLE_RAIDBUFFS = "Enable Raid Buff Tracking",
    BUFFMONITOR_UNLOCK_RAIDBUFFS = "Unlock Raid Buffs",
    BUFFMONITOR_ONLY_SELFCAST = "Only Sound for Self-Castable",
    BUFFMONITOR_ONLY_SELFCAST_DESC = "Only play sound if you can cast the missing buff",
    BUFFMONITOR_RAIDBUFF_ICONSIZE = "Raid Buff Icon Size",
    BUFFMONITOR_LABEL_FONTSIZE = "Label Font Size",
    BUFFMONITOR_LABEL_COLOR = "Label Color",
    BUFFMONITOR_LABEL_OPACITY = "Label Opacity",
    BUFFMONITOR_SECTION_CUSTOM_DISPLAY = "CUSTOM TRACKER DISPLAY",
    BUFFMONITOR_CUSTOM_ICONSIZE = "Custom Tracker Icon Size",
    BUFFMONITOR_TIMER_FONTSIZE = "Timer Font Size",
    BUFFMONITOR_SECTION_CUSTOM = "CUSTOM BUFF TRACKERS",
    BUFFMONITOR_CUSTOM_DESC = "Aura groups to monitor. Exclusive = only 1 required.",
    BUFFMONITOR_POPUP_EDIT = "Edit Tracker",
    BUFFMONITOR_POPUP_NEW = "New Tracker",
    BUFFMONITOR_CLASS = "Class:",
    BUFFMONITOR_EXCLUSIVE = "Exclusive (only 1 required)",
    BUFFMONITOR_FILTER_DIFFICULTY = "Filter by Difficulty",
    BUFFMONITOR_ADD_TRACKER = "Add Tracker",
    BUFFMONITOR_NO_TRACKERS = "No trackers defined. Click Add Tracker below.",
    BUFFMONITOR_UNNAMED = "Unnamed Tracker",

    ---------------------------------------------------------------------------
    -- BUFF TRACKER
    ---------------------------------------------------------------------------
    BUFFTRACKER_TITLE = "BUFF TRACKER",
    BUFFTRACKER_SUBTITLE = "Track buffs, auras, stances",
    BUFFTRACKER_ENABLE = "Enable Buff Tracker",
    BUFFTRACKER_SECTION_TRACKING = "TRACKING",
    BUFFTRACKER_RAID_MODE = "Raid Mode",
    BUFFTRACKER_RAID_MODE_DESC = "Show ALL raid buffs instead of just yours",
    BUFFTRACKER_RAID_BUFFS = "Raid Buffs",
    BUFFTRACKER_PERSONAL_AURAS = "Personal Auras",
    BUFFTRACKER_STANCES = "Stances / Forms",
    BUFFTRACKER_SHOW_MISSING = "Show Missing Only",
    BUFFTRACKER_COMBAT_ONLY = "Show Only in Combat",
    BUFFTRACKER_SHOW_COOLDOWN = "Show Cooldown Spiral",
    BUFFTRACKER_SHOW_STACKS = "Show Stack Count",
    BUFFTRACKER_GROW_DIR = "Grow Direction",
    BUFFTRACKER_SPACING = "Spacing",
    BUFFTRACKER_ICONS_PER_ROW = "Icons Per Row",

    ---------------------------------------------------------------------------
    -- COMBAT ALERT
    ---------------------------------------------------------------------------
    COMBATALERT_TITLE = "COMBAT ALERT",
    COMBATALERT_SUBTITLE = "Combat notifications",
    COMBATALERT_ENABLE = "Enable Combat Alert",
    COMBATALERT_SECTION_ENTER = "ENTER COMBAT",
    COMBATALERT_SECTION_LEAVE = "LEAVE COMBAT",
    COMBATALERT_DISPLAY_TEXT = "Display Text",
    COMBATALERT_AUDIO_MODE = "Audio Mode",
    COMBATALERT_AUDIO_NONE = "None",
    COMBATALERT_AUDIO_SOUND = "Sound",
    COMBATALERT_AUDIO_TTS = "Text-to-Speech",
    COMBATALERT_DEFAULT_ENTER = "++ Combat",
    COMBATALERT_DEFAULT_LEAVE = "-- Combat",
    COMBATALERT_TTS_ENTER = "Combat",
    COMBATALERT_TTS_LEAVE = "Safe",

    ---------------------------------------------------------------------------
    -- COMBAT TIMER
    ---------------------------------------------------------------------------
    COMBATTIMER_TITLE = "COMBAT TIMER",
    COMBATTIMER_SUBTITLE = "Combat timer settings",
    COMBATTIMER_ENABLE = "Enable Combat Timer",
    COMBATTIMER_SECTION_OPTIONS = "OPTIONS",
    COMBATTIMER_INSTANCE_ONLY = "Instance Only",
    COMBATTIMER_CHAT_REPORT = "Chat Report",
    COMBATTIMER_STICKY = "Sticky Timer",
    COMBATTIMER_HIDE_PREFIX = "Hide Prefix",
    COMBATTIMER_COLOR = "Timer Color",
    COMBATTIMER_CHAT_MSG = "You were in combat for:",

    ---------------------------------------------------------------------------
    -- CONSUMABLE CHECKER
    ---------------------------------------------------------------------------
    CONSUMABLE_TITLE = "CONSUMABLE CHECKER",
    CONSUMABLE_SUBTITLE = "Track consumables",
    CONSUMABLE_NOTE = "Note:",
    CONSUMABLE_DISCLAIMER = "Shows when consumable buffs are missing or expiring inside instances.",
    CONSUMABLE_ENABLE = "Enable Consumable Checker",
    CONSUMABLE_CLICK_BLOCK = "Click icons to use consumables.",
    CONSUMABLE_TIMER_FONTSIZE = "Timer Font Size",
    CONSUMABLE_STACK_FONTSIZE = "Stack Font Size",
    CONSUMABLE_STACK_COLOR = "Stack Color",
    CONSUMABLE_STACK_ALPHA = "Stack Alpha",
    CONSUMABLE_SECTION_DIFFICULTY = "DIFFICULTY FILTERS",
    CONSUMABLE_DIFF_DESC = "Show consumable strip in these instance difficulties.",
    CONSUMABLE_SECTION_CATEGORIES = "CONSUMABLE CATEGORIES",
    CONSUMABLE_CAT_DESC = "Each category checks for any matching buff. Missing = none active.",
    CONSUMABLE_POPUP_EDIT = "Edit Category",
    CONSUMABLE_POPUP_NEW = "New Category",
    CONSUMABLE_WEAPON_ENCH = "Weapon Ench",
    CONSUMABLE_WEAPON_SLOT = "Weapon slot:",
    CONSUMABLE_MAIN_HAND = "Main Hand",
    CONSUMABLE_OFF_HAND = "Off Hand",
    CONSUMABLE_WEAPON_HINT = "Detects temporary enchant on Main Hand/Off Hand weapon.",
    CONSUMABLE_ICON_ID = "Icon ID:",
    CONSUMABLE_ITEM_ID = "Item ID (optional, for click-to-use):",
    CONSUMABLE_ITEM_HINT = "Leave empty to auto-detect from bags.",
    CONSUMABLE_TRACKED_ITEMS = "Tracked Items (for bag scanning):",
    CONSUMABLE_SCAN_BAGS = "Scan Bags",
    CONSUMABLE_SELECT_ITEM = "Select Item to Add",
    CONSUMABLE_EXPIRY_THRESHOLDS = "Expiry warning thresholds (minutes):",
    CONSUMABLE_ADD_CATEGORY = "Add Category",
    CONSUMABLE_NO_CATEGORIES = "No categories defined. Click Add Category below.",
    CONSUMABLE_UNNAMED = "Unnamed Category",
    CONSUMABLE_NO_BAGS = "No consumables found in bags.",
    CONSUMABLE_ALREADY_ADDED = "Item already in list.",

    ---------------------------------------------------------------------------
    -- DRAGONRIDING
    ---------------------------------------------------------------------------
    DRAGON_TITLE = "DRAGON RIDING",
    DRAGON_SUBTITLE = "Skyriding speed and vigor display",
    DRAGON_ENABLE = "Enable Dragonriding HUD",
    DRAGON_SECTION_LAYOUT = "LAYOUT",
    DRAGON_BAR_WIDTH = "Bar Width",
    DRAGON_SPEED_HEIGHT = "Speed Height",
    DRAGON_CHARGE_HEIGHT = "Charge Height",
    DRAGON_GAP = "Gap / Padding",
    DRAGON_SECTION_ANCHOR = "ANCHOR",
    DRAGON_ANCHOR_FRAME = "Anchor To Frame",
    DRAGON_ANCHOR_SELF = "Anchor Point (Self)",
    DRAGON_ANCHOR_TARGET = "Anchor Point (Target)",
    DRAGON_MATCH_WIDTH = "Match Anchor Width",
    DRAGON_MATCH_WIDTH_DESC = "Auto-size bar width to match anchor frame",
    DRAGON_OFFSET_X = "Offset X",
    DRAGON_OFFSET_Y = "Offset Y",
    DRAGON_BAR_STYLE = "Bar Style",
    DRAGON_SPEED_COLOR = "Speed Color",
    DRAGON_THRILL_COLOR = "Thrill Color",
    DRAGON_CHARGE_COLOR = "Charge Color",
    DRAGON_BG_COLOR = "Background Color",
    DRAGON_BG_OPACITY = "Background Opacity",
    DRAGON_BORDER_COLOR = "Border Color",
    DRAGON_BORDER_OPACITY = "Border Opacity",
    DRAGON_BORDER_SIZE = "Border Size",
    DRAGON_SPEED_FONT = "Speed Font",
    DRAGON_SHOW_SPEED = "Show Speed Text",
    DRAGON_SHOW_SPEED_DESC = "Display numeric speed on the speed bar",
    DRAGON_SWAP_BARS = "Swap Speed / Charges",
    DRAGON_SWAP_BARS_DESC = "Put charge bars above the speed bar",
    DRAGON_HIDE_GROUNDED = "Hide When Grounded + Full",
    DRAGON_HIDE_GROUNDED_DESC = "Hide the display when landed with full vigor",
    DRAGON_HIDE_COOLDOWN = "Hide Cooldown Manager While Mounted",
    DRAGON_HIDE_COOLDOWN_DESC = "Hide Blizzard cooldown viewers while skyriding",
    DRAGON_SECTION_FEATURES = "FEATURES",
    DRAGON_SECOND_WIND = "Second Wind",
    DRAGON_SECOND_WIND_DESC = "Show Second Wind charges as an underlay",
    DRAGON_WHIRLING_SURGE = "Whirling Surge",
    DRAGON_WHIRLING_SURGE_DESC = "Show Whirling Surge cooldown icon",
    DRAGON_SECTION_ICON = "ICON",
    DRAGON_ICON_SIZE = "Icon Size (0 = Auto)",
    DRAGON_ICON_ANCHOR = "Anchor",
    DRAGON_ICON_RIGHT = "Right",
    DRAGON_ICON_LEFT = "Left",
    DRAGON_ICON_TOP = "Top",
    DRAGON_ICON_BOTTOM = "Bottom",
    DRAGON_ICON_BORDER_COLOR = "Icon Border Color",
    DRAGON_ICON_BORDER_OPACITY = "Icon Border Opacity",
    DRAGON_ICON_BORDER_SIZE = "Icon Border Size",

    ---------------------------------------------------------------------------
    -- EMOTE DETECTION
    ---------------------------------------------------------------------------
    EMOTE_TITLE = "EMOTE DETECTION",
    EMOTE_SUBTITLE = "Detects feasts, cauldrons, and custom emotes",
    EMOTE_ENABLE = "Enable Emote Detection",
    EMOTE_SECTION_FILTER = "EMOTE FILTER",
    EMOTE_MATCH_PATTERN = "Match Pattern:",
    EMOTE_PATTERN_HINT = "Comma-separated patterns matched against emote text.",
    EMOTE_SECTION_AUTO = "AUTO EMOTE",
    EMOTE_AUTO_DESC = "Automatically send emotes when casting specific spells.",
    EMOTE_ENABLE_AUTO = "Enable Auto Emote",
    EMOTE_COOLDOWN = "Cooldown (seconds)",
    EMOTE_POPUP_EDIT = "Edit Auto Emote",
    EMOTE_POPUP_NEW = "New Auto Emote",
    EMOTE_TEXT = "Emote Text:",
    EMOTE_TEXT_HINT = "Text sent as /e (e.g. 'prepares soulwell')",
    EMOTE_ADD = "Add Auto Emote",
    EMOTE_NO_AUTO = "No auto emotes configured.",
    EMOTE_CLICK_BLOCK = "Click to block",
    EMOTE_ID = "ID:",

    ---------------------------------------------------------------------------
    -- FOCUS CAST BAR
    ---------------------------------------------------------------------------
    FOCUS_TITLE = "FOCUS CAST BAR",
    FOCUS_SUBTITLE = "Track interruptible casts from your focus target",
    FOCUS_ENABLE = "Enable Focus Cast Bar",
    FOCUS_BAR_COLOR = "Bar Color",
    FOCUS_BAR_READY = "Interrupt Ready",
    FOCUS_BAR_CD = "Interrupt CD",
    FOCUS_BACKGROUND = "Background",
    FOCUS_BG_OPACITY = "Background Opacity",
    FOCUS_SECTION_ICON = "ICON",
    FOCUS_SHOW_ICON = "Show Spell Icon",
    FOCUS_ICON_POS = "Icon Position",
    FOCUS_SECTION_TEXT = "TEXT",
    FOCUS_SHOW_NAME = "Show Spell Name",
    FOCUS_SHOW_TIME = "Show Time Remaining",
    FOCUS_SHOW_EMPOWER = "Show Empower Stage Markers",
    FOCUS_HIDE_FRIENDLY = "Hide Casts from Friendly Units",
    FOCUS_SECTION_NONINT = "NON-INTERRUPTIBLE DISPLAY",
    FOCUS_SHOW_SHIELD = "Show Shield Icon",
    FOCUS_CHANGE_COLOR = "Recolor Uninterruptible",
    FOCUS_NONINT_COLOR = "Non-Interruptible",
    FOCUS_SOUND_START = "Play Sound on Cast Start",
    FOCUS_USE_TTS = "Use Text-to-Speech (TTS)",
    FOCUS_TTS_DEFAULT = "Interrupt",

    ---------------------------------------------------------------------------
    -- GCD TRACKER
    ---------------------------------------------------------------------------
    GCD_TITLE = "GCD TRACKER",
    GCD_SUBTITLE = "Track your recent spell casts with scrolling icons",
    GCD_ENABLE = "Enable GCD Tracker",
    GCD_COMBAT_ONLY = "Combat Only",
    GCD_DURATION = "Duration (seconds)",
    GCD_SPACING = "Spacing",
    GCD_FADE_START = "Fade Start",
    GCD_SCROLL_DIR = "Scroll Direction",
    GCD_STACK_OVERLAPPING = "Stack Overlapping Casts",
    GCD_SECTION_TIMELINE = "TIMELINE",
    GCD_THICKNESS = "Thickness",
    GCD_TIMELINE_COLOR = "Timeline Color",
    GCD_SHOW_DOWNTIME = "Show Downtime Summary",
    GCD_SECTION_ZONE = "ZONE VISIBILITY",
    GCD_SHOW_DUNGEONS = "Show in Dungeons",
    GCD_SHOW_RAIDS = "Show in Raids",
    GCD_SHOW_ARENAS = "Show in Arenas",
    GCD_SHOW_BGS = "Show in Battlegrounds",
    GCD_SHOW_WORLD = "Show in World",
    GCD_SECTION_BLOCKLIST = "SPELL BLOCKLIST",
    GCD_BLOCKLIST_DESC = "Block specific spells from appearing (enter Spell ID)",
    GCD_SPELLID_PLACEHOLDER = "Spell ID...",
    GCD_RECENT_SPELLS = "Recent spells (click to block):",
    GCD_CAST_TO_POPULATE = "cast some abilities to populate",

    ---------------------------------------------------------------------------
    -- MODULES (QOL MISC)
    ---------------------------------------------------------------------------
    MODULES_TITLE = "QOL MISC",
    MODULES_SUBTITLE = "Miscellaneous features",
    MODULES_SECTION_LOOT = "ITEMS / LOOT",
    MODULES_FASTER_LOOT = "Faster Auto Loot",
    MODULES_FASTER_LOOT_DESC = "Instant auto-loot",
    MODULES_SUPPRESS_WARNINGS = "Suppress Loot Warnings",
    MODULES_SUPPRESS_WARNINGS_DESC = "Auto-confirm loot dialogs",
    MODULES_EASY_DESTROY = "Easy Item Destroy",
    MODULES_EASY_DESTROY_DESC = "Auto-fill DELETE text",
    MODULES_AUTO_KEYSTONE = "Auto Insert Keystone",
    MODULES_AUTO_KEYSTONE_DESC = "Auto-insert keystone",
    MODULES_AH_EXPANSION = "AH Current Expansion",
    MODULES_AH_EXPANSION_DESC = "Filter AH to current expansion",
    MODULES_SECTION_UI = "UI CLUTTER",
    MODULES_HIDE_ALERTS = "Hide Alerts",
    MODULES_HIDE_ALERTS_DESC = "Hide achievement popups",
    MODULES_HIDE_TALKING = "Hide Talking Head",
    MODULES_HIDE_TALKING_DESC = "Hide NPC talking heads",
    MODULES_HIDE_TOASTS = "Hide Event Toasts",
    MODULES_HIDE_TOASTS_DESC = "Hide level-up toasts",
    MODULES_HIDE_ZONE = "Hide Zone Text",
    MODULES_HIDE_ZONE_DESC = "Hide zone name overlays",
    MODULES_SKIP_QUEUE = "Skip Queue Confirmation",
    MODULES_SKIP_QUEUE_DESC = "Auto-confirm applications (Ctrl to skip)",
    MODULES_SECTION_DEATH = "DEATH / DURABILITY / REPAIR",
    MODULES_DONT_RELEASE = "Don't Release",
    MODULES_DONT_RELEASE_DESC = "Hold Alt 1s to release spirit",
    MODULES_DONT_RELEASE_TIMER = "Hold Alt %.1f",
    MODULES_AUTO_REPAIR = "Auto Repair",
    MODULES_AUTO_REPAIR_DESC = "Repair gear at merchants",
    MODULES_GUILD_FUNDS = "Use Guild Funds",
    MODULES_GUILD_FUNDS_DESC = "Use guild bank first",
    MODULES_DURABILITY = "Durability Warning",
    MODULES_DURABILITY_DESC = "Alert when durability low",
    MODULES_DURABILITY_THRESHOLD = "Warning Threshold",

    ---------------------------------------------------------------------------
    -- OPTIMIZATIONS
    ---------------------------------------------------------------------------
    OPT_TITLE = "SYSTEM OPTIMIZATIONS",
    OPT_SUBTITLE = "FPS optimization",
    OPT_SUCCESS = "Aggressive FPS optimizations applied successfully.",
    OPT_RELOAD_REQUIRED = "A UI Reload is required to apply all changes.",
    OPT_GFX_RESTART = "Graphics engine restarted successfully.",
    OPT_CONFLICT_WARNING = "A UI Reload is required to prevent conflicts.",
    OPT_SECTION_PRESETS = "PRESETS",
    OPT_OPTIMAL = "Optimal FPS Settings",
    OPT_ULTRA = "Ultra Settings",
    OPT_REVERT = "Revert Settings",
    OPT_SECTION_SQW = "SPELL QUEUE WINDOW",
    OPT_SQW_LABEL = "Spell Queue Window (ms)",
    OPT_SQW_RECOMMENDED = "Recommended Settings:",
    OPT_SQW_MELEE = "Melee: Ping + 100,",
    OPT_SQW_RANGED = "Ranged: Ping + 150",
    OPT_SECTION_DIAG = "DIAGNOSTICS",
    OPT_PROFILER = "Addon Profiler",
    OPT_SECTION_MONITOR = "REAL-TIME MONITOR",
    OPT_WARMING = "Warming up...",
    OPT_UNAVAILABLE = "Profiler unavailable",
    OPT_AVG_TICK = "Avg (60 tick):",
    OPT_LAST_TICK = "Last Tick:",
    OPT_PEAK = "Peak:",
    OPT_ENCOUNTER_AVG = "Encounter Avg:",

    ---------------------------------------------------------------------------
    -- RAID ALERTS
    ---------------------------------------------------------------------------
    RAIDALERTS_TITLE = "RAID ALERTS",
    RAIDALERTS_SUBTITLE = "Notifications for feasts, cauldrons, and utility casts",
    RAIDALERTS_ENABLE = "Enable Raid Alerts",
    RAIDALERTS_SECTION_FEASTS = "FEASTS",
    RAIDALERTS_ENABLE_FEASTS = "Enable FEASTS Alerts",
    RAIDALERTS_TRACKED = "Tracked Spells:",
    RAIDALERTS_ADD_SPELLID = "Add Spell ID:",
    RAIDALERTS_ERR_VALID = "Enter a valid spell ID",
    RAIDALERTS_ERR_BUILTIN = "Already a built-in spell",
    RAIDALERTS_ERR_ADDED = "Already added",
    RAIDALERTS_ERR_UNKNOWN = "Unknown spell ID",
    RAIDALERTS_SECTION_CAULDRONS = "CAULDRONS",
    RAIDALERTS_ENABLE_CAULDRONS = "Enable CAULDRONS Alerts",
    RAIDALERTS_SECTION_WARLOCK = "WARLOCK",
    RAIDALERTS_ENABLE_WARLOCK = "Enable WARLOCK Alerts",
    RAIDALERTS_SECTION_OTHER = "OTHER",
    RAIDALERTS_ENABLE_OTHER = "Enable OTHER Alerts",

    ---------------------------------------------------------------------------
    -- RANGE CHECK
    ---------------------------------------------------------------------------
    RANGE_TITLE = "RANGE CHECK",
    RANGE_SUBTITLE = "Target distance tracking",
    RANGE_ENABLE = "Enable Range Check",
    RANGE_COMBAT_ONLY = "Only Show In Combat",

    ---------------------------------------------------------------------------
    -- SLASH COMMANDS
    ---------------------------------------------------------------------------
    SLASH_TITLE = "SLASH COMMANDS",
    SLASH_SUBTITLE = "Create shortcuts to open frames",
    SLASH_ENABLE = "Enable Slash Commands Module",
    SLASH_NO_COMMANDS = "No commands yet. Click 'Add Command' to create one.",
    SLASH_ADD = "+ Add Command",
    SLASH_RESTORE = "Restore Defaults",
    SLASH_PREFIX_RUNS = "Runs:",
    SLASH_PREFIX_OPENS = "Opens:",
    SLASH_DEL = "Del",
    SLASH_POPUP_ADD = "Add Slash Command",
    SLASH_CMD_NAME = "Command Name:",
    SLASH_CMD_HINT = "(e.g. 'r' for /r)",
    SLASH_ACTION_TYPE = "Action Type:",
    SLASH_FRAME_TOGGLE = "Frame Toggle",
    SLASH_COMMAND = "Slash Command",
    SLASH_SEARCH_FRAMES = "Search Frames:",
    SLASH_CMD_RUN = "Command to Run:",
    SLASH_CMD_RUN_HINT = "e.g. /reload, /script print('hi'), /invite Playername",
    SLASH_ARGS_NOTE = "Arguments passed to your alias are appended automatically.",
    SLASH_FRAME_WARN = "Not all frames may work or be useful, some may throw Lua errors",
    SLASH_POPUP_TEST = "Frame Test",
    SLASH_TEST_WORKS = "Works",
    SLASH_TEST_USELESS = "Useless",
    SLASH_TEST_ERROR = "Lua Error",
    SLASH_TEST_SILENT = "Silent Fail",
    SLASH_TEST_SKIP = "Skip",
    SLASH_TEST_STOP = "Stop",
    SLASH_ERR_NAME = "Please enter a command name.",
    SLASH_ERR_INVALID = "Command name can only contain letters, numbers, and underscores.",
    SLASH_ERR_FRAME = "Please select a frame.",
    SLASH_ERR_CMD = "Please enter a command to run.",
    SLASH_ERR_EXISTS = "A command with that name already exists.",
    SLASH_WARN_CONFLICT = "already exists from another addon. Skipping.",
    SLASH_ERR_COMBAT = "Cannot toggle frames during combat.",

    ---------------------------------------------------------------------------
    -- STEALTH REMINDER
    ---------------------------------------------------------------------------
    STEALTH_TITLE = "STEALTH / STANCE",
    STEALTH_SUBTITLE = "Stealth and stance form reminders",
    STEALTH_ENABLE = "Enable Stealth Reminder",
    STEALTH_SECTION_STEALTH = "STEALTH SETTINGS",
    STEALTH_SHOW_STEALTHED = "Show Stealthed Notice",
    STEALTH_SHOW_NOT = "Show Not Stealthed Notice",
    STEALTH_DISABLE_RESTED = "Disable in Rested Areas",
    STEALTH_COLOR_STEALTHED = "Stealthed",
    STEALTH_COLOR_NOT = "Not Stealthed",
    STEALTH_TEXT = "Stealth Text:",
    STEALTH_DEFAULT = "STEALTH",
    STEALTH_WARNING_TEXT = "Warning Text:",
    STEALTH_WARNING_DEFAULT = "RESTEALTH",
    STEALTH_DRUID_NOTE = "Druid Options (Feral always enabled):",
    STEALTH_BALANCE = "Balance",
    STEALTH_GUARDIAN = "Guardian",
    STEALTH_RESTORATION = "Restoration",
    STEALTH_ENABLE_STANCE = "Enable Stance Check",
    STEALTH_SECTION_STANCE = "STANCE ALERTS",
    STEALTH_WRONG_COLOR = "Wrong Stance",
    STEALTH_STANCE_DEFAULT = "CHECK STANCE",
    STEALTH_ENABLE_SOUND = "Enable Sound Alert",
    STEALTH_REPEAT = "Repeat Interval (sec)",

    ---------------------------------------------------------------------------
    -- STATIC POPUPS
    ---------------------------------------------------------------------------
    POPUP_CHANGES_APPLIED = "Changes applied.",
    POPUP_RELOAD_WARNING = "Reload UI to apply.",
    POPUP_SETTINGS_IMPORTED = "Settings imported.",
    POPUP_PROFILER_ENABLE = "Reload required to enable profiling.",
    POPUP_PROFILER_OVERHEAD = "Profiling adds CPU overhead.",
    POPUP_PROFILER_DISABLE = "Reload required to disable profiling.",
    POPUP_PROFILER_RECOMMEND = "Recommended to reduce CPU overhead.",
    POPUP_BUFFTRACKER_RESET = "Reset Buff Tracker to defaults?",

    ---------------------------------------------------------------------------
    -- COMBAT LOGGER DISPLAY
    ---------------------------------------------------------------------------
    COMBATLOGGER_ENABLED = "Combat logging enabled for %s (%s).",
    COMBATLOGGER_DISABLED = "Combat logging disabled for %s (%s).",
    COMBATLOGGER_STOPPED = "Combat logging stopped (left instance).",
    COMBATLOGGER_POPUP = "Enable combat logging for:\n%s\n(%s)\n\nYour choice will be remembered.",
    COMBATLOGGER_ENABLE_BTN = "Enable Logging",
    COMBATLOGGER_SKIP_BTN = "Skip",

    ---------------------------------------------------------------------------
    -- TALENT REMINDER
    ---------------------------------------------------------------------------
    TALENT_COMBAT_ERROR = "Cannot swap talents in combat",
    TALENT_SWAPPED = "Swapped to %s",
    TALENT_NOT_FOUND = "Saved loadout not found - it may have been deleted",
    TALENT_SAVE_POPUP = "Save current talents for:\n%s\n(%s)\n(%s)\n\nCurrent: %s",
    TALENT_MISMATCH_POPUP = "Talent mismatch for:\n%s\n\nCurrent: %s\nSaved: %s",
    TALENT_SAVED = "Talent saved for %s",
    TALENT_OVERWRITTEN = "Talents overwritten for %s",
    TALENT_SAVE_BTN = "Save",
    TALENT_SWAP_BTN = "Swap",
    TALENT_OVERWRITE_BTN = "Overwrite",
    TALENT_IGNORE_BTN = "Ignore",

    ---------------------------------------------------------------------------
    -- DURABILITY DISPLAY
    ---------------------------------------------------------------------------
    DURABILITY_WARNING = "Low Durability: %d%%",

    ---------------------------------------------------------------------------
    -- GCD TRACKER DISPLAY
    ---------------------------------------------------------------------------
    GCD_DOWNTIME_MSG = "Downtime: %.1fs (%.1f%%)",

    ---------------------------------------------------------------------------
    -- CROSSHAIR DISPLAY
    ---------------------------------------------------------------------------
    CROSSHAIR_MELEE_UNSUPPORTED = "Melee range indicator not supported for ranged classes",

    ---------------------------------------------------------------------------
    -- FOCUS CAST BAR DISPLAY
    ---------------------------------------------------------------------------
    FOCUS_PREVIEW_CAST = "Preview Cast",
    FOCUS_PREVIEW_TIME = "1.5",

    ---------------------------------------------------------------------------
    -- MOUSE RING
    ---------------------------------------------------------------------------
    MOUSE_TITLE = "MOUSE RING",
    MOUSE_SUBTITLE = "Customize your cursor ring & trail",
    MOUSE_ENABLE = "Enable Mouse Ring",
    MOUSE_VISIBLE_OOC = "Visible Outside Combat",
    MOUSE_HIDE_ON_CLICK = "Hide on RMB",
    MOUSE_SECTION_APPEARANCE = "APPEARANCE",
    MOUSE_SHAPE = "Ring Shape",
    MOUSE_SHAPE_CIRCLE = "Circle",
    MOUSE_SHAPE_THIN = "Thin Circle",
    MOUSE_SHAPE_THICK = "Thick Circle",
    MOUSE_COLOR_BACKGROUND = "Background Color",
    MOUSE_SIZE = "Ring Size",
    MOUSE_OPACITY_COMBAT = "Combat Opacity",
    MOUSE_OPACITY_OOC = "OOC Opacity",
    MOUSE_SECTION_GCD = "GCD SWIPE",
    MOUSE_GCD_ENABLE = "Enable GCD Swipe",
    MOUSE_HIDE_BACKGROUND = "Hide Background Ring (GCD Only Mode)",
    MOUSE_COLOR_SWIPE = "Swipe Color",
    MOUSE_COLOR_READY = "Ready Color",
    MOUSE_GCD_READY_MATCH = "Same as Swipe",
    MOUSE_OPACITY_SWIPE = "Swipe Opacity",
    MOUSE_CAST_SWIPE_ENABLE = "Cast Progress Swipe",
    MOUSE_COLOR_CAST_SWIPE = "Cast Swipe Color",
    MOUSE_SECTION_TRAIL = "MOUSE TRAIL",
    MOUSE_TRAIL_ENABLE = "Enable Mouse Trail",
    MOUSE_TRAIL_DURATION = "Trail Duration",
    MOUSE_TRAIL_COLOR = "Color",

    ---------------------------------------------------------------------------
    -- CROSSHAIR
    ---------------------------------------------------------------------------
    CROSSHAIR_TITLE = "CROSSHAIR",
    CROSSHAIR_SUBTITLE = "Screen-center crosshair overlay",
    CROSSHAIR_ENABLE = "Enable Crosshair",
    CROSSHAIR_COMBAT_ONLY = "Combat Only",
    CROSSHAIR_HIDE_MOUNTED = "Hide While Mounted",
    CROSSHAIR_SECTION_SHAPE = "SHAPE PRESETS",
    CROSSHAIR_PRESET_CROSS = "Cross",
    CROSSHAIR_PRESET_DOT = "Dot Only",
    CROSSHAIR_PRESET_CIRCLE = "Circle + Cross",
    CROSSHAIR_ARM_TOP = "Top",
    CROSSHAIR_ARM_RIGHT = "Right",
    CROSSHAIR_ARM_BOTTOM = "Bottom",
    CROSSHAIR_ARM_LEFT = "Left",
    CROSSHAIR_SECTION_DIMENSIONS = "DIMENSIONS",
    CROSSHAIR_ROTATION = "Rotation",
    CROSSHAIR_ARM_LENGTH = "Arm Length",
    CROSSHAIR_THICKNESS = "Thickness",
    CROSSHAIR_CENTER_GAP = "Center Gap",
    CROSSHAIR_DOT_SIZE = "Dot Size",
    CROSSHAIR_CENTER_DOT = "Center Dot",
    CROSSHAIR_SECTION_APPEARANCE = "APPEARANCE",
    CROSSHAIR_COLOR_PRIMARY = "Primary Color",
    CROSSHAIR_OPACITY = "Opacity",
    CROSSHAIR_DUAL_COLOR = "Dual Color Mode",
    CROSSHAIR_DUAL_COLOR_DESC = "Different colors for top/bottom vs left/right",
    CROSSHAIR_COLOR_SECONDARY = "Secondary Color",
    CROSSHAIR_BORDER_ALWAYS = "Add Border Always",
    CROSSHAIR_BORDER_THICKNESS = "Border Thickness",
    CROSSHAIR_COLOR_BORDER = "Border Color",
    CROSSHAIR_SECTION_CIRCLE = "CIRCLE",
    CROSSHAIR_CIRCLE_ENABLE = "Enable Circle Ring",
    CROSSHAIR_COLOR_CIRCLE = "Circle Color",
    CROSSHAIR_CIRCLE_SIZE = "Circle Size",
    CROSSHAIR_SECTION_POSITION = "POSITION",
    CROSSHAIR_OFFSET_X = "X Offset",
    CROSSHAIR_OFFSET_Y = "Y Offset",
    CROSSHAIR_RESET_POSITION = "Reset Position",
    CROSSHAIR_SECTION_DETECTION = "DETECTION",
    CROSSHAIR_MELEE_ENABLE = "Enable Melee Range Indicator",
    CROSSHAIR_RECOLOR_BORDER = "Recolor Border",
    CROSSHAIR_RECOLOR_ARMS = "Recolor Arms",
    CROSSHAIR_RECOLOR_DOT = "Recolor Dot",
    CROSSHAIR_RECOLOR_CIRCLE = "Recolor Circle",
    CROSSHAIR_COLOR_OUT_OF_RANGE = "Out of Range Color",
    CROSSHAIR_SOUND_ENABLE = "Enable Sound Alert",
    CROSSHAIR_SOUND_INTERVAL = "Repeat Interval (sec)",
    CROSSHAIR_SPELL_ID = "Range Check Spell ID",
    CROSSHAIR_SPELL_CURRENT = "Current: %s",
    CROSSHAIR_SPELL_UNSUPPORTED = "Not supported for this spec",
    CROSSHAIR_SPELL_NONE = "No spell configured",
    CROSSHAIR_RESET_SPELL = "Reset to Default",

    ---------------------------------------------------------------------------
    -- CORE
    ---------------------------------------------------------------------------
    CORE_LOADED = "Loaded. Type |cff00ff00/nao|r to open settings.",
    CORE_MISSING_KEY = "Missing localization key:",
})
