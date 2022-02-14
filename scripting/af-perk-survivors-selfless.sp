//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define IS_PLUGIN
#define PLUGIN_DESCRIPTION "A custom perk for the Alien Fortress gamemode."
#define PLUGIN_VERSION "1.0.0"

//Perk Defines
#define AF_PERK_NAME	"Selfless"
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

//Globals
bool g_bLate;
int g_iPerkID = INVALID_PERK_ID;

//Plugin Info
public Plugin myinfo =
{
	name = "[TF2] Alien Fortress Perk: Selfless",
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

	convar_Status = CreateConVar("sm_af_perk_survivors_selfless_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	//HookConVarChange(convar_Stat_SpeedBonus, OnConVarChanged_OnStatChange);
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

public void OnMapStart()
{
	PrecacheSound("items/cart_explode.wav");
}

/*public void OnConVarChanged_OnStatChange(ConVar convar, const char[] oldValue, const char[] newValue)
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
}*/

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

	}
}

public void OnPerkUnequip(int client, int perk, bool disconnect)
{
	if (!disconnect)
	{

	}
}

public void OnSpawnWithPerk(int client, int perk)
{

}

public void OnDieWithPerk(int client, int perk, int attacker)
{
	if (perk != g_iPerkID)
	{
		return;
	}

	float vecOrigin[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", vecOrigin);

	CreateParticle("cinefx_goldrush", 10.0, vecOrigin);
	EmitSoundToAll("items/cart_explode.wav");
	ScreenShakeAll(SHAKE_START, 50.0, 150.0, 2.0);
	DamageArea(vecOrigin, 500.0, 99999.0, attacker, client, GetClientTeam(client), DMG_BLAST);
}
