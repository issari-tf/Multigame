#if defined _multigame_included
  #endinput
#endif
#define _multigame_included

methodmap Multigame
{
  // Gets current gamemode name
  public native void GetCurrentGameMode(char[] sBuffer, int iMaxlen);

  // Gets current map name
  public native void GetCurrentMapName(char[] sBuffer, int iMaxlen);

  // Sets current gamemode name
  public native bool SetCurrentGameMode(const char[] sBuffer, int iMaxlen);

  // Sets current map name
  public native bool SetCurrentMapName(const char[] sBuffer, int iMaxlen);
  
  // Get Gamemode Count
  public native int GetGamemodeCount();

  // Get Gamemode from config
  public native void GetGamemodeName(int index, char[] sBuffer, int iMaxlen);

  // Get Map Count of Gamemode
  public native int GetMapCount(int iGameIndex);

  // Get Map Name from Gamemode
  public native void GetMapName(int iGameIndex, int iMapIndex, char[] sBuffer, int iMaxlen);

  // Display Internal Menu
  public native int DisplayMenu();

  // Change Map & Game
  public native int ChangeLevel();
}

public SharedPlugin __pl_multigame =
{
  name = "multigame",
  file = "multigame.smx",
#if defined REQUIRE_PLUGIN
  required = 1,
#else
  required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_multigame_SetNTVOptional()
{
  MarkNativeAsOptional("Multigame.GetCurrentGameMode");
  MarkNativeAsOptional("Multigame.GetCurrentMapName");
  MarkNativeAsOptional("Multigame.SetCurrentGameMode");
  MarkNativeAsOptional("Multigame.SetCurrentMapName");
  MarkNativeAsOptional("Multigame.GetGamemodeCount");
  MarkNativeAsOptional("Multigame.GetGamemodeName");
  MarkNativeAsOptional("Multigame.GetMapCount");
  MarkNativeAsOptional("Multigame.GetMapName");
  MarkNativeAsOptional("Multigame.DisplayMenu");
  MarkNativeAsOptional("Multigame.ChangeLevel");
}
#endif