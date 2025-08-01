#pragma semicolon 1 
#pragma newdecls required

#include <sourcemod>
#include <adminmenu>
#include "include/multigame.inc"

#define TEXT_TAG "[MultiGame] "

#define PLUGIN_VERSION          "1.0.0"
#define PLUGIN_VERSION_REVISION "manual"
#define PLUGIN_DESCRIPTION      "Multigame addon - Gives Admins Controls"
#define PLUGIN_URL              "https://github.com/lessari-tf/Multigame"

public Plugin myinfo = 
{
  name        = "Multiadmin",
  author      = "Aidan Sanders",
  description =  PLUGIN_DESCRIPTION,
  version     =  PLUGIN_VERSION ... "." ... PLUGIN_VERSION_REVISION,
  url         =  PLUGIN_URL,
};

Multigame mg;

TopMenu g_TopMenu;

public void OnPluginStart()
{
    RegConsoleCmd("sm_multigame_admin", Command_AdminMenu);

    TopMenu topmenu = GetAdminTopMenu();
    if (topmenu != null)
    {
        OnAdminMenuReady(topmenu);
    }
}

// Called when admin menu is ready
public void OnAdminMenuReady(Handle topmenu)
{
    TopMenu obj = TopMenu.FromHandle(topmenu);
    g_TopMenu = obj;

    TopMenuObject menu = obj.AddCategory("Multigame", TopMenuHandler_MultigameCategory);
    obj.AddItem("Multigame_ChangeMode", TopMenuHandler_ChangeMode, menu, "sm_multigame_admin", ADMFLAG_GENERIC);
}

public Action Command_AdminMenu(int client, int args)
{
    if (!IsClientInGame(client) || !IsClientAuthorized(client))
        return Plugin_Handled;

    if (g_TopMenu != null)
    {
        g_TopMenu.Display(client, TopMenuPosition_LastCategory);
    }

    return Plugin_Handled;
}

// Top-level category label
public void TopMenuHandler_MultigameCategory(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayTitle || action == TopMenuAction_DisplayOption)
    {
        strcopy(buffer, maxlength, "Multigame Options");
    }
}

// Menu item label
public void TopMenuHandler_ChangeMode(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        strcopy(buffer, maxlength, "Change Gamemode");
    }
    else if (action == TopMenuAction_SelectOption)
    {
        ShowGamemodeMenu(param);
    }
}

void ShowGamemodeMenu(int client)
{
    Menu menu = new Menu(MenuHandler_GamemodeSelect);
    menu.SetTitle("Select a Gamemode");

    int count = mg.GetGamemodeCount();
    for (int i = 0; i < count; i++)
    {
        char sName[64];
        mg.GetGamemodeName(i, sName, sizeof(sName));
        menu.AddItem(sName, sName); // both display and info = gamemode name
    }

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_GamemodeSelect(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Select)
    {
        char sGamemode[64];
        menu.GetItem(item, sGamemode, sizeof(sGamemode));
        mg.SetCurrentGameMode(sGamemode, sizeof(sGamemode));
        PrintToChat(client, "%s Gamemode changed to \x04%s", TEXT_TAG, sGamemode);

        // Optionally show map menu too
        ShowMapMenu(client, sGamemode);
    }

    return 0;
}

void ShowMapMenu(int client, const char[] gamemode)
{
    Menu menu = new Menu(MenuHandler_MapSelect);
    menu.SetTitle("Select a Map");

    int count = mg.GetGamemodeCount();
    for (int i = 0; i < count; i++)
    {
      char sBuffer[64];
      mg.GetGamemodeName(i, sBuffer, sizeof(sBuffer));
      if (StrEqual(sBuffer, gamemode))
      {
        char sMapBuffer[64];
        int iMapCount = mg.GetMapCount(i);
        for (int j = 0; j < iMapCount; j++)
        {
            mg.GetMapName(i, j, sMapBuffer, sizeof(sMapBuffer));        
            menu.AddItem(sMapBuffer, sMapBuffer);
            PrintToChat(client, sMapBuffer);
        }
        break;
      }
    }

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_MapSelect(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Select)
    {
        char sMap[64];
        menu.GetItem(item, sMap, sizeof(sMap));
        mg.SetCurrentMapName(sMap, sizeof(sMap));
        PrintToChat(client, "%s Map changed to \x04%s", TEXT_TAG, sMap);
        mg.ChangeLevel();
    }

    return 0;
}
