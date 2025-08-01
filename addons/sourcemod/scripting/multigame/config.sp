/*
 * Multigame - SourceMod Plugin
 *
 * This plugin enables server administrators to configure multiple
 * gamemodes with a maplist for each gamemode. It provides features 
 * such as ranking the gamemodes and maps using a SQL database to
 * increase the likelihood of the most popular gamemodes and maps 
 * being played on the server.
 * --------------------------------------------------------------------
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

#define CONFIG_PATH             "configs/multigame.cfg"

enum struct MapInfo 
{
  char sName[64];       // Name of the map
  int  iMaxPlayers;     // Maximum number of players 
  int  iMinPlayers;     // Minimum number of players
}

methodmap MapList < ArrayList 
{
  // Constructor that initializes the MapList as an ArrayList
  public MapList() 
  {
    return (view_as<MapList>(new ArrayList(ByteCountToCells(64))));
  }
  
  // Insert a map info the MapList
  public void Insert(MapInfo mapinfo) 
  {
    this.PushArray(mapinfo);
  }
  
  // Retrieve a map from the MapList by Index
  public void GetMap(int iIndex, MapInfo mapinfo) 
  {
    this.GetArray(iIndex, mapinfo, sizeof(mapinfo));
  }
}

enum struct Gamemode 
{
  char      sName[64];   // Name of the gamemode
  ArrayList aPluginList; // List of plugin names
  MapList   maplist;     // List of maps for the gamemode
  
  // Method to release the resources
  void Release() 
  {
    delete this.maplist;
    delete this.aPluginList;
  }
}

methodmap GameModeMap < StringMap 
{
  // Initialize the GamemodeHashmap as a StringMap
  public GameModeMap() 
  {
    return (view_as<GameModeMap>(new StringMap()));
  }

  // Retrieve a gamemode by key
  public bool Get(const char[] sKey, Gamemode gamemode) 
  {
    // Get the gamemode object associated with the specified key
    return (this.GetArray(sKey, gamemode, sizeof(gamemode)) ? true : false);
  }

  // Set a gamemode with a key
  public bool Set(const char[] sKey, Gamemode gamemode) 
  {
    // Set the gamemode object with the specified key
    return this.SetArray(sKey, gamemode, sizeof(gamemode), false);
  }

  // Find a gamemode by index
  public bool Find(const int iIndex, Gamemode gamemode) 
  {
    // Take a snapshot of the GamemodeHashmap
    StringMapSnapshot hSnapshot = this.Snapshot();
    
    char sKey[64];
    bool bResult;
    
    // Get the key at the specified index
    hSnapshot.GetKey(iIndex, sKey, sizeof(sKey)); 
    
    // Retrieve the gamemode object associated with the key
    if (this.Get(sKey, gamemode)) 
      bResult = true;

    delete hSnapshot;
    return bResult;
  }
  
  // Find a gamemode by name
  public bool FindByName(const char[] sName, Gamemode gamemode) 
  {
    // Take a snapshot of the GamemodeHashmap
    StringMapSnapshot hSnapshot = this.Snapshot();
    
    int iLength = hSnapshot.Length;
    char sKey[64];
    bool bResult;
    
    for (int i = 0; i < iLength; i++) 
    {
      // Get the key at the current index
      hSnapshot.GetKey(i, sKey, sizeof(sKey));

      // Retrieve the gamemode object and check if the names match
      if (this.Get(sKey, gamemode) && StrEqual(sName, gamemode.sName)) 
      {
        bResult = true;
        break;
      }
    }

    delete hSnapshot;
    return bResult;
  }
  
  // Delete a gamemode by key
  public bool Delete(const char[] sKey)
  {
    Gamemode gamemode;

    // Retrieve the gamemode object associated with the key
    if (this.GetArray(sKey, gamemode, sizeof(gamemode))) 
    {
      // Release the resources associated with the gamemode
      gamemode.Release();

      // Remove the gamemode from the GamemodeHashmap
      this.Remove(sKey);

      return true;
    }
    return false;
  }
  
  // Delete all gamemodes
  public bool DeleteAll() 
  {
    // Take a snapshot of the GamemodeHashmap
    StringMapSnapshot hSnapshot = this.Snapshot();
    
    int iLength = hSnapshot.Length;
    char sKey[64];
    bool bResult;
    
    Gamemode gamemode;

    for (int i = 0; i < iLength; i++) 
    {
      // Get the key at the current index
      hSnapshot.GetKey(i, sKey, sizeof(sKey));
      
      // Retrieve the gamemode object associated with the key
      if (this.Get(sKey, gamemode))
      {
        // Release the resources associated with each gamemode
        gamemode.Release();
        bResult = true;
      }
    }

    // Clear the GamemodeHashmap
    this.Clear();

    delete hSnapshot;

    return bResult;
  }
}

GameModeMap g_GameModeMap;


// Load and parse a KeyValues config file
KeyValues Config_LoadFile(const char[] sFilename, const char[] sSection)
{
  char sPath[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, sPath, sizeof(sPath), sFilename);

  // Check if the file exists
  if (!FileExists(sPath))
  {
    LogMessage("[Multigame] Failed to load config file (file missing: %s!)", sPath);
    return null;
  }
  
  // Create a new KeyValues object for the specified section
  KeyValues kv = new KeyValues(sSection);
  kv.SetEscapeSequences(true);

  // Import the file into the KeyValues object
  if (!kv.ImportFromFile(sPath))
  {
    LogMessage("[Multigame] Failed to parse config file: %s!", sPath);
    return null;
  }

  return kv;
}

// Get an integer value from a KeyValues object
int Config_Value(const char[] sBuffer, KeyValues kv)
{
  char sValue[64];
  if (kv.GetString(sBuffer, sValue, sizeof(sValue)))
  {
    return StringToInt(sValue);
  }
  else
  {
    return -1;
  }
}


// Refresh the configuration by loading the config file and updating the gamemode hashmap
void Config_Refresh()
{
  // Load the config file
  KeyValues kv = Config_LoadFile(CONFIG_PATH, "multigame");
  if (kv == null)
    return;

  // Update the gamemode hashmap based on the config file
  if (kv.JumpToKey("gamemode", false))
  {
    // Create a new gamemode hashmap if it doesn't exist, or delete all existing entries
    if (g_GameModeMap == null)
    {
      g_GameModeMap = new GameModeMap();
    }
    else
    {
      g_GameModeMap.DeleteAll();
    }

    // Iterate through each gamemode section in the config file
    if (kv.GotoFirstSubKey(false))
    {
      do 
      {
        Gamemode gamemode;
        kv.GetSectionName(gamemode.sName, sizeof(gamemode.sName));

        gamemode.aPluginList = new ArrayList(ByteCountToCells(64));

        // Get list of plugins
        if (kv.JumpToKey("plugins", false)) 
        {
          if (kv.GotoFirstSubKey(false))
          {
            do 
            {
              char sPluginName[64];
              kv.GetSectionName(sPluginName, sizeof(sPluginName));
              gamemode.aPluginList.PushString(sPluginName);
            } 
            while (kv.GotoNextKey(false));
          }
          kv.GoBack(); // Exit "plugins"
          kv.GoBack(); // Exit plugin section
        }

        gamemode.maplist = new MapList();

        // Handle the 'maps' subsection for each gamemode
        if (kv.JumpToKey("maps", false)) 
        {
          if (kv.GotoFirstSubKey(false))
          {
            do 
            {
              MapInfo mapinfo;
              kv.GetSectionName(mapinfo.sName, sizeof(mapinfo.sName));

              // Validate map existence
              if (!IsMapValid(mapinfo.sName))
              {
                PrintToServer("[WARNING] Skipping invalid map: %s", mapinfo.sName);
                continue;
              }

              // Extract map metadata
              mapinfo.iMaxPlayers = Config_Value("max_players", kv);
              mapinfo.iMinPlayers = Config_Value("min_players", kv);

              gamemode.maplist.Insert(mapinfo);
              //PrintToServer("[DEBUG] Loaded valid map: %s (Min: %d, Max: %d)", mapinfo.sName, mapinfo.iMinPlayers, mapinfo.iMaxPlayers);
            }
            while (kv.GotoNextKey(false));
          }
          kv.GoBack(); // Exit "maps"
        }

        // Add the gamemode to the map
        g_GameModeMap.Set(gamemode.sName, gamemode);

        kv.GoBack(); // Exit gamemode
      } 
      while (kv.GotoNextKey(false));
    }
  }
}
