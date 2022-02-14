//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define IS_PLUGIN
#define PLUGIN_DESCRIPTION "A Team Fortress 2 custom gamemode."
#define PLUGIN_VERSION "1.0.0"

#define FUNCTION_PERK_ONPERKEQUIP 0
#define FUNCTION_PERK_ONPERKUNEQUIP 1
#define FUNCTION_PERK_ONSPAWNWITHPERK 2
#define FUNCTION_PERK_ONDIEWITHPERK 3

//Sourcemod Includes
#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>
#include <tf2attributes>

//Our Includes
#include <alienfortress/alienfortress-core>
#include <alienfortress/alienfortress-mechanics>

//ConVars
ConVar convar_ChangePerkAtSpawn;
ConVar convar_ChangePerkOnRespawn;

//Forwards
Handle g_hForward_OnRegisteringPerks;
Handle g_hForward_OnTakeDamage;
Handle g_hForward_OnTakeDamage_Post;
Handle g_hForward_GetMaxHealth;

//Globals
bool g_bLate;
//bool g_bBetweenRounds;

ArrayList g_hArray_PerksList;
StringMap g_hTrie_PerkTeams;
StringMap g_hTrie_PerkFunctions;

int g_iCurrentPerk[MAXPLAYERS + 1][TFTeam];
int g_iQueuedPerk[MAXPLAYERS + 1][TFTeam];
int g_iPerkCooldown[MAXPLAYERS + 1][TFTeam];
bool g_bIsInRespawnZone[MAXPLAYERS + 1];

//Plugin Info
public Plugin myinfo =
{
	name = "[TF2] Gamemode: Alien Fortress",
	author = "Drixevel",
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = "https://drixevel.dev/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("alienfortress_core");

	CreateNative("AlienFortress_RegisterPerk", Native_RegisterPerk);
	CreateNative("AlienFortress_UnregisterPerk", Native_UnregisterPerk);
	CreateNative("AlienFortress_GetClientPerk", Native_GetClientPerk);

	g_hForward_OnRegisteringPerks = CreateGlobalForward("AlienFortress_OnRegisteringPerks", ET_Ignore);
	g_hForward_OnTakeDamage = CreateGlobalForward("AlienFortress_OnTakeDamage", ET_Event, Param_Cell, Param_Cell, Param_CellByRef, Param_Cell, Param_CellByRef, Param_Cell, Param_FloatByRef, Param_CellByRef, Param_CellByRef, Param_Array, Param_Array, Param_Cell);
	g_hForward_OnTakeDamage_Post = CreateGlobalForward("AlienFortress_OnTakeDamage_Post", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Cell, Param_Cell, Param_Array, Param_Array, Param_Cell);
	g_hForward_GetMaxHealth = CreateGlobalForward("AlienFortress_GetMaxHealth", ET_Event, Param_Cell, Param_Cell, Param_CellByRef);

	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_ChangePerkAtSpawn = CreateConVar("sm_alienfortress_changeperkatspawn", "0", "Allow players to change their perks at spawn freely.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_ChangePerkOnRespawn = CreateConVar("sm_alienfortress_changeperkonrespawn", "1", "Allow players to change their perks and take effect after respawn.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	RegConsoleCmd("sm_af", Command_ShowMenu);
	RegConsoleCmd("sm_zf", Command_ShowMenu);

	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_team", Event_OnPlayerTeam);
	HookEvent("player_death", Event_OnPlayerDeath);
	HookEvent("arena_round_start", Event_OnArenaRoundStart);
	HookEvent("teamplay_round_win", Event_OnRoundWin);

	g_hArray_PerksList = CreateArray(ByteCountToCells(MAX_PERK_NAME_LENGTH));
	g_hTrie_PerkTeams = CreateTrie();
	g_hTrie_PerkFunctions = CreateTrie();

	RegAdminCmd("sm_resetperks", Command_ReloadPerks, ADMFLAG_ROOT);
	RegAdminCmd("sm_reloadperks", Command_ReloadPerks, ADMFLAG_ROOT);
	RegAdminCmd("sm_resetattributes", Command_ResetAttributes, ADMFLAG_ROOT);
	RegAdminCmd("sm_reloadattributes", Command_ResetAttributes, ADMFLAG_ROOT);
}

public void OnConfigsExecuted()
{
	if (g_bLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}
		}

		int entity = INVALID_ENT_INDEX;
		while ((entity = FindEntityByClassname(entity, "*")) != INVALID_ENT_INDEX)
		{
			char sClassname[64];
			GetEntityClassname(entity, sClassname, sizeof(sClassname));
			OnEntityCreated(entity, sClassname);
		}

		ReloadPerks();

		g_bLate = false;
	}
}

public void OnAllPluginsLoaded()
{
	ReloadPerks();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamagePost, Hook_OnTakeDamagePost);
	SDKHook(client, SDKHook_GetMaxHealth, Hook_GetMaxHealth);

	g_iCurrentPerk[client][TFTeam_Unassigned] = INVALID_PERK_ID;
	g_iCurrentPerk[client][TFTeam_Spectator] = INVALID_PERK_ID;
	g_iCurrentPerk[client][TFTeam_Red] = INVALID_PERK_ID;
	g_iCurrentPerk[client][TFTeam_Blue] = INVALID_PERK_ID;

	g_iQueuedPerk[client][TFTeam_Unassigned] = INVALID_PERK_ID;
	g_iQueuedPerk[client][TFTeam_Spectator] = INVALID_PERK_ID;
	g_iQueuedPerk[client][TFTeam_Red] = INVALID_PERK_ID;
	g_iQueuedPerk[client][TFTeam_Blue] = INVALID_PERK_ID;

	g_iPerkCooldown[client][TFTeam_Unassigned] = 0;
	g_iPerkCooldown[client][TFTeam_Spectator] = 0;
	g_iPerkCooldown[client][TFTeam_Red] = 0;
	g_iPerkCooldown[client][TFTeam_Blue] = 0;
}

public void OnClientDisconnect(int client)
{
	if (IsClientInGame(client))
	{
		TFTeam team = TF2_GetClientTeam(client);

		if (g_iCurrentPerk[client][team] != INVALID_PERK_ID)
		{
			ExecutePerkFunction(client, g_iCurrentPerk[client][team], FUNCTION_PERK_ONPERKUNEQUIP, true);
		}
	}

	g_iCurrentPerk[client][TFTeam_Unassigned] = INVALID_PERK_ID;
	g_iCurrentPerk[client][TFTeam_Spectator] = INVALID_PERK_ID;
	g_iCurrentPerk[client][TFTeam_Red] = INVALID_PERK_ID;
	g_iCurrentPerk[client][TFTeam_Blue] = INVALID_PERK_ID;

	g_iQueuedPerk[client][TFTeam_Unassigned] = INVALID_PERK_ID;
	g_iQueuedPerk[client][TFTeam_Spectator] = INVALID_PERK_ID;
	g_iQueuedPerk[client][TFTeam_Red] = INVALID_PERK_ID;
	g_iQueuedPerk[client][TFTeam_Blue] = INVALID_PERK_ID;

	g_iPerkCooldown[client][TFTeam_Unassigned] = 0;
	g_iPerkCooldown[client][TFTeam_Spectator] = 0;
	g_iPerkCooldown[client][TFTeam_Red] = 0;
	g_iPerkCooldown[client][TFTeam_Blue] = 0;

	g_bIsInRespawnZone[client] = false;
}

/*-------------------------------------------------------*/
//	SDK Hook Callbacks
/*-------------------------------------------------------*/

public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	Action results;

	Call_StartForward(g_hForward_OnTakeDamage);
	Call_PushCell(victim);
	Call_PushCell(IsPlayerIndex(victim) ? AlienFortress_GetClientPerk(victim, TF2_GetClientTeam(victim)) : INVALID_PERK_ID);
	Call_PushCellRef(attacker);
	Call_PushCell(IsPlayerIndex(attacker) ? AlienFortress_GetClientPerk(attacker, TF2_GetClientTeam(attacker)) : INVALID_PERK_ID);
	Call_PushCellRef(inflictor);
	Call_PushCell(IsPlayerIndex(inflictor) ? AlienFortress_GetClientPerk(inflictor, TF2_GetClientTeam(inflictor)) : INVALID_PERK_ID);
	Call_PushFloatRef(damage);
	Call_PushCellRef(damagetype);
	Call_PushCellRef(weapon);
	Call_PushArrayEx(damageForce, sizeof(damageForce), SM_PARAM_COPYBACK);
	Call_PushArrayEx(damagePosition, sizeof(damagePosition), SM_PARAM_COPYBACK);
	Call_PushCell(damagecustom);
	Call_Finish(results);

	return results;
}

public void Hook_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	Call_StartForward(g_hForward_OnTakeDamage_Post);
	Call_PushCell(victim);
	Call_PushCell(IsPlayerIndex(victim) ? AlienFortress_GetClientPerk(victim, TF2_GetClientTeam(victim)) : INVALID_PERK_ID);
	Call_PushCell(attacker);
	Call_PushCell(IsPlayerIndex(attacker) ? AlienFortress_GetClientPerk(attacker, TF2_GetClientTeam(attacker)) : INVALID_PERK_ID);
	Call_PushCell(inflictor);
	Call_PushCell(IsPlayerIndex(inflictor) ? AlienFortress_GetClientPerk(inflictor, TF2_GetClientTeam(inflictor)) : INVALID_PERK_ID);
	Call_PushFloat(damage);
	Call_PushCell(damagetype);
	Call_PushCell(weapon);
	Call_PushArray(damageForce, sizeof(damageForce));
	Call_PushArray(damagePosition, sizeof(damagePosition));
	Call_PushCell(damagecustom);
	Call_Finish();
}

public Action Hook_GetMaxHealth(int entity, int &maxhealth)
{
	Action results;

	Call_StartForward(g_hForward_GetMaxHealth);
	Call_PushCell(entity);
	Call_PushCell(IsPlayerIndex(entity) ? AlienFortress_GetClientPerk(entity, TF2_GetClientTeam(entity)) : INVALID_PERK_ID);
	Call_PushCellRef(maxhealth);
	Call_Finish(results);

	return results;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "func_respawnroom"))
	{
		SDKHook(entity, SDKHook_StartTouchPost, OnRespawnRoomStartTouch);
		SDKHook(entity, SDKHook_EndTouchPost, OnRespawnRoomEndTouch);
	}
}

public void OnRespawnRoomStartTouch(int entity, int other)
{
	if (IsPlayerIndex(other))
	{
		g_bIsInRespawnZone[other] = true;
	}
}

public void OnRespawnRoomEndTouch(int entity, int other)
{
	if (IsPlayerIndex(other))
	{
		g_bIsInRespawnZone[other] = false;
	}
}

/*-------------------------------------------------------*/
//	Events
/*-------------------------------------------------------*/

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);

	if (client == 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client))
	{
		return;
	}

	TFTeam team = TF2_GetClientTeam(client);

	if (g_iQueuedPerk[client][team] > -1)
	{
		g_iCurrentPerk[client][team] = g_iQueuedPerk[client][team];
		g_iQueuedPerk[client][team] = -1;
	}

	ExecutePerkFunction(client, g_iCurrentPerk[client][team], FUNCTION_PERK_ONSPAWNWITHPERK);
}

public void Event_OnPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);

	if (client == 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client))
	{
		return;
	}

	int old_team = GetEventInt(event, "oldteam");
	int team = GetEventInt(event, "team");

	if (old_team == team)
	{
		return;
	}

	ExecutePerkFunction(client, g_iCurrentPerk[client][old_team], FUNCTION_PERK_ONPERKUNEQUIP);

	DataPack pack;
	CreateDataTimer(0.2, Timer_DelayReequip, pack, TIMER_FLAG_NO_MAPCHANGE);
	WritePackCell(pack, GetClientUserId(client));
	WritePackCell(pack, team);
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);

	if (!IsPlayerIndex(client) || !IsClientInGame(client) || IsFakeClient(client))
	{
		return;
	}

	int attacker_userid = GetEventInt(event, "attacker");
	int attacker_client = GetClientOfUserId(attacker_userid);

	TFTeam team = TF2_GetClientTeam(client);

	ExecutePerkFunction(client, g_iCurrentPerk[client][team], FUNCTION_PERK_ONDIEWITHPERK, attacker_client);
}

public void Event_OnArenaRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	//g_bBetweenRounds = false;
}

public void Event_OnRoundWin(Event event, const char[] name, bool dontBroadcast)
{
	//g_bBetweenRounds = true;
}

/*-------------------------------------------------------*/
//	Command - Reload Perks
/*-------------------------------------------------------*/

public Action Command_ReloadPerks(int client, int args)
{
	ReloadPerks();
	ReplyToCommand(client, "Perks have been reloaded.");
	return Plugin_Handled;
}

/*-------------------------------------------------------*/
//	Command - Reload Attributes
/*-------------------------------------------------------*/

public Action Command_ResetAttributes(int client, int args)
{
	TF2Attrib_RemoveAll(client);
	TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.0);

	for (int i = 0; i < 5; i++)
	{
		int weapon = GetPlayerWeaponSlot(client, i);

		if (IsValidEntity(weapon))
		{
			TF2Attrib_RemoveAll(weapon);
		}
	}

	PrintToChat(client, "Attributes reset on you and your weapons.");
	return Plugin_Handled;
}

/*-------------------------------------------------------*/
//	Reload Perks
/*-------------------------------------------------------*/

void ClearAllClientPerks()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			TFTeam team = TF2_GetClientTeam(i);

			if (g_iCurrentPerk[i][team] != INVALID_PERK_ID)
			{
				ExecutePerkFunction(i, g_iCurrentPerk[i][team], FUNCTION_PERK_ONPERKUNEQUIP, true);
			}
		}

		g_iCurrentPerk[i][TFTeam_Unassigned] = INVALID_PERK_ID;
		g_iCurrentPerk[i][TFTeam_Spectator] = INVALID_PERK_ID;
		g_iCurrentPerk[i][TFTeam_Red] = INVALID_PERK_ID;
		g_iCurrentPerk[i][TFTeam_Blue] = INVALID_PERK_ID;
	}
}

void ReloadPerks()
{
	ClearAllClientPerks();

	ClearArray(g_hArray_PerksList);
	ClearTrie(g_hTrie_PerkTeams);
	ClearTrie(g_hTrie_PerkFunctions);

	Call_StartForward(g_hForward_OnRegisteringPerks);
	Call_Finish();
}

/*-------------------------------------------------------*/
//	Command - Main Menu
/*-------------------------------------------------------*/

public Action Command_ShowMenu(int client, int args)
{
	ShowMainMenu(client);
	return Plugin_Handled;
}

/*-------------------------------------------------------*/
//	Main Menu
/*-------------------------------------------------------*/

void ShowMainMenu(int client)
{
	Menu menu = CreateMenu(MenuHandler_ShowMainMenu);
	SetMenuTitle(menu, "Alien Fortress - Version: %s", PLUGIN_VERSION);

	AddMenuItem(menu, "survivor_perks", "Survivor Perks");
	AddMenuItem(menu, "alien_perks", "Alien Perks");
	AddMenuItem(menu, "team_preferences", "Team Preferences");
	AddMenuItem(menu, "class_info", "Class Information");

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandler_ShowMainMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "survivor_perks"))
			{
				ShowPerksMenu(param1, TFTeam_Red, true);
			}
			else if (StrEqual(sInfo, "alien_perks"))
			{
				ShowPerksMenu(param1, TFTeam_Blue, true);
			}
			else if (StrEqual(sInfo, "team_preferences"))
			{
				ShowTeamPreferencesMenu(param1);
			}
			else if (StrEqual(sInfo, "class_info"))
			{
				ShowClassInfoMenu(param1);
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

/*-------------------------------------------------------*/
//	Perks Menu
/*-------------------------------------------------------*/

void ShowPerksMenu(int client, TFTeam team, bool equip = false)
{
	char sTeam[32];
	GetAlienFortressTeamNames(team, sTeam, sizeof(sTeam));

	int current_perk = g_iCurrentPerk[client][team];

	Menu menu = CreateMenu(MenuHandler_ShowPerksMenu);
	SetMenuTitle(menu, "Alien Fortress - %s perks for %s", equip ? "Equip" : "Read about", sTeam);

	for (int i = 0; i < GetArraySize(g_hArray_PerksList); i++)
	{
		char sPerkName[MAX_PERK_NAME_LENGTH];
		GetArrayString(g_hArray_PerksList, i, sPerkName, sizeof(sPerkName));

		int required_team;
		if (GetTrieValue(g_hTrie_PerkTeams, sPerkName, required_team) && required_team > 0 && view_as<int>(team) != required_team)
		{
			continue;
		}

		int draw = ITEMDRAW_DEFAULT;

		if (current_perk != INVALID_PERK_ID && g_iCurrentPerk[client][team] == i)
		{
			draw = ITEMDRAW_DISABLED;
		}

		char sPerkID[12];
		IntToString(i, sPerkID, sizeof(sPerkID));

		AddMenuItem(menu, sPerkID, sPerkName, draw);
	}

	if (GetMenuItemCount(menu) == 0)
	{
		AddMenuItem(menu, "", "[No Perks Available]", ITEMDRAW_DISABLED);
	}

	PushMenuCell(menu, "team", view_as<int>(team));
	PushMenuCell(menu, "equip", equip);

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandler_ShowPerksMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sPerkID[12]; char sPerkName[MAX_PERK_NAME_LENGTH];
			GetMenuItem(menu, param2, sPerkID, sizeof(sPerkID), _, sPerkName, sizeof(sPerkName));

			TFTeam team = view_as<TFTeam>(GetMenuCell(menu, "team"));
			bool equip = view_as<bool>(GetMenuCell(menu, "equip"));
			int perk = StringToInt(sPerkID);

			char sTeam[32];
			GetAlienFortressTeamNames(team, sTeam, sizeof(sTeam));

			if (equip)
			{
				if (!GetConVarBool(convar_ChangePerkAtSpawn) && g_bIsInRespawnZone[param1])
				{
					PrintToChat(param1, "You cannot change your perk inside of a spawn area.");
					ShowPerksMenu(param1, team, equip);
					return;
				}

				if (GetConVarBool(convar_ChangePerkOnRespawn))
				{
					g_iQueuedPerk[param1][team] = perk;
					CPrintToChat(param1, "You have equipped the perk %s for the %s team, it will be active next respawn.", sPerkName, sTeam);
				}
				else
				{
					if (GetTime() - g_iPerkCooldown[param1][team] < 5)
					{
						PrintToChat(param1, "Please wait a couple seconds before switching perks again for the %s.", sTeam);
						ShowPerksMenu(param1, team, equip);
						return;
					}

					g_iPerkCooldown[param1][team] = GetTime();

					if (TF2_GetClientTeam(param1) == team && g_iCurrentPerk[param1][team] != INVALID_PERK_ID)
					{
						ExecutePerkFunction(param1, g_iCurrentPerk[param1][team], FUNCTION_PERK_ONPERKUNEQUIP, false);
					}

					g_iCurrentPerk[param1][team] = perk;
					CPrintToChat(param1, "You have equipped the perk '%s' for the %s team.", sPerkName, sTeam);

					if (TF2_GetClientTeam(param1) == team)
					{
						ExecutePerkFunction(param1, g_iCurrentPerk[param1][team], FUNCTION_PERK_ONPERKEQUIP, IsPlayerAlive(param1));
					}
				}
			}

			ShowPerksMenu(param1, team, equip);
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

/*-------------------------------------------------------*/
//	Team Preferences Menu
/*-------------------------------------------------------*/

void ShowTeamPreferencesMenu(int client)
{
	PrintToChat(client, "Coming Soon.");
	ShowMainMenu(client);
}

/*-------------------------------------------------------*/
//	Class Info Menu
/*-------------------------------------------------------*/

void ShowClassInfoMenu(int client)
{
	Menu menu = CreateMenu(MenuHandler_ShowClassInfoMenu);
	SetMenuTitle(menu, "Alien Fortress - Class Information");

	AddMenuItem(menu, "survivors", "Survivors");
	AddMenuItem(menu, "aliens", "Aliens");

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandler_ShowClassInfoMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "survivors"))
			{
				ShowClassInfoMenuClasses(param1, TFTeam_Red);
			}
			else if (StrEqual(sInfo, "aliens"))
			{
				ShowClassInfoMenuClasses(param1, TFTeam_Blue);
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

/*-------------------------------------------------------*/
//	Class Info Classes Menu
/*-------------------------------------------------------*/

void ShowClassInfoMenuClasses(int client, TFTeam team)
{
	char sTeam[32];
	GetAlienFortressTeamNames(team, sTeam, sizeof(sTeam));

	Menu menu = CreateMenu(MenuHandler_ShowClassInfoClassesMenu);
	SetMenuTitle(menu, "Alien Fortress - %s Class Information", sTeam);

	switch (team)
	{
		case TFTeam_Red:
		{
			AddMenuItem(menu, "1", "Scout");
			AddMenuItem(menu, "7", "Pyro");
			AddMenuItem(menu, "3", "Soldier");
			AddMenuItem(menu, "4", "Demoman");
			AddMenuItem(menu, "9", "Engineer");
			AddMenuItem(menu, "5", "Medic");
			AddMenuItem(menu, "2", "Sniper");
		}
		case TFTeam_Blue:
		{
			AddMenuItem(menu, "1", "Scout");
			AddMenuItem(menu, "7", "Pyro");
			AddMenuItem(menu, "6", "Heavy");
			AddMenuItem(menu, "5", "Medic");
			AddMenuItem(menu, "8", "Spy");
		}
	}

	PushMenuCell(menu, "team", view_as<int>(team));

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandler_ShowClassInfoClassesMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[12];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo));

			ShowClassInfoPanel(param1, view_as<TFTeam>(GetMenuCell(menu, "team")), view_as<TFClassType>(StringToInt(sInfo)));
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

/*-------------------------------------------------------*/
//	Class Info Panel Menu
/*-------------------------------------------------------*/

void ShowClassInfoPanel(int client, TFTeam team, TFClassType class)
{
	char sTeam[32];
	GetAlienFortressTeamNames(team, sTeam, sizeof(sTeam));

	char sClass[32];
	TF2_GetClassName(class, sClass, sizeof(sClass), true);

	Menu menu = CreateMenu(MenuHandler_ShowClassInfoPanel);
	SetMenuTitle(menu, "Alien Fortress - %s %s info", sTeam, sClass);

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/alienfortress/classinfo.cfg");

	KeyValues kv = CreateKeyValues("alienfortress_classinfo");

	if (FileToKeyValues(kv, sPath) && KvJumpToKey(kv, sClass) && KvGotoFirstSubKey(kv, false))
	{
		char sTeamID[12];
		IntToString(view_as<int>(team), sTeamID, sizeof(sTeamID));

		do
		{
			char sSection[12];
			KvGetSectionName(kv, sSection, sizeof(sSection));

			if (StrEqual(sTeamID, sSection))
			{
				char sDisplay[255];
				KvGetString(kv, NULL_STRING, sDisplay, sizeof(sDisplay));

				if (strlen(sDisplay) > 0)
				{
					AddMenuItem(menu, "", sDisplay, ITEMDRAW_DISABLED);
				}
			}
		}
		while (KvGotoNextKey(kv, false));
	}

	CloseHandle(kv);

	if (GetMenuItemCount(menu) == 0)
	{
		AddMenuItem(menu, "", "[No Info Found]");
	}

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandler_ShowClassInfoPanel(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{

		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

/*-------------------------------------------------------*/
//	Register new perks
/*-------------------------------------------------------*/

int RegisterNewPerk(Handle plugin, const char[] name, int team = 0, Function func_OnPerkEquip = INVALID_FUNCTION, Function func_OnPerkUnequip = INVALID_FUNCTION, Function func_OnSpawnWithPerk = INVALID_FUNCTION, Function func_OnDieWithPerk = INVALID_FUNCTION)
{
	if (plugin == null || strlen(name) == 0 || FindStringInArray(g_hArray_PerksList, name) != INVALID_PERK_ID)
	{
		return INVALID_PERK_ID;
	}

	Handle callbacks[4];

	if (func_OnPerkEquip != INVALID_FUNCTION)
	{
		callbacks[FUNCTION_PERK_ONPERKEQUIP] = CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
		AddToForward(callbacks[FUNCTION_PERK_ONPERKEQUIP], plugin, func_OnPerkEquip);
	}

	if (func_OnPerkUnequip != INVALID_FUNCTION)
	{
		callbacks[FUNCTION_PERK_ONPERKUNEQUIP] = CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
		AddToForward(callbacks[FUNCTION_PERK_ONPERKUNEQUIP], plugin, func_OnPerkUnequip);
	}

	if (func_OnSpawnWithPerk != INVALID_FUNCTION)
	{
		callbacks[FUNCTION_PERK_ONSPAWNWITHPERK] = CreateForward(ET_Ignore, Param_Cell, Param_Cell);
		AddToForward(callbacks[FUNCTION_PERK_ONSPAWNWITHPERK], plugin, func_OnSpawnWithPerk);
	}

	if (func_OnDieWithPerk != INVALID_FUNCTION)
	{
		callbacks[FUNCTION_PERK_ONDIEWITHPERK] = CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
		AddToForward(callbacks[FUNCTION_PERK_ONDIEWITHPERK], plugin, func_OnDieWithPerk);
	}

	SetTrieArray(g_hTrie_PerkFunctions, name, callbacks, sizeof(callbacks));
	SetTrieValue(g_hTrie_PerkTeams, name, team);

	return PushArrayString(g_hArray_PerksList, name);
}

/*-------------------------------------------------------*/
//	Unregister current perks
/*-------------------------------------------------------*/

bool UnregisterPerk(int index)
{
	if (index < 0 || index > GetArraySize(g_hArray_PerksList) - 1)
	{
		return false;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_iCurrentPerk[i][TFTeam_Unassigned] == index)
		{
			if (IsPlayerAlive(i) && TF2_GetClientTeam(i) == TFTeam_Unassigned)
			{
				ExecutePerkFunction(i, index, FUNCTION_PERK_ONPERKUNEQUIP, false);
			}

			g_iCurrentPerk[i][TFTeam_Unassigned] = 0;
		}

		if (g_iCurrentPerk[i][TFTeam_Spectator] == index)
		{
			if (IsPlayerAlive(i) && TF2_GetClientTeam(i) == TFTeam_Spectator)
			{
				ExecutePerkFunction(i, index, FUNCTION_PERK_ONPERKUNEQUIP, false);
			}

			g_iCurrentPerk[i][TFTeam_Spectator] = 0;
		}

		if (g_iCurrentPerk[i][TFTeam_Red] == index)
		{
			if (IsPlayerAlive(i) && TF2_GetClientTeam(i) == TFTeam_Red)
			{
				ExecutePerkFunction(i, index, FUNCTION_PERK_ONPERKUNEQUIP, false);
			}

			g_iCurrentPerk[i][TFTeam_Red] = 0;
		}

		if (g_iCurrentPerk[i][TFTeam_Blue] == index)
		{
			if (IsPlayerAlive(i) && TF2_GetClientTeam(i) == TFTeam_Blue)
			{
				ExecutePerkFunction(i, index, FUNCTION_PERK_ONPERKUNEQUIP, false);
			}

			g_iCurrentPerk[i][TFTeam_Blue] = 0;
		}
	}

	char sPerkName[MAX_PERK_NAME_LENGTH];
	GetArrayString(g_hArray_PerksList, index, sPerkName, sizeof(sPerkName));

	Handle callbacks[4];
	if (GetTrieArray(g_hTrie_PerkFunctions, sPerkName, callbacks, sizeof(callbacks)))
	{
		for (int i = 0; i < sizeof(callbacks); i++)
		{
			CloseHandle(callbacks[i]);
		}
	}

	RemoveFromTrie(g_hTrie_PerkFunctions, sPerkName);
	RemoveFromTrie(g_hTrie_PerkTeams, sPerkName);
	RemoveFromArray(g_hArray_PerksList, index);

	return true;
}

/*-------------------------------------------------------*/
//	Execute perk functions
/*-------------------------------------------------------*/

bool ExecutePerkFunction(int client, int perk, int func, any data = 0)
{
	if (perk == INVALID_PERK_ID || GetArraySize(g_hArray_PerksList) == 0)
	{
		return false;
	}

	char sPerkName[MAX_PERK_NAME_LENGTH];
	int copy = GetArrayString(g_hArray_PerksList, perk, sPerkName, sizeof(sPerkName));

	if (strlen(sPerkName) == 0 || copy == 0)
	{
		return false;
	}

	Handle callbacks[4];
	if (!GetTrieArray(g_hTrie_PerkFunctions, sPerkName, callbacks, sizeof(callbacks)))
	{
		return false;
	}

	if (callbacks[func] != null && GetForwardFunctionCount(callbacks[func]) > 0)
	{
		Call_StartForward(callbacks[func]);
		Call_PushCell(client);
		Call_PushCell(perk);

		switch (func)
		{
			case FUNCTION_PERK_ONPERKEQUIP:
			{
				Call_PushCell(data);
			}
			case FUNCTION_PERK_ONPERKUNEQUIP:
			{
				Call_PushCell(data);
			}
			case FUNCTION_PERK_ONSPAWNWITHPERK:
			{

			}
			case FUNCTION_PERK_ONDIEWITHPERK:
			{
				Call_PushCell(data);
			}
		}

		Call_Finish();
		return true;
	}

	return false;
}

/*-------------------------------------------------------*/
//	Stocks
/*-------------------------------------------------------*/

/*-------------------------------------------------------*/
//	Timer Callbacks
/*-------------------------------------------------------*/

public Action Timer_DelayReequip(Handle timer, any data)
{
	ResetPack(data);

	int client = GetClientOfUserId(ReadPackCell(data));
	int team = ReadPackCell(data);

	if (client > 0)
	{
		ExecutePerkFunction(client, g_iCurrentPerk[client][team], FUNCTION_PERK_ONPERKEQUIP);
	}
}


/*-------------------------------------------------------*/
//	Natives
/*-------------------------------------------------------*/

public int Native_RegisterPerk(Handle plugin, int numParams)
{
	int size;
	GetNativeStringLength(1, size);

	char[] sPerkName = new char[size + 1];
	GetNativeString(1, sPerkName, size + 1);

	int iTeam = GetNativeCell(2);

	Function func_OnPerkEquip = GetNativeFunction(3);
	Function func_OnPerkUnequip = GetNativeFunction(4);
	Function func_OnSpawnWithPerk = GetNativeFunction(5);
	Function func_OnDieWithPerk = GetNativeFunction(6);

	return RegisterNewPerk(plugin, sPerkName, iTeam, func_OnPerkEquip, func_OnPerkUnequip, func_OnSpawnWithPerk, func_OnDieWithPerk);
}

public int Native_UnregisterPerk(Handle plugin, int numParams)
{
	return UnregisterPerk(GetNativeCell(1));
}

public int Native_GetClientPerk(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	TFTeam team = view_as<TFTeam>(GetNativeCell(2));

	return g_iCurrentPerk[client][team];
}
