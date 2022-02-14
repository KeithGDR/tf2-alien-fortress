//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define IS_PLUGIN
#define PLUGIN_DESCRIPTION "A custom perk for the Alien Fortress gamemode."
#define PLUGIN_VERSION "1.0.0"

//Perk Defines
#define AF_PERK_NAME	"Athletic"
#define AF_PERK_TEAM	SURVIVOR_TEAM

//Sourcemod Includes
#include <sourcemod>
#include <tf2_stocks>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>
#include <tf2attributes>

//Our Includes
#include <alienfortress/alienfortress-core>

//ConVars
ConVar convar_Status;
ConVar convar_Stat_SpeedBonus;
ConVar convar_Stat_DamagePenalty;
ConVar convar_Stat_ROFBonus;

//Globals
bool g_bLate;
int g_iPerkID = INVALID_PERK_ID;

//Plugin Info
public Plugin myinfo =
{
	name = "[TF2] Alien Fortress Perk: Athletic",
	author = "Drixevel",
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = "https://drixevel.dev/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_af_perk_survivors_athletic_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Stat_SpeedBonus = CreateConVar("sm_af_perk_survivors_athletic_stat_speedbonus", "1.75", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);
	convar_Stat_DamagePenalty = CreateConVar("sm_af_perk_survivors_athletic_stat_damagepenalty", "0.8", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);
	convar_Stat_ROFBonus = CreateConVar("sm_af_perk_survivors_athletic_stat_rofbonus", "0.25", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);

	HookConVarChange(convar_Stat_SpeedBonus, OnConVarChanged_OnStatChange);
	HookConVarChange(convar_Stat_DamagePenalty, OnConVarChanged_OnStatChange);
	HookConVarChange(convar_Stat_ROFBonus, OnConVarChanged_OnStatChange);
}

public void OnConfigsExecuted()
{
	if (g_bLate)
	{
		AlienFortress_OnRegisteringPerks();
		g_bLate = false;
	}
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
		TF2Attrib_ApplyMoveSpeedBonus(client, GetConVarFloat(convar_Stat_SpeedBonus));

		TF2Attrib_SetByName(client, "damage penalty", GetConVarFloat(convar_Stat_DamagePenalty));

		TF2Attrib_SetByName_Weapons(client, -1, "fire rate bonus", GetConVarFloat(convar_Stat_ROFBonus));
	}
}

public void OnPerkUnequip(int client, int perk, bool disconnect)
{
	if (!disconnect)
	{
		TF2Attrib_RemoveMoveSpeedBonus(client);

		TF2Attrib_RemoveByName(client, "damage penalty");

		TF2Attrib_RemoveByName_Weapons(client, -1, "fire rate bonus");
	}
}

public void OnSpawnWithPerk(int client, int perk)
{
	TF2Attrib_ApplyMoveSpeedBonus(client, GetConVarFloat(convar_Stat_SpeedBonus));

	TF2Attrib_SetByName(client, "damage penalty", GetConVarFloat(convar_Stat_DamagePenalty));

	TF2Attrib_SetByName_Weapons(client, -1, "fire rate bonus", GetConVarFloat(convar_Stat_ROFBonus));
}

public void OnDieWithPerk(int client, int perk, int attacker)
{
	TF2Attrib_RemoveMoveSpeedBonus(client);

	TF2Attrib_RemoveByName(client, "damage penalty");

	TF2Attrib_RemoveByName_Weapons(client, -1, "fire rate bonus");
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result)
{
	if (AlienFortress_GetClientPerk(client, TF2_GetClientTeam(client)) == g_iPerkID)
	{
		result = false;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}
