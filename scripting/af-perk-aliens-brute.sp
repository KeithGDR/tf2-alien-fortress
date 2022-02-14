//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define PLUGIN_DESCRIPTION "A custom perk for the Alien Fortress gamemode."
#define PLUGIN_VERSION "1.0.0"

//Perk Defines
#define IS_PLUGIN
#define AF_PERK_NAME	"Brute"
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
ConVar convar_Stat_Armor;
ConVar convar_Stat_DamageBonus;
ConVar convar_Stat_SpeedPenalty;
ConVar convar_Stat_ROFPenalty;
ConVar convar_Stat_IncreaseHealth;
ConVar convar_Stat_ModelSize;

//Globals
int g_iPerkID = INVALID_PERK_ID;

//Plugin Info
public Plugin myinfo =
{
	name = "[TF2] Alien Fortress Perk: Brute",
	author = "Drixevel",
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = "https://drixevel.dev/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_af_perk_aliens_brute_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Stat_Armor = CreateConVar("sm_af_perk_aliens_brute_stat_armor", "0.50", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);
	convar_Stat_DamageBonus = CreateConVar("sm_af_perk_aliens_brute_stat_damagebonus", "0.50", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);
	convar_Stat_SpeedPenalty = CreateConVar("sm_af_perk_aliens_brute_stat_speedpenalty", "0.50", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);
	convar_Stat_ROFPenalty = CreateConVar("sm_af_perk_aliens_brute_stat_rofpenalty", "0.25", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);
	convar_Stat_IncreaseHealth = CreateConVar("sm_af_perk_aliens_brute_stat_increasehealth", "300", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);
	convar_Stat_ModelSize = CreateConVar("sm_af_perk_aliens_brute_stat_modelsize", "1.5", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);

	HookConVarChange(convar_Stat_Armor, OnConVarChanged_OnStatChange);
	HookConVarChange(convar_Stat_DamageBonus, OnConVarChanged_OnStatChange);
	HookConVarChange(convar_Stat_SpeedPenalty, OnConVarChanged_OnStatChange);
	HookConVarChange(convar_Stat_ROFPenalty, OnConVarChanged_OnStatChange);
	HookConVarChange(convar_Stat_ModelSize, OnConVarChanged_OnStatChange);
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
	TF2Attrib_ApplyMoveSpeedPenalty(client, GetConVarFloat(convar_Stat_SpeedPenalty));
	TF2Attrib_SetByName_Weapons(client, -1, "fire rate penalty", GetConVarFloat(convar_Stat_ROFPenalty), true);
	SetEntPropFloat(client, Prop_Data, "m_flModelScale", GetConVarFloat(convar_Stat_ModelSize));
}

public void OnPerkUnequip(int client, int perk, bool disconnect)
{
	if (!disconnect)
	{
		TF2Attrib_RemoveMoveSpeedPenalty(client);
		TF2Attrib_RemoveByName_Weapons(client, -1, "fire rate penalty");
		SetEntPropFloat(client, Prop_Data, "m_flModelScale", 1.0);
	}
}

public void OnSpawnWithPerk(int client, int perk)
{
	TF2Attrib_ApplyMoveSpeedPenalty(client, GetConVarFloat(convar_Stat_SpeedPenalty));
	TF2Attrib_SetByName_Weapons(client, -1, "fire rate penalty", GetConVarFloat(convar_Stat_ROFPenalty), true);
	SetEntPropFloat(client, Prop_Data, "m_flModelScale", GetConVarFloat(convar_Stat_ModelSize));
}

public void OnDieWithPerk(int client, int perk, int attacker)
{
	TF2Attrib_RemoveMoveSpeedPenalty(client);
	TF2Attrib_RemoveByName_Weapons(client, -1, "fire rate penalty");
	SetEntPropFloat(client, Prop_Data, "m_flModelScale", 1.0);
}

public Action AlienFortress_OnTakeDamage(int victim, int victim_perk, int &attacker, int attacker_perk, int &inflictor, int inflictor_perk, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	bool bChanged;

	if (victim > 0 && victim_perk == g_iPerkID)
	{
		damage = FloatDivider(damage, GetConVarFloat(convar_Stat_Armor));

		if (damagecustom == TF_CUSTOM_HEADSHOT)
		{
			damage /= 2.0;
		}

		bChanged = true;
	}

	if (attacker > 0 && attacker_perk == g_iPerkID)
	{
		damage = FloatMultiplier(damage, GetConVarFloat(convar_Stat_DamageBonus));
		bChanged = true;
	}

	return bChanged ? Plugin_Changed : Plugin_Continue;
}

public Action AlienFortress_GetMaxHealth(int client, int perk, int &maxhealth)
{
	if (perk == g_iPerkID)
	{
		maxhealth += GetConVarInt(convar_Stat_IncreaseHealth);
		return Plugin_Changed;
	}

	return Plugin_Continue;
}
