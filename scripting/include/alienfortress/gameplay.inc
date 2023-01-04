#if defined _alienfortress_gameplay_included
#endinput
#endif
#define _alienfortress_gameplay_included

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
public void __pl_alienfortress_gameplay_SetNTVOptional()
{
    MarkNativeAsOptional("AlienFortress_IsClientSurvivor");
    MarkNativeAsOptional("AlienFortress_IsClientAlien");
}
#endif

public SharedPlugin __pl_alienfortress_gameplay =
{
    name = "alienfortress_gameplay",
    file = "tf2-alienfortress-gameplay.smx",
    #if defined REQUIRE_PLUGIN
    required = 1,
    #else
    required = 0,
    #endif
};
