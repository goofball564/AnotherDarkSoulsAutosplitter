/* 
Dark Souls 1 and Remastered Autosplitter But This Time In ASL Script Form
Version 0.3.1

Update History:
    Version 0.4:
        - Added Exit Boss Arena splits
        - Fixed typos in ParseZoneTransition
        - Moved split trigger data to separate text files
    Version 0.3:
        - Added option for "retroactive" upwarp splitting; if upwarp is 
        detected, split time is set to what the time was during the loading
        screen, not the current time
        - Fixed In-Game Time offsets for PTDE
        - Double checked that the rest of the offsets looked good with my eyeballs
        - Tweak Darkroot Basin elevator upwarp bounding box
    Version 0.2:
        - Performance optimization for event flags
        - Fixed ClearCount offsets for PTDE
    Version 0.1:
        - First public version

TODO
- more splits
- performance optimizations if necessary
- actually testing and supporting NG+
- support for non-current-patch versions of DSR
- option to recheck a split trigger in NG+?
- option to ignore a split trigger in NG?
*/

state("DARKSOULS") {}

state("DarkSoulsRemastered") {}

startup
{
    // ---------- USER CONFIGURABLE SECTION ----------

    // Set lower to improve performance; setting too low may break script, 
    // because the window for detecting loading screens is short;
    // lowering comes at the theoretical cost of less precise split times.
    refreshRate = 60;

    // true: Mousing over split trigger settings shows information about them,
    // e.g., event flag ID, bonfire ID, coordinates of bounding box.
    // false: Disable these tooltips.
    vars.DebugToolTips = true;

    // ---------- END OF USER CONFIGURABLE SECTION ----------

    //  Stopwatch used in Init block.
    vars.CooldownStopwatch = new Stopwatch();

    // ---------- CONSTANTS ----------
    // Can't actually be consts if needed in other blocks.

    vars.IMMEDIATE_SPLIT_TYPE = Tuple.Create("imm", "Split Immediately");
    vars.QUITOUT_SPLIT_TYPE = Tuple.Create("quit", "Split On Next Quitout");
    vars.NON_QUITOUT_SPLIT_TYPE = Tuple.Create("nonquit", "Split On Next Non-Quitout Load Screen");

    vars.NG_ID = "ng";
    vars.NG_PLUS_ID = "ng+";

    vars.RETROACTIVE = "retroactive";

    vars.EVENT_FLAG_ID_LENGTH = 8;

    const string scriptFileName = "DarkSouls1.asl";
    const string splitTriggersFolderName = "DarkSoulsSplitTriggers";

    const string eventFlagFileName = "EventFlag.txt";
    const string bonfireLitFileName = "Bonfire.txt";
    const string currentPositionFileName = "CurrentPosition.txt";
    const string upwarpFileName = "Upwarp.txt";
    const string initialPositionFileName = "InitialPosition.txt";
    const string zoneTransitionFileName = "ZoneTransition.txt";
    const string bossArenaExitFileName = "BossArenaExit.txt";

    // ---------- GET PATH OF THIS SCRIPT ----------

    string scriptPath = "";

    // This method is extremely hacky; the working directory when the code is
    // executing is LiveSplit's directory. Get the directory of the script by
    // iterating through the Layout Components, find the component that loads
    // this script, and get the path from the component's settings.
    // Also, LiveSplit.UI.Components.ASLComponent doesn't seem to be in the
    // namespace accessible from ASL Scripts, so we can't check if an object is
    // that type directly and instead use a string comparison.
    var doc = new System.Xml.XmlDocument();
    foreach(LiveSplit.UI.Components.ILayoutComponent ilc in timer.Layout.LayoutComponents)
    {
        LiveSplit.UI.Components.IComponent component = ilc.Component;
        if (component.GetType().ToString() == "LiveSplit.UI.Components.ASLComponent")
        {
            System.Xml.XmlNode componentSettings = component.GetSettings(doc);
            string path = componentSettings["ScriptPath"].FirstChild.Value;
            if (path.EndsWith(scriptFileName))
            {
                scriptPath = path;
                break;
            }
        }
    }

    string scriptDirectory = Directory.GetParent(scriptPath).ToString();
    string splitTriggersDirectory = Path.Combine(scriptDirectory, splitTriggersFolderName);
    Directory.CreateDirectory(splitTriggersDirectory);

    // ---------- SPLIT TRIGGER INFO VARS ----------

    vars.EventFlags = new ExpandoObject();
    vars.EventFlags.SettingsIds = new List<string>();
    vars.EventFlags.Offsets = new Dictionary<string, int>();
    vars.EventFlags.Masks = new Dictionary<string, uint>();

    vars.EventFlagOffsets = new ExpandoObject();
    vars.EventFlagOffsets.MemoryWatchers = new Dictionary<int, MemoryWatcher<uint>>();

    vars.Bonfires = new ExpandoObject();
    vars.Bonfires.SettingsIds = new List<string>();

    vars.CurrentPositionBoundingBoxes = new ExpandoObject();
    vars.CurrentPositionBoundingBoxes.SettingsIds = new List<string>();
    vars.CurrentPositionBoundingBoxes.Coords = new Dictionary<string, Tuple<float, float, float, float, float, float>>();

    vars.UpwarpBoundingBoxes = new ExpandoObject();
    vars.UpwarpBoundingBoxes.SettingsIds = new List<string>();
    vars.UpwarpBoundingBoxes.Coords = new Dictionary<string, Tuple<float, float, float, float, float, float>>();

    vars.InitialPositionBoundingBoxes = new ExpandoObject();
    vars.InitialPositionBoundingBoxes.SettingsIds = new List<string>();
    vars.InitialPositionBoundingBoxes.Coords = new Dictionary<string, Tuple<float, float, float, float, float, float>>();
    
    vars.ZoneTransitions = new ExpandoObject();
    vars.ZoneTransitions.SettingsIds = new List<string>();
    vars.ZoneTransitions.Tuples = new Dictionary<string, Tuple<int, int, int, int>>();

    vars.BossArenaExits = new ExpandoObject();
    vars.BossArenaExits.SettingsIds = new List<string>();
    vars.BossArenaExits.Tuples = new Dictionary<string, Tuple<int, int>>();

    // ---------- SPLIT LOGIC VARS ----------

    // Dictionary of bools that are initialized false and set true if a 
    // specific split has been triggered; used to avoid double splits.
    vars.SplitTriggered = new Dictionary<string, bool>();

    vars.ResetSplitLogic = (Action) (() => 
    {
        foreach(string id in vars.EventFlags.SettingsIds)
        {
            vars.SplitTriggered[id] = false;
        }

        foreach(string id in vars.Bonfires.SettingsIds)
        {
            vars.SplitTriggered[id] = false;
        }

        foreach(string id in vars.CurrentPositionBoundingBoxes.SettingsIds)
        {
            vars.SplitTriggered[id] = false;
        }

        foreach(string id in vars.UpwarpBoundingBoxes.SettingsIds)
        {
            vars.SplitTriggered[id] = false;
        }

        foreach(string id in vars.InitialPositionBoundingBoxes.SettingsIds)
        {
            vars.SplitTriggered[id] = false;
        }

        foreach(string id in vars.ZoneTransitions.SettingsIds)
        {
            vars.SplitTriggered[id] = false;
        }

        foreach(string id in vars.BossArenaExits.SettingsIds)
        {
            vars.SplitTriggered[id] = false;
        }

        vars.LoadingSplitTriggered = false;
        vars.QuitoutSplitTriggered = false;
        vars.NonQuitoutLoadingSplitTriggered = false;
        vars.RetroactiveSplitTriggered = false;
        
        vars.NGSplitTriggered = false;

        vars.CheckInitPosition = false;
        vars.CheckUpwarp = false;

        vars.CheckLoadInInGameTime = false;
        vars.LoadInInGameTime = 0;
        vars.LoadInTimerTime = new Time();

        vars.QuitoutDetected = false;
    });

    // ---------- BOUNDING BOX FUNCTIONS ----------

    vars.WithinBoundingBox = (Func<Tuple<float, float, float>, Tuple<float, float, float, float, float, float>, bool>) ((coords, boundingCoords) =>
    {
        float x = coords.Item1;
        float y = coords.Item2;
        float z = coords.Item3;

        float minX = boundingCoords.Item1;
        float maxX = boundingCoords.Item2;
        float minY = boundingCoords.Item3;
        float maxY = boundingCoords.Item4;
        float minZ = boundingCoords.Item5;
        float maxZ = boundingCoords.Item6;

        return x >= minX && x <= maxX && y >= minY && y <= maxY && z >= minZ && z <= maxZ;  
    });

    vars.PrettyFormattedBoundingBoxString = (Func<Tuple<float, float, float, float, float, float>, string>) ((boundingCoords) =>
    {
        return "X Min: " + boundingCoords.Item1 + ", X Max: " + boundingCoords.Item2 + ", Y Min: " + boundingCoords.Item3 + ", Y Max: " + boundingCoords.Item4 + ", Z Min: " + boundingCoords.Item5 + ", Z Max: " + boundingCoords.Item6;
    });

    vars.SimpleFormattedBoundingBoxString = (Func<Tuple<float, float, float, float, float, float>, string>) ((boundingCoords) =>
    {
        return "" + boundingCoords.Item1 + "," + boundingCoords.Item2 + "," + boundingCoords.Item3 + "," + boundingCoords.Item4 + "," + boundingCoords.Item5 + "," + boundingCoords.Item6;
    });

    vars.ParseBoundingBox = (Func<string, Tuple<float, float, float, float, float, float>>) ((coordsString) =>
    {
        const int BOUNDING_BOX_TUPLE_LENGTH = 6;

        string[] coordsSplit = coordsString.Split(',');
        float[] coords = new float[BOUNDING_BOX_TUPLE_LENGTH];
        if (coordsSplit.Length != BOUNDING_BOX_TUPLE_LENGTH)
        {
            throw new ArgumentException("Bounding box must have 6 values: x min, x max, y min, y max, z min, z max: " + coordsString);
        }

        for(int i = 0; i < BOUNDING_BOX_TUPLE_LENGTH; i++)
        {
            coords[i] = Single.Parse(coordsSplit[i].Trim());
        }

        return Tuple.Create(coords[0], coords[1], coords[2], coords[3], coords[4], coords[5]);
    });

    // ---------- BONFIRE FUNCTIONS ----------

    vars.BonfireIdIsValid = (Func<string, bool>) ((bonfireId) =>
    {
        const int BONFIRE_ID_LENGTH = 7;

        int idInt;
        if (bonfireId.Length != BONFIRE_ID_LENGTH || !Int32.TryParse(bonfireId, out idInt))
            return false;
        return true;        
    });

    // ---------- EVENT FLAG FUNCTIONS ----------

    vars.EventFlagGroups = new Dictionary<string, int>()
    {
        {"0", 0x00000},
        {"1", 0x00500},
        {"5", 0x05F00},
        {"6", 0x0B900},
        {"7", 0x11300},
    };

    vars.EventFlagAreas = new Dictionary<string, int>()
    {
        {"000", 00},
        {"100", 01},
        {"101", 02},
        {"102", 03},
        {"110", 04},
        {"120", 05},
        {"121", 06},
        {"130", 07},
        {"131", 08},
        {"132", 09},
        {"140", 10},
        {"141", 11},
        {"150", 12},
        {"151", 13},
        {"160", 14},
        {"170", 15},
        {"180", 16},
        {"181", 17},
    };

    vars.EventFlagIsValid = (Func<string, bool>) ((id) =>
    {
        id = id.PadLeft(vars.EVENT_FLAG_ID_LENGTH, '0');

        int i;
        string group = id.Substring(0, 1);
        string area = id.Substring(1, 3);

        if (id.Length != vars.EVENT_FLAG_ID_LENGTH || !Int32.TryParse(id, out i))
            return false;
        if (!vars.EventFlagGroups.ContainsKey(group) || !vars.EventFlagAreas.ContainsKey(area))
            return false;

        return true;
    });

    vars.GetEventFlagOffsetAndMask = (Func<string, Tuple<int, uint>>) ((id) =>
    {
        id = id.PadLeft(vars.EVENT_FLAG_ID_LENGTH, '0');

        if (!vars.EventFlagIsValid(id))
        {
            throw new ArgumentException("Invalid event flag ID: " + id);
        }

        string group = id.Substring(0, 1);
        string area = id.Substring(1, 3);
        int section = Int32.Parse(id.Substring(4, 1));
        int number = Int32.Parse(id.Substring(5, 3));

        int offset = vars.EventFlagGroups[group];
        offset += vars.EventFlagAreas[area] * 0x500;
        offset += section * 128;
        offset += (number - (number % 32)) / 8;

        uint mask = 0x80000000 >> (number % 32);

        return Tuple.Create(offset, mask);
    });

    // ---------- ZONE TRANSITION FUNCTIONS ----------

    vars.ZoneTransitionTupleToId = (Func<Tuple<int, int, int, int>, string>) ((zoneTransitionTuple) =>
    {
        return "" + zoneTransitionTuple.Item1 + "," + zoneTransitionTuple.Item2 + "," + zoneTransitionTuple.Item3 + "," + zoneTransitionTuple.Item4; 
    });

    vars.ZoneTransitionTupleToToolTip = (Func<Tuple<int, int, int, int>, string>) ((zoneTransitionTuple) =>
    {
        return "Old Area: " + zoneTransitionTuple.Item1 + ", Old World: " + zoneTransitionTuple.Item2 + ", New Area: " + zoneTransitionTuple.Item3 + ", New World: " + zoneTransitionTuple.Item4; 
    });

    vars.ParseZoneTransition = (Func<string, Tuple<int, int, int, int>>) ((zoneTransitionString) =>
    {
        const int ZONE_TRANSITION_TUPLE_LENGTH = 4;

        string[] zoneTransitionSplit = zoneTransitionString.Split(',');
        var zoneTransition = new int[ZONE_TRANSITION_TUPLE_LENGTH];
        if (zoneTransitionSplit.Length != ZONE_TRANSITION_TUPLE_LENGTH)
        {
            throw new ArgumentException("Zone Transition must have 4 values: old area, old world, new area, new world: " + zoneTransitionString);
        }

        for(int i = 0; i < ZONE_TRANSITION_TUPLE_LENGTH; i++)
        {
            zoneTransition[i] = Int32.Parse(zoneTransitionSplit[i].Trim());
        }

        return Tuple.Create(zoneTransition[0], zoneTransition[1], zoneTransition[2], zoneTransition[3]);
    });

    // ---------- BOSS ARENA FUNCTIONS ----------

    vars.BossArenaExitTupleToToolTip = (Func<Tuple<int, int>, string>) ((bossArenaExitTuple) =>
    {
        return "Boss Death Flag: " + bossArenaExitTuple.Item1 + ", Boss Arena Region ID: " + bossArenaExitTuple.Item2;
    });

    vars.BossArenaExitTupleToId = (Func<Tuple<int, int>, string>) ((bossArenaExitTuple) =>
    {
        return "" + bossArenaExitTuple.Item1 + "," + bossArenaExitTuple.Item2;
    });

    vars.ParseBossArenaExit = (Func<string, Tuple<int, int>>) ((bossArenaExitString) =>
    {
        const int BOSS_ARENA_EXIT_TUPLE_LENGTH = 2;

        string[] bossArenaExitSplit = bossArenaExitString.Split(',');
        var bossArenaExit = new int[BOSS_ARENA_EXIT_TUPLE_LENGTH];
        if (bossArenaExitSplit.Length != BOSS_ARENA_EXIT_TUPLE_LENGTH)
        {
            throw new ArgumentException("Boss Arena must have 2 values: boss death flag, boss arena region ID: " + bossArenaExitString);
        }

        for(int i = 0; i < BOSS_ARENA_EXIT_TUPLE_LENGTH; i++)
        {
            bossArenaExit[i] = Int32.Parse(bossArenaExitSplit[i].Trim());
        }

        return Tuple.Create(bossArenaExit[0], bossArenaExit[1]);
    });

    // ---------- SETTINGS ACTIONS ----------

    vars.ParentSettingsAdded = new Dictionary<string, bool>();

    vars.CreateSplitTriggerSetting = (Action<string, string, string>) ((id, description, parent) =>
    {
        if (parent != "" && !vars.ParentSettingsAdded.ContainsKey(parent))
        {
            settings.Add(parent, true);
            vars.ParentSettingsAdded[parent] = true;
        }

        if (parent != "")
            settings.Add(id, false, description, parent);
        else
            settings.Add(id, false, description);
    });

    vars.CreateSplitTypeSettings = (Action<string, List<Tuple<string, string>>>) ((splitTriggerId, splitTypes) =>
    {
        foreach (Tuple<string, string> splitType in splitTypes)
        {
            var splitTypeId = splitType.Item1;
            var splitTypeDescription = splitType.Item2;

            string concatenatedId = splitTriggerId + splitTypeId;
            settings.Add(concatenatedId, false, splitTypeDescription, splitTriggerId);
        }
    });

    // ---------- TEXT PARSING FUNCTION ----------

    vars.ParseSplitTriggerData = (Func<string, List<string[]>>) ((splitTriggerData) =>
    {
        var parsedDataList = new List<string[]>();
        string currentCategory = "";

        var reader = new StringReader(splitTriggerData);
        for (string line = reader.ReadLine(); line != null; line = reader.ReadLine())
        {
            line = line.Trim();
            if (line != "") // skip empty lines
            {
                if (line.Contains("|"))
                {
                    // line is split trigger data
                    string[] splitLine = line.Split('|');
                    string splitTriggerId = splitLine[0].Trim();
                    string splitTriggerDescription = splitLine[1].Trim();

                    if (splitTriggerId == "")
                    {
                        throw new ArgumentException("Data contains incorrectly formatted line (no split trigger data before | separator): \n" + line);
                    }
                    if (splitTriggerDescription == "")
                    {
                        throw new ArgumentException("Data contains incorrectly formatted line (no split trigger description after | separator): \n" + line);
                    }

                    var arr = new string[] {splitTriggerId, splitTriggerDescription, currentCategory};
                    parsedDataList.Add(arr);
                }
                else
                {
                    // line is category
                    currentCategory = line;
                }
            }
        }

        return parsedDataList;
    });

    // ---------- CREATE SETTINGS ----------

    var allSplitTypes = new List<Tuple<string, string>>
    {
        vars.IMMEDIATE_SPLIT_TYPE,
        vars.QUITOUT_SPLIT_TYPE,
        vars.NON_QUITOUT_SPLIT_TYPE,
    };

    const string EVENT_FLAGS = "Event Flags";
    const string BONFIRES_LIT = "Bonfires Lit";
    const string BOUNDING_BOX = "Bounding Box";
    const string CURRENT_POSITION = "Current Position";
    const string UPWARP = "Upwarps";
    const string LOAD_IN = "Location On Load In";
    const string ZONE_TRANSITION = "Zone Transitions";
    const string BOSS_ARENA = "Exit Boss Arena";

    settings.Add(vars.RETROACTIVE, false, "Retroactive Upwarp Splits");
    settings.SetToolTip(vars.RETROACTIVE, "See Readme for Explanation");

    settings.Add(vars.NG_ID, false, "NG Completion");
    settings.Add(vars.NG_PLUS_ID, false, "NG+ and Later Completion");

    settings.Add(EVENT_FLAGS, true);
    settings.Add(BONFIRES_LIT, true);
    settings.Add(BOUNDING_BOX, true);
    settings.Add(CURRENT_POSITION, true, CURRENT_POSITION, BOUNDING_BOX);
    settings.Add(UPWARP, true, UPWARP, BOUNDING_BOX);
    settings.Add(LOAD_IN, true, LOAD_IN, BOUNDING_BOX);
    settings.Add(ZONE_TRANSITION, true);
    settings.Add(BOSS_ARENA, true);

    string eventFlagData = File.ReadAllText(Path.Combine(splitTriggersDirectory, eventFlagFileName));
    List<string[]> eventFlagSettings = vars.ParseSplitTriggerData(eventFlagData);

    settings.CurrentDefaultParent = EVENT_FLAGS;
    foreach (string[] eventFlagSetting in eventFlagSettings)
    {
        string id = eventFlagSetting[0];
        string description = eventFlagSetting[1];
        string parent = eventFlagSetting[2];

        id = id.PadLeft(vars.EVENT_FLAG_ID_LENGTH, '0');

        if (!vars.EventFlagIsValid(id))
            throw new ArgumentException("Invalid event flag ID: " + id);

        vars.EventFlags.SettingsIds.Add(id);

        vars.CreateSplitTriggerSetting(id, description, parent);
        vars.CreateSplitTypeSettings(id, allSplitTypes);

        if (vars.DebugToolTips)
        {
            string toolTip = "Event Flag ID: " + id;
            settings.SetToolTip(id, toolTip);
        }
    }

    string bonfireLitData = File.ReadAllText(Path.Combine(splitTriggersDirectory, bonfireLitFileName));
    List<string[]> bonfireLitSettings = vars.ParseSplitTriggerData(bonfireLitData);

    settings.CurrentDefaultParent = BONFIRES_LIT;
    foreach (string[] bonfireLitSetting in bonfireLitSettings)
    {
        string id = bonfireLitSetting[0];
        string description = bonfireLitSetting[1];
        string parent = bonfireLitSetting[2];

        if (!vars.BonfireIdIsValid(id))
            throw new ArgumentException("Invalid bonfire ID format: " + id);

        vars.Bonfires.SettingsIds.Add(id);

        vars.CreateSplitTriggerSetting(id, description, parent);
        vars.CreateSplitTypeSettings(id, allSplitTypes);

        if (vars.DebugToolTips)
        {
            string toolTip = "Bonfire ID: " + id;
            settings.SetToolTip(id, toolTip);
        }
    }

    string currentPositionBoundingBoxData = File.ReadAllText(Path.Combine(splitTriggersDirectory, currentPositionFileName));
    List<string[]> currentPositionBoundingBoxSettings = vars.ParseSplitTriggerData(currentPositionBoundingBoxData);

    settings.CurrentDefaultParent = CURRENT_POSITION;
    foreach (string[] currentPositionBoundingBoxSetting in currentPositionBoundingBoxSettings)
    {
        string boundingCoordsString = currentPositionBoundingBoxSetting[0];
        string description =  currentPositionBoundingBoxSetting[1];
        string parent = currentPositionBoundingBoxSetting[2];

        var boundingCoords = vars.ParseBoundingBox(boundingCoordsString);
        string id = vars.SimpleFormattedBoundingBoxString(boundingCoords);

        vars.CurrentPositionBoundingBoxes.SettingsIds.Add(id);
        vars.CurrentPositionBoundingBoxes.Coords[id] = boundingCoords;

        vars.CreateSplitTriggerSetting(id, description, parent);
        vars.CreateSplitTypeSettings(id, allSplitTypes);

        if (vars.DebugToolTips)
        {
            string toolTip = vars.PrettyFormattedBoundingBoxString(boundingCoords);
            settings.SetToolTip(id, toolTip);
        }
    }

    string upwarpBoundingBoxData = File.ReadAllText(Path.Combine(splitTriggersDirectory, upwarpFileName));
    List<string[]> upwarpBoundingBoxSettings = vars.ParseSplitTriggerData(upwarpBoundingBoxData);

    settings.CurrentDefaultParent = UPWARP;
    foreach (string[] upwarpBoundingBoxSetting in upwarpBoundingBoxSettings)
    {
        string boundingCoordsString = upwarpBoundingBoxSetting[0];
        string description =  upwarpBoundingBoxSetting[1];
        string parent = upwarpBoundingBoxSetting[2];

        var boundingCoords = vars.ParseBoundingBox(boundingCoordsString);
        string id = vars.SimpleFormattedBoundingBoxString(boundingCoords);

        vars.UpwarpBoundingBoxes.SettingsIds.Add(id);
        vars.UpwarpBoundingBoxes.Coords[id] = boundingCoords;

        vars.CreateSplitTriggerSetting(id, description, parent);

        if (vars.DebugToolTips)
        {
            string toolTip = vars.PrettyFormattedBoundingBoxString(boundingCoords);
            settings.SetToolTip(id, toolTip);
        }
    }

    string initialPositionBoundingBoxData = File.ReadAllText(Path.Combine(splitTriggersDirectory, initialPositionFileName));
    List<string[]> initialPositionBoundingBoxSettings = vars.ParseSplitTriggerData(initialPositionBoundingBoxData);

    settings.CurrentDefaultParent = LOAD_IN;
    foreach (string[] initialPositionBoundingBoxSetting in initialPositionBoundingBoxSettings)
    {
        string boundingCoordsString = initialPositionBoundingBoxSetting[0];
        string description =  initialPositionBoundingBoxSetting[1];
        string parent = initialPositionBoundingBoxSetting[2];

        var boundingCoords = vars.ParseBoundingBox(boundingCoordsString);
        string id = vars.SimpleFormattedBoundingBoxString(boundingCoords);

        vars.InitialPositionBoundingBoxes.SettingsIds.Add(id);
        vars.InitialPositionBoundingBoxes.Coords[id] = boundingCoords;

        vars.CreateSplitTriggerSetting(id, description, parent);

        if (vars.DebugToolTips)
        {
            string toolTip = vars.PrettyFormattedBoundingBoxString(boundingCoords);
            settings.SetToolTip(id, toolTip);
        }
    }
    
    string zoneTransitionData = File.ReadAllText(Path.Combine(splitTriggersDirectory, zoneTransitionFileName));
    List<string[]> zoneTransitionSettings = vars.ParseSplitTriggerData(zoneTransitionData);

    settings.CurrentDefaultParent = ZONE_TRANSITION;
    foreach (string[] zoneTransitionSetting in zoneTransitionSettings)
    {
        string zoneTransitionString = zoneTransitionSetting[0];
        string description =  zoneTransitionSetting[1];
        string parent = zoneTransitionSetting[2];

        var zoneTransitionTuple = vars.ParseZoneTransition(zoneTransitionString);
        string id = vars.ZoneTransitionTupleToId(zoneTransitionTuple);

        vars.ZoneTransitions.SettingsIds.Add(id);
        vars.ZoneTransitions.Tuples[id] = zoneTransitionTuple;

        vars.CreateSplitTriggerSetting(id, description, parent);
        vars.CreateSplitTypeSettings(id, allSplitTypes);

        if (vars.DebugToolTips)
        {
            string toolTip = vars.ZoneTransitionTupleToToolTip(zoneTransitionTuple);
            settings.SetToolTip(id, toolTip);
        }
    }

    string bossArenaExitData = File.ReadAllText(Path.Combine(splitTriggersDirectory, bossArenaExitFileName));
    List<string[]> bossArenaExitSettings = vars.ParseSplitTriggerData(bossArenaExitData);

    settings.CurrentDefaultParent = BOSS_ARENA;
    foreach (string[] bossArenaExitSetting in bossArenaExitSettings)
    {
        string bossArenaExitString = bossArenaExitSetting[0];
        string description =  bossArenaExitSetting[1];
        string parent = bossArenaExitSetting[2];

        var bossArenaExitTuple = vars.ParseBossArenaExit(bossArenaExitString);
        string id = vars.BossArenaExitTupleToId(bossArenaExitTuple);

        vars.BossArenaExits.SettingsIds.Add(id);
        vars.BossArenaExits.Tuples[id] = bossArenaExitTuple;

        vars.CreateSplitTriggerSetting(id, description, parent);
        vars.CreateSplitTypeSettings(id, allSplitTypes);

        if (vars.DebugToolTips)
        {
            string toolTip = vars.BossArenaExitTupleToToolTip(bossArenaExitTuple);
            settings.SetToolTip(id, toolTip);
        }
    }

    // Initialize split logic on script startup.
    vars.ResetSplitLogic();
}

init
{
    // ---------- POINTER FUNCTIONS ----------

    vars.GetAOBRelativePtr = (Func<SignatureScanner, SigScanTarget, int, IntPtr>) ((scanner, sst, instructionLength) => 
    {
        int aobOffset = sst.Signatures[0].Offset;

        IntPtr ptr = scanner.Scan(sst);
        if (ptr == default(IntPtr))
        {
            throw new Exception("AOB Scan Unsuccessful");
        }

        int offset = memory.ReadValue<int>(ptr);

        return ptr - aobOffset + offset + instructionLength;
    });

    // Needs to have same signature as other AOB Ptr Func; ignoredValue is ignored.
    vars.GetAOBAbsolutePtr = (Func<SignatureScanner, SigScanTarget, int, IntPtr>) ((scanner, sst, ignoredValue) => 
    {
        IntPtr ptr = scanner.Scan(sst);
        if (ptr == default(IntPtr))
        {
            throw new Exception("AOB Scan Unsuccessful");
        }

        IntPtr tempPtr;
        if (!game.ReadPointer(ptr, out tempPtr))
        {
            throw new Exception("AOB scan did not yield valid pointer");
        }

        return tempPtr;
    });

    vars.GetLowestLevelPtr = (Func<DeepPointer, IntPtr>) ((deepPointer) => 
    {
        IntPtr tempPtr;
        if (!deepPointer.DerefOffsets(game, out tempPtr))
        {
           tempPtr = IntPtr.Zero;
        }
        return tempPtr;
    });

    vars.PtrResolves = (Func<DeepPointer, bool>) ((deepPointer) =>
    {
        IntPtr tempPtr;
        return deepPointer.DerefOffsets(game, out tempPtr);
    });

    // ---------- GAME SPECIFIC AOBs, OFFSETS, AND VALUES ----------

    SignatureScanner sigScanner = new SignatureScanner(game, modules.First().BaseAddress, modules.First().ModuleMemorySize);
    
    if (game.ProcessName.ToString() == "DARKSOULS")
    {
        vars.EventFlagAOB = new SigScanTarget(8, "56 8B F1 8B 46 1C 50 A1 ?? ?? ?? ?? 32 C9");        
        vars.FrpgNetManImpAOB = new SigScanTarget(2, "83 3D ?? ?? ?? ?? 00 75 4B A1");
        vars.ChrFollowCamAOB = new SigScanTarget(4, "D9 45 08 A1 ?? ?? ?? ?? 51 D9 1C 24 50");
        vars.GameDataManAOB = new SigScanTarget(1, "A1 ?? ?? ?? ?? 8B 40 34 53 32");
        
        // I don't know if this also points to a WorldChrManImp like the Remaster AOB
        vars.CoordsBaseAOB = new SigScanTarget(2, "8B 15 ?? ?? ?? ?? F3 0F 10 44 24 30 52");
        vars.BaseCAOB = new SigScanTarget(1, "A1 ?? ?? ?? ?? 53 56 57 8B F9 8B 88 ?? ?? ?? ?? 8B");

        vars.BonfireLinkedListFirstItemOffsets = new int[] {0xB48, 0x24, 0x0, 0x0};
        vars.CharacterLoadedOffsets = new int[] {0x0, 0x3C};
        vars.BonfireListSizeOffsets = new int[] {0xB48, 0x28};
        vars.ClearCountOffsets = new int[] {0x3C};
        vars.PlayerXOffsets = new int[] {0x4, 0x0, 0x28, 0x1C, 0x10};
        vars.PlayerYOffsets = new int[] {0x4, 0x0, 0x28, 0x1C, 0x14};
        vars.PlayerZOffsets = new int[] {0x4, 0x0, 0x28, 0x1C, 0x18};
        vars.InitXOffsets = new int[] {0xA50};
        vars.InitYOffsets = new int[] {0xA54};
        vars.InitZOffsets = new int[] {0xA58};
        vars.InGameTimeOffsets = new int[] {0x68};
        vars.AreaOffsets = new int[] {0xA12};
        vars.WorldOffsets = new int[] {0xA13};
        vars.PlayRegionOffsets = new int[] {0xA14};

        vars.GetAOBPtr = vars.GetAOBAbsolutePtr;

        vars.BonfireObjectOffset = 0x8;
        vars.BonfireIdOffset = 0x4;
        vars.BonfireStateOffset = 0x8;
    }
    else if (game.ProcessName.ToString() == "DarkSoulsRemastered")
    {
        vars.EventFlagAOB = new SigScanTarget(3, "48 8B 0D ?? ?? ?? ?? 99 33 C2 45 33 C0 2B C2 8D 50 F6");
        vars.FrpgNetManImpAOB = new SigScanTarget(3, "48 8B 05 ?? ?? ?? ?? 48 05 08 0A 00 00 48 89 44 24 50 E8 34 FC FD FF");
        vars.ChrFollowCamAOB = new SigScanTarget(3, "48 8B 0D ?? ?? ?? ?? E8 ?? ?? ?? ?? 48 8B 4E 68 48 8B 05 ?? ?? ?? ?? 48 89 48 60");
        vars.GameDataManAOB = new SigScanTarget(3, "48 8B 05 ?? ?? ?? ?? 45 33 ED 48 8B F1 48 85 C0");
        
        // WorldChrManImp
        vars.CoordsBaseAOB = new SigScanTarget(3, "48 8B 05 ?? ?? ?? ?? 48 8B 48 68 48 85 C9 0F 84 ?? ?? ?? ?? 48 39 5E 10 0F 84 ?? ?? ?? ?? 48");
        vars.BaseCAOB = new SigScanTarget(3, "48 8B 05 ?? ?? ?? ?? 0F 28 01 66 0F 7F 80 ?? ?? 00 00 C6 80");

        vars.BonfireLinkedListFirstItemOffsets = new int[] {0xB68, 0x28, 0x0, 0x0};
        vars.CharacterLoadedOffsets = new int[] {0x0, 0x60};
        vars.BonfireListSizeOffsets = new int[] {0xB68, 0x30};
        vars.ClearCountOffsets = new int[] {0x78};
        vars.PlayerXOffsets = new int[] {0x68, 0x68, 0x28, 0x10};
        vars.PlayerYOffsets = new int[] {0x68, 0x68, 0x28, 0x14};
        vars.PlayerZOffsets = new int[] {0x68, 0x68, 0x28, 0x18};
        vars.InitXOffsets = new int[] {0xA80};
        vars.InitYOffsets = new int[] {0xA84};
        vars.InitZOffsets = new int[] {0xA88};
        vars.InGameTimeOffsets = new int[] {0xA4};
        vars.AreaOffsets = new int[] {0xA22};
        vars.WorldOffsets = new int[] {0xA23};
        vars.PlayRegionOffsets = new int[] {0xA24};

        vars.GetAOBPtr = vars.GetAOBRelativePtr;

        vars.BonfireObjectOffset = 0x10;
        vars.BonfireIdOffset = 0x8;
        vars.BonfireStateOffset = 0xC;
    }

    // ---------- GET BASE POINTERS ----------

    // How long to wait before retrying AOB scanning if AOB scanning fails.
    const int MILLISECONDS_TO_WAIT_BEFORE_RESCAN = 100;

    // Stopwatch is defined in startup block and is used to mimic
    // Thread.Sleep without locking the Livesplit UI; 
    // If an AOB scan fails, retry after a specified number of milliseconds.
    if (!vars.CooldownStopwatch.IsRunning || vars.CooldownStopwatch.ElapsedMilliseconds > MILLISECONDS_TO_WAIT_BEFORE_RESCAN)
    {
        vars.CooldownStopwatch.Start();
        try 
        {
            vars.EventFlagPtr = vars.GetAOBPtr(sigScanner, vars.EventFlagAOB, 7);
            vars.FrpgNetManImpPtr = vars.GetAOBPtr(sigScanner, vars.FrpgNetManImpAOB, 7);
            vars.ChrFollowCamPtr = vars.GetAOBPtr(sigScanner, vars.ChrFollowCamAOB, 7);
            vars.GameDataManPtr = vars.GetAOBPtr(sigScanner, vars.GameDataManAOB, 7);
            vars.CoordsBasePtr = vars.GetAOBPtr(sigScanner, vars.CoordsBaseAOB, 7);
            vars.BaseCPtr = vars.GetAOBPtr(sigScanner, vars.BaseCAOB, 7);
        }
        catch (Exception e)
        {
            vars.CooldownStopwatch.Restart();
            throw new Exception(e.ToString() + "\ninit{} needs to be recalled; base pointer creation unsuccessful");
        }
    }
    else
    {
        throw new Exception("init{} needs to be recalled; waiting to rescan for base pointers");
    }

    vars.CooldownStopwatch.Reset();

    // ---------- CREATE DEEP POINTERS AND MEMORY WATCHERS ----------

    vars.Watchers = new MemoryWatcherList();
    vars.FlagWatchers = new MemoryWatcherList();

    vars.Watchers.Add(vars.BonfireListSize = new MemoryWatcher<byte>(new DeepPointer(vars.FrpgNetManImpPtr, vars.BonfireListSizeOffsets)));
    vars.Watchers.Add(vars.Area = new MemoryWatcher<byte>(new DeepPointer(vars.FrpgNetManImpPtr, vars.AreaOffsets)));
    vars.Watchers.Add(vars.World = new MemoryWatcher<byte>(new DeepPointer(vars.FrpgNetManImpPtr, vars.WorldOffsets)));
    vars.Watchers.Add(vars.PlayRegion = new MemoryWatcher<int>(new DeepPointer(vars.FrpgNetManImpPtr, vars.PlayRegionOffsets)));
    
    vars.Watchers.Add(vars.ClearCount = new MemoryWatcher<byte>(new DeepPointer(vars.GameDataManPtr, vars.ClearCountOffsets)));
    vars.Watchers.Add(vars.InGameTime = new MemoryWatcher<uint>(new DeepPointer(vars.GameDataManPtr, vars.InGameTimeOffsets)));
    
    vars.Watchers.Add(vars.PlayerX = new MemoryWatcher<float>(new DeepPointer(vars.CoordsBasePtr, vars.PlayerXOffsets)));
    vars.Watchers.Add(vars.PlayerY = new MemoryWatcher<float>(new DeepPointer(vars.CoordsBasePtr, vars.PlayerYOffsets)));
    vars.Watchers.Add(vars.PlayerZ = new MemoryWatcher<float>(new DeepPointer(vars.CoordsBasePtr, vars.PlayerZOffsets)));
    
    vars.Watchers.Add(vars.InitX = new MemoryWatcher<float>(new DeepPointer(vars.BaseCPtr, vars.InitXOffsets)));
    vars.Watchers.Add(vars.InitY = new MemoryWatcher<float>(new DeepPointer(vars.BaseCPtr, vars.InitYOffsets)));
    vars.Watchers.Add(vars.InitZ = new MemoryWatcher<float>(new DeepPointer(vars.BaseCPtr, vars.InitZOffsets)));
    
    vars.BonfireLinkedListFirstItemDeepPtr = new DeepPointer(vars.FrpgNetManImpPtr, vars.BonfireLinkedListFirstItemOffsets);
    vars.CharacterLoadedDeepPtr = new DeepPointer(vars.ChrFollowCamPtr, vars.CharacterLoadedOffsets);

    // ---------- EVENT FLAG MEMORY WATCHERS ----------

    vars.OffsetMemoryWatcherExists = new Dictionary<int, bool>();

    Action<string> WatchEventFlag = ((flagId) =>
    {
        Tuple<int, uint> tup = vars.GetEventFlagOffsetAndMask(flagId);
        int finalOffset = tup.Item1;
        uint mask = tup.Item2;
        var offsets = new int[] {0, finalOffset};
        
        vars.EventFlags.Offsets[flagId] = finalOffset;
        vars.EventFlags.Masks[flagId] = mask;

        if (!vars.OffsetMemoryWatcherExists.ContainsKey(finalOffset))
        {
            var temp = new MemoryWatcher<uint>(new DeepPointer(vars.EventFlagPtr, offsets));
            vars.EventFlagOffsets.MemoryWatchers[finalOffset] = temp;
            vars.FlagWatchers.Add(temp);

            vars.OffsetMemoryWatcherExists[finalOffset] = true;
        }
    });

    foreach (string flagId in vars.EventFlags.SettingsIds)
    {
        WatchEventFlag(flagId);
    }
}

onReset
{
    vars.ResetSplitLogic();
}

update
{
    vars.Watchers.UpdateAll(game);
    vars.FlagWatchers.UpdateAll(game);

    current.CharLoaded = vars.PtrResolves(vars.CharacterLoadedDeepPtr);
}

split
{
    bool split = false;
    
    var playerCoords = Tuple.Create(vars.PlayerX.Current, vars.PlayerY.Current, vars.PlayerZ.Current);
    var initCoords = Tuple.Create(vars.InitX.Current, vars.InitY.Current, vars.InitZ.Current);

    // ---------- LOADING SCREEN ----------

    // When character loads in (start of loading screen)
    if (current.CharLoaded && !old.CharLoaded)
    {
        if (vars.InGameTime.Current != 0)
        {
            vars.LoadInInGameTime = vars.InGameTime.Current;
            vars.LoadInTimerTime = timer.CurrentTime;
        }
        else
        {
            vars.CheckLoadInInGameTime = true;
        }

        vars.CheckInitPosition = true;
        vars.CheckUpwarp = true;
        
        if (vars.NonQuitoutLoadingSplitTriggered && !vars.QuitoutDetected)
        {
            vars.NonQuitoutLoadingSplitTriggered = false;
            split = true;
        }

        if (vars.QuitoutSplitTriggered && vars.QuitoutDetected)
        {
            vars.QuitoutSplitTriggered = false;
            split = true;
        }

        if (vars.LoadingSplitTriggered)
        {
            vars.LoadingSplitTriggered = false;
            split = true;
        }

        // Reset this on load in.
        vars.QuitoutDetected = false;
    }

    // If IGT wasn't set immediately on loading in, keep checking 
    // until it's not 0.
    if (vars.CheckLoadInInGameTime && vars.InGameTime.Current != 0)
    {
        vars.LoadInInGameTime = vars.InGameTime.Current;
        vars.LoadInTimerTime = timer.CurrentTime;
        vars.CheckLoadInInGameTime = false;
    }

    // ---------- QUITOUT DETECTION ----------

    // Don't set false again until character reloads.
    if (!current.CharLoaded && vars.InGameTime.Current == 0)
    {
        vars.QuitoutDetected = true;
    }

    // ---------- INITIAL POSITION BOUNDING BOX SPLITS ----------

    if (vars.CheckInitPosition && (vars.InitX.Changed || vars.InitY.Changed || vars.InitZ.Changed))
    {
        foreach (string boxId in vars.InitialPositionBoundingBoxes.SettingsIds)
        {
            if (settings[boxId] && !vars.SplitTriggered[boxId])
            {
                Tuple<float, float, float, float, float, float> boundingCoords = vars.InitialPositionBoundingBoxes.Coords[boxId];
                if (vars.WithinBoundingBox(initCoords, boundingCoords))
                {
                    split = true;
                    vars.SplitTriggered[boxId] = true;
                    break;
                }
            }
        }
        vars.CheckInitPosition = false;
    }

    // ---------- UPWARP BOUNDING BOX SPLITS ----------

    const int MILLISECONDS_TO_DETECT_UPWARP = 500;
    if (vars.CheckUpwarp && !vars.CheckLoadInInGameTime)
    {
        bool upwarpDetected = false;
        if (vars.PlayerX.Changed || vars.PlayerY.Changed || vars.PlayerZ.Changed)
        {
            foreach (string boxId in vars.UpwarpBoundingBoxes.SettingsIds)
            {
                if (settings[boxId] && !vars.SplitTriggered[boxId])
                {
                    Tuple<float, float, float, float, float, float> boundingCoords = vars.UpwarpBoundingBoxes.Coords[boxId];

                    if (vars.WithinBoundingBox(playerCoords, boundingCoords))
                    {
                        vars.SplitTriggered[boxId] = true;
                        upwarpDetected = true;
                        break;
                    }
                }
            }
        }
        
        if (upwarpDetected || vars.InGameTime.Current > vars.LoadInInGameTime + MILLISECONDS_TO_DETECT_UPWARP)
        {
            vars.CheckUpwarp = false;
        }

        if (upwarpDetected)
        {
            if (settings[vars.RETROACTIVE])
            {
                vars.RetroactiveSplitTriggered = true;
            }
            else
            {
                split = true;
            }
        }
    }

    // ---------- EVENT FLAG SPLITS ----------

    foreach (string flagId in vars.EventFlags.SettingsIds)
    {
        if (settings[flagId] && !vars.SplitTriggered[flagId])
        {
            int flagOffset = vars.EventFlags.Offsets[flagId];
            uint flagMask = vars.EventFlags.Masks[flagId];

            MemoryWatcher<uint> flagMem = vars.EventFlagOffsets.MemoryWatchers[flagOffset];

            // If flag is set.
            if (flagMem.Changed && ((uint) flagMem.Current & flagMask) != 0)
            {
                vars.SplitTriggered[flagId] = true;

                string imm = flagId + vars.IMMEDIATE_SPLIT_TYPE.Item1;
                string quit = flagId + vars.QUITOUT_SPLIT_TYPE.Item1;
                string nonquit = flagId + vars.NON_QUITOUT_SPLIT_TYPE.Item1;

                if (settings[imm])
                {
                    split = true;
                }
                else if (settings[quit])
                {
                    vars.QuitoutSplitTriggered = true;
                }
                else if (settings[nonquit])
                {
                    vars.NonQuitoutLoadingSplitTriggered = true;
                }
                else
                {
                    vars.LoadingSplitTriggered = true;
                }
            }
        }
    }

    // ---------- BONFIRE SPLITS ----------

    int bonfireLitId = -1;
    int bonfireObjectOffset = vars.BonfireObjectOffset;
    int bonfireIdOffset = vars.BonfireIdOffset;
    int bonfireStateOffset = vars.BonfireStateOffset;

    // Iterate through bonfire linked list, check if any has been lit 
    // (has a bonfireState > 0, but (implicitly) didn't before).
    IntPtr linkedListItemPtr = vars.GetLowestLevelPtr(vars.BonfireLinkedListFirstItemDeepPtr);
    if (linkedListItemPtr != IntPtr.Zero)
    {
        for (int i = 0; i < vars.BonfireListSize.Current; i++)
        {
            IntPtr bonfirePtr;
            game.ReadPointer(linkedListItemPtr + bonfireObjectOffset, out bonfirePtr);
            
            int bonfireId = memory.ReadValue<int>(bonfirePtr + bonfireIdOffset);
            int bonfireState = memory.ReadValue<int>(bonfirePtr + bonfireStateOffset);

            string bonfireIdString = bonfireId.ToString();

            bool splitTriggered = true;
            if (vars.SplitTriggered.TryGetValue(bonfireIdString, out splitTriggered))
            {
                if (settings[bonfireIdString] && !splitTriggered && bonfireState > 0)
                {
                    vars.SplitTriggered[bonfireIdString] = true;
                    bonfireLitId = bonfireId;
                    break;
                }
            }

            game.ReadPointer(linkedListItemPtr, out linkedListItemPtr);
        }
    }

    if (bonfireLitId > 0)
    {
        string bonfireLitIdString = bonfireLitId.ToString();
        
        string imm = bonfireLitIdString + vars.IMMEDIATE_SPLIT_TYPE.Item1;
        string quit = bonfireLitIdString + vars.QUITOUT_SPLIT_TYPE.Item1;
        string nonquit = bonfireLitIdString + vars.NON_QUITOUT_SPLIT_TYPE.Item1;

        if (settings[imm])
        {
            split = true;
        }
        else if (settings[quit])
        {
            vars.QuitoutSplitTriggered = true;
        }
        else if (settings[nonquit])
        {
            vars.NonQuitoutLoadingSplitTriggered = true;
        }
        else
        {
            vars.LoadingSplitTriggered = true;
        }
    }

    // ---------- CURRENT POSITION BOUNDING BOX SPLITS ----------

    foreach (string boxId in vars.CurrentPositionBoundingBoxes.SettingsIds)
    {
        if (settings[boxId] && !vars.SplitTriggered[boxId])
        {
            Tuple<float, float, float, float, float, float> boundingCoords = vars.CurrentPositionBoundingBoxes.Coords[boxId];
            if (vars.WithinBoundingBox(playerCoords, boundingCoords))
            {
                vars.SplitTriggered[boxId] = true;

                string imm = boxId + vars.IMMEDIATE_SPLIT_TYPE.Item1;
                string quit = boxId + vars.QUITOUT_SPLIT_TYPE.Item1;
                string nonquit = boxId + vars.NON_QUITOUT_SPLIT_TYPE.Item1;

                if (settings[imm])
                {
                    split = true;
                }
                else if (settings[quit])
                {
                    vars.QuitoutSplitTriggered = true;
                }
                else if (settings[nonquit])
                {
                    vars.NonQuitoutLoadingSplitTriggered = true;
                }
                else
                {
                    vars.LoadingSplitTriggered = true;
                }
            }
        }
    }

    // ---------- ZONE TRANSITION SPLITS ----------

    foreach (string zoneTransitionId in vars.ZoneTransitions.SettingsIds)
    {
        if (settings[zoneTransitionId] && !vars.SplitTriggered[zoneTransitionId])
        {
            Tuple<int, int, int, int> zoneTransitionTuple = vars.ZoneTransitions.Tuples[zoneTransitionId];
            int oldArea = zoneTransitionTuple.Item1;
            int oldWorld = zoneTransitionTuple.Item2;
            int newArea = zoneTransitionTuple.Item3;
            int newWorld = zoneTransitionTuple.Item4;

            if (vars.Area.Old == oldArea && vars.World.Old == oldWorld && vars.Area.Current == newArea && vars.World.Current == newWorld)
            {
                vars.SplitTriggered[zoneTransitionId] = true;

                string imm = zoneTransitionId + vars.IMMEDIATE_SPLIT_TYPE.Item1;
                string quit = zoneTransitionId + vars.QUITOUT_SPLIT_TYPE.Item1;
                string nonquit = zoneTransitionId + vars.NON_QUITOUT_SPLIT_TYPE.Item1;

                if (settings[imm])
                {
                    split = true;
                }
                else if (settings[quit])
                {
                    vars.QuitoutSplitTriggered = true;
                }
                else if (settings[nonquit])
                {
                    vars.NonQuitoutLoadingSplitTriggered = true;
                }
                else
                {
                    vars.LoadingSplitTriggered = true;
                }
            }
        }
    }

    // ---------- BOSS ARENA SPLITS ----------

    foreach (string bossArenaExitId in vars.BossArenaExits.SettingsIds)
    {
        if (settings[bossArenaExitId] && !vars.SplitTriggered[bossArenaExitId])
        {
            Tuple<int, int> bossArenaExitTuple = vars.BossArenaExits.Tuples[bossArenaExitId];
            int bossDeathFlag = bossArenaExitTuple.Item1;
            int bossArenaPlayRegionId = bossArenaExitTuple.Item2;

            string flagId = bossDeathFlag.ToString().PadLeft(vars.EVENT_FLAG_ID_LENGTH, '0');

            int flagOffset = vars.EventFlags.Offsets[flagId];
            uint flagMask = vars.EventFlags.Masks[flagId];

            MemoryWatcher<uint> flagMem = vars.EventFlagOffsets.MemoryWatchers[flagOffset];

            if (((uint) flagMem.Current & flagMask) != 0 && vars.PlayRegion.Current != bossArenaPlayRegionId)
            {
                vars.SplitTriggered[bossArenaExitId] = true;

                string imm = bossArenaExitId + vars.IMMEDIATE_SPLIT_TYPE.Item1;
                string quit = bossArenaExitId + vars.QUITOUT_SPLIT_TYPE.Item1;
                string nonquit = bossArenaExitId + vars.NON_QUITOUT_SPLIT_TYPE.Item1;

                if (settings[imm])
                {
                    split = true;
                }
                else if (settings[quit])
                {
                    vars.QuitoutSplitTriggered = true;
                }
                else if (settings[nonquit])
                {
                    vars.NonQuitoutLoadingSplitTriggered = true;
                }
                else
                {
                    vars.LoadingSplitTriggered = true;
                }
            }
        }
    }

    // ---------- GAME COMPLETION SPLITS ----------

    //  Happen on next load screen, not start of credits, to avoid splitting early.
    if (settings[vars.NG_ID] && !vars.NGSplitTriggered && vars.ClearCount.Current == 1 && vars.ClearCount.Old == 0)
    {
        vars.LoadingSplitTriggered = true;
        vars.NGSplitTriggered = true;
    }
    else if (settings[vars.NG_PLUS_ID] && vars.ClearCount.Old > 0 && vars.ClearCount.Current == vars.ClearCount.Old + 1)
    {
        vars.LoadingSplitTriggered = true;
    }

    // ---------- RETROACTIVE SPLITS (UPWARPS ONLY) ----------

    if (vars.RetroactiveSplitTriggered)
    {
        timer.Run[timer.CurrentSplitIndex].SplitTime = vars.LoadInTimerTime;
        timer.CurrentSplitIndex++;
        vars.RetroactiveSplitTriggered = false;
    }

    return split;
}