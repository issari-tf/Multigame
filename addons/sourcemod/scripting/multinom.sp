#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include "include/multigame.inc"

#define TEXT_TAG "[MultiGame] "

#define PLUGIN_VERSION          "1.0.0"
#define PLUGIN_VERSION_REVISION "manual"
#define PLUGIN_DESCRIPTION      "Multigame addon - adds nominations"
#define PLUGIN_URL              "https://github.com/lessari-tf/Multigame"

public Plugin myinfo = 
{
  name        = "Multinom",
  author      = "Aidan Sanders",
  description =  PLUGIN_DESCRIPTION,
  version     =  PLUGIN_VERSION ... "." ... PLUGIN_VERSION_REVISION,
  url         =  PLUGIN_URL,
};

#define MAX_MAPS 128
#define MAX_MAP_NAME_LENGTH 64

Multigame mg;  // methodmap instance

char g_sPlayerNominations[MAXPLAYERS + 1][MAX_MAP_NAME_LENGTH];

void Menu_ShowNominationMenu(int client)
{
  if (!IsClientInGame(client) || !IsPlayerAlive(client))
    return;

  Menu menu = new Menu(MenuHandler_Nominate);
  menu.SetTitle("Choose a map to nominate:");
  menu.ExitButton = true;

  char sGamemode[64];
  mg.GetCurrentGameMode(sGamemode, sizeof(sGamemode));
  
  int iGameCount = mg.GetGamemodeCount();
  
  ArrayList aMapList = new ArrayList(ByteCountToCells(64));

  // Fetch Maps for Game
  for (int i = 0; i < iGameCount; i++)
  {
    char sBuffer[64];
    mg.GetGamemodeName(i, sBuffer, sizeof(sBuffer));
    if (StrEqual(sBuffer, sGamemode))
    {
      char sMapBuffer[64];
      int iMapCount = mg.GetMapCount(i);
      for (int j = 0; j < iMapCount; j++)
      {
        mg.GetMapName(i, j, sMapBuffer, sizeof(sMapBuffer));        
        aMapList.PushString(sMapBuffer);
      }
      break;
    }
  }

  // Add to menu
  char sMapName[64];
  for (int i = 0; i < aMapList.Length; i++)
  {
    aMapList.GetString(i, sMapName, sizeof(sMapName));

    bool bNominated = false;
    for (int j = 1; j <= MaxClients; j++)
    {
      if (IsClientInGame(j) && strlen(g_sPlayerNominations[j]) > 0)
      {
        if (StrEqual(g_sPlayerNominations[j], sMapName))
        {
          bNominated = true;
          break;
        }
      }
    }

    char sText[96];
    if (bNominated)
    {
      Format(sText, sizeof(sText), "%s (nominated)", sMapName);
      menu.AddItem(sMapName, sText, ITEMDRAW_DISABLED);
    }
    else
    {
      menu.AddItem(sMapName, sMapName);
    }
  }

  delete aMapList;
  menu.Display(client, 20);
}

public int MenuHandler_Nominate(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Select)
    {
        if (item < 0 || !IsClientInGame(client)) return 0;

        char mapName[64];
        menu.GetItem(item, mapName, sizeof(mapName));

        strcopy(g_sPlayerNominations[client], sizeof(g_sPlayerNominations[]), mapName);
        PrintToChat(client, "[\x04Nominate\x01] You nominated: \x04%s", mapName);
    }

    return 0;
}

public Action Command_NominateMenu(int iClient, int args)
{
  Menu_ShowNominationMenu(iClient);
  return Plugin_Handled;
}

public void OnPluginStart()
{
  RegConsoleCmd("sm_nominate", Command_NominateMenu);
}

public void OnMapStart()
{
  for (int i = 1; i <= MaxClients; i++)
  {
    g_sPlayerNominations[i][0] = '\0'; // Sets the first char to null terminator = empty string
  }
}