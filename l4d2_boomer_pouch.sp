#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZOMBIECLASS_BOOMER 2

public Plugin myinfo =
{
    name = "L4D2 Boomer Tank Punch",
    author = "Shadow L4D2",
    description = "Boomer golpea como Tank - Simple y directo",
    version = "5.0",
    url = "https://sourcemod.net"
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

    g_hPunchDamage   = CreateConVar("sm_boomer_punch_damage", "4", "Daño del golpe");
    g_hPunchForce    = CreateConVar("sm_boomer_punch_force", "900", "Fuerza horizontal");
    g_hPunchUpForce  = CreateConVar("sm_boomer_punch_upforce", "300", "Fuerza vertical");
    g_hPunchDelay    = CreateConVar("sm_boomer_punch_delay", "1.5", "Delay entre golpes");
    g_hHorde1        = CreateConVar("sm_boomer_horde_1", "13", "Horda nivel 1");
    g_hHorde2        = CreateConVar("sm_boomer_horde_2", "23", "Horda nivel 2");
    g_hHorde3        = CreateConVar("sm_boomer_horde_3", "43", "Horda nivel 3");
    g_hHorde4        = CreateConVar("sm_boomer_horde_4", "53", "Horda nivel 4");

    AutoExecConfig(true, "boomer_berserker");

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            ResetBoomer(i);
        }
    }
}

public void OnClientPutInServer(int client)
{
    ResetBoomer(client);
}

public void OnClientDisconnect(int client)
{
    ResetBoomer(client);
}

void ResetBoomer(int client)
{
    g_iBoomVomitLevel[client] = 0;
    g_fNextPunch[client] = 0.0;
}

public Action Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client) || !IsPlayerAlive(client) || !IsBoomer(client))
        return Plugin_Continue;

    char ability[64];
    event.GetString("ability", ability, sizeof(ability));

    if (StrEqual(ability, "ability_vomit"))
    {
        g_iBoomVomitLevel[client]++;
        if (g_iBoomVomitLevel[client] > 4) g_iBoomVomitLevel[client] = 4;
        SpawnBoomerHorde(client);
    }
    return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if (!IsValidClient(client) || !IsPlayerAlive(client) || !IsBoomer(client))
        return Plugin_Continue;

    if (buttons & IN_ATTACK2)
    {
        float gameTime = GetGameTime();
        if (gameTime >= g_fNextPunch[client])
        {
            g_fNextPunch[client] = gameTime + g_hPunchDelay.FloatValue;
            BoomerTankPunch(client);
        }
    }
    return Plugin_Continue;
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

void BoomerTankPunch(int client)
{
    int target = GetClientAimTarget(client, false);
    if (target <= 0 || target > MaxClients) return;
    if (!IsClientInGame(target)) return;
    if (GetClientTeam(target) != TEAM_SURVIVOR) return;
    if (!IsPlayerAlive(target)) return;

    float ang[3], vec[3];
    GetClientEyeAngles(client, ang);
    GetAngleVectors(ang, vec, NULL_VECTOR, NULL_VECTOR);
    
    NormalizeVector(vec, vec);
    ScaleVector(vec, g_hPunchForce.FloatValue);
    vec[2] = g_hPunchUpForce.FloatValue;

    float targetPos[3];
    GetClientAbsOrigin(target, targetPos);
    targetPos[2] += 20.0;

    SDKHooks_TakeDamage(target, client, client, g_hPunchDamage.FloatValue, DMG_CLUB);
    
    L4D_StaggerPlayer(target, client, vec);
    
    CreateTimer(2.0, Timer_ResetStagger, target);
}

public Action Timer_ResetStagger(Handle timer, int client)
{
    if (IsValidClient(client) && IsPlayerAlive(client))
    {
        L4D_StaggerPlayer(client, 0, NULL_VECTOR);
    }
    return Plugin_Stop;
}

bool IsBoomer(int client)
{
    if (GetClientTeam(client) != TEAM_INFECTED) return false;
    return (GetEntProp(client, Prop_Send, "m_zombieClass") == ZOMBIECLASS_BOOMER);
}

bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}