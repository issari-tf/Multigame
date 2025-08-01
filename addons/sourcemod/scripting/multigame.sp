#pragma semicolon 1 
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <SteamWorks> 
#include <tf2>
#include <tf2_stocks>
#include "include/multigame.inc"

#define PLUGIN_VERSION          "1.0.0"
#define PLUGIN_VERSION_REVISION "manual"
#define PLUGIN_DESCRIPTION      "Multiple Gamemodes for Team Fortress 2"
#define PLUGIN_URL              "https://github.com/lessari-tf/Multigame"

public Plugin myinfo = 
{
  name        = "Multigame",
  author      = "Aidan Sanders",
  description =  PLUGIN_DESCRIPTION,
  version     =  PLUGIN_VERSION ... "." ... PLUGIN_VERSION_REVISION,
  url         =  PLUGIN_URL,
};

#define MAX_LENGTH 64

enum struct Cvars 
{
  ConVar mp_timelimit;      // Maximum time limit of the game 
  ConVar mp_winlimit;       // Maximum number of wins required by game
  ConVar mp_maxrounds;      // Maximum number of rounds in a game
  ConVar mp_fraglimit;      // Maximum number of frags allowed in game
  ConVar mp_bonusroundtime; // Time limit of a bonus round
}
Cvars g_hCvars;

enum
{
  CURRENT,
  PREVIOUS,
  MAX_COUNT
}

char g_sGameName[MAX_COUNT][64];
char g_sMapName[MAX_COUNT][64];
int  g_iTotalRoundPlayed = 0;
int  g_iStartingMapTime = 0;
bool g_bChangeMap = false;

#include "multigame/config.sp"

void Native_AskLoad()
{
  // Internal
  CreateNative("Multigame.GetCurrentGameMode", Native_GetCurrentGameMode);
  CreateNative("Multigame.GetCurrentMapName",  Native_GetCurrentMapName);

  CreateNative("Multigame.SetCurrentGameMode", Native_SetCurrentGameMode);
  CreateNative("Multigame.SetCurrentMapName",  Native_SetCurrentMapName);

  // From Config
  CreateNative("Multigame.GetGamemodeCount", Native_GetGamemodeCount);
  CreateNative("Multigame.GetGamemodeName",  Native_GetGamemodeName);
  
  CreateNative("Multigame.GetMapCount",      Native_GetMapCount);
  CreateNative("Multigame.GetMapName",       Native_GetMapName);

  CreateNative("Multigame.DisplayMenu",      Native_DisplayMenu);
  CreateNative("Multigame.ChangeLevel",      Native_ChangeLevel);
}

// Native to get current gamemode name
public int Native_GetCurrentGameMode(Handle hPlugin, int iNumParams)
{
  int iLength = GetNativeCell(3);
  char[] buffer = new char[iLength];
  strcopy(buffer, iLength, g_sGameName[CURRENT]);
  SetNativeString(2, buffer, iLength);
  return 0;
}

// Native to get current map name
public int Native_GetCurrentMapName(Handle hPlugin, int iNumParams)
{
  int iLength = GetNativeCell(3);
  char[] buffer = new char[iLength];
  strcopy(buffer, iLength, g_sMapName[CURRENT]);
  SetNativeString(2, buffer, iLength);
  return 0;
}

// Native to set current gamemode name
public int Native_SetCurrentGameMode(Handle hPlugin, int iNumParams)
{
  int iLength = GetNativeCell(3);
  char[] sNewGame = new char[iLength];
  GetNativeString(2, sNewGame, iLength);
  strcopy(g_sGameName[PREVIOUS], MAX_LENGTH, g_sGameName[CURRENT]);
  strcopy(g_sGameName[CURRENT], MAX_LENGTH, sNewGame);
  return 0;
}

// Native to set current map name
public int Native_SetCurrentMapName(Handle hPlugin, int iNumParams)
{
  int iLength = GetNativeCell(3);
  char[] sNewMap = new char[iLength];
  GetNativeString(2, sNewMap, iLength);
  strcopy(g_sMapName[PREVIOUS], MAX_LENGTH, g_sMapName[CURRENT]);
  strcopy(g_sMapName[CURRENT], MAX_LENGTH, sNewMap);
  return 0;
}

public int Native_GetGamemodeCount(Handle hPlugin, int iNumParams)
{
  return g_GameModeMap.Size;
}

public int Native_GetGamemodeName(Handle hPlugin, int iNumParams)
{
  Gamemode gamemode;
  int iIndex = GetNativeCell(2);
  if (!g_GameModeMap.Find(iIndex, gamemode))
    return 1;
  
  int iLength = GetNativeCell(4);
  char[] sGamemodeName = new char[iLength];
  strcopy(sGamemodeName, iLength, gamemode.sName);
  SetNativeString(3, sGamemodeName, iLength);
  return 0;
}

public int Native_GetMapCount(Handle hPlugin, int iNumParams)
{
  Gamemode gamemode;
  int iIndex = GetNativeCell(2);
  if (!g_GameModeMap.Find(iIndex, gamemode))
    return 1;
  
  return gamemode.maplist.Length;
}

public int Native_GetMapName(Handle hPlugin, int iNumParams)
{
  Gamemode gamemode;
  int iIndex = GetNativeCell(2);
  if (!g_GameModeMap.Find(iIndex, gamemode))
    return 1;
  
  iIndex = GetNativeCell(3);
  int iLength = GetNativeCell(5);
  char[] sMapName = new char[iLength];
  
  MapInfo mapinfo;
  gamemode.maplist.GetMap(iIndex, mapinfo);

  strcopy(sMapName, iLength, mapinfo.sName);
  SetNativeString(4, sMapName, iLength);
  return 0;
}

public int Native_DisplayMenu(Handle hPlugin, int iNumParams)
{
  Menu_ShowMenu(MENUTYPE_GAME);
  return 0;
}

public int Native_ChangeLevel(Handle hPlugin, int iNumParams)
{
  g_bChangeMap = true;
  ChangeLevel();
  return 0;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
  Native_AskLoad();
  RegPluginLibrary("multigame_test");
  return APLRes_Success;
}



#define MAX_VOTE_MAPS 8

// Function to get the list of gamemodes
void GetGames(GameModeMap& hMap, ArrayList &aList)
{
  Gamemode game;
  int iSize = hMap.Size;
  for (int i = 0; i < iSize; i++) 
  {
    hMap.Find(i, game);
    aList.PushString(game.sName);
  }
  aList.Sort(Sort_Random, Sort_String);
}

int GetMaps(const char[] sGamemode, GameModeMap &hMap, 
             ArrayList &aList)
{
  Gamemode game;
  if (!hMap.FindByName(sGamemode, game))
    return 0;
    
  int iLength = game.maplist.Length;
  if (iLength == 0)
    return 0;

  int iPicked = 0;
  bool[] bPicked = new bool[iLength];
  for (int i = 0; i < iLength; i++)
    bPicked[i] = false;
  
  while (iPicked < MAX_VOTE_MAPS && iPicked < iLength)
  {
    int iRandom = GetRandomInt(0, iLength - 1);
    if (bPicked[iRandom])
      continue;

    bPicked[iRandom] = true;
    MapInfo mapinfo;
    game.maplist.GetMap(iRandom, mapinfo);
    aList.PushString(mapinfo.sName);
    iPicked++;
  }

  return iPicked;
}

void SetRandomGameAndMap()
{
  char sSelected[64];
  int iRandomIndex;
  ArrayList aList = new ArrayList(ByteCountToCells(64));

  // Get Gamemodes
  GetGames(g_GameModeMap, aList);
  
  iRandomIndex = GetRandomInt(0, aList.Length - 1);
  aList.GetString(iRandomIndex, sSelected, sizeof(sSelected));
  strcopy(g_sGameName[PREVIOUS], MAX_LENGTH, g_sGameName[CURRENT]);
  strcopy(g_sGameName[CURRENT], MAX_LENGTH, sSelected);
  PrintToServer("[MultiGame] Selected random gamemode: %s", sSelected);
  
  aList.Clear();

  // Get Maps
  GetMaps(sSelected, g_GameModeMap, aList);

  iRandomIndex = GetRandomInt(0, aList.Length - 1);
  aList.GetString(iRandomIndex, sSelected, sizeof(sSelected));
  strcopy(g_sMapName[PREVIOUS], MAX_LENGTH, g_sMapName[CURRENT]);
  strcopy(g_sMapName[CURRENT], MAX_LENGTH, sSelected);
  PrintToServer("[MultiGame] Selected random map: %s", sSelected);

  delete aList;
}

void ChangeLevel()
{
  // Disable all plugins from all gamemodes
  for (int i = 0; i < g_GameModeMap.Size; i++)
  {
    Gamemode gamemode;
    if (g_GameModeMap.Find(i, gamemode))
    {
      int count = gamemode.aPluginList.Length;
      for (int j = 0; j < count; j++)
      {
        char pluginName[64];
        gamemode.aPluginList.GetString(j, pluginName, sizeof(pluginName));
        EnablePlugin(pluginName, false);
      }
    }
  }

  // Enable all plugins for the selected gamemode
  Gamemode selectedMode;
  if (g_GameModeMap.FindByName(g_sGameName[CURRENT], selectedMode))
  {
    int count = selectedMode.aPluginList.Length;
    for (int j = 0; j < count; j++)
    {
      char pluginName[64];
      selectedMode.aPluginList.GetString(j, pluginName, sizeof(pluginName));
      EnablePlugin(pluginName, true);
    }
  }

  ForceChangeLevel(g_sMapName[CURRENT], "Map Vote");
}


enum MenuType
{
  MENUTYPE_GAME,
  MENUTYPE_MAP
}

ArrayList Menu_GetGameList()
{
  ArrayList aList = new ArrayList(ByteCountToCells(64));
  GetGames(g_GameModeMap, aList);

  // Reorder so "saxtonhale" is at the first position.
  char sGamemode[64];
  bool bFound = false;
  for (int i = 0; i < aList.Length; i++) 
  {
    aList.GetString(i, sGamemode, sizeof(sGamemode));
    if (StrEqual(sGamemode, "saxtonhale")) 
    {
      aList.Erase(i);
      bFound = true;
      break;
    }
  }

  if (!bFound) 
  {
    // Optional: log or handle if "saxtonhale" wasn't in original list
    PrintToServer("ERROR: Couldn't find saxtonhale");
  }

  aList.ShiftUp(0);
  aList.SetString(0, "saxtonhale");

  // Shuffle the rest (excluding the first item).
  ArrayList aTailList = new ArrayList(ByteCountToCells(64));
  for (int i = 1; i < aList.Length; i++) 
  {
    aList.GetString(i, sGamemode, sizeof(sGamemode));
    aTailList.PushString(sGamemode);
  }
  aTailList.Sort(Sort_Random, Sort_String);

  // Rebuild aList: saxtonhale + randomized tail
  for (int i = 1; i < aList.Length; i++) 
  {
    aTailList.GetString(i - 1, sGamemode, sizeof(sGamemode));
    aList.SetString(i, sGamemode);
  }
  delete aTailList;
  return aList;
}

void Menu_ShowMenu(MenuType type)
{
  switch (type)
  {
    case MENUTYPE_GAME:
    {
      Menu menu = new Menu(GameMenu_Handler);
      menu.SetTitle("Pick a Game:");
      menu.VoteResultCallback = Handler_GameVoteFinished;
      menu.ExitButton         = false;

      char sGamemode[64];
      ArrayList aList = Menu_GetGameList();
      for (int i = 0; i < 4; i++)
      {
        aList.GetString(i, sGamemode, sizeof(sGamemode));
        menu.AddItem(sGamemode, sGamemode);
      }
      delete aList;
      menu.DisplayVoteToAll(20);
    }
    case MENUTYPE_MAP:
    {
      Menu menu = new Menu(MapMenu_Handler);
      menu.SetTitle("Pick a Map:");
      menu.VoteResultCallback = Handler_MapVoteFinished;
      menu.ExitButton         = false;

      ArrayList aList = new ArrayList(ByteCountToCells(64));
      GetMaps(g_sGameName[CURRENT], g_GameModeMap, aList);

      char sMapName[64];
      for (int i = 0; i < 8; i++)
      {
        aList.GetString(i, sMapName, sizeof(sMapName));
        menu.AddItem(sMapName, sMapName);
      }
      delete aList;

      menu.DisplayVoteToAll(20);
    }
  }
}

public int GameMenu_Handler(Menu hMenu, MenuAction hAction, int iClient, int iItem)
{
  if (hAction == MenuAction_End)
  {
    delete hMenu;
  }
  else if (hAction == MenuAction_Select)
  {
    // Invalid
    if (iItem == -1)
      return 0;

    char sSelected[64];
    hMenu.GetItem(iItem, sSelected, sizeof(sSelected));
    PrintToChatAll("[Multigame] %N has VOTED for %s!", iClient, sSelected);
  }
  return 0;
}

public void Handler_GameVoteFinished(Menu hMenu,
                                     int iNumVotes,
                                     int iNumClients,
                                     const int[][] iClientInfo,
                                     int iNumItems,
                                     const int[][] iItemInfo)
{
  char sSelected[64];
  int iWinningIndex = iItemInfo[0][0];
  //int iVoteCount = iItemInfo[0][1];

  hMenu.GetItem(iWinningIndex, sSelected, sizeof(sSelected));
  strcopy(g_sGameName[PREVIOUS], MAX_LENGTH, g_sGameName[CURRENT]);
  strcopy(g_sGameName[CURRENT], MAX_LENGTH, sSelected);  
  Menu_ShowMenu(MENUTYPE_MAP);
}

public int MapMenu_Handler(Menu hMenu, MenuAction hAction, int iClient, int iItem)
{
  if (hAction == MenuAction_End)
  {
    delete hMenu;
  }
  else if (hAction == MenuAction_Select)
  {
    // Invalid
    if (iItem == -1)
      return 0;

    char sSelected[64];
    hMenu.GetItem(iItem, sSelected, sizeof(sSelected));
    PrintToChatAll("%N VOTED for %s", iClient, sSelected);
  }
  return 0;
}


public void Handler_MapVoteFinished(Menu hMenu,
                                    int iNumVotes,
                                    int iNumClients,
                                    const int[][] iClientInfo,
                                    int iNumItems,
                                    const int[][] iItemInfo)
{
  char sSelected[64];
  int iWinningIndex = iItemInfo[0][0];
  //int iVoteCount = iItemInfo[0][1];

  hMenu.GetItem(iWinningIndex, sSelected, sizeof(sSelected));
  strcopy(g_sMapName[PREVIOUS], MAX_LENGTH, g_sMapName[CURRENT]);
  strcopy(g_sMapName[CURRENT], MAX_LENGTH, sSelected);

  if (!AreMapsSame())
    g_bChangeMap = true;
  else {
    ExtendMapTimeLimit(g_iStartingMapTime);
    // Recall this.
    OnMapStart();
    OnMapEnd();
  }
}

public void OnPluginStart()
{
  strcopy(g_sGameName[CURRENT], 64, "default_gamemode");
  strcopy(g_sMapName[CURRENT], 64, "default_map");

  g_hCvars.mp_timelimit      = FindConVar("mp_timelimit");
  g_hCvars.mp_winlimit       = FindConVar("mp_winlimit");
  g_hCvars.mp_maxrounds      = FindConVar("mp_maxrounds");
  g_hCvars.mp_fraglimit      = FindConVar("mp_fraglimit");
  g_hCvars.mp_bonusroundtime = FindConVar("mp_bonusroundtime"); 

  Config_Refresh();

  HookEvent("teamplay_round_win", Event_RoundEnd);
}

public void OnMapStart()
{
  g_iStartingMapTime = g_hCvars.mp_timelimit.IntValue * 60;
  
  // Early timer. Used for Voting
  CreateTimer(float(g_iStartingMapTime-240), Timer_MenuDisplay, _, TIMER_FLAG_NO_MAPCHANGE);

  // Fallback
  CreateTimer(float(g_iStartingMapTime), Timer_MenuDisplay, _, TIMER_FLAG_NO_MAPCHANGE);

  // Set Server name
  SetServerName();
}

public void OnMapEnd()
{
  g_iTotalRoundPlayed = 0;
  g_bChangeMap = false;
}

public Action Timer_MenuDisplay(Handle hTimer)
{
  if (g_bChangeMap)
  {
    ChangeLevel();
    return Plugin_Handled;
  }

  if (GetValidPlayers() == 0)
  {
    SetRandomGameAndMap();
    ChangeLevel();
    return Plugin_Handled;
  }

  Menu_ShowMenu(MENUTYPE_GAME);
  return Plugin_Handled;
}

public Action Timer_DelayedLevelChange(Handle hTimer)
{
  ChangeLevel();
  return Plugin_Handled;
}

public void Event_RoundEnd(Event event, const char[] sName, bool bDontBroadcast)
{
  g_iTotalRoundPlayed++;
  if (g_bChangeMap) 
  {
    CreateTimer(10.0, Timer_DelayedLevelChange, _, TIMER_FLAG_NO_MAPCHANGE);
    return;
  }

  // Minus 1 round so we can display change game / map
  int iMaxRounds = g_hCvars.mp_maxrounds.IntValue - 1;
  if (g_iTotalRoundPlayed >= iMaxRounds && iMaxRounds > 0 && !g_bChangeMap)
  {
    Menu_ShowMenu(MENUTYPE_GAME);
    g_bChangeMap = true;
  }
}

stock void StrToUpper(char[] sBuffer)
{
  int iLength = strlen(sBuffer);
  for (int i = 0; i < iLength; i++)
  {
    sBuffer[i] = CharToUpper(sBuffer[i]);
  }
}

stock void SetServerName()
{
  char sDescription[64];
  strcopy(sDescription, sizeof(sDescription), g_sGameName[CURRENT]);
  SteamWorks_SetGameDescription(sDescription);
  
  StrToUpper(sDescription);
  
  char sHostname[64];
  Format(sHostname, sizeof(sHostname), "█ Issari.TF | %s | SG █", sDescription);
  ServerCommand("hostname %s", sHostname);
}

stock void EnablePlugin(const char[] sFilename, bool bEnable) 
{
  char sDisabledPath[PLATFORM_MAX_PATH];
  char sEnabledPath[PLATFORM_MAX_PATH];
  
  BuildPath(Path_SM, sDisabledPath, sizeof(sDisabledPath), 
    "plugins/disabled/%s.smx", sFilename);
  BuildPath(Path_SM, sEnabledPath, sizeof(sEnabledPath),
    "plugins/%s.smx", sFilename);
  
  if (bEnable) 
  {
    if (!FileExists(sDisabledPath) 
      || FileExists(sEnabledPath))
    return;

    RenameFile(sEnabledPath, sDisabledPath);
  }
  else
  {
    if (!FileExists(sEnabledPath)
      || FileExists(sDisabledPath))
    return;

    RenameFile(sDisabledPath, sEnabledPath);
  }
}

stock bool IsValidClient(const int iClient, bool bReplayCheck=true)
{
  if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
    return false;
  else if (GetEntProp(iClient, Prop_Send, "m_bIsCoaching"))
    return false;
  else if (bReplayCheck && (IsClientSourceTV(iClient) || IsClientReplay(iClient)))
    return false;
  else if (TF2_GetPlayerClass(iClient) == TFClass_Unknown)
    return false;
  return true;
}

stock bool AreMapsSame()
{
  return StrEqual(g_sMapName[CURRENT], g_sMapName[PREVIOUS], false);
}

stock int GetValidPlayers()
{
  int count = 0;
  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsValidClient(i))
    {
      count++;
    }
  }
  return count;
}