#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include "include/multigame.inc"

#define TEXT_TAG "[MultiGame] "

#define PLUGIN_VERSION          "1.0.0"
#define PLUGIN_VERSION_REVISION "manual"
#define PLUGIN_DESCRIPTION      "Multiple Gamemodes for Team Fortress 2"
#define PLUGIN_URL              "https://github.com/lessari-tf/Multigame"

Multigame mg;  // methodmap instance

enum struct Cvars
{
  ConVar Needed;
  ConVar MinPlayers;
  ConVar Delay;
  ConVar Interval;
}

enum struct VoteSystem 
{
  Cvars hCvars;
  bool  bAllowed;
  int   iPlayers;
  int   iCount;
  int   iNeeded;
  
  void Reset()
  {
    this.bAllowed = false;
    this.iPlayers = 0;
    this.iCount   = 0;
    this.iNeeded  = 0; 
  }
}
VoteSystem g_VoteSystem;

bool bPlayerVoted[MAXPLAYERS+1];

public Plugin myinfo = 
{
  name        = "Multivote",
  author      = "Aidan Sanders",
  description =  PLUGIN_DESCRIPTION,
  version     =  PLUGIN_VERSION ... "." ... PLUGIN_VERSION_REVISION,
  url         =  PLUGIN_URL,
};

public void OnPluginStart()
{
  g_VoteSystem.Reset();
  
  g_VoteSystem.hCvars.Needed = CreateConVar(
    "votes_needed", "0.50", 
    "Percentage needed to vote to switch",
    0, true, 0.05, true, 1.0);
  
  g_VoteSystem.hCvars.MinPlayers = CreateConVar(
    "votes_min_players", "0", 
    "Minimum players before vote will be enabled",
    0, true, 0.0, true, float(MAXPLAYERS));
  
  g_VoteSystem.hCvars.Delay = CreateConVar(
    "votes_delay", "0.0",
    "Time (in seconds) before first vote can be held",
    0, true, 0.00);
  
  g_VoteSystem.hCvars.Interval = CreateConVar(
    "votes_interval", "10.0",
    "Time (in seconds) after a failed vote before another can be held",
    0, true, 0.00);
  
  RegConsoleCmd("sm_rtv", Command_RockTheVote);
  
  AutoExecConfig(true, "multivote");
  OnMapEnd();

  for (int iClient = 1; iClient <= MaxClients; iClient++)
  {
    if (IsClientConnected(iClient))
    {
      OnClientConnected(iClient);
    }
  }
}

public void OnMapStart()
{
  CreateTimer(60.0, Timer_ChatMessage);
  CreateTimer(240.0, Timer_ChatMessage, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ChatMessage(Handle hTimer)
{
  PrintToChatAll("%sType !rtv to change map or gamemode", TEXT_TAG);
  return Plugin_Continue;
}

public void OnMapEnd()
{
  g_VoteSystem.Reset();
}

public void OnConfigsExecuted()
{
  CreateTimer(g_VoteSystem.hCvars.Delay.FloatValue, 
    Timer_DelayVote, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientConnected(int iClient)
{
  if (!IsFakeClient(iClient))
  {
    g_VoteSystem.iPlayers++;
    g_VoteSystem.iNeeded = RoundToCeil(
      float(g_VoteSystem.iPlayers) * g_VoteSystem.hCvars.Needed.FloatValue);
  }
}

public void OnClientDisconnect(int iClient)
{
  if (bPlayerVoted[iClient])
  {
    g_VoteSystem.iCount--;
    bPlayerVoted[iClient] = false;
  }

  if (!IsFakeClient(iClient))
  {
    g_VoteSystem.iPlayers--;
    g_VoteSystem.iNeeded = RoundToCeil(
      float(g_VoteSystem.iPlayers) * g_VoteSystem.hCvars.Needed.FloatValue);
  }

  if (g_VoteSystem.iCount 
   && g_VoteSystem.iPlayers 
   && g_VoteSystem.iCount >= g_VoteSystem.iNeeded
   && g_VoteSystem.bAllowed)
  {
    Vote_Start();
  }
}

public void OnClientSayCommand_Post(int iClient, 
  const char[] sCommand, const char[] sArgs)
{
  if (!iClient || IsChatTrigger())
    return;
  
  if (strcmp(sArgs, "rtv", false) == 0 
   || strcmp(sArgs, "rockthevote", false) == 0)
  {
    ReplySource hReplySource = SetCmdReplySource(SM_REPLY_TO_CHAT);
    Vote_Attempt(iClient);
    SetCmdReplySource(hReplySource);
  }
}

public Action Command_RockTheVote(int iClient, int iArgc)
{
  if (!iClient)
    return Plugin_Continue;
  
  Vote_Attempt(iClient);
  return Plugin_Handled;
}


public Action Timer_DelayVote(Handle hTimer)
{
  g_VoteSystem.bAllowed = true;
  return Plugin_Continue;
}

void Vote_Attempt(int iClient)
{
  if (bPlayerVoted[iClient])
  {
    ReplyToCommand(iClient, 
      "[Multigame] You have already voted (%i votes, %i required)",
      g_VoteSystem.iCount, g_VoteSystem.iNeeded);
    return;
  }

  if (!g_VoteSystem.bAllowed)
  {
    ReplyToCommand(iClient,
      "[Multigame] Voting is not allowed yet.");
    return;
  }

  if (GetClientCount(true) < g_VoteSystem.hCvars.MinPlayers.IntValue)
  {
    ReplyToCommand(iClient, 
      "[Multigame] Not enough players (%i required)", 
      g_VoteSystem.hCvars.MinPlayers.IntValue);
    return;
  }

  char sName[MAX_NAME_LENGTH];
  GetClientName(iClient, sName, sizeof(sName));

  g_VoteSystem.iCount++;
  bPlayerVoted[iClient] = true;
  PrintToChatAll("%s%s has voted to change. (%i votes, %i required)",
    TEXT_TAG, sName, g_VoteSystem.iCount, g_VoteSystem.iNeeded);
  
  if (g_VoteSystem.iCount >= g_VoteSystem.iNeeded)
  {
    Vote_Start();
  }
}

void Vote_Start()
{
  mg.DisplayMenu();
  g_VoteSystem.bAllowed = false;
  g_VoteSystem.iCount = 0;

  for (int iClient = 1; iClient <= MaxClients; iClient++)
  {
    bPlayerVoted[iClient] = false;
  }
}