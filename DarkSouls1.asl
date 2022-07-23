/* 
Dark Souls 1 and Remastered Autosplitter But This Time In ASL Script Form
Version 0.4

Update History:
    Version 0.4:
        - Added Exit Boss Arena splits
        - Moved split trigger data to separate text files
        - Refactored with reflection
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
    refreshRate = 66;

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

    vars.RETROACTIVE_ID = "retroactive";

    const string scriptFileName = "DarkSouls1.asl";

    const string splitTriggersFolderName = "DarkSoulsSplitTriggers";

    const string eventFlagFileName = "EventFlag.txt";
    const string bonfireLitFileName = "Bonfire.txt";
    const string currentPositionFileName = "CurrentPosition.txt";
    const string upwarpFileName = "Upwarp.txt";
    const string initialPositionFileName = "InitialPosition.txt";
    const string zoneTransitionFileName = "ZoneTransition.txt";
    const string bossArenaExitFileName = "BossArenaExit.txt";

    const string srcFolderName = "src";

    const string splitTriggersSrcFileName = "SplitTriggers.cs";

    // ---------- GET PATH OF THIS SCRIPT ----------

    string scriptPath = "";

    // This method is extremely hacky; the working directory when the code is
    // executing is LiveSplit's directory. Get the directory of the script by
    // iterating through the Layout Components, find the component that loads
    // this script, and get the path from the component's settings.
    // Also, LiveSplit.UI.Components.ASLComponent doesn't seem to be in the
    // namespace accessible from ASL Scripts, so we can't check if an object is
    // that type directly and instead use a string comparison.
    foreach(LiveSplit.UI.Components.ILayoutComponent ilc in timer.Layout.LayoutComponents)
    {
        LiveSplit.UI.Components.IComponent component = ilc.Component;
        if (component.GetType().ToString() == "LiveSplit.UI.Components.ASLComponent")
        {
            dynamic componentSettings = component.GetSettingsControl(0);
            string path = componentSettings.ScriptPath;
            if (path.EndsWith(scriptFileName))
            {
                scriptPath = path;
                break;
            }
        }
    }

    string scriptDirectory = Directory.GetParent(scriptPath).ToString();
    
    string splitTriggersDirectory = Path.Combine(scriptDirectory, splitTriggersFolderName);
    string srcDirectory = Path.Combine(scriptDirectory, srcFolderName);

    Directory.CreateDirectory(splitTriggersDirectory);
    Directory.CreateDirectory(srcDirectory);

    Type EventFlagSplitTrigger;
    Type BonfireLitSplitTrigger;
    Type BoundingBoxSplitTrigger;
    Type ZoneTransitionSplitTrigger;
    Type BossArenaExitSplitTrigger;
    using (var provider = new Microsoft.CSharp.CSharpCodeProvider())
    {
        var parameters = new System.CodeDom.Compiler.CompilerParameters
        {
            GenerateInMemory = true,
            ReferencedAssemblies = { "System.dll", "System.Runtime.dll", "System.Collections.dll" }
        };

        var source = File.ReadAllText(Path.Combine(srcDirectory, splitTriggersSrcFileName));
        var assembly = provider.CompileAssemblyFromSource(parameters, source);

        foreach (var error in assembly.Errors)
            print(error.ToString());

        EventFlagSplitTrigger = assembly.CompiledAssembly.GetType("SplitTriggers.EventFlagSplitTrigger", true);
        BonfireLitSplitTrigger = assembly.CompiledAssembly.GetType("SplitTriggers.BonfireLitSplitTrigger", true);
        BoundingBoxSplitTrigger = assembly.CompiledAssembly.GetType("SplitTriggers.BoundingBoxSplitTrigger", true);
        ZoneTransitionSplitTrigger = assembly.CompiledAssembly.GetType("SplitTriggers.ZoneTransitionSplitTrigger", true);
        BossArenaExitSplitTrigger = assembly.CompiledAssembly.GetType("SplitTriggers.BossArenaExitSplitTrigger", true);
    }

    // ---------- SPLIT TRIGGER INFO VARS ----------

    Type eventFlagListType = typeof(List<>).MakeGenericType(EventFlagSplitTrigger);
    vars.EventFlags = Activator.CreateInstance(eventFlagListType);

    // Type bonfireDictType = typeof(Dictionary<,>).MakeGenericType(typeof(int), BonfireLitSplitTrigger);
    // vars.Bonfires = Activator.CreateInstance(bonfireDictType);

    vars.Bonfires = new Dictionary<int, dynamic>();

    Type boundingBoxListType = typeof(List<>).MakeGenericType(BoundingBoxSplitTrigger);
    vars.CurrentPositionBoundingBoxes = Activator.CreateInstance(boundingBoxListType);
    vars.UpwarpBoundingBoxes = Activator.CreateInstance(boundingBoxListType);
    vars.InitialPositionBoundingBoxes = Activator.CreateInstance(boundingBoxListType);
    
    Type zoneTransitionListType = typeof(List<>).MakeGenericType(ZoneTransitionSplitTrigger);
    vars.ZoneTransitions = Activator.CreateInstance(zoneTransitionListType);

    Type bossArenaExitListType = typeof(List<>).MakeGenericType(BossArenaExitSplitTrigger);
    vars.BossArenaExits = Activator.CreateInstance(bossArenaExitListType);

    // ---------- SPLIT LOGIC VARS ----------

    vars.ResetSplitLogic = (Action) (() => 
    {
        foreach(dynamic eventFlag in vars.EventFlags)
        {
            eventFlag.Triggered = false;
        }

        foreach(dynamic bonfire in vars.Bonfires.Values)
        {
            bonfire.Triggered = false;
        }

        foreach(dynamic boundingBox in vars.CurrentPositionBoundingBoxes)
        {
            boundingBox.Triggered = false;
        }

        foreach(dynamic boundingBox in vars.UpwarpBoundingBoxes)
        {
            boundingBox.Triggered = false;
        }

        foreach(dynamic boundingBox in vars.InitialPositionBoundingBoxes)
        {
            boundingBox.Triggered = false;
        }

        foreach(dynamic zoneTransition in vars.ZoneTransitions)
        {
            zoneTransition.Triggered = false;
        }

        foreach(dynamic bossArenaExit in vars.BossArenaExits)
        {
            bossArenaExit.Triggered = false;
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

    // ---------- BONFIRE FUNCTIONS ----------

    // vars.BonfireIdIsValid = (Func<string, bool>) ((bonfireId) =>
    // {
    //     const int BONFIRE_ID_LENGTH = 7;

    //     int idInt;
    //     if (bonfireId.Length != BONFIRE_ID_LENGTH || !Int32.TryParse(bonfireId, out idInt))
    //         return false;
    //     return true;        
    // });

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

    settings.Add(vars.RETROACTIVE_ID, false, "Retroactive Upwarp Splits");
    settings.SetToolTip(vars.RETROACTIVE_ID, "See Readme for Explanation");

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
        string parameters = eventFlagSetting[0];
        string description = eventFlagSetting[1];
        string parent = eventFlagSetting[2];

        dynamic eventFlag = EventFlagSplitTrigger.GetMethod("Parse").Invoke(null, new object[] {parameters});
        vars.EventFlags.Add(eventFlag);

        vars.CreateSplitTriggerSetting(eventFlag.SettingsId, description, parent);
        vars.CreateSplitTypeSettings(eventFlag.SettingsId, allSplitTypes);

        if (vars.DebugToolTips)
        {
            settings.SetToolTip(eventFlag.SettingsId, eventFlag.ToolTip);
        }
    }

    string bonfireLitData = File.ReadAllText(Path.Combine(splitTriggersDirectory, bonfireLitFileName));
    List<string[]> bonfireLitSettings = vars.ParseSplitTriggerData(bonfireLitData);

    settings.CurrentDefaultParent = BONFIRES_LIT;
    foreach (string[] bonfireLitSetting in bonfireLitSettings)
    {
        string parameters = bonfireLitSetting[0];
        string description = bonfireLitSetting[1];
        string parent = bonfireLitSetting[2];

        dynamic bonfire = BonfireLitSplitTrigger.GetMethod("Parse").Invoke(null, new object[] {parameters});
        vars.Bonfires[bonfire.BonfireId] = bonfire;

        vars.CreateSplitTriggerSetting(bonfire.SettingsId, description, parent);
        vars.CreateSplitTypeSettings(bonfire.SettingsId, allSplitTypes);

        if (vars.DebugToolTips)
        {
            settings.SetToolTip(bonfire.SettingsId, bonfire.ToolTip);
        }
    }

    string currentPositionBoundingBoxData = File.ReadAllText(Path.Combine(splitTriggersDirectory, currentPositionFileName));
    List<string[]> currentPositionBoundingBoxSettings = vars.ParseSplitTriggerData(currentPositionBoundingBoxData);

    settings.CurrentDefaultParent = CURRENT_POSITION;
    foreach (string[] currentPositionBoundingBoxSetting in currentPositionBoundingBoxSettings)
    {
        string parameters = currentPositionBoundingBoxSetting[0];
        string description =  currentPositionBoundingBoxSetting[1];
        string parent = currentPositionBoundingBoxSetting[2];

        dynamic boundingBox = BoundingBoxSplitTrigger.GetMethod("Parse").Invoke(null, new object[] {parameters});
        vars.CurrentPositionBoundingBoxes.Add(boundingBox);

        vars.CreateSplitTriggerSetting(boundingBox.SettingsId, description, parent);
        vars.CreateSplitTypeSettings(boundingBox.SettingsId, allSplitTypes);

        if (vars.DebugToolTips)
        {
            settings.SetToolTip(boundingBox.SettingsId, boundingBox.ToolTip);
        }
    }

    string upwarpBoundingBoxData = File.ReadAllText(Path.Combine(splitTriggersDirectory, upwarpFileName));
    List<string[]> upwarpBoundingBoxSettings = vars.ParseSplitTriggerData(upwarpBoundingBoxData);

    settings.CurrentDefaultParent = UPWARP;
    foreach (string[] upwarpBoundingBoxSetting in upwarpBoundingBoxSettings)
    {
        string parameters = upwarpBoundingBoxSetting[0];
        string description =  upwarpBoundingBoxSetting[1];
        string parent = upwarpBoundingBoxSetting[2];

        dynamic boundingBox = BoundingBoxSplitTrigger.GetMethod("Parse").Invoke(null, new object[] {parameters});
        vars.UpwarpBoundingBoxes.Add(boundingBox);

        vars.CreateSplitTriggerSetting(boundingBox.SettingsId, description, parent);
        // vars.CreateSplitTypeSettings(boundingBox.SettingsId, allSplitTypes);

        if (vars.DebugToolTips)
        {
            settings.SetToolTip(boundingBox.SettingsId, boundingBox.ToolTip);
        }
    }

    string initialPositionBoundingBoxData = File.ReadAllText(Path.Combine(splitTriggersDirectory, initialPositionFileName));
    List<string[]> initialPositionBoundingBoxSettings = vars.ParseSplitTriggerData(initialPositionBoundingBoxData);

    settings.CurrentDefaultParent = LOAD_IN;
    foreach (string[] initialPositionBoundingBoxSetting in initialPositionBoundingBoxSettings)
    {
        string parameters = initialPositionBoundingBoxSetting[0];
        string description =  initialPositionBoundingBoxSetting[1];
        string parent = initialPositionBoundingBoxSetting[2];

        dynamic boundingBox = BoundingBoxSplitTrigger.GetMethod("Parse").Invoke(null, new object[] {parameters});
        vars.InitialPositionBoundingBoxes.Add(boundingBox);

        vars.CreateSplitTriggerSetting(boundingBox.SettingsId, description, parent);
        // vars.CreateSplitTypeSettings(boundingBox.SettingsId, allSplitTypes);

        if (vars.DebugToolTips)
        {
            settings.SetToolTip(boundingBox.SettingsId, boundingBox.ToolTip);
        }
    }
    
    string zoneTransitionData = File.ReadAllText(Path.Combine(splitTriggersDirectory, zoneTransitionFileName));
    List<string[]> zoneTransitionSettings = vars.ParseSplitTriggerData(zoneTransitionData);

    settings.CurrentDefaultParent = ZONE_TRANSITION;
    foreach (string[] zoneTransitionSetting in zoneTransitionSettings)
    {
        string parameters = zoneTransitionSetting[0];
        string description =  zoneTransitionSetting[1];
        string parent = zoneTransitionSetting[2];

        dynamic zoneTransition = ZoneTransitionSplitTrigger.GetMethod("Parse").Invoke(null, new object[] {parameters});
        vars.ZoneTransitions.Add(zoneTransition);

        vars.CreateSplitTriggerSetting(zoneTransition.SettingsId, description, parent);
        vars.CreateSplitTypeSettings(zoneTransition.SettingsId, allSplitTypes);

        if (vars.DebugToolTips)
        {
            settings.SetToolTip(zoneTransition.SettingsId, zoneTransition.ToolTip);
        }
    }

    string bossArenaExitData = File.ReadAllText(Path.Combine(splitTriggersDirectory, bossArenaExitFileName));
    List<string[]> bossArenaExitSettings = vars.ParseSplitTriggerData(bossArenaExitData);

    settings.CurrentDefaultParent = BOSS_ARENA;
    foreach (string[] bossArenaExitSetting in bossArenaExitSettings)
    {
        string parameters = bossArenaExitSetting[0];
        string description =  bossArenaExitSetting[1];
        string parent = bossArenaExitSetting[2];

        dynamic bossArenaExit = BossArenaExitSplitTrigger.GetMethod("Parse").Invoke(null, new object[] {parameters});
        vars.BossArenaExits.Add(bossArenaExit);

        vars.CreateSplitTriggerSetting(bossArenaExit.SettingsId, description, parent);
        vars.CreateSplitTypeSettings(bossArenaExit.SettingsId, allSplitTypes);

        if (vars.DebugToolTips)
        {
            settings.SetToolTip(bossArenaExit.SettingsId, bossArenaExit.ToolTip);
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

    vars.EventFlagMemoryWatcherList = new MemoryWatcherList();
    vars.EventFlagMemoryWatcherDictionary = new Dictionary<int, MemoryWatcher<uint>>();

    vars.OtherMemoryWatchers = new MemoryWatcherList();

    vars.OtherMemoryWatchers.Add(vars.BonfireListSize = new MemoryWatcher<byte>(new DeepPointer(vars.FrpgNetManImpPtr, vars.BonfireListSizeOffsets)));
    vars.OtherMemoryWatchers.Add(vars.Area = new MemoryWatcher<byte>(new DeepPointer(vars.FrpgNetManImpPtr, vars.AreaOffsets)));
    vars.OtherMemoryWatchers.Add(vars.World = new MemoryWatcher<byte>(new DeepPointer(vars.FrpgNetManImpPtr, vars.WorldOffsets)));
    vars.OtherMemoryWatchers.Add(vars.PlayRegion = new MemoryWatcher<int>(new DeepPointer(vars.FrpgNetManImpPtr, vars.PlayRegionOffsets)));
    
    vars.OtherMemoryWatchers.Add(vars.ClearCount = new MemoryWatcher<byte>(new DeepPointer(vars.GameDataManPtr, vars.ClearCountOffsets)));
    vars.OtherMemoryWatchers.Add(vars.InGameTime = new MemoryWatcher<uint>(new DeepPointer(vars.GameDataManPtr, vars.InGameTimeOffsets)));
    
    vars.OtherMemoryWatchers.Add(vars.PlayerX = new MemoryWatcher<float>(new DeepPointer(vars.CoordsBasePtr, vars.PlayerXOffsets)));
    vars.OtherMemoryWatchers.Add(vars.PlayerY = new MemoryWatcher<float>(new DeepPointer(vars.CoordsBasePtr, vars.PlayerYOffsets)));
    vars.OtherMemoryWatchers.Add(vars.PlayerZ = new MemoryWatcher<float>(new DeepPointer(vars.CoordsBasePtr, vars.PlayerZOffsets)));
    
    vars.OtherMemoryWatchers.Add(vars.InitX = new MemoryWatcher<float>(new DeepPointer(vars.BaseCPtr, vars.InitXOffsets)));
    vars.OtherMemoryWatchers.Add(vars.InitY = new MemoryWatcher<float>(new DeepPointer(vars.BaseCPtr, vars.InitYOffsets)));
    vars.OtherMemoryWatchers.Add(vars.InitZ = new MemoryWatcher<float>(new DeepPointer(vars.BaseCPtr, vars.InitZOffsets)));
    
    vars.BonfireLinkedListFirstItemDeepPtr = new DeepPointer(vars.FrpgNetManImpPtr, vars.BonfireLinkedListFirstItemOffsets);
    vars.CharacterLoadedDeepPtr = new DeepPointer(vars.ChrFollowCamPtr, vars.CharacterLoadedOffsets);

    // ---------- EVENT FLAG MEMORY WATCHERS ----------

    vars.OffsetMemoryWatcherExists = new HashSet<int>();

    foreach (dynamic eventFlag in vars.EventFlags)
    {
        if (!vars.OffsetMemoryWatcherExists.Contains(eventFlag.Offset))
        {
            var offsets = new int[] {0, eventFlag.Offset};
            var memoryWatcher = new MemoryWatcher<uint>(new DeepPointer(vars.EventFlagPtr, offsets));
            vars.EventFlagMemoryWatcherDictionary[eventFlag.Offset] = memoryWatcher;
            vars.EventFlagMemoryWatcherList.Add(memoryWatcher);

            vars.OffsetMemoryWatcherExists.Add(eventFlag.Offset);
        }
    }
}

// onStart
// {

// }

onReset
{
    vars.ResetSplitLogic();
}

update
{
    vars.EventFlagMemoryWatcherList.UpdateAll(game);
    vars.OtherMemoryWatchers.UpdateAll(game);

    current.CharLoaded = vars.PtrResolves(vars.CharacterLoadedDeepPtr);
}

split
{
    bool split = false;
    
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
        foreach (dynamic boundingBox in vars.InitialPositionBoundingBoxes)
        {
            if (settings[boundingBox.SettingsId] && !boundingBox.Triggered && boundingBox.ContainsCoordinates(vars.InitX.Current, vars.InitY.Current, vars.InitZ.Current))
            {
                split = true;
                boundingBox.Triggered = true;
                break;
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
            foreach (dynamic boundingBox in vars.UpwarpBoundingBoxes)
            {
                if (settings[boundingBox.SettingsId] && !boundingBox.Triggered && boundingBox.ContainsCoordinates(vars.PlayerX.Current, vars.PlayerY.Current, vars.PlayerZ.Current))
                {
                    boundingBox.Triggered = true;
                    upwarpDetected = true;
                    break;
                }
            }
        }
        
        if (upwarpDetected || vars.InGameTime.Current > vars.LoadInInGameTime + MILLISECONDS_TO_DETECT_UPWARP)
        {
            vars.CheckUpwarp = false;
        }

        if (upwarpDetected)
        {
            if (settings[vars.RETROACTIVE_ID])
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

    foreach (dynamic eventFlag in vars.EventFlags)
    {
        if (settings[eventFlag.SettingsId] && !eventFlag.Triggered)
        {
            uint eventFlagMemory = vars.EventFlagMemoryWatcherDictionary[eventFlag.Offset].Current;

            if ((eventFlagMemory & eventFlag.Mask) != 0)
            {
                eventFlag.Triggered = true;

                string imm = eventFlag.SettingsId + vars.IMMEDIATE_SPLIT_TYPE.Item1;
                string quit = eventFlag.SettingsId + vars.QUITOUT_SPLIT_TYPE.Item1;
                string nonquit = eventFlag.SettingsId + vars.NON_QUITOUT_SPLIT_TYPE.Item1;

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

    string bonfireLitIdString = "";

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

            dynamic bonfire;
            if (vars.Bonfires.TryGetValue(bonfireId, out bonfire))
            {
                if (settings[bonfire.SettingsId] && !bonfire.Triggered && bonfireState > 0)
                {
                    bonfire.Triggered = true;
                    bonfireLitIdString = bonfire.SettingsId;
                    break;
                }
            }

            game.ReadPointer(linkedListItemPtr, out linkedListItemPtr);
        }
    }

    if (bonfireLitIdString != "")
    {       
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

    foreach (dynamic boundingBox in vars.CurrentPositionBoundingBoxes)
    {
        if (settings[boundingBox.SettingsId] && !boundingBox.Triggered)
        {
            if (boundingBox.ContainsCoordinates(vars.PlayerX.Current, vars.PlayerY.Current, vars.PlayerZ.Current))
            {
                boundingBox.Triggered = true;

                string imm = boundingBox.SettingsId + vars.IMMEDIATE_SPLIT_TYPE.Item1;
                string quit = boundingBox.SettingsId + vars.QUITOUT_SPLIT_TYPE.Item1;
                string nonquit = boundingBox.SettingsId + vars.NON_QUITOUT_SPLIT_TYPE.Item1;

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

    foreach (dynamic zoneTransition in vars.ZoneTransitions)
    {
        if (settings[zoneTransition.SettingsId] && !zoneTransition.Triggered 
        && vars.Area.Old == zoneTransition.OldArea && vars.World.Old == zoneTransition.OldWorld 
        && vars.Area.Current == zoneTransition.NewArea && vars.World.Current == zoneTransition.NewWorld)
        {
            zoneTransition.Triggered = true;

            string imm = zoneTransition.SettingsId + vars.IMMEDIATE_SPLIT_TYPE.Item1;
            string quit = zoneTransition.SettingsId + vars.QUITOUT_SPLIT_TYPE.Item1;
            string nonquit = zoneTransition.SettingsId + vars.NON_QUITOUT_SPLIT_TYPE.Item1;

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

    // ---------- BOSS ARENA SPLITS ----------

    foreach (dynamic bossArenaExit in vars.BossArenaExits)
    {
        if (settings[bossArenaExit.SettingsId] && !bossArenaExit.Triggered)
        {
            int eventFlagOffset = bossArenaExit.Offset;
            uint eventFlagMask = bossArenaExit.Mask;
            uint eventFlagMemory = vars.EventFlagMemoryWatcherDictionary[eventFlagOffset].Current;

            if ((eventFlagMemory & eventFlagMask) != 0 && vars.PlayRegion.Current != bossArenaExit.BossArenaPlayRegionId)
            {
                bossArenaExit.Triggered = true;

                string imm = bossArenaExit.SettingsId + vars.IMMEDIATE_SPLIT_TYPE.Item1;
                string quit = bossArenaExit.SettingsId + vars.QUITOUT_SPLIT_TYPE.Item1;
                string nonquit = bossArenaExit.SettingsId + vars.NON_QUITOUT_SPLIT_TYPE.Item1;

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