using System;
using System.Collections.Generic;

namespace SplitTriggers
{
    public abstract class SplitTrigger
    {
        public string SettingsId {get; protected set;}
        public bool Triggered {get; set;}
        public abstract string ToolTip {get;}

        public SplitTrigger()
        {
            Triggered = false;
        }
    }


    public class EventFlagSplitTrigger : SplitTrigger
    {
        public int EventFlagId {get; private set;}
        public int Offset {get; private set;}
        public uint Mask {get; private set;}
        public override string ToolTip { get { return "Event Flag ID: " + EventFlagId; } }

        private const int EVENT_FLAG_ID_LENGTH = 8;
        private const int NUM_PARAMETERS = 1;

        public EventFlagSplitTrigger(int eventFlagId) : base()
        {
            // move input checking here

            EventFlagId = eventFlagId;

            uint mask;
            Offset = GetEventFlagOffset(eventFlagId, out mask);
            Mask = mask;

            SettingsId = eventFlagIdToString(eventFlagId);
        }

        public static EventFlagSplitTrigger Parse(string commaSeparatedParameters)
        {
            string[] parameters = commaSeparatedParameters.Split(',');
            
            if (parameters.Length != NUM_PARAMETERS)
                throw new ArgumentException("Event Flag Split Trigger must have 1 parameter: event flag ID: \n" + commaSeparatedParameters);

            return new EventFlagSplitTrigger(Int32.Parse(parameters[0]));
        }

        protected static string eventFlagIdToString(int eventFlagId)
        {
            return eventFlagId.ToString().PadLeft(EVENT_FLAG_ID_LENGTH, '0');
        }

        protected static Dictionary<string, int> eventFlagGroups = new Dictionary<string, int>()
        {
            {"0", 0x00000},
            {"1", 0x00500},
            {"5", 0x05F00},
            {"6", 0x0B900},
            {"7", 0x11300},
        };

        protected static Dictionary<string, int> eventFlagAreas = new Dictionary<string, int>()
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

        protected int GetEventFlagOffset(int eventFlagId, out uint mask)
        {
            string idString = eventFlagIdToString(eventFlagId);
            if (idString.Length == 8)
            {
                string group = idString.Substring(0, 1);
                string area = idString.Substring(1, 3);
                int section = Int32.Parse(idString.Substring(4, 1));
                int number = Int32.Parse(idString.Substring(5, 3));

                if (eventFlagGroups.ContainsKey(group) && eventFlagAreas.ContainsKey(area))
                {
                    int offset = eventFlagGroups[group];
                    offset += eventFlagAreas[area] * 0x500;
                    offset += section * 128;
                    offset += (number - (number % 32)) / 8;

                    mask = 0x80000000 >> (number % 32);
                    return offset;
                }
            }
            throw new ArgumentException("Unknown event flag ID: " + idString);
        }
    }


    public class BonfireLitSplitTrigger : SplitTrigger
    {
        public int BonfireId {get; private set;}
        public override string ToolTip { get { return "Bonfire ID: " + BonfireId; } }

        public BonfireLitSplitTrigger(int bonfireId) : base()
        {
            BonfireId = bonfireId;

            SettingsId = bonfireId.ToString();
        }

        private const int NUM_PARAMETERS = 1;
        public static BonfireLitSplitTrigger Parse(string commaSeparatedParameters)
        {
            string[] parameters = commaSeparatedParameters.Split(',');
            
            if (parameters.Length != NUM_PARAMETERS)
                throw new ArgumentException("Bonfire Lit Split Trigger must have 1 parameter: bonfire ID: \n" + commaSeparatedParameters);

            return new BonfireLitSplitTrigger(Int32.Parse(parameters[0]));
        }
    }


    public class BoundingBoxSplitTrigger : SplitTrigger
    {
        private float xMin {get; set;}
        private float xMax {get; set;}
        private float yMin {get; set;}
        private float yMax {get; set;}
        private float zMin {get; set;}
        private float zMax {get; set;}

        public override string ToolTip { get { return "X Min: " + xMin + ", X Max: " + xMax + ", Y Min: " +yMin + ", Y Max: " + yMax + ", Z Min: " + zMin + ", Z Max: " + zMax; } }

        public BoundingBoxSplitTrigger(float xMin, float xMax, float yMin, float yMax, float zMin, float zMax) : base()
        {
            this.xMin = xMin;
            this.xMax = xMax;
            this.yMin = yMin;
            this.yMax = yMax;
            this.zMin = zMin;
            this.zMax = zMax;

            SettingsId = xMin + "," + xMax + "," + yMin + "," + yMax + "," + zMin + "," + zMax;
        }

        private const int NUM_PARAMETERS = 6;
        public static BoundingBoxSplitTrigger Parse(string commaSeparatedParameters)
        {
            string[] parameters = commaSeparatedParameters.Split(',');

            if (parameters.Length != NUM_PARAMETERS)
                throw new ArgumentException("Bounding Box Split Trigger must have 6 parameters: x min, x max, y min, y max, z min, z max: \n" + commaSeparatedParameters);

            return new BoundingBoxSplitTrigger(Single.Parse(parameters[0]), Single.Parse(parameters[1]), Single.Parse(parameters[2]), Single.Parse(parameters[3]), Single.Parse(parameters[4]), Single.Parse(parameters[5]));
        }

        public bool ContainsCoordinates(float x, float y, float z)
        {
            return x >= xMin && x <= xMax && y >= yMin && y <= yMax && z >= zMin && z <= zMax;
        }
    }


    public class ZoneTransitionSplitTrigger : SplitTrigger
    {
        public int OldArea {get; private set;}
        public int OldWorld {get; private set;}
        public int NewArea {get; private set;}
        public int NewWorld {get; private set;}
        public override string ToolTip { get { return "Old World: " + OldWorld + ", Old Area: " + OldArea + ", New World: " + NewWorld + ", New Area: " + NewArea; } }

        public ZoneTransitionSplitTrigger(int oldArea, int oldWorld, int newArea, int newWorld) : base()
        {
            OldArea = oldArea;
            OldWorld = oldWorld;
            NewArea = newArea;
            NewWorld = newWorld;

            SettingsId = OldArea + "," + OldWorld + "," + NewArea + "," + NewWorld;
        }

        private const int NUM_PARAMETERS = 4;
        public static ZoneTransitionSplitTrigger Parse(string commaSeparatedParameters)
        {
            string[] parameters = commaSeparatedParameters.Split(',');
            
            if (parameters.Length != NUM_PARAMETERS)
                throw new ArgumentException("Zone Transition Split Trigger must have 4 parameters: old area, old world, new area, new world: \n" + commaSeparatedParameters);

            return new ZoneTransitionSplitTrigger(Int32.Parse(parameters[0]), Int32.Parse(parameters[1]), Int32.Parse(parameters[2]), Int32.Parse(parameters[3]));
        }
    }


    public class BossArenaExitSplitTrigger : EventFlagSplitTrigger
    {
        public int BossArenaPlayRegionId {get; private set;}
        public override string ToolTip { get { return "Boss Death Flag: " + EventFlagId + ", Boss Arena Region ID: " + BossArenaPlayRegionId; } }

        public BossArenaExitSplitTrigger(int bossDeathEventFlagId, int bossArenaPlayRegionId) : base(bossDeathEventFlagId)
        {
            BossArenaPlayRegionId = bossArenaPlayRegionId;

            SettingsId = eventFlagIdToString(EventFlagId) + "," + BossArenaPlayRegionId;
        }

        private const int NUM_PARAMETERS = 2;
        public static BossArenaExitSplitTrigger Parse(string commaSeparatedParameters)
        {
            string[] parameters = commaSeparatedParameters.Split(',');
            
            if (parameters.Length != NUM_PARAMETERS)
                throw new ArgumentException("Boss Arena Exit Split Trigger must have 2 parameters: boss death event flag ID, boss arena play region ID: \n" + commaSeparatedParameters);

            return new BossArenaExitSplitTrigger(Int32.Parse(parameters[0]), Int32.Parse(parameters[1]));
        }
    }
}
