//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define IS_PLUGIN
#define PLUGIN_DESCRIPTION "A custom perk for the Alien Fortress gamemode."
#define PLUGIN_VERSION "1.0.0"

//Perk Defines
#define AF_PERK_NAME	"Heroic"
#define AF_PERK_TEAM	SURVIVOR_TEAM

//Sourcemod Includes
#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>

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
ConVar convar_Stat_CritsTimePerKill;
ConVar convar_Stat_CritsTimePerAssist;

//Globals
int g_iPerkID = INVALID_PERK_ID;

float g_iCritsTime[MAXPLAYERS + 1];

//Plugin Info
public Plugin myinfo =
{
	name = "[TF2] Alien Fortress Perk: Heroic",
	author = "Drixevel",
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = "https://drixevel.dev/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_af_perk_survivors_athletic_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Stat_Armor = CreateConVar("sm_af_perk_survivors_athletic_stat_armor", "0.15", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);
	convar_Stat_DamageBonus = CreateConVar("sm_af_perk_survivors_athletic_stat_damagebonus", "0.15", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);
	convar_Stat_CritsTimePerKill = CreateConVar("sm_af_perk_survivors_heroic_stat_critstimeperkill", "5.0", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);
	convar_Stat_CritsTimePerAssist = CreateConVar("sm_af_perk_survivors_heroic_stat_critstimeperassist", "3.0", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);

	HookConVarChange(convar_Stat_CritsTimePerKill, OnConVarChanged_OnStatChange);
	HookConVarChange(convar_Stat_CritsTimePerAssist, OnConVarChanged_OnStatChange);

	HookEvent("player_death", Event_OnPlayerDeath);
	HookEvent("teamplay_round_win", Event_OnRoundEnd);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
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
		TF2Attrib_SetByName_Weapons(client, -1, "damage bonus", GetConVarFloat(convar_Stat_DamageBonus));
	}
}

public void OnPerkUnequip(int client, int perk, bool disconnect)
{
	TF2Attrib_RemoveByName_Weapons(client, -1, "damage bonus");
}

public void OnSpawnWithPerk(int client, int perk)
{
	TF2Attrib_SetByName_Weapons(client, -1, "damage bonus", GetConVarFloat(convar_Stat_DamageBonus));
}

public void OnDieWithPerk(int client, int perk, int attacker)
{
	TF2Attrib_RemoveByName_Weapons(client, -1, "damage bonus");

	g_iCritsTime[client] = 0.0;
}

public void OnClientDisconnect(int client)
{
	g_iCritsTime[client] = 0.0;
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int assister = GetClientOfUserId(GetEventInt(event, "assister"));

	if (client == 0 || client > MaxClients)
	{
		return;
	}

	if (attacker > 0 && attacker <= MaxClients && AlienFortress_GetClientPerk(attacker, TF2_GetClientTeam(attacker)) == g_iPerkID)
	{
		float add = GetConVarFloat(convar_Stat_CritsTimePerKill);
		g_iCritsTime[attacker] += add;
		PrintToChat(attacker, "You have gained %.2f seconds to your crits clock for a kill. (Total: %.2f)", add, g_iCritsTime[attacker]);
	}

	if (assister > 0 && assister <= MaxClients && AlienFortress_GetClientPerk(assister, TF2_GetClientTeam(assister)) == g_iPerkID)
	{
		float add = GetConVarFloat(convar_Stat_CritsTimePerAssist);
		g_iCritsTime[assister] += add;
		PrintToChat(assister, "You have gained %.2f seconds to your crits clock for an assist. (Total: %.2f)", add, g_iCritsTime[assister]);
	}

	RequestFrame(Frame_CheckLastAlive);
}

public void Frame_CheckLastAlive(any data)
{
	int last_alive;
	if (IsLastAlive(last_alive) && AlienFortress_GetClientPerk(last_alive, TF2_GetClientTeam(last_alive)) == g_iPerkID)
	{
		TF2_AddCondition(last_alive, TFCond_Kritzkrieged, g_iCritsTime[last_alive]);
		PrintToChat(last_alive, "You are the last alive, you have gained %.2f seconds of crits.", g_iCritsTime[last_alive]);
	}
}

bool IsLastAlive(int& last_alive)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			last_alive = i;
			return true;
		}
	}

	return false;
}

public void Event_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iCritsTime[i] = 0.0;
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (victim == 0 || !IsClientInGame(victim))
	{
		return Plugin_Continue;
	}

	if (AlienFortress_GetClientPerk(victim, TF2_GetClientTeam(victim)) == g_iPerkID)
	{
		damage = FloatDivider(damage, GetConVarFloat(convar_Stat_Armor));
		return Plugin_Changed;
	}

	return Plugin_Continue;
}
