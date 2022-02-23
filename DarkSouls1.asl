/* 
Dark Souls 1 and Remastered Autosplitter But This Time In ASL Script Form
Version 0.2.2

Update History:
    Version 0.3:
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

    // ---------- SPLIT TRIGGER DATA ----------

    // Splits triggered by an event flag being set.
    // Event flag may be less than 8 characters, or padded to 8 if you wish.
    // Format: event flag id | event flag description
    string eventFlagData = @"        
        Bells of Awakening
        11010700|Undead Parish, Upper Bell of Awakening
        11400200|Blighttown, Lower Bell of Awakening

        Lordvessel Flags
        11510400|Dark Anor Londo
        11510592|Receive Lordvessel With Gwynevere Still Alive
        50000090|Receive Lordvessel (Gwynevere Alive or Dead)

        Boss Deaths
        00000016|Asylum Demon
        00000010|Bed of Chaos
        00000003|Bell Gargoyles
        11210004|Black Dragon Kalameet
        11210063|Black Dragon Kalameet (Goughless)
        11010902|Capra Demon
        11410900|Ceaseless Discharge
        11410901|Centipede Demon
        00000009|Chaos Witch Quelaag
        00000004|Crossbreed Priscilla
        11510900|Dark Sun Gwyndolin
        11410410|Demon Firesage
        00000012|Dragonslayer Ornstein & Executioner Smough
        00000013|Four Kings
        00000002|Gaping Dragon
        00000007|Gravelord Nito
        00000015|Gwyn, Lord of Cinder
        00000011|Iron Golem
        11210001|Knight Artorias
        11210002|Manus, Father of the Abyss
        11200900|Moonlight Butterfly
        00000006|Pinwheel
        11210000|Sanctuary Guardian
        00000014|Seath, the Scaleless
        00000005|Sif, the Great Gray Wolf
        11810900|Stray Demon
        11010901|Taurus Demon

        Doors, Elevators, and Shortcuts
        11510220|Anor Londo, Elevator Active
        11510110|Anor Londo, Door to Gwynevere
        61200500|Darkroot Garden, Crest of Artorias Door
        11410340|Demon Ruins, Shortcut to Lost Izalith
        11810110|Northern Undead Asylum, Big Pilgrim Door

        NPC Flags
        1121|Dusk, Rescued From Golem
        1122|Dusk, Available for Summon (Said Yes After Rescue)
        1125|Dusk, Dead
        1702|Oswald, Dead
        1513|Siegmeyer, Dead
        1764|Shiva Bodyguard, Dead

        Ring Item Pickups
        51300020|Catacombs, Darkmoon Seance Ring
        51020130|Firelink Shrine, Ring of Sacrifice
        51810060|Northern Undead Asylum, Rusted Iron Ring
        51310140|Tomb of the Giants, Covetous Silver Serpent Ring
        51600380|Valley of the Drakes, Red Tearstone Ring

        Non-Ring Item Pickups
        51510560|Anor Londo, Dragon Tooth
        51200200|Darkroot Basin, Grass Crest Shield
        51810080|Northern Undead Asylum, Peculiar Doll
                                    
        Siegmeyer Rings
        50000010|Tiny Being's Ring
        50000070|Speckled Stoneplate Ring (Looted or Given)

        Join Covenants
        851|Way of White
        852|Princess Guard
        853|Warrior of Sunlight
        854|Darkwraith
        855|Path of the Dragon
        856|Gravelord Servant
        857|Forest Hunter
        858|Darkmoon Blade
        859|Chaos Servant
    ";

    // TODO
    // chloranthy ring
    // dark wood grain ring
    // white seance ring
    // hydra dead
    // embers for all achievements?
    // ?

    // Splits triggered by a bonfire being lit.
    // Every bonfire in this list starts out unlit and the autosplitter logic depends on this.
    // Format: bonfire ID | bonfire description
    string bonfireLitData = @" 
        Lordvessel Bonfire
        1801960|Firelink Altar (Place Lordvessel)

        Normal Bonfires
        1601950|Abyss
        1511950|Anor Londo (Chamber of the Princess)
        1511961|Anor Londo (Interior)
        1511962|Anor Londo (Darkmoon Tomb)
        1321961|Ash Lake (Bonfire #1)
        1401961|Blighttown (Swamp Bonfire)
        1401962|Blighttown (Bridge Bonfire)
        1301960|Catacombs (Bonfire #1)
        1301961|Catacombs (Behind Illusory Wall)
        1211950|Chasm of the Abyss
        1701950|Crystal Cave
        1601961|Darkroot Basin
        1201961|Darkroot Garden
        1411961|Demon Ruins (Before Ceaseless)
        1411962|Demon Ruins (After Ceaseless)
        1411963|Demon Ruins (After Firesage)
        1001960|Depths
        1701960|Duke's Archives (Balcony)
        1701961|Duke's Archives (Cell)
        1701962|Duke's Archives (Elevator)
        1321962|Great Hollow
        1411950|Lost Izalith (Bed of Chaos)
        1411960|Lost Izalith (Behind Illusory Wall)
        1411964|Lost Izalith (After Centipede Demon)
        1811960|Northern Undead Asylum (Courtyard)
        1811961|Northern Undead Asylum (Interior)
        1211961|Oolacile Sanctuary
        1211962|Oolacile Township
        1211964|Oolacile Township Dungeon
        1101960|Painted World of Ariamis
        1211963|Sanctuary Garden
        1501961|Sen's Fortress
        1311960|Tomb of the Giants (Bonfire #1)
        1311961|Tomb of the Giants (Bonfire #2)
        1311950|Tomb of the Giants (Altar of the Gravelord)
        1011962|Undead Burg
        1011961|Undead Parish (Sunlight Altar)
        1011964|Undead Parish (Andre)
    ";

    // Bounding box splits triggered based on where the player is currently.
    // May have decimals.
    // Format: x min, x max, y min, y max, z min, z max | description
    string currentPositionBoundingBoxData = @"     
        Current Location
        86,90,16,17,178,179|Sen's Fortress, Gate
    ";

    // Bounding box splits triggered if player upwarps into them.
    // (if the player is in them within a certain short amount of time of loading in)
    // Same format as the above bounding box splits.
    string upwarpBoundingBoxData = @"
        Upwarps
        171,177,-78.65,-77,-87,-81|Darkroot Basin, Top of Elevator
    ";

    // Bounding box splits triggered based on where the player character is going to load in.
    // Same format as the above bounding box splits.
    string loadInBoundingBoxData = @"    
        Wrong Warp Destination
        120.65,122.65,-80.12,-78.12,123.27,125.27|Kiln of the First Flame
        -51.0,-49.0,-137.5,-135.5,50.0,52.0|New Londo Ruins
        -48.77,-46.77,-22.79,-20.79,-36.62,-34.62|Undead Burg
        87.0,89.0,12.2,14.2,163.0,165.0|Sen's Fortress
        96.94,98.94,-6.128,-4.128,33.92,35.92|Darkroot Garden

        Fall Damage Cancel Quitout Location
        250,265,113,123,240,268|Anor Londo Fall Control Quitout (Base of Elevator Tower)
        230,256,134,136,240,268|Anor Londo Meme-rolls (High Platform of Elevator Tower)
        -140,-120,-216,-215,85,100|Blighttown Meme-rolls (In Swamp After Meme-rolls)
        40,45,-165.5,-164.5,53.5,58|Seal Skip (Upper Platform)
        30,40,-169,-167,47.5,56|Seal Skip (Lower Platform)
    ";

    // Splits Triggered by traveling between separate locations in the game.
    // Format: old area, old world, new area, new world | description
    string zoneTransitionData = @"
        Zone Transition
        1,18,2,10|Undead Asylum to Firelink Shrine
        2,10,1,18|Firelink Shrine to Undead Asylum
        0,15,1,15|Sen's Fortress to Anor Londo
        1,15,0,15|Anor Londo to Sen's Fortress
        1,15,0,11|Anor Londo to Painted World
        0,11,1,15|Painted World to Anor Londo
        0,12,1,12|Darkroot Basin to DLC
    ";

    // ---------- CONSTANTS ----------
    // Need to be accessed in other blocks, so can't actually be consts.

    vars.IMMEDIATE_SPLIT_TYPE = Tuple.Create("imm", "Split Immediately");
    vars.QUITOUT_SPLIT_TYPE = Tuple.Create("quit", "Split On Next Quitout");
    vars.NON_QUITOUT_SPLIT_TYPE = Tuple.Create("nonquit", "Split On Next Non-Quitout Load Screen");

    vars.NG_ID = "ng";
    vars.NG_PLUS_ID = "ng+";

    vars.EVENT_FLAG_ID_LENGTH = 8;

    // ---------- SPLIT TRIGGER INFO VARS ----------

    vars.EventFlags = new ExpandoObject();
    vars.EventFlags.Ids = new List<string>();
    vars.EventFlags.Offsets = new Dictionary<string, int>();
    vars.EventFlags.Masks = new Dictionary<string, uint>();

    vars.EventFlagOffsets = new ExpandoObject();
    vars.EventFlagOffsets.MemoryWatchers = new Dictionary<int, MemoryWatcher<uint>>();

    vars.Bonfires = new ExpandoObject();
    vars.Bonfires.Ids = new List<string>();

    vars.CurrentPositionBoundingBoxes = new ExpandoObject();
    vars.CurrentPositionBoundingBoxes.Ids = new List<string>();
    vars.CurrentPositionBoundingBoxes.Coords = new Dictionary<string, Tuple<float, float, float, float, float, float>>();

    vars.UpwarpBoundingBoxes = new ExpandoObject();
    vars.UpwarpBoundingBoxes.Ids = new List<string>();
    vars.UpwarpBoundingBoxes.Coords = new Dictionary<string, Tuple<float, float, float, float, float, float>>();

    vars.LoadInBoundingBoxes = new ExpandoObject();
    vars.LoadInBoundingBoxes.Ids = new List<string>();
    vars.LoadInBoundingBoxes.Coords = new Dictionary<string, Tuple<float, float, float, float, float, float>>();
    
    vars.ZoneTransitions = new ExpandoObject();
    vars.ZoneTransitions.Ids = new List<string>();
    vars.ZoneTransitions.Tuples = new Dictionary<string, Tuple<int, int, int, int>>();

    // ---------- SPLIT LOGIC VARS ----------

    // Dictionary of bools that are initialized false and set true if a 
    // specific split has been triggered; used to avoid double splits.
    vars.SplitTriggered = new Dictionary<string, bool>();

    vars.ResetSplitLogic = (Action) (() => 
    {
        foreach(string flagId in vars.EventFlags.Ids)
        {
            vars.SplitTriggered[flagId] = false;
        }

        foreach(string bonfireId in vars.Bonfires.Ids)
        {
            vars.SplitTriggered[bonfireId] = false;
        }

        foreach(string boxId in vars.CurrentPositionBoundingBoxes.Ids)
        {
            vars.SplitTriggered[boxId] = false;
        }

        foreach(string boxId in vars.UpwarpBoundingBoxes.Ids)
        {
            vars.SplitTriggered[boxId] = false;
        }

        foreach(string boxId in vars.LoadInBoundingBoxes.Ids)
        {
            vars.SplitTriggered[boxId] = false;
        }

        foreach(string zoneTransitionId in vars.ZoneTransitions.Ids)
        {
            vars.SplitTriggered[zoneTransitionId] = false;
        }

        vars.LoadingSplitTriggered = false;
        vars.QuitoutSplitTriggered = false;
        vars.NonQuitoutLoadingSplitTriggered = false;
        
        vars.NGSplitTriggered = false;

        vars.CheckInitPosition = false;
        vars.CheckUpwarp = false;

        vars.CheckLoadInInGameTime = false;
        vars.LoadInInGameTime = 0;

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
        if (zoneTransition.Length != ZONE_TRANSITION_TUPLE_LENGTH)
        {
            throw new ArgumentException("Zone Transition must have 4 values: old area, old world, new area, new world: " + zoneTransition);
        }

        for(int i = 0; i < ZONE_TRANSITION_TUPLE_LENGTH; i++)
        {
            zoneTransition[i] = Int32.Parse(zoneTransitionSplit[i].Trim());
        }

        return Tuple.Create(zoneTransition[0], zoneTransition[1], zoneTransition[2], zoneTransition[3]);
    });

    // ---------- SETTINGS ACTIONS ----------

    vars.ParentSettingsAdded = new Dictionary<string, bool>();

    vars.CreateSplitTriggerSetting = (Action<string, string, string>) ((id, description, parent) =>
    {
        if (!vars.ParentSettingsAdded.ContainsKey(parent))
        {
            settings.Add(parent, true);
            vars.ParentSettingsAdded[parent] = true;
        }

        settings.Add(id, false, description, parent);
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
                    if (currentCategory == "")
                    {
                        throw new ArgumentException("Uncatgorized split trigger: \n" + line);
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

    var noSplitTypes = new List<Tuple<string, string>> {};

    var currentPositionBoundingBoxSplitTypes = new List<Tuple<string, string>>
    {
        vars.QUITOUT_SPLIT_TYPE,
        vars.NON_QUITOUT_SPLIT_TYPE,
    };

    settings.Add(vars.NG_ID, false, "NG Completion");
    settings.Add(vars.NG_PLUS_ID, false, "NG+ and Later Completion");

    settings.CurrentDefaultParent = null;
    const string EVENT_FLAGS = "Event Flags";
    settings.Add(EVENT_FLAGS, true);
    settings.CurrentDefaultParent = EVENT_FLAGS;

    List<string[]> eventFlagSettings = vars.ParseSplitTriggerData(eventFlagData);

    foreach (string[] eventFlagSetting in eventFlagSettings)
    {
        string id = eventFlagSetting[0];
        string description = eventFlagSetting[1];
        string parent = eventFlagSetting[2];

        id = id.PadLeft(vars.EVENT_FLAG_ID_LENGTH, '0');

        if (!vars.EventFlagIsValid(id))
            throw new ArgumentException("Invalid event flag ID: " + id);

        vars.EventFlags.Ids.Add(id);

        vars.CreateSplitTriggerSetting(id, description, parent);
        vars.CreateSplitTypeSettings(id, allSplitTypes);

        if (vars.DebugToolTips)
        {
            string toolTip = "Event Flag ID: " + id;
            settings.SetToolTip(id, toolTip);
        }
    }
    
    settings.CurrentDefaultParent = null;
    const string BONFIRES_LIT = "Bonfires Lit";
    settings.Add(BONFIRES_LIT, true);
    settings.CurrentDefaultParent = BONFIRES_LIT;

    List<string[]> bonfireLitSettings = vars.ParseSplitTriggerData(bonfireLitData);

    foreach (string[] bonfireLitSetting in bonfireLitSettings)
    {
        string id = bonfireLitSetting[0];
        string description = bonfireLitSetting[1];
        string parent = bonfireLitSetting[2];

        if (!vars.BonfireIdIsValid(id))
            throw new ArgumentException("Invalid bonfire ID format: " + id);

        vars.Bonfires.Ids.Add(id);

        vars.CreateSplitTriggerSetting(id, description, parent);
        vars.CreateSplitTypeSettings(id, allSplitTypes);

        if (vars.DebugToolTips)
        {
            string toolTip = "Bonfire ID: " + id;
            settings.SetToolTip(id, toolTip);
        }
    }

    settings.CurrentDefaultParent = null;
    const string BOUNDING_BOX = "Bounding Box";
    settings.Add(BOUNDING_BOX, true);
    settings.CurrentDefaultParent = BOUNDING_BOX;

    List<string[]> currentPositionBoundingBoxSettings = vars.ParseSplitTriggerData(currentPositionBoundingBoxData);

    foreach (string[] currentPositionBoundingBoxSetting in currentPositionBoundingBoxSettings)
    {
        string boundingCoordsString = currentPositionBoundingBoxSetting[0];
        string description =  currentPositionBoundingBoxSetting[1];
        string parent = currentPositionBoundingBoxSetting[2];

        var boundingCoords = vars.ParseBoundingBox(boundingCoordsString);
        string id = vars.SimpleFormattedBoundingBoxString(boundingCoords);

        vars.CurrentPositionBoundingBoxes.Ids.Add(id);
        vars.CurrentPositionBoundingBoxes.Coords[id] = boundingCoords;

        vars.CreateSplitTriggerSetting(id, description, parent);
        vars.CreateSplitTypeSettings(id, currentPositionBoundingBoxSplitTypes);

        if (vars.DebugToolTips)
        {
            string toolTip = vars.PrettyFormattedBoundingBoxString(boundingCoords);
            settings.SetToolTip(id, toolTip);
        }
    }

    settings.CurrentDefaultParent = BOUNDING_BOX;

    List<string[]> upwarpBoundingBoxSettings = vars.ParseSplitTriggerData(upwarpBoundingBoxData);

    foreach (string[] upwarpBoundingBoxSetting in upwarpBoundingBoxSettings)
    {
        string boundingCoordsString = upwarpBoundingBoxSetting[0];
        string description =  upwarpBoundingBoxSetting[1];
        string parent = upwarpBoundingBoxSetting[2];

        var boundingCoords = vars.ParseBoundingBox(boundingCoordsString);
        string id = vars.SimpleFormattedBoundingBoxString(boundingCoords);

        vars.UpwarpBoundingBoxes.Ids.Add(id);
        vars.UpwarpBoundingBoxes.Coords[id] = boundingCoords;

        vars.CreateSplitTriggerSetting(id, description, parent);
        vars.CreateSplitTypeSettings(id, noSplitTypes);

        if (vars.DebugToolTips)
        {
            string toolTip = vars.PrettyFormattedBoundingBoxString(boundingCoords);
            settings.SetToolTip(id, toolTip);
        }
    }

    settings.CurrentDefaultParent = BOUNDING_BOX;
    const string LOAD_IN = "Location On Load In";
    settings.Add(LOAD_IN, true, LOAD_IN, settings.CurrentDefaultParent);
    settings.CurrentDefaultParent = LOAD_IN;

    List<string[]> loadInBoundingBoxSettings = vars.ParseSplitTriggerData(loadInBoundingBoxData);

    foreach (string[] loadInBoundingBoxSetting in loadInBoundingBoxSettings)
    {
        string boundingCoordsString = loadInBoundingBoxSetting[0];
        string description =  loadInBoundingBoxSetting[1];
        string parent = loadInBoundingBoxSetting[2];

        var boundingCoords = vars.ParseBoundingBox(boundingCoordsString);
        string id = vars.SimpleFormattedBoundingBoxString(boundingCoords);

        vars.LoadInBoundingBoxes.Ids.Add(id);
        vars.LoadInBoundingBoxes.Coords[id] = boundingCoords;

        vars.CreateSplitTriggerSetting(id, description, parent);
        vars.CreateSplitTypeSettings(id, noSplitTypes);

        if (vars.DebugToolTips)
        {
            string toolTip = vars.PrettyFormattedBoundingBoxString(boundingCoords);
            settings.SetToolTip(id, toolTip);
        }
    }

    settings.CurrentDefaultParent = null;
    
    List<string[]> zoneTransitionSettings = vars.ParseSplitTriggerData(zoneTransitionData);

    foreach (string[] zoneTransitionSetting in zoneTransitionSettings)
    {
        string zoneTransitionString = zoneTransitionSetting[0];
        string description =  zoneTransitionSetting[1];
        string parent = zoneTransitionSetting[2];

        var zoneTransitionTuple = vars.ParseZoneTransition(zoneTransitionString);
        string id = vars.ZoneTransitionTupleToId(zoneTransitionTuple);

        vars.ZoneTransitions.Ids.Add(id);
        vars.ZoneTransitions.Tuples[id] = zoneTransitionTuple;

        vars.CreateSplitTriggerSetting(id, description, parent);
        vars.CreateSplitTypeSettings(id, allSplitTypes);

        if (vars.DebugToolTips)
        {
            string toolTip = vars.ZoneTransitionTupleToToolTip(zoneTransitionTuple);
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
        vars.EventFlagsAOB = new SigScanTarget(8, "56 8B F1 8B 46 1C 50 A1 ?? ?? ?? ?? 32 C9");        
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

        vars.GetAOBPtr = vars.GetAOBAbsolutePtr;

        vars.BonfireObjectOffset = 0x8;
        vars.BonfireIdOffset = 0x4;
        vars.BonfireStateOffset = 0x8;
    }
    else if (game.ProcessName.ToString() == "DarkSoulsRemastered")
    {
        vars.EventFlagsAOB = new SigScanTarget(3, "48 8B 0D ?? ?? ?? ?? 99 33 C2 45 33 C0 2B C2 8D 50 F6");
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
            vars.EventFlagsPtr = vars.GetAOBPtr(sigScanner, vars.EventFlagsAOB, 7);
            vars.FrpgNetManImpPtr = vars.GetAOBPtr(sigScanner, vars.FrpgNetManImpAOB, 7);
            vars.ChrFollowCamPtr = vars.GetAOBPtr(sigScanner, vars.ChrFollowCamAOB, 7);
            vars.GameDataManPtr = vars.GetAOBPtr(sigScanner, vars.GameDataManAOB, 7);
            vars.CoordsBasePtr = vars.GetAOBPtr(sigScanner, vars.CoordsBaseAOB, 7);
            vars.BaseCPtr = vars.GetAOBPtr(sigScanner, vars.BaseCAOB, 7);
        }
        catch (Exception e)
        {
            vars.CooldownStopwatch.Restart();
            throw new Exception(e.ToString() + "\ninit {} needs to be recalled; base pointer creation unsuccessful");
        }
    }
    else
    {
        throw new Exception("init {} needs to be recalled; waiting to rescan for base pointers");
    }

    vars.CooldownStopwatch.Reset();

    // ---------- CREATE DEEP POINTERS AND MEMORY WATCHERS ----------

    vars.Watchers = new MemoryWatcherList();
    vars.FlagWatchers = new MemoryWatcherList();

    vars.Watchers.Add(vars.BonfireListSize = new MemoryWatcher<byte>(new DeepPointer(vars.FrpgNetManImpPtr, vars.BonfireListSizeOffsets)));
    vars.Watchers.Add(vars.Area = new MemoryWatcher<byte>(new DeepPointer(vars.FrpgNetManImpPtr, vars.AreaOffsets)));
    vars.Watchers.Add(vars.World = new MemoryWatcher<byte>(new DeepPointer(vars.FrpgNetManImpPtr, vars.WorldOffsets)));
    
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
            var temp = new MemoryWatcher<uint>(new DeepPointer(vars.EventFlagsPtr, offsets));
            vars.EventFlagOffsets.MemoryWatchers[finalOffset] = temp;
            vars.FlagWatchers.Add(temp);

            vars.OffsetMemoryWatcherExists[finalOffset] = true;
        }
    });

    foreach (string flagId in vars.EventFlags.Ids)
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

    // print(vars.InGameTime.Current.ToString());

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
            print("poop1");
        }
        else
        {
            vars.CheckLoadInInGameTime = true;
            print("poop2");
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
        vars.CheckLoadInInGameTime = false;
        print("poop3");
    }

    // ---------- QUITOUT DETECTION ----------

    // Don't set false again until character reloads.
    if (!current.CharLoaded && vars.InGameTime.Current == 0)
    {
        vars.QuitoutDetected = true;
    }

    // ---------- LOAD-IN POSITION BOUNDING BOX SPLITS ----------

    if (vars.CheckInitPosition && (vars.InitX.Changed || vars.InitY.Changed || vars.InitZ.Changed))
    {
        foreach (string boxId in vars.LoadInBoundingBoxes.Ids)
        {
            if (settings[boxId] && !vars.SplitTriggered[boxId])
            {
                Tuple<float, float, float, float, float, float> boundingCoords = vars.LoadInBoundingBoxes.Coords[boxId];
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
            foreach (string boxId in vars.UpwarpBoundingBoxes.Ids)
            {
                // print(boxId);
                // print(vars.SplitTriggered[boxId].ToString());
                if (settings[boxId] && !vars.SplitTriggered[boxId])
                {
                    print("poop3.5");
                    Tuple<float, float, float, float, float, float> boundingCoords = vars.UpwarpBoundingBoxes.Coords[boxId];

                    print("" + playerCoords.Item1 + " " + playerCoords.Item2 + " " + playerCoords.Item3);
                    print(vars.SimpleFormattedBoundingBoxString(boundingCoords));

                    if (vars.WithinBoundingBox(playerCoords, boundingCoords))
                    {
                        print("poop6");
                        vars.SplitTriggered[boxId] = true;
                        upwarpDetected = true;
                        break;
                    }
                }
            }
        }
        
        if (upwarpDetected || vars.InGameTime.Current > vars.LoadInInGameTime + MILLISECONDS_TO_DETECT_UPWARP)
        {
            print("poop4");
            vars.CheckUpwarp = false;
        }

        if (upwarpDetected)
        {
            split = true;
        }
    }

    // ---------- EVENT FLAG SPLITS ----------

    foreach (string flagId in vars.EventFlags.Ids)
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

    // ---------- PLAYER POSITION BOUNDING BOX SPLITS ----------

    foreach (string boxId in vars.CurrentPositionBoundingBoxes.Ids)
    {
        if (settings[boxId] && !vars.SplitTriggered[boxId])
        {
            Tuple<float, float, float, float, float, float> boundingCoords = vars.CurrentPositionBoundingBoxes.Coords[boxId];
            if (vars.WithinBoundingBox(playerCoords, boundingCoords))
            {
                vars.SplitTriggered[boxId] = true;

                string quit = boxId + vars.QUITOUT_SPLIT_TYPE.Item1;
                string nonquit = boxId + vars.NON_QUITOUT_SPLIT_TYPE.Item1;

                if (settings[quit])
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

    foreach (string zoneTransitionId in vars.ZoneTransitions.Ids)
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

    return split;
}