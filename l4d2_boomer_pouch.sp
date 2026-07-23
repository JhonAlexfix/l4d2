#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZOMBIECLASS_BOOMER 2
#define PUNCH_RADIUS 120.0
#define PUNCH_CONE 0.7

public Plugin myinfo =
{
    name = "L4D2 Boomer Tank Punch",
    author = "Shadow L4D2",
    description = "Boomer con golpe REAL de Tank",
    version = "5.4",
    url = ""
};

int g_iBoomVomitLevel[MAXPLAYERS + 1];
float g_fNextPunch[MAXPLAYERS + 1];

ConVar g_hPunchDamage;
ConVar g_hPunchForce;
ConVar g_hPunchUpForce;
ConVar g_hPunchDelay;
ConVar g_hHorde1;
ConVar g_hHorde2;
ConVar g_hHorde3;
ConVar g_hHorde4;

public void OnPluginStart()
{
    HookEvent("ability_use", Event_AbilityUse);
    HookEvent("player_death", Event_PlayerDeath);

    g_hPunchDamage = CreateConVar("sm_boomer_punch_damage", "5");
    g_hPunchForce = CreateConVar("sm_boomer_punch_force", "1200");
    g_hPunchUpForce = CreateConVar("sm_boomer_punch_upforce", "400");
    g_hPunchDelay = CreateConVar("sm_boomer_punch_delay", "2.5");
    g_hHorde1 = CreateConVar("sm_boomer_horde_1", "13");
    g_hHorde2 = CreateConVar("sm_boomer_horde_2", "23");
    g_hHorde3 = CreateConVar("sm_boomer_horde_3", "43");
    g_hHorde4 = CreateConVar("sm_boomer_horde_4", "53");

    AutoExecConfig(true, "boomer_berserker");
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    ResetBoomer(client);
}

public void OnClientPutInServer(int client) { ResetBoomer(client); }
public void OnClientDisconnect(int client) { ResetBoomer(client); }

void ResetBoomer(int client)
{
    g_iBoomVomitLevel[client] = 0;
    g_fNextPunch[client] = 0.0;
}

public Action Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client) ||!IsPlayerAlive(client) ||!IsBoomer(client)) return Plugin_Continue;

    char ability[64];
    event.GetString("ability", ability, sizeof(ability));

    if (StrEqual(ability, "ability_vomit"))
    {
        if (g_iBoomVomitLevel[client] < 4) g_iBoomVomitLevel[client]++;
        CreateTimer(0.1 * g_iBoomVomitLevel[client], Timer_SpawnHorde, GetClientUserId(client));
    }
    return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if (!IsValidClient(client) ||!IsPlayerAlive(client) ||!IsBoomer(client)) return Plugin_Continue;

    if (buttons & IN_ATTACK2)
    {
        float gameTime = GetGameTime();
        if (gameTime >= g_fNextPunch[client])
        {
            g_fNextPunch[client] = gameTime + g_hPunchDelay.FloatValue;
            BoomerTankPunchArea(client);
        }
    }
    return Plugin_Continue;
}

public Action Timer_SpawnHorde(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClient(client) ||!IsPlayerAlive(client)) return Plugin_Stop;
    SpawnBoomerHorde(client);
    return Plugin_Stop;
}

void SpawnBoomerHorde(int client)
{
    int amount = g_hHorde1.IntValue;
    switch (g_iBoomVomitLevel[client])
    {
        case 2: amount = g_hHorde2.IntValue;
        case 3: amount = g_hHorde3.IntValue;
        case 4: amount = g_hHorde4.IntValue;
    }

    int flags = GetCommandFlags("z_spawn_old");
    SetCommandFlags("z_spawn_old", flags & ~FCVAR_CHEAT);

    for (int i = 0; i < amount; i++)
    {
        ServerCommand("z_spawn_old mob auto");
    }

    SetCommandFlags("z_spawn_old", flags);
}

void BoomerTankPunchArea(int client)
{
    float clientPos[3], clientAng[3], clientForward[3];
    GetClientAbsOrigin(client, clientPos);
    GetClientEyeAngles(client, clientAng);
    GetAngleVectors(clientAng, clientForward, NULL_VECTOR, NULL_VECTOR);
    clientPos[2] += 40.0;

    for (int target = 1; target <= MaxClients; target++)
    {
        if (!IsValidClient(target) ||!IsPlayerAlive(target)) continue;
        if (GetClientTeam(target)!= TEAM_SURVIVOR) continue;

        float targetPos[3];
        GetClientAbsOrigin(target, targetPos);
        targetPos[2] += 40.0;

        if (GetVectorDistance(clientPos, targetPos) > PUNCH_RADIUS) continue;

        float vecToTarget[3];
        SubtractVectors(targetPos, clientPos, vecTo
