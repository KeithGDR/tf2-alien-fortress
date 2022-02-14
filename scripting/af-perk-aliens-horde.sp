//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define IS_PLUGIN
#define PLUGIN_DESCRIPTION "A custom perk for the Alien Fortress gamemode."
#define PLUGIN_VERSION "1.0.0"

//Perk Defines
#define AF_PERK_NAME	"Horde"
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
ConVar convar_Stat_VectorDistance;
ConVar convar_Stat_BaseSpeed;
ConVar convar_Stat_SpeedMultiplier;

//Globals
int g_iPerkID = INVALID_PERK_ID;

int g_iNearCache[MAXPLAYERS + 1] = {-1, ...};

//Plugin Info
public Plugin myinfo =
{
	name = "[TF2] Alien Fortress Perk: Horde",
	author = "Drixevel",
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = "https://drixevel.dev/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_af_perk_aliens_horde_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Stat_VectorDistance = CreateConVar("sm_af_perk_aliens_horde_stat_vectordistance", "750.0", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);
	convar_Stat_BaseSpeed = CreateConVar("sm_af_perk_aliens_horde_stat_basespeed", "0.85", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);
	convar_Stat_SpeedMultiplier = CreateConVar("sm_af_perk_aliens_horde_stat_speedmultiplier", "0.15", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);

	HookConVarChange(convar_Stat_VectorDistance, OnConVarChanged_OnStatChange);
	HookConVarChange(convar_Stat_BaseSpeed, OnConVarChanged_OnStatChange);
	HookConVarChange(convar_Stat_SpeedMultiplier, OnConVarChanged_OnStatChange);
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
	SDKHook(client, SDKHook_PostThink, OnPostThink);
}

public void OnPerkUnequip(int client, int perk, bool disconnect)
{
	if (!disconnect)
	{
		SDKUnhook(client, SDKHook_PostThink, OnPostThink);
		TF2Attrib_RemoveByName(client, "move speed bonus");
	}
}

public void OnSpawnWithPerk(int client, int perk)
{

}

public void OnDieWithPerk(int client, int perk, int attacker)
{
	TF2Attrib_RemoveByName(client, "move speed bonus");
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_PostThink, OnPostThink);
	g_iNearCache[client] = -1;
}

public void OnPostThink(int client)
{
	if (!IsPlayerAlive(client))
	{
		return;
	}

	float vecPosition[3];
	GetClientAbsOrigin(client, vecPosition);

	float distance = GetConVarFloat(convar_Stat_VectorDistance);

	float vecOtherPosition[3]; int count;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || IsFakeClient(i) || AlienFortress_GetClientPerk(i, TF2_GetClientTeam(i)) != g_iPerkID)
		{
			continue;
		}

		GetClientAbsOrigin(i, vecOtherPosition);

		if (GetVectorDistance(vecPosition, vecOtherPosition) > distance)
		{
			continue;
		}

		count++;
	}

	if (g_iNearCache[client] == count)
	{
		return;
	}

	TF2Attrib_SetByName(client, "move speed bonus", GetConVarFloat(convar_Stat_BaseSpeed) + (GetConVarFloat(convar_Stat_SpeedMultiplier) * count));

	g_iNearCache[client] = count;
}
