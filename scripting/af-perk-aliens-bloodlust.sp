//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define IS_PLUGIN
#define PLUGIN_DESCRIPTION "A custom perk for the Alien Fortress gamemode."
#define PLUGIN_VERSION "1.0.0"

//Perk Defines
#define AF_PERK_NAME	"Bloodlust"
#define AF_PERK_TEAM	ALIEN_TEAM

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

//ConVars
ConVar convar_Status;
ConVar convar_Stat_DamagePenalty;
ConVar convar_Stat_Bloodlust_Timer;
ConVar convar_Stat_Bloodlust_DamageBonus;
ConVar convar_Stat_Bloodlust_SpeedBonus;

//Globals
int g_iPerkID = INVALID_PERK_ID;

Handle g_hTimer_Bloodlust[MAXPLAYERS + 1];

//Plugin Info
public Plugin myinfo =
{
	name = "[TF2] Alien Fortress Perk: Bloodlust",
	author = "Drixevel",
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = "https://drixevel.dev/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_af_perk_aliens_bloodlust_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Stat_DamagePenalty = CreateConVar("sm_af_perk_aliens_bloodlust_stat_damagepenalty", "0.10", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);
	convar_Stat_Bloodlust_Timer = CreateConVar("sm_af_perk_aliens_bloodlust_stat_bloodlust_timer", "30.0", "Timer for bloodlust to be active.", FCVAR_NOTIFY);
	convar_Stat_Bloodlust_DamageBonus = CreateConVar("sm_af_perk_aliens_bloodlust_stat_bloodlust_damagebonus", "0.30", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);
	convar_Stat_Bloodlust_SpeedBonus = CreateConVar("sm_af_perk_aliens_bloodlust_stat_bloodlust_speedbonus", "0.30", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);

	HookConVarChange(convar_Stat_DamagePenalty, OnConVarChanged_OnStatChange);
	HookConVarChange(convar_Stat_Bloodlust_DamageBonus, OnConVarChanged_OnStatChange);
	HookConVarChange(convar_Stat_Bloodlust_SpeedBonus, OnConVarChanged_OnStatChange);

	HookEvent("player_spawn", Event_OnPlayerSpawn);
}

public void OnPluginEnd()
{
	AlienFortress_UnregisterPerk(g_iPerkID);
}

public void OnMapEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_hTimer_Bloodlust[i] = null;
	}
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
		TF2Attrib_SetByName_Weapons(client, -1, "damage penalty", GetConVarFloat(convar_Stat_DamagePenalty));

		KillTimerSafe(g_hTimer_Bloodlust[client]);
	}
}

public void OnPerkUnequip(int client, int perk, bool disconnect)
{
	if (!disconnect)
	{
		TF2Attrib_RemoveByName_Weapons(client, -1, "damage penalty");

		TF2Attrib_RemoveByName_Weapons(client, -1, "damage bonus");
		TF2Attrib_RemoveMoveSpeedBonus(client);

		KillTimerSafe(g_hTimer_Bloodlust[client]);
	}
}

public void OnSpawnWithPerk(int client, int perk)
{
	TF2Attrib_SetByName_Weapons(client, -1, "damage penalty", GetConVarFloat(convar_Stat_DamagePenalty));

	KillTimerSafe(g_hTimer_Bloodlust[client]);
}

public void OnDieWithPerk(int client, int perk, int attacker)
{
	TF2Attrib_RemoveByName_Weapons(client, -1, "damage penalty");

	TF2Attrib_RemoveByName_Weapons(client, -1, "damage bonus");
	TF2Attrib_RemoveMoveSpeedBonus(client);

	KillTimerSafe(g_hTimer_Bloodlust[client]);
}

public void OnClientDisconnect(int client)
{
	KillTimerSafe(g_hTimer_Bloodlust[client]);
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!IsPlayerIndex(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}

	if (AlienFortress_GetClientPerk(client, TF2_GetClientTeam(client)) == g_iPerkID)
	{
		TF2Attrib_RemoveByName_Weapons(client, -1, "damage penalty");

		TF2Attrib_SetByName_Weapons(client, -1, "damage bonus", GetConVarFloat(convar_Stat_Bloodlust_DamageBonus), true);
		TF2Attrib_ApplyMoveSpeedBonus(client, GetConVarFloat(convar_Stat_Bloodlust_SpeedBonus));

		KillTimerSafe(g_hTimer_Bloodlust[client]);
		g_hTimer_Bloodlust[client] = CreateTimer(GetConVarFloat(convar_Stat_Bloodlust_Timer), Timer_DisableBloodlust, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_DisableBloodlust(Handle timer, any data)
{
	int client = data;

	if (client > 0)
	{
		TF2Attrib_RemoveByName_Weapons(client, -1, "damage bonus");
		TF2Attrib_RemoveMoveSpeedBonus(client);

		TF2Attrib_SetByName_Weapons(client, -1, "damage penalty", GetConVarFloat(convar_Stat_DamagePenalty));

		g_hTimer_Bloodlust[client] = null;
	}
}
