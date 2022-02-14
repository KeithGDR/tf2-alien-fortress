//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define IS_PLUGIN
#define PLUGIN_DESCRIPTION "A custom perk for the Alien Fortress gamemode."
#define PLUGIN_VERSION "1.0.0"

//Perk Defines
#define AF_PERK_NAME	"Juggernaut"
#define AF_PERK_TEAM	SURVIVOR_TEAM

//Sourcemod Includes
#include <sourcemod>
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
ConVar convar_Stat_SpeedPenalty;
ConVar convar_Stat_ROFPenalty;
ConVar convar_Stat_Knockback;

//Globals
int g_iPerkID;

//Plugin Info
public Plugin myinfo =
{
	name = "[TF2] Alien Fortress Perk: Juggernaut",
	author = "Drixevel",
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = "https://drixevel.dev/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_af_perk_survivors_juggernaut_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Stat_Armor = CreateConVar("sm_af_perk_survivors_juggernaut_stat_armor", "0.35", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);
	convar_Stat_DamageBonus = CreateConVar("sm_af_perk_survivors_juggernaut_stat_damagebonus", "0.20", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);
	convar_Stat_SpeedPenalty = CreateConVar("sm_af_perk_survivors_juggernaut_stat_speedpenalty", "0.35", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);
	convar_Stat_ROFPenalty = CreateConVar("sm_af_perk_survivors_juggernaut_stat_rofpenalty", "0.35", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);
	convar_Stat_Knockback = CreateConVar("sm_af_perk_survivors_juggernaut_stat_knockback", "2000.0", "Stat for a custom perk for Alien Fortress.", FCVAR_NOTIFY);

	HookConVarChange(convar_Stat_DamageBonus, OnConVarChanged_OnStatChange);
	HookConVarChange(convar_Stat_SpeedPenalty, OnConVarChanged_OnStatChange);
	HookConVarChange(convar_Stat_ROFPenalty, OnConVarChanged_OnStatChange);

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
		TF2Attrib_ApplyMoveSpeedPenalty(client, GetConVarFloat(convar_Stat_SpeedPenalty));
		TF2Attrib_SetByName_Weapons(client, -1, "fire rate penalty", GetConVarFloat(convar_Stat_ROFPenalty), true);
	}
}

public void OnPerkUnequip(int client, int perk, bool disconnect)
{
	if (!disconnect)
	{
		TF2Attrib_RemoveByName_Weapons(client, -1, "damage bonus");
		TF2Attrib_RemoveMoveSpeedPenalty(client);
		TF2Attrib_RemoveByName_Weapons(client, -1, "fire rate penalty");
	}
}

public void OnSpawnWithPerk(int client, int perk)
{
	TF2Attrib_SetByName_Weapons(client, -1, "damage bonus", GetConVarFloat(convar_Stat_DamageBonus));
	TF2Attrib_ApplyMoveSpeedPenalty(client, GetConVarFloat(convar_Stat_SpeedPenalty));
	TF2Attrib_SetByName_Weapons(client, -1, "fire rate penalty", GetConVarFloat(convar_Stat_ROFPenalty));
}

public void OnDieWithPerk(int client, int perk, int attacker)
{
	TF2Attrib_RemoveByName_Weapons(client, -1, "damage bonus");
	TF2Attrib_RemoveMoveSpeedPenalty(client);
	TF2Attrib_RemoveByName_Weapons(client, -1, "fire rate penalty");
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (AlienFortress_GetClientPerk(victim, TF2_GetClientTeam(victim)) == g_iPerkID)
	{
		damage = FloatDivider(damage, GetConVarFloat(convar_Stat_Armor));
		return Plugin_Changed;
	}

	if (IsPlayerIndex(attacker) && GetClientActiveSlot(attacker) == TFWeaponSlot_Melee && damagecustom != TF_CUSTOM_BURNING && AlienFortress_GetClientPerk(attacker, TF2_GetClientTeam(attacker)) == g_iPerkID)
	{
		ThrowEntity(attacker, victim, GetConVarFloat(convar_Stat_Knockback));
	}

	return Plugin_Continue;
}

void ThrowEntity(int client, int entity, float force = 1000.0)
{
	float vecEyeAngle[3];
	GetClientEyeAngles(client, vecEyeAngle);
	vecEyeAngle[0] = 0.0;

	float vecForward[3];
	GetAngleVectors(vecEyeAngle, vecForward, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vecForward, vecForward);
	ScaleVector(vecForward, force);

	float vecVelocity[3];

	vecVelocity[0] += vecForward[0];
	vecVelocity[1] += vecForward[1];
	vecVelocity[2] += vecForward[2];

	float vecOrigin[3];
	GetClientAbsOrigin(entity, vecOrigin);
	vecOrigin[2] += 20.0;

	TeleportEntity(entity, vecOrigin, NULL_VECTOR, vecVelocity);
}

/*
float vecEyeAngle[3];
GetClientEyeAngles(client, vecEyeAngle);
vecEyeAngle[0] = 0.0;

float vecForward[3];
GetAngleVectors(vecEyeAngle, vecForward, NULL_VECTOR, NULL_VECTOR);
NormalizeVector(vecForward, vecForward);
ScaleVector(vecForward, force);

float vecOrigin[3];
GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vecOrigin);

vecOrigin[0] += vecForward[0];
vecOrigin[1] += vecForward[1];
vecOrigin[2] += vecForward[2];

TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, vecOrigin);
*/
