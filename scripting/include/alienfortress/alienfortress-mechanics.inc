#if defined _alienfortress_mechanics_included
#endinput
#endif
#define _alienfortress_mechanics_included

//////////////////////////////////////////////
//Natives

native bool AlienFortress_IsClientSurvivor(int client);
native bool AlienFortress_IsClientAlien(int client);

//////////////////////////////////////////////
//Forwards

forward void AlienFortress_OnClientInfected(int client);

//////////////////////////////////////////////
//Info

#if !defined REQUIRE_PLUGIN
public void __pl_alienfortress_mechanics_SetNTVOptional()
{
    MarkNativeAsOptional("AlienFortress_IsClientSurvivor");
    MarkNativeAsOptional("AlienFortress_IsClientAlien");
}
#endif

public SharedPlugin __pl_alienfortress_mechanics =
{
    name = "alienfortress_mechanics",
    file = "alienfortress-mechanics.smx",
    #if defined REQUIRE_PLUGIN
    required = 1,
    #else
    required = 0,
    #endif
};
