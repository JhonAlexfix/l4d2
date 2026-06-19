#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define WITCH_SEARCH_RANGE 500.0
#define WITCH_MOVE_SPEED 200.0
#define WITCH_ATTACK_RANGE 80.0
#define WITCH_ATTACK_DAMAGE 20.0
#define WITCH_MOVE_UPDATE_RATE 0.05
#define CAMERA_HEIGHT_OFFSET 80.0
#define CAMERA_DISTANCE_BEHIND 100.0

#define MAX_WITCHES 32
#define TEAM_INFECTED 3
#define TEAM_SURVIVOR 2

enum struct WitchControlData
{
    int WitchEntity;
    int ControllerClient;
    float LastMoveUpdate;
    float LastSoundTime;
    float OriginalPosition[3];
    float OriginalAngles[3];
    bool IsControlled;
    
    void Reset()
    {
        this.WitchEntity = -1;
        this.ControllerClient = -1;
        this.LastMoveUpdate = 0.0;
        this.LastSoundTime = 0.0;
        this.IsControlled = false;
    }
}

WitchControlData g_WitchData[MAX_WITCHES + 1];
int g_PlayerWitchMap[MAXPLAYERS + 1];
int g_ViewEntities[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name = "L4D2 Witch Control System",
    author = "Shadow L4d2",
    description = "Special Infected ghosts can possess and control Witches",
    version = "5.0",
    url = ""
};

public void OnPluginStart()
{
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_team", Event_PlayerTeam);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("witch_spawn", Event_WitchSpawn);
    HookEvent("witch_killed", Event_WitchKilled);
    HookEvent("player_transitioned", Event_PlayerTransitioned);
    
    ResetAllData();
}

public void OnMapStart()
{
    PrecacheSound("UI/Beep07.wav", true);
    PrecacheSound("UI/Beep05.wav", true);
    PrecacheSound("UI/Beep06.wav", true);
    PrecacheSound("player/smoker/claw/attack_1.wav", true);
    PrecacheSound("player/boomer/claw/attack_1.wav", true);
    PrecacheSound("player/hunter/claw/hit_1.wav", true);
    PrecacheSound("player/spitter/claw/hit_1.wav", true);
    PrecacheSound("player/jockey/claw/hit_1.wav", true);
    PrecacheSound("player/charger/claw/hit_1.wav", true);
    PrecacheSound("npc/witch/voice/attack/start_02.wav", true);
    PrecacheSound("npc/witch/voice/attack/fall_behind_02.wav", true);
    PrecacheSound("npc/witch/voice/attack/fall_short_01.wav", true);
    PrecacheSound("npc/witch/voice/attack/hit_02.wav", true);
    PrecacheSound("npc/witch/voice/retreat/retreat_02.wav", true);
    PrecacheSound("npc/witch/voice/idle/idle_02.wav", true);
    
    PrecacheGeneric("effects/screen_blood.vtf", true);
    
    ResetAllData();
}

public void OnMapEnd()
{
    ResetAllData();
}

void ResetAllData()
{
    for (int i = 0; i <= MAX_WITCHES; i++)
    {
        g_WitchData[i].Reset();
    }
    
    for (int i = 1; i <= MaxClients; i++)
    {
        g_PlayerWitchMap[i] = -1;
        
        if (g_ViewEntities[i] > 0 && IsValidEntity(g_ViewEntities[i]))
        {
            AcceptEntityInput(g_ViewEntities[i], "Kill");
        }
        g_ViewEntities[i] = -1;
    }
}

int FindFreeWitchSlot()
{
    for (int i = 0; i <= MAX_WITCHES; i++)
    {
        if (!g_WitchData[i].IsControlled && g_WitchData[i].WitchEntity == -1)
        {
            return i;
        }
    }
    return -1;
}

int FindWitchSlotByEntity(int witch)
{
    for (int i = 0; i <= MAX_WITCHES; i++)
    {
        if (g_WitchData[i].WitchEntity == witch)
        {
            return i;
        }
    }
    return -1;
}

public void OnClientDisconnect(int client)
{
    int slot = g_PlayerWitchMap[client];
    if (slot != -1)
    {
        ReleaseWitchControl(slot, true);
    }
    
    g_PlayerWitchMap[client] = -1;
    
    if (g_ViewEntities[client] > 0 && IsValidEntity(g_ViewEntities[client]))
    {
        AcceptEntityInput(g_ViewEntities[client], "Kill");
    }
    g_ViewEntities[client] = -1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && IsClientInGame(client))
    {
        int slot = g_PlayerWitchMap[client];
        if (slot != -1)
        {
            ReleaseWitchControl(slot, true);
        }
        
        g_PlayerWitchMap[client] = -1;
        RestorePlayerState(client);
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && IsClientInGame(client))
    {
        int slot = g_PlayerWitchMap[client];
        if (slot != -1)
        {
            ReleaseWitchControl(slot, true);
        }
        
        g_PlayerWitchMap[client] = -1;
    }
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && IsClientInGame(client))
    {
        int newTeam = event.GetInt("team");
        if (newTeam != TEAM_INFECTED)
        {
            int slot = g_PlayerWitchMap[client];
            if (slot != -1)
            {
                ReleaseWitchControl(slot, true);
            }
            g_PlayerWitchMap[client] = -1;
        }
    }
}

public void Event_PlayerTransitioned(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && IsClientInGame(client))
    {
        int slot = g_PlayerWitchMap[client];
        if (slot != -1)
        {
            ReleaseWitchControl(slot, true);
        }
        g_PlayerWitchMap[client] = -1;
    }
}

public void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int witch = event.GetInt("witchid");
    if (witch > 0 && IsValidEntity(witch))
    {
        SDKHook(witch, SDKHook_OnTakeDamage, OnWitchTakeDamage);
        
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && IsAllowedSpecialInfected(i))
            {
                bool isGhost = view_as<bool>(GetEntProp(i, Prop_Send, "m_isGhost", 1));
                if (isGhost && g_PlayerWitchMap[i] == -1)
                {
                    PrintToChat(i, "\x04[Witch Control]\x01 Presiona \x05CTRL+ESPACIO\x01 para poseerla");
                }
            }
        }
    }
}

public void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
    int witch = event.GetInt("witchid");
    if (witch > 0)
    {
        int slot = FindWitchSlotByEntity(witch);
        if (slot != -1 && g_WitchData[slot].IsControlled)
        {
            int client = g_WitchData[slot].ControllerClient;
            ReleaseWitchControl(slot, true);
            
            if (client > 0 && IsClientInGame(client))
            {
                PrintToChat(client, "\x04[Witch Control]\x01 ¡Tu Witch ha sido asesinada!");
            }
        }
    }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = 0; i <= MAX_WITCHES; i++)
    {
        if (g_WitchData[i].IsControlled)
        {
            ReleaseWitchControl(i, false);
        }
    }
    ResetAllData();
}

public Action OnWitchTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    int slot = FindWitchSlotByEntity(victim);
    if (slot != -1 && g_WitchData[slot].IsControlled)
    {
        if (attacker == g_WitchData[slot].ControllerClient)
        {
            damage = 0.0;
            return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount)
{
    if (!IsClientInGame(client) || GetClientTeam(client) != TEAM_INFECTED)
        return Plugin_Continue;
    
    if (!IsAllowedSpecialInfected(client))
        return Plugin_Continue;
    
    bool isGhost = view_as<bool>(GetEntProp(client, Prop_Send, "m_isGhost", 1));
    int slot = g_PlayerWitchMap[client];
    
    if (isGhost && slot == -1)
    {
        if ((buttons & IN_DUCK) && (buttons & IN_JUMP))
        {
            buttons &= ~IN_JUMP;
            buttons &= ~IN_DUCK;
            
            int witch = FindNearestAvailableWitch(client);
            if (witch != -1)
            {
                int newSlot = FindFreeWitchSlot();
                if (newSlot != -1)
                {
                    PossessWitch(client, witch, newSlot);
                    return Plugin_Handled;
                }
            }
        }
    }
    
    else if (slot != -1 && g_WitchData[slot].IsControlled && g_WitchData[slot].ControllerClient == client)
    {
        int witch = g_WitchData[slot].WitchEntity;
        
        if (!IsValidEntity(witch) || !IsWitchAlive(witch))
        {
            ReleaseWitchControl(slot, true);
            return Plugin_Continue;
        }
        
        if (buttons & IN_ATTACK)
        {
            PerformWitchAttack(client, slot);
        }
        
        if (buttons & IN_JUMP)
        {
            buttons &= ~IN_JUMP;
        }
        
        UpdateWitchMovement(client, slot, buttons, angles);
        
        vel[0] = 0.0;
        vel[1] = 0.0;
        vel[2] = 0.0;
        buttons = 0;
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

void PossessWitch(int client, int witch, int slot)
{
    GetEntPropVector(witch, Prop_Send, "m_vecOrigin", g_WitchData[slot].OriginalPosition);
    GetEntPropVector(witch, Prop_Send, "m_angRotation", g_WitchData[slot].OriginalAngles);
    
    g_WitchData[slot].WitchEntity = witch;
    g_WitchData[slot].ControllerClient = client;
    g_WitchData[slot].IsControlled = true;
    g_WitchData[slot].LastMoveUpdate = 0.0;
    g_WitchData[slot].LastSoundTime = 0.0;
    
    g_PlayerWitchMap[client] = slot;
    
    SetEntityMoveType(witch, MOVETYPE_NOCLIP);
    SetEntPropFloat(witch, Prop_Send, "m_rage", 0.0);
    SetEntProp(witch, Prop_Send, "m_mobRush", 0);
    
    SetEntityRenderMode(witch, RENDER_TRANSCOLOR);
    SetEntityRenderColor(witch, 255, 100, 255, 200);
    
    SetEntityRenderMode(client, RENDER_TRANSCOLOR);
    SetEntityRenderColor(client, 255, 255, 255, 0);
    
    CreateCameraEntity(client, witch);
    
    EmitSoundToClient(client, "UI/Beep07.wav");
    EmitSoundToAll("npc/witch/voice/attack/start_02.wav", witch);
    
    PrintToChat(client, "\x04[Witch Control]\x01 Has poseído a la Witch.");
}

void ReleaseWitchControl(int slot, bool forceRestorePosition)
{
    if (!g_WitchData[slot].IsControlled)
        return;
    
    int witch = g_WitchData[slot].WitchEntity;
    int client = g_WitchData[slot].ControllerClient;
    
    if (IsValidEntity(witch))
    {
        EmitSoundToAll("npc/witch/voice/retreat/retreat_02.wav", witch);
        
        SetEntityMoveType(witch, MOVETYPE_WALK);
        SetEntPropFloat(witch, Prop_Send, "m_rage", 0.5);
        
        SetEntityRenderMode(witch, RENDER_NORMAL);
        SetEntityRenderColor(witch, 255, 255, 255, 255);
        
        if (forceRestorePosition)
        {
            TeleportEntity(witch, g_WitchData[slot].OriginalPosition, g_WitchData[slot].OriginalAngles, NULL_VECTOR);
        }
        
        SDKUnhook(witch, SDKHook_OnTakeDamage, OnWitchTakeDamage);
    }
    
    if (client > 0 && IsClientInGame(client))
    {
        RestorePlayerState(client);
        g_PlayerWitchMap[client] = -1;
    }
    
    g_WitchData[slot].Reset();
}

void RestorePlayerState(int client)
{
    if (!IsClientInGame(client))
        return;
    
    SetEntityRenderMode(client, RENDER_NORMAL);
    SetEntityRenderColor(client, 255, 255, 255, 255);
    
    SetClientViewEntity(client, client);
    
    if (g_ViewEntities[client] > 0 && IsValidEntity(g_ViewEntities[client]))
    {
        AcceptEntityInput(g_ViewEntities[client], "Kill");
    }
    g_ViewEntities[client] = -1;
}

void CreateCameraEntity(int client, int witch)
{
    if (g_ViewEntities[client] > 0 && IsValidEntity(g_ViewEntities[client]))
    {
        AcceptEntityInput(g_ViewEntities[client], "Kill");
    }
    
    int camera = CreateEntityByName("prop_dynamic_override");
    if (camera != -1)
    {
        DispatchKeyValue(camera, "model", "models/w_models/weapons/w_eq_medkit.mdl");
        DispatchKeyValue(camera, "solid", "0");
        DispatchKeyValue(camera, "rendermode", "10");
        DispatchSpawn(camera);
        
        float witchPos[3], witchAng[3];
        GetEntPropVector(witch, Prop_Send, "m_vecOrigin", witchPos);
        GetEntPropVector(witch, Prop_Send, "m_angRotation", witchAng);
        
        float fwd[3];
        GetAngleVectors(witchAng, fwd, NULL_VECTOR, NULL_VECTOR);
        ScaleVector(fwd, -CAMERA_DISTANCE_BEHIND);
        
        float cameraPos[3];
        cameraPos[0] = witchPos[0] + fwd[0];
        cameraPos[1] = witchPos[1] + fwd[1];
        cameraPos[2] = witchPos[2] + CAMERA_HEIGHT_OFFSET;
        
        TeleportEntity(camera, cameraPos, witchAng, NULL_VECTOR);
        
        SetClientViewEntity(client, camera);
        g_ViewEntities[client] = camera;
    }
}

void UpdateCameraPosition(int client, int witch, float angles[3])
{
    if (g_ViewEntities[client] > 0 && IsValidEntity(g_ViewEntities[client]))
    {
        float witchPos[3];
        GetEntPropVector(witch, Prop_Send, "m_vecOrigin", witchPos);
        
        float fwd[3];
        GetAngleVectors(angles, fwd, NULL_VECTOR, NULL_VECTOR);
        ScaleVector(fwd, -CAMERA_DISTANCE_BEHIND);
        
        float cameraPos[3];
        cameraPos[0] = witchPos[0] + fwd[0];
        cameraPos[1] = witchPos[1] + fwd[1];
        cameraPos[2] = witchPos[2] + CAMERA_HEIGHT_OFFSET;
        
        TeleportEntity(g_ViewEntities[client], cameraPos, angles, NULL_VECTOR);
    }
}

void UpdateWitchMovement(int client, int slot, int buttons, float angles[3])
{
    float gameTime = GetGameTime();
    if (gameTime - g_WitchData[slot].LastMoveUpdate < WITCH_MOVE_UPDATE_RATE)
        return;
    
    g_WitchData[slot].LastMoveUpdate = gameTime;
    
    int witch = g_WitchData[slot].WitchEntity;
    
    float witchPos[3];
    GetEntPropVector(witch, Prop_Send, "m_vecOrigin", witchPos);
    
    float forwardDir[3], rightDir[3];
    GetAngleVectors(angles, forwardDir, rightDir, NULL_VECTOR);
    
    float wishVel[3] = {0.0, 0.0, 0.0};
    bool isMoving = false;
    
    if (buttons & IN_FORWARD)
    {
        wishVel[0] += forwardDir[0];
        wishVel[1] += forwardDir[1];
        isMoving = true;
    }
    if (buttons & IN_BACK)
    {
        wishVel[0] -= forwardDir[0];
        wishVel[1] -= forwardDir[1];
        isMoving = true;
    }
    if (buttons & IN_MOVELEFT)
    {
        wishVel[0] -= rightDir[0];
        wishVel[1] -= rightDir[1];
        isMoving = true;
    }
    if (buttons & IN_MOVERIGHT)
    {
        wishVel[0] += rightDir[0];
        wishVel[1] += rightDir[1];
        isMoving = true;
    }
    
    if (isMoving)
    {
        float len = SquareRoot(wishVel[0] * wishVel[0] + wishVel[1] * wishVel[1]);
        if (len > 0.0)
        {
            wishVel[0] = (wishVel[0] / len) * WITCH_MOVE_SPEED * WITCH_MOVE_UPDATE_RATE;
            wishVel[1] = (wishVel[1] / len) * WITCH_MOVE_SPEED * WITCH_MOVE_UPDATE_RATE;
        }
        
        float newPos[3];
        newPos[0] = witchPos[0] + wishVel[0];
        newPos[1] = witchPos[1] + wishVel[1];
        newPos[2] = witchPos[2];
        
        TeleportEntity(witch, newPos, angles, NULL_VECTOR);
        
        if (gameTime - g_WitchData[slot].LastSoundTime > 2.0)
        {
            EmitSoundToAll("npc/witch/voice/attack/fall_behind_02.wav", witch);
            g_WitchData[slot].LastSoundTime = gameTime;
        }
    }
    else
    {
        TeleportEntity(witch, NULL_VECTOR, angles, NULL_VECTOR);
        
        if (gameTime - g_WitchData[slot].LastSoundTime > 5.0)
        {
            EmitSoundToAll("npc/witch/voice/idle/idle_02.wav", witch);
            g_WitchData[slot].LastSoundTime = gameTime;
        }
    }
    
    UpdateCameraPosition(client, witch, angles);
}

void PerformWitchAttack(int client, int slot)
{
    int witch = g_WitchData[slot].WitchEntity;
    
    float witchPos[3], witchAng[3];
    GetEntPropVector(witch, Prop_Send, "m_vecOrigin", witchPos);
    GetEntPropVector(witch, Prop_Send, "m_angRotation", witchAng);
    
    float fwd[3];
    GetAngleVectors(witchAng, fwd, NULL_VECTOR, NULL_VECTOR);
    
    bool hitSomeone = false;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i))
            continue;
        
        float targetPos[3];
        GetClientAbsOrigin(i, targetPos);
        
        float distance = GetVectorDistance(witchPos, targetPos);
        if (distance > WITCH_ATTACK_RANGE)
            continue;
        
        float toTarget[3];
        SubtractVectors(targetPos, witchPos, toTarget);
        NormalizeVector(toTarget, toTarget);
        
        float dotProduct = GetVectorDotProduct(fwd, toTarget);
        if (dotProduct < 0.5)
            continue;
        
        int zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
        float damage = GetClassDamage(zombieClass);
        
        SDKHooks_TakeDamage(i, witch, client, damage, DMG_SLASH);
        
        char soundEffect[64];
        switch (zombieClass)
        {
            case 1: strcopy(soundEffect, sizeof(soundEffect), "player/smoker/claw/attack_1.wav");
            case 2: strcopy(soundEffect, sizeof(soundEffect), "player/boomer/claw/attack_1.wav");
            case 3: strcopy(soundEffect, sizeof(soundEffect), "player/hunter/claw/hit_1.wav");
            case 4: strcopy(soundEffect, sizeof(soundEffect), "player/spitter/claw/hit_1.wav");
            case 5: strcopy(soundEffect, sizeof(soundEffect), "player/jockey/claw/hit_1.wav");
            case 6: strcopy(soundEffect, sizeof(soundEffect), "player/charger/claw/hit_1.wav");
        }
        EmitSoundToAll(soundEffect, witch);
        
        ClientCommand(i, "r_screenoverlay effects/screen_blood.vtf");
        CreateTimer(0.5, Timer_RemoveScreenOverlay, i);
        
        char weaponName[32];
        switch (zombieClass)
        {
            case 1: strcopy(weaponName, sizeof(weaponName), "smoker_claw");
            case 2: strcopy(weaponName, sizeof(weaponName), "boomer_claw");
            case 3: strcopy(weaponName, sizeof(weaponName), "hunter_claw");
            case 4: strcopy(weaponName, sizeof(weaponName), "spitter_claw");
            case 5: strcopy(weaponName, sizeof(weaponName), "jockey_claw");
            case 6: strcopy(weaponName, sizeof(weaponName), "charger_claw");
            default: strcopy(weaponName, sizeof(weaponName), "witch_scratch");
        }
        
        Event damageEvent = CreateEvent("player_hurt", true);
        if (damageEvent != null)
        {
            damageEvent.SetInt("userid", GetClientUserId(i));
            damageEvent.SetInt("attacker", GetClientUserId(client));
            damageEvent.SetInt("health", GetClientHealth(i));
            damageEvent.SetInt("dmg_health", RoundToFloor(damage));
            damageEvent.SetString("weapon", weaponName);
            damageEvent.SetInt("type", DMG_SLASH);
            damageEvent.Fire();
        }
        
        hitSomeone = true;
        break;
    }
    
    if (hitSomeone)
    {
        EmitSoundToAll("npc/witch/voice/attack/hit_02.wav", witch);
        EmitSoundToClient(client, "UI/Beep06.wav");
    }
    else
    {
        EmitSoundToAll("npc/witch/voice/attack/fall_short_01.wav", witch);
    }
}

float GetClassDamage(int zombieClass)
{
    switch (zombieClass)
    {
        case 1: return 15.0;
        case 2: return 12.0;
        case 3: return 25.0;
        case 4: return 10.0;
        case 5: return 18.0;
        case 6: return 30.0;
    }
    return WITCH_ATTACK_DAMAGE;
}

public Action Timer_RemoveScreenOverlay(Handle timer, int client)
{
    if (IsClientInGame(client))
    {
        ClientCommand(client, "r_screenoverlay off");
    }
    return Plugin_Stop;
}

int FindNearestAvailableWitch(int client)
{
    float clientPos[3];
    GetClientAbsOrigin(client, clientPos);
    
    int closestWitch = -1;
    float closestDistance = WITCH_SEARCH_RANGE;
    
    int witch = -1;
    while ((witch = FindEntityByClassname(witch, "witch")) != -1)
    {
        if (!IsValidEntity(witch) || !IsWitchAlive(witch))
            continue;
        
        bool isControlled = false;
        for (int i = 0; i <= MAX_WITCHES; i++)
        {
            if (g_WitchData[i].IsControlled && g_WitchData[i].WitchEntity == witch)
            {
                isControlled = true;
                break;
            }
        }
        if (isControlled)
            continue;
        
        float rage = GetEntPropFloat(witch, Prop_Send, "m_rage");
        if (rage > 0.0)
            continue;
        
        float witchPos[3];
        GetEntPropVector(witch, Prop_Send, "m_vecOrigin", witchPos);
        float distance = GetVectorDistance(clientPos, witchPos);
        
        if (distance < closestDistance)
        {
            closestDistance = distance;
            closestWitch = witch;
        }
    }
    
    return closestWitch;
}

bool IsAllowedSpecialInfected(int client)
{
    if (!IsClientInGame(client))
        return false;
    
    int zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
    return (zombieClass >= 1 && zombieClass <= 6);
}

bool IsWitchAlive(int witch)
{
    if (!IsValidEntity(witch))
        return false;
    
    if (HasEntProp(witch, Prop_Data, "m_iHealth"))
    {
        int health = GetEntProp(witch, Prop_Data, "m_iHealth");
        if (health <= 0)
            return false;
    }
    
    if (HasEntProp(witch, Prop_Send, "m_nSequence"))
    {
        int sequence = GetEntProp(witch, Prop_Send, "m_nSequence");
        if (sequence >= 20)
            return false;
    }
    
    return true;
}
