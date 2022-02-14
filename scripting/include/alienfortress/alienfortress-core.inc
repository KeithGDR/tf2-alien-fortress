#if defined _alienfortress_core_included
#endinput
#endif
#define _alienfortress_core_included

//////////////////////////////////////////////
//Globals/Defines

#define MAXENTITIES 4096

#define INVALID_PERK_ID -1
#define MAX_PERK_NAME_LENGTH 32

#define BOTH_TEAMS 0
#define ALIEN_TEAM 3
#define SURVIVOR_TEAM 2

//////////////////////////////////////////////
//Typedefs
typedef AlienFortress_Func_OnPerkEquip = function void (int client, int perk, bool alive);
typedef AlienFortress_Func_OnPerkUnequip = function void (int client, int perk, bool disconnect);
typedef AlienFortress_Func_OnSpawnWithPerk = function void (int client, int perk);
typedef AlienFortress_Func_OnDieWithPerk = function void (int client, int perk, int attacker);

//////////////////////////////////////////////
//Natives

native int AlienFortress_RegisterPerk(char[] name, int team, AlienFortress_Func_OnPerkEquip OnPerkEquip = INVALID_FUNCTION, AlienFortress_Func_OnPerkUnequip OnPerkUnequip = INVALID_FUNCTION, AlienFortress_Func_OnSpawnWithPerk OnSpawnWithPerk = INVALID_FUNCTION, AlienFortress_Func_OnDieWithPerk OnDieWithPerk = INVALID_FUNCTION);
native bool AlienFortress_UnregisterPerk(int index);
native int AlienFortress_GetClientPerk(int client, TFTeam team);

//////////////////////////////////////////////
//Forwards

forward void AlienFortress_OnRegisteringPerks();
forward Action AlienFortress_OnTakeDamage(int victim, int victim_perk, int &attacker, int attacker_perk, int &inflictor, int inflictor_perk, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom);
forward void AlienFortress_OnTakeDamage_Post(int victim, int victim_perk, int attacker, int attacker_perk, int inflictor, int inflictor_perk, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom);
forward Action AlienFortress_GetMaxHealth(int client, int perk, int &maxhealth);

//////////////////////////////////////////////
//Stocks

stock void GetAlienFortressTeamNames(TFTeam team, char[] buffer, int size)
{
	switch (team)
	{
		case TFTeam_Red: strcopy(buffer, size, "Survivors");
		case TFTeam_Blue: strcopy(buffer, size, "Aliens");
	}
}

//////////////////////////////////////////////
//Info

#if !defined REQUIRE_PLUGIN
public void __pl_alienfortress_core_SetNTVOptional()
{
    MarkNativeAsOptional("AlienFortress_RegisterPerk");
    MarkNativeAsOptional("AlienFortress_UnregisterPerk");
    MarkNativeAsOptional("AlienFortress_GetClientPerk");
}
#endif

public SharedPlugin __pl_alienfortress_core =
{
    name = "alienfortress_core",
    file = "alienfortress-core.smx",
    #if defined REQUIRE_PLUGIN
    required = 1,
    #else
    required = 0,
    #endif
};
