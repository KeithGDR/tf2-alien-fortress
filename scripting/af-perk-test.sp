//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define IS_PLUGIN
#define PLUGIN_DESCRIPTION "A custom perk for the Alien Fortress gamemode."
#define PLUGIN_VERSION "1.0.0"

//Perk Defines
#define AF_PERK_NAME	"Test"
#define AF_PERK_TEAM	BOTH_TEAMS

//Sourcemod Includes
#include <sourcemod>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>

//Our Includes
#include <alienfortress/alienfortress-core>

//ConVars
ConVar convar_Status;

//Globals
int g_iPerkID;

//Plugin Info
public Plugin myinfo =
{
	name = "[TF2] Alien Fortress Perk: Test",
	author = "Drixevel",
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = "https://drixevel.dev/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_af_perk_both_test_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
}

public void OnPluginEnd()
{
	AlienFortress_UnregisterPerk(g_iPerkID);
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
	PrintToChat(client, "Event: Equip - Client: %N - Perk: %i - Alive: %s", client, perk, alive ? "True" : "False");
}

public void OnPerkUnequip(int client, int perk, bool disconnect)
{
	PrintToChat(client, "Event: Unequip - Client: %N - Perk: %i - Disconnect: %s", client, perk, disconnect ? "True" : "False");
}

public void OnSpawnWithPerk(int client, int perk)
{
	PrintToChat(client, "Event: Spawn - Client: %N - Perk: %i", client, perk);
}

public void OnDieWithPerk(int client, int perk, int attacker)
{
	PrintToChat(client, "Event: Death - Client: %N - Perk: %i - Attacker: %N", client, perk, attacker);
}

public Action AlienFortress_OnTakeDamage(int victim, int victim_perk, int &attacker, int attacker_perk, int &inflictor, int inflictor_perk, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	PrintToChat(victim, "OnTakeDamage: victim: %i - victim_perk: %i - attacker: %i - attacker_perk: %i - damage: %.2f", victim, victim_perk, attacker, attacker_perk, damage);
}

public void AlienFortress_OnTakeDamage_Post(int victim, int victim_perk, int attacker, int attacker_perk, int inflictor, int inflictor_perk, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	PrintToChat(victim, "OnTakeDamage_Post: victim: %i - victim_perk: %i - attacker: %i - attacker_perk: %i - damage: %.2f", victim, victim_perk, attacker, attacker_perk, damage);
}
