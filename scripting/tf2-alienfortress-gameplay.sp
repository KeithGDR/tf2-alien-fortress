//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define IS_PLUGIN
#define PLUGIN_DESCRIPTION "A Team Fortress 2 custom gamemode."
#define PLUGIN_VERSION "1.0.0"

//Sourcemod Includes
#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>

//External Includes
#include <misc-colors>

//Our Includes
#include <alienfortress/alienfortress>
#include <alienfortress/gameplay>

//ConVars
ConVar convar_Mechanics;
ConVar convar_MainTeam;
ConVar convar_Ratio;

//Forwards
Handle g_hForward_OnClientInfected;

//Globals
int g_iMaxHealth[MAXPLAYERS + 1];
bool g_bActiveRound;

//Plugin Info
public Plugin myinfo =
{
	name = "[TF2] Alien Fortress Module: Mechanics",
	author = "Drixevel",
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = "https://drixevel.dev/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("alienfortress_gameplay");

	CreateNative("AlienFortress_IsClientSurvivor", Native_IsClientSurvivor);
	CreateNative("AlienFortress_IsClientAlien", Native_IsClientAlien);
	CreateNative("AlienFortress_InfectClient", Native_InfectClient);

	g_hForward_OnClientInfected = CreateGlobalForward("AlienFortress_OnClientInfected", ET_Ignore, Param_Cell);

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Mechanics = CreateConVar("sm_alienfortress_mechanics", "1");
	convar_MainTeam = CreateConVar("sm_alienfortress_survivor_team", "2");
	convar_Ratio = CreateConVar("sm_alienfortress_ratio", "2");

	RegAdminCmd("sm_endround", Command_EndRound, ADMFLAG_ROOT);

	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("post_inventory_application", Event_OnPostInventoryApplication);
	HookEvent("player_death", Event_OnPlayerDeath);

	HookEvent("teamplay_round_start", Event_OnRoundStart);
	HookEvent("teamplay_setup_finished", Event_OnSetupFinished);
	HookEvent("teamplay_round_win", Event_OnRoundWin);

	AddCommandListener(Command_JoinTeam, "jointeam");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}

	CreateTimer(1.0, Timer_RegenerateAliens, _, TIMER_REPEAT);
}

public Action Timer_RegenerateAliens(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && IsZombie(i))
		{
			int health = GetClientHealth(i) + 3;
			health = ClampCell(health, 0, GetEntProp(i, Prop_Data, "m_iMaxHealth"));
			SetEntityHealth(i, health);
		}
	}

	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (attacker > 0 && attacker <= MaxClients && IsZombie(attacker) && damagecustom == TF_CUSTOM_BACKSTAB)
	{
		damage = 75.0 / 3.0;
		return Plugin_Changed;
	}

	if (victim != attacker)
	{

	}

	return Plugin_Continue;
}

public Action AlienFortress_GetMaxHealth(int client, int perk, int &maxhealth)
{
	g_iMaxHealth[client] = maxhealth;
	return Plugin_Continue;
}

public Action Command_EndRound(int client, int args)
{
	if (!GetConVarBool(convar_Mechanics))
	{
		ReplyToCommand(client, "Mechanics are currently disabled.");
		return Plugin_Handled;
	}

	TF2_ForceRoundWin(TFTeam_Unassigned);
	return Plugin_Handled;
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	CreateTimer(0.5, Timer_DelaySpawn, userid, TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_OnPostInventoryApplication(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	CreateTimer(0.5, Timer_DelaySpawn, userid, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_DelaySpawn(Handle timer, any data)
{
	int client = GetClientOfUserId(data);

	if (!GetConVarBool(convar_Mechanics) || client == 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}

	if (TF2_GetClientTeam(client) == GetZombiesTeam())
	{
		TF2_StripToMelee(client);
	}

	return Plugin_Continue;
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);

	if (client == 0 || client > MaxClients || !IsClientInGame(client))
	{
		return;
	}

	if (GetConVarBool(convar_Mechanics))
	{
		if (!g_bActiveRound)
		{
			TF2_RespawnPlayer(client);
		}

		InfectClient(client);

		CreateTimer(1.0, Timer_CheckForRoundEnd, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_CheckForRoundEnd(Handle timer, any data)
{
	if (GetTeamAliveCount(view_as<int>(GetSurvivorsTeam())) == 0)
	{
		TF2_ForceRoundWin(GetZombiesTeam());
	}

	return Plugin_Continue;
}

public void Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (GetConVarBool(convar_Mechanics))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i))
			{
				TF2_ChangeClientTeam(i, GetSurvivorsTeam());
				TF2_RespawnPlayer(i);
			}
		}
	}
}

public void Event_OnSetupFinished(Event event, const char[] name, bool dontBroadcast)
{
	g_bActiveRound = true;

	if (GetConVarBool(convar_Mechanics))
	{
		int move = GetTeamAliveCount(view_as<int>(GetSurvivorsTeam())) / GetConVarInt(convar_Ratio);

		if (move > 0)
		{
			while (move > 0)
			{
				int client = GetRandomClient(true, true, true, view_as<int>(GetSurvivorsTeam()));

				if (client > 0)
				{
					InfectClient(client, true);
				}

				move--;
			}
		}
	}
}

public void Event_OnRoundWin(Event event, const char[] name, bool dontBroadcast)
{
	g_bActiveRound = false;
}

public Action Command_JoinTeam(int client, const char[] command, int argc)
{
	if (!GetConVarBool(convar_Mechanics))
	{
		return Plugin_Continue;
	}

	char sNewTeam[4];
	GetCmdArg(1, sNewTeam, sizeof(sNewTeam));
	TFTeam new_team = view_as<TFTeam>(StringToInt(sNewTeam));

	if (new_team == GetSurvivorsTeam())
	{
		PrintToChat(client, "You are not allowed to join the survivors team.");
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

bool InfectClient(int client, bool alive = false)
{
	if (!g_bActiveRound)
	{
		return false;
	}

	if (TF2_GetClientTeam(client) == GetSurvivorsTeam())
	{
		if (alive)
		{
			int EntProp = GetEntProp(client, Prop_Send, "m_lifeState");
			SetEntProp(client, Prop_Send, "m_lifeState", 2);
			ChangeClientTeam(client, view_as<int>(GetZombiesTeam()));
			SetEntProp(client, Prop_Send, "m_lifeState", EntProp);

			TF2_StripToMelee(client);
		}
		else
		{
			TF2_ChangeClientTeam(client, GetZombiesTeam());
			TF2_RespawnPlayer(client);
		}

		Call_StartForward(g_hForward_OnClientInfected);
		Call_PushCell(client);
		Call_Finish();

		return true;
	}

	return false;
}

bool IsSurvivor(int client)
{
	return view_as<bool>(TF2_GetClientTeam(client) == GetSurvivorsTeam());
}

bool IsZombie(int client)
{
	return view_as<bool>(TF2_GetClientTeam(client) == GetZombiesTeam());
}

public int Native_IsClientSurvivor(Handle plugin, int numParams)
{
	return IsSurvivor(GetNativeCell(1));
}

public int Native_IsClientAlien(Handle plugin, int numParams)
{
	return IsZombie(GetNativeCell(1));
}

public int Native_InfectClient(Handle plugin, int numParams)
{
	return InfectClient(GetNativeCell(1));
}

TFTeam GetSurvivorsTeam()
{
	return view_as<TFTeam>(GetConVarInt(convar_MainTeam));
}

TFTeam GetZombiesTeam()
{
	return view_as<TFTeam>(GetConVarInt(convar_MainTeam) == 2 ? 3 : 2);
}

any ClampCell(any value, any min, any max) {
	if (value < min) {
		value = min;
	}

	if (value > max) {
		value = max;
	}

	return value;
}

void TF2_ForceRoundWin(TFTeam team = TFTeam_Unassigned) {
	//Need to make sure the world exists in order for entities to be created.
	if (!IsValidEntity(0)) {
		return;
	}
	
	int entity = FindEntityByClassname(-1, "team_control_point_master");

	if (!IsValidEntity(entity)) {
		entity = CreateEntityByName("team_control_point_master");
		DispatchSpawn(entity);
		AcceptEntityInput(entity, "Enable");
	}

	SetVariantInt(view_as<int>(team));
	AcceptEntityInput(entity, "SetWinner");
}

void TF2_StripToMelee(int client) {
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Grenade);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Building);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_PDA);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Item1);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Item2);

	int melee;
	if ((melee = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee)) != -1) {
		EquipPlayerWeapon(client, melee);
	}
}

int GetTeamAliveCount(int team) {
	int count;

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsClientSourceTV(i) || !IsPlayerAlive(i) || GetClientTeam(i) != team) {
			continue;
		}

		count++;
	}

	return count;
}

int GetRandomClient(bool ingame = true, bool alive = false, bool fake = false, int team = 0) {
	int[] clients = new int[MaxClients];
	int amount;

	for (int i = 1; i <= MaxClients; i++) {
		if (ingame && !IsClientInGame(i) || alive && !IsPlayerAlive(i) || !fake && IsFakeClient(i) || team > 0 && team != GetClientTeam(i)) {
			continue;
		}

		clients[amount++] = i;
	}

	return (amount == 0) ? -1 : clients[GetRandomInt(0, amount - 1)];
}