//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define IS_PLUGIN
#define PLUGIN_DESCRIPTION "A custom perk for the Alien Fortress gamemode."
#define PLUGIN_VERSION "1.0.0"

//Perk Defines
#define AF_PERK_NAME	"Reaper"
#define AF_PERK_TEAM	ALIEN_TEAM

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>
#include <sdkhooks>
#include <tf2_stocks>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>
#include <tf2attributes>

//Our Includes
#include <alienfortress/alienfortress-core>

//ConVars
ConVar convar_Status;
ConVar convar_Stat_ROFPenalty;
ConVar convar_Stat_SpeedPenalty;
ConVar convar_Stat_Slowdown_Duration;
ConVar convar_Stat_Slowdown_Amount;

//Globals
int g_iPerkID = INVALID_PERK_ID;

//Plugin Info
public Plugin myinfo =
{
	name = "[TF2] Alien Fortress Perk: Reaper",
	author = "Drixevel",
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = "https://drixevel.dev/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_af_perk_aliens_reaper_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Stat_ROFPenalty = CreateConVar("sm_af_perk_aliens_reaper_stat_rofpenalty", "1.3", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);
	convar_Stat_SpeedPenalty = CreateConVar("sm_af_perk_aliens_reaper_stat_speedpenalty", "0.30", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);
	convar_Stat_Slowdown_Duration = CreateConVar("sm_af_perk_aliens_reaper_stat_slowdown_duration", "3.0", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);
	convar_Stat_Slowdown_Amount = CreateConVar("sm_af_perk_aliens_reaper_stat_slowdown_amount", "1.00", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);

	HookConVarChange(convar_Stat_ROFPenalty, OnConVarChanged_OnStatChange);
	HookConVarChange(convar_Stat_SpeedPenalty, OnConVarChanged_OnStatChange);
	HookConVarChange(convar_Stat_Slowdown_Duration, OnConVarChanged_OnStatChange);
	HookConVarChange(convar_Stat_Slowdown_Amount, OnConVarChanged_OnStatChange);

	HookEvent("player_hurt", Event_OnPlayerHurt);
}

public void OnPluginEnd()
{
	AlienFortress_UnregisterPerk(g_iPerkID);
}

public void OnConVarChanged_OnStatChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (StrEqual(oldValue, newValue) || g_iPerkID == INVALID_PERK_ID)
	{
		return;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && AlienFortress_GetClientPerk(i, TF2_GetClientTeam(i)) == g_iPerkID)
		{
			OnPerkUnequip(i, g_iPerkID, false);
			CreateTimer(0.2, Timer_ReequipPerk, i, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action Timer_ReequipPerk(Handle timer, any data)
{
	int client = data;
	OnPerkEquip(client, g_iPerkID, IsPlayerAlive(client));
}

public void AlienFortress_OnRegisteringPerks()
{
	if (GetConVarBool(convar_Status))
	{
		g_iPerkID = AlienFortress_RegisterPerk(AF_PERK_NAME, AF_PERK_TEAM, OnPerkEquip, OnPerkUnequip, OnSpawnWithPerk, OnDieWithPerk);

		if (g_iPerkID == INVALID_PERK_ID)
		{
			LogError("Error registering a new perk: %s", AF_PERK_NAME);
		}
	}
}

public void OnPerkEquip(int client, int perk, bool alive)
{
	if (alive)
	{
		TF2Attrib_SetByName_Weapons(client, -1, "fire rate penalty", GetConVarFloat(convar_Stat_ROFPenalty), true);
		TF2Attrib_ApplyMoveSpeedPenalty(client, GetConVarFloat(convar_Stat_SpeedPenalty));
		TF2_SetPlayerColor(client, 0, 0, 0, 255);
	}
}

public void OnPerkUnequip(int client, int perk, bool disconnect)
{
	if (!disconnect)
	{
		TF2Attrib_RemoveByName_Weapons(client, -1, "fire rate penalty");
		TF2Attrib_RemoveMoveSpeedPenalty(client);
		TF2_SetPlayerColor(client, 255, 255, 255, 255);
	}
}

public void OnSpawnWithPerk(int client, int perk)
{
	TF2Attrib_SetByName_Weapons(client, -1, "fire rate penalty", GetConVarFloat(convar_Stat_ROFPenalty), true);
	TF2Attrib_ApplyMoveSpeedPenalty(client, GetConVarFloat(convar_Stat_SpeedPenalty));
	TF2_SetPlayerColor(client, 0, 0, 0, 255);
}

public void OnDieWithPerk(int client, int perk, int attacker)
{
	TF2Attrib_RemoveByName_Weapons(client, -1, "fire rate penalty");
	TF2Attrib_RemoveMoveSpeedPenalty(client);
	TF2_SetPlayerColor(client, 255, 255, 255, 255);
}

public void Event_OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client == 0 || client > MaxClients)
	{
		return;
	}

	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (attacker > 0 && attacker <= MaxClients && client != attacker&& AlienFortress_GetClientPerk(attacker, TF2_GetClientTeam(attacker)) == g_iPerkID)
	{
		TF2_StunPlayer(client, GetConVarFloat(convar_Stat_Slowdown_Duration), GetConVarFloat(convar_Stat_Slowdown_Amount), TF_STUNFLAGS_LOSERSTATE|TF_STUNFLAG_THIRDPERSON, attacker);
	}
}
