//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define IS_PLUGIN
#define PLUGIN_DESCRIPTION "A custom perk for the Alien Fortress gamemode."
#define PLUGIN_VERSION "1.0.0"

//Perk Defines
#define AF_PERK_NAME	"Magnetic"
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
ConVar convar_Stat_ReactivationTime;

//Globals
int g_iPerkID = INVALID_PERK_ID;

float g_iDisabledTimer[MAXENTITIES + 1];

//Plugin Info
public Plugin myinfo =
{
	name = "[TF2] Alien Fortress Perk: Magnetic",
	author = "Drixevel",
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = "https://drixevel.dev/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_af_perk_aliens_magnetic_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Stat_VectorDistance = CreateConVar("sm_af_perk_aliens_magnetic_stat_vectordistance", "750.0", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);
	convar_Stat_ReactivationTime = CreateConVar("sm_af_perk_aliens_magnetic_stat_reactivationtime", "2.0", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);

	HookConVarChange(convar_Stat_VectorDistance, OnConVarChanged_OnStatChange);
	HookConVarChange(convar_Stat_ReactivationTime, OnConVarChanged_OnStatChange);

	CreateTimer(0.1, Timer_CheckDisabledSentries, _, TIMER_REPEAT);
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

	if (alive)
	{
		TF2Attrib_SetByName(client, "airblast functionality flags", 4.0);
	}
}

public void OnPerkUnequip(int client, int perk, bool disconnect)
{
	if (!disconnect)
	{
		SDKUnhook(client, SDKHook_PostThink, OnPostThink);
		TF2Attrib_RemoveByName(client, "airblast functionality flags");
	}
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_PostThink, OnPostThink);
}

public void OnSpawnWithPerk(int client, int perk)
{
	TF2Attrib_SetByName(client, "airblast functionality flags", 4.0);
}

public void OnDieWithPerk(int client, int perk, int attacker)
{
	TF2Attrib_RemoveByName(client, "airblast functionality flags");
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

	float vecOtherPosition[3]; int entity = -1;
	while ((entity = FindEntityByClassname(entity, "obj_sentrygun")) != -1)
	{
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecOtherPosition);

		if (GetVectorDistance(vecPosition, vecOtherPosition) > distance)
		{
			continue;
		}

		SetEntProp(entity, Prop_Send, "m_bDisabled", 1);
		g_iDisabledTimer[entity] = GetGameTime();
	}
}

public Action Timer_CheckDisabledSentries(Handle timer)
{
	float time = GetGameTime();
	float reactive = GetConVarFloat(convar_Stat_ReactivationTime);

	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "obj_sentrygun")) != -1)
	{
		if (g_iDisabledTimer[entity] == 0 || time - g_iDisabledTimer[entity] < reactive)
		{
			continue;
		}

		SetEntProp(entity, Prop_Send, "m_bDisabled", 0);
		g_iDisabledTimer[entity] = 0.0;
	}
}
