#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <adminmenu>
#include <menus>
#include <console>
#include <sdktools_sound>

#pragma semicolon 1
#pragma newdecls required

#define MAX_CLIENTS 129
#define MAX_INTEGER_STRING_LENGTH 16
#define HIDEHUD_RADAR 1 << 12

public Plugin myinfo = 
{
    name = "Võidujooksu 1", 
    author = "Erki", 
    description = "TONT", 
    version = "1", 
    url = "http://www.sourcemod.net/"
};

ConVar ctDefaultPrimary;
ConVar ctDefaultSecondary;
ConVar damagePrintEnabled;
ConVar skinColorEnabled;
ConVar headshotOnlyEnabled;
ConVar fastEquipEnabled;
ConVar freeForAllEnabled;
ConVar deathmatchModeEnabled;
ConVar botIgnorePlayersEnabled;
ConVar hitSoundEnabled;
ConVar instantRespawnEnabled;

float myVolume;
char hitSoundFile[256];
char headshotSoundFile[256];
int roundDamageDone[MAXPLAYERS+1][MAXPLAYERS+1];
int roundDamageDoneHits[MAXPLAYERS+1][MAXPLAYERS+1];
char g_cPrimaryWeapon[MAXPLAYERS + 1][24];
char g_cSecondaryWeapon[MAXPLAYERS + 1][24];
int ctR;
int ctG;
int ctB;
int tR;
int tG;
int tB;
int colorteam;

public void OnPluginStart()
{
    ctR = 255, ctG = 255, ctB = 255;
    tR = 255, tG = 255, tB = 255;
    hitSoundEnabled = CreateConVar("hks_enabled", "1");
    myVolume = 0.80;
    hitSoundFile = "buttons/button15.wav";
    headshotSoundFile = "buttons/button17.wav";


    LoadTranslations("botmenu_test.phrases");
    LoadTranslations("configmenu_test.phrases");

    RegConsoleCmd("sm_race1", MainMenu);

    instantRespawnEnabled = CreateConVar("sm_instantrespawn_enabled", "0");
    skinColorEnabled = CreateConVar("sm_skincolor_enabled", "0");
    damagePrintEnabled = CreateConVar("sm_damageprint_enabled", "1");
    headshotOnlyEnabled = FindConVar("mp_damage_headshot_only");
    botIgnorePlayersEnabled = FindConVar("bot_ignore_players");
    fastEquipEnabled = CreateConVar("sm_fast_equip", "0");
    freeForAllEnabled = CreateConVar("dm_free_for_all", "0");
    deathmatchModeEnabled = CreateConVar("sm_enabled", "0");


    freeForAllEnabled.AddChangeHook(Event_CvarChange);
    HookEvent("player_hurt", PlayerHurt);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
    HookEvent("player_hurt", Event_DamageDealt, EventHookMode_Pre);
    HookEvent("server_cvar", Event_ServerCvar, EventHookMode_Pre);
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
    HookEvent("player_death", OnPlayerDeath);
}

public void OnMapStart()
{
    OnConfigsExecutedDefaultWeapon();
    SetBuyZones("Disable");
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (instantRespawnEnabled.BoolValue)
    {
        if (IsValidClient(client))
        {
            RequestFrame(Frame_InstantRespawn, GetClientSerial(client));
        }
    }
    
}

public void PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    if (GetConVarBool(hitSoundEnabled))
    {       
        PrecacheSound(hitSoundFile);
        int attackerID = event.GetInt("attacker");
        int attacker = GetClientOfUserId(attackerID);
        int hGroup = event.GetInt("hitgroup");

        if (IsValidClient(attacker))
        {
            if (hGroup == 1)
            {
                EmitSoundToClient(attacker, headshotSoundFile, SOUND_FROM_PLAYER, SNDCHAN_BODY, SNDLEVEL_NORMAL, SND_NOFLAGS, myVolume);
            }
            else
            {
                EmitSoundToClient(attacker, hitSoundFile, SOUND_FROM_PLAYER, SNDCHAN_BODY, SNDLEVEL_NORMAL, SND_NOFLAGS, myVolume);
            }
        }
    }
}

public void Frame_RemoveRadar(any serial)
{
	int clientserial = GetClientFromSerial(serial);
	
	if (IsPlayerAlive(clientserial))
    {
    	SetEntProp(clientserial, Prop_Send, "m_iHideHUD", HIDEHUD_RADAR);
    }
}

public void Frame_InstantRespawn(any serial)
{
    int client = GetClientFromSerial(serial);

    if (IsValidClient(client)) 
    {
    	if (!IsPlayerAlive(client))
    	{
        	CS_RespawnPlayer(client);  
    	}
    }
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (damagePrintEnabled.IntValue == 0)
    return;

    for (int i = 1; i <= MaxClients; i++) 
    {
        if (IsValidClient(i)) 
        {
            PrintDamageInfo(i);
        }
    }
    for (int i = 1; i <= MaxClients; i++) 
    {
        for (int j = 1; j <= MaxClients; j++) 
        {
            roundDamageDone[i][j] = 0;
            roundDamageDoneHits[i][j] = 0;
        }
    }
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int team = GetClientTeam(client);
    RequestFrame(Frame_RemoveRadar, GetClientSerial(client));


    if (skinColorEnabled.BoolValue)
    {
        if (IsValidClient(client))
        {
            if (team == CS_TEAM_CT) 
            {   
                SetEntityRenderColor(client, ctR, ctG, ctB, 255);
            }
            else if (team == CS_TEAM_T)
            {
                SetEntityRenderColor(client, tR, tG, tB, 255);
            }
            else
            {
                return;
            }
        }
    }

    if (fastEquipEnabled.BoolValue)
    {
        if (IsValidClient(client))
        {
            if (!IsFakeClient(client))
            {
                GiveSavedWeapons(client, true, true);
            }
        }
    }
}

public Action Event_DamageDealt(Event event, const char[] name, bool dontBroadcast) 
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = GetClientOfUserId(event.GetInt("userid"));
    bool validAttacker = IsValidClient(attacker);
    bool validVictim = IsValidClient(victim);

    if (validAttacker && validVictim) {
        int preDamageHealth = GetClientHealth(victim);
        int damage = event.GetInt("dmg_health");
        int postDamageHealth = event.GetInt("health");

        if (postDamageHealth == 0) {
            damage += preDamageHealth;
        }
        roundDamageDone[attacker][victim] += damage;
        roundDamageDoneHits[attacker][victim]++;
    }
}

public void Event_CvarChange(ConVar cvar, const char[] oldValue, const char[] newValue)
{
    if (cvar == freeForAllEnabled)
    {
        UpdateState();
    }
}


public Action Event_ServerCvar(Handle event, const char[] name, bool dontBroadcast)
{
    dontBroadcast = true;
    return Plugin_Handled;
}

stock bool IsValidClient(int client) 
{
    return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client);
}

public Action Load1v1Competitive(int client)
{
    ServerCommand("exec gamemode_competitive_server");
    deathmatchModeEnabled.SetString("0");
    OnConfigsExecutedDefaultWeapon();
    return Plugin_Handled;
}

public Action Load1v1DM(int client)
{
    ServerCommand("exec 1v1conf");
    deathmatchModeEnabled.SetString("1");
    OnConfigsExecutedDefaultWeapon();
    return Plugin_Handled;
}

public Action LoadAWP(int client)
{
    ServerCommand("exec awp");
    OnConfigsExecutedDefaultWeapon();
    return Plugin_Handled;
}

public Action LoadUSP(int client)
{
    ServerCommand("exec usp");
    OnConfigsExecutedDefaultWeapon();
    return Plugin_Handled;
}

public void OnConfigsExecutedDefaultWeapon()
{
    ctDefaultPrimary = FindConVar("mp_ct_default_primary");
    ctDefaultSecondary = FindConVar("mp_ct_default_secondary");
}

static void PrintDamageInfo(int client) 
{
    if (!IsValidClient(client))
        return;

    int team = GetClientTeam(client);

    if (team != CS_TEAM_T && team != CS_TEAM_CT)
        return;

    char message[256];
    int otherTeam = (team == CS_TEAM_T) ? CS_TEAM_CT : CS_TEAM_T;

    for (int i = 1; i <= MaxClients; i++) 
    {
        if (IsValidClient(i) && GetClientTeam(i) == otherTeam) 
        {
            int health = IsPlayerAlive(i) ? GetClientHealth(i) : 0;
            char name[64];
            GetClientName(i, name, sizeof(name));
            message = "\x04[Race1] To: [{DMG_TO} / {HITS_TO}] From: [{DMG_FROM} / {HITS_FROM}) hits] {NAME} ({HEALTH} hp)";
            ReplaceStringWithInt(message, sizeof(message), "{DMG_TO}", roundDamageDone[client][i], false);
            ReplaceStringWithInt(message, sizeof(message), "{HITS_TO}", roundDamageDoneHits[client][i], false);
            ReplaceStringWithInt(message, sizeof(message), "{DMG_FROM}", roundDamageDone[i][client], false);
            ReplaceStringWithInt(message, sizeof(message), "{HITS_FROM}", roundDamageDoneHits[i][client], false);
            ReplaceString(message, sizeof(message), "{NAME}", name, false);
            ReplaceStringWithInt(message, sizeof(message), "{HEALTH}", health, false);
            PrintToChat(client, message);
        }
    }
}

stock void ReplaceStringWithInt(char[] buffer, int len, const char[] replace, int value, bool caseSensitive=true) 
{
    char intString[MAX_INTEGER_STRING_LENGTH];
    IntToString(value, intString, sizeof(intString));
    ReplaceString(buffer, len, replace, intString, caseSensitive);
}

public void Frame_FastSwitch(any serial)
{
    int client = GetClientFromSerial(serial);
    if (!IsValidClient(client) || !IsPlayerAlive(client))
        return;

    int sequence = 0;
    SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime());
    int viewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");

    if (IsValidEntity(viewModel))
        SetEntProp(viewModel, Prop_Send, "m_nSequence", sequence);
}

public void GiveSkinnedWeapon(int client, const char[] weapon)
{
    GivePlayerItem(client, weapon);

    if (fastEquipEnabled.BoolValue)
    RequestFrame(Frame_FastSwitch, GetClientSerial(client));
}

void RemoveClientWeapons(int client, bool primary = true, bool secondary = false)
{
    if (IsValidClient(client) && IsPlayerAlive(client))
    {
        int weapon;
        if (primary)
            weapon = 0;
        else if (secondary)
            weapon = 1;
        else
            weapon = 1;

        FakeClientCommand(client, "use weapon_knife");
        for (int i = weapon; i < 4; i++)
        {
            if (i == 2) continue; /* Keep knife. */
            int entityIndex;
            while ((entityIndex = GetPlayerWeaponSlot(client, i)) != -1)
            {
                RemovePlayerItem(client, entityIndex);
                AcceptEntityInput(entityIndex, "Kill");
            }
        }
    }
}

void GiveSavedWeapons(int client, bool primary, bool secondary)
{
    char cPrimary[24];
    char cSecondary[24];

    ctDefaultPrimary.GetString(cPrimary, 24);
    ctDefaultSecondary.GetString(cSecondary, 24);

    g_cPrimaryWeapon[client] = cPrimary;
    g_cSecondaryWeapon[client] = cSecondary;

    if (primary)
    {
        RemoveClientWeapons(client, primary, secondary);
        GiveSkinnedWeapon(client, g_cPrimaryWeapon[client]);
    }
    if (secondary)
    {
        int entityIndex = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE);
        if (entityIndex != -1)
        {
            RemovePlayerItem(client, entityIndex);
            AcceptEntityInput(entityIndex, "Kill");
        }
        GiveSkinnedWeapon(client, g_cSecondaryWeapon[client]);
        GivePlayerItem(client, "weapon_knife");
    }
}

void UpdateState()
{
    if (deathmatchModeEnabled.BoolValue)
    {
        if (freeForAllEnabled.BoolValue)
        {
            ServerCommand("exec enableFFA");
        }
        else
        {
            ServerCommand("exec disableFFA");
        }
    }
}

void SetBuyZones(const char[] status)
{
    int maxEntities = GetMaxEntities();
    char class[24];

    for (int i = MaxClients + 1; i < maxEntities; i++)
    {
        if (IsValidEdict(i))
        {
            GetEdictClassname(i, class, sizeof(class));
            if (StrEqual(class, "func_buyzone"))
                AcceptEntityInput(i, status);
        }
    }
}

public Action MainMenu(int client, int args)
{
    Menu mainMenu = new Menu(Menu_Callback);
    mainMenu.SetTitle("Race1 Menu");
    mainMenu.AddItem("option1", "Set Configuration");
    mainMenu.AddItem("option2", "Change Map");
    mainMenu.AddItem("option3", "Bot Menu"); 
    mainMenu.AddItem("option4", "Simple Body Colors");
    mainMenu.AddItem("option5", "Select Skin/Knife");
    mainMenu.Display(client, 20);
    return Plugin_Handled;
}

public int Menu_Callback(Menu menu, MenuAction action, int client, int param2)
{    
    switch (action) 
    {
        case MenuAction_Select:        
        {
            char item[64];
            menu.GetItem(param2, item, sizeof(item));
            
            if(StrEqual(item, "option1"))            
            {
                DisplayConfigMenu(client);
            }
            else if (StrEqual(item, "option2"))            
            {
                DisplayMapMenu(client);
            }
            else if (StrEqual(item, "option3"))
            {
                DisplayBotMenu(client);
            }
            else if (StrEqual(item, "option4"))
            {   
                DisplayColorMenuPickTeam(client);
            }
            else if (StrEqual(item, "option5"))
            {
                DisplaySkinMenu(client);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }   
}

public int ConfigMenu_Callback(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) 
    {
        case MenuAction_Start:
        {
            PrintToServer("Displaying menu");
        }
        case MenuAction_Display:
        {
            char buffer[255];
            Format(buffer, sizeof(buffer), "%T", "Configuration Menu", client); 
            Panel panel = view_as<Panel>(param2);
            panel.SetTitle(buffer);
            PrintToServer("Client %d was sent menu with panel %x", client, param2);
        }
        case MenuAction_Select:
        {
            char item[32];
            menu.GetItem(param2, item, sizeof(item));
            
            if(StrEqual(item, "option1"))
            {
                Load1v1Competitive(client);
                DisplayConfigMenu(client);
            }
            else if (StrEqual(item, "option2"))
            {
                Load1v1DM(client);
                DisplayConfigMenu(client);
            }
            else if (StrEqual(item, "option3"))
            {
                LoadAWP(client);
                DisplayConfigMenu(client);
            }
            else if (StrEqual(item, "option4"))
            {
                LoadUSP(client);
                DisplayConfigMenu(client);                
            }
            else if (StrEqual(item, "option5"))
            {
                fastEquipEnabled.SetString("1");
                DisplayConfigMenu(client);
            }
            else if (StrEqual(item, "option6"))
            {
                fastEquipEnabled.SetString("0");
                DisplayConfigMenu(client);
            }
            else if (StrEqual(item, "option7"))
            {
                freeForAllEnabled.SetString("1");
                DisplayConfigMenu(client);
            }
            else if (StrEqual(item, "option8"))
            {
                freeForAllEnabled.SetString("0");
                DisplayConfigMenu(client);
            }
            else if (StrEqual(item, "option9"))
            {
                headshotOnlyEnabled.SetString("1");
                DisplayConfigMenu(client);
            }
            else if (StrEqual(item, "option10"))
            {
                headshotOnlyEnabled.SetString("0");
                DisplayConfigMenu(client);
            }
            else if (StrEqual(item, "option11"))
            {
                hitSoundEnabled.SetString("1");
                DisplayConfigMenu(client);
            }
            else if (StrEqual(item, "option12"))
            {
                hitSoundEnabled.SetString("0");
                DisplayConfigMenu(client);
            }
            else if (StrEqual(item, "option13"))
            {
                instantRespawnEnabled.SetString("1");
                DisplayConfigMenu(client);
            }
            else if (StrEqual(item, "option12"))
            {
                instantRespawnEnabled.SetString("0");
                DisplayConfigMenu(client);
            }
        }
        case MenuAction_Cancel:
        {
            PrintToServer("Client %d's menu was cancelled for reason %d", client, param2);
        }
        case MenuAction_End:
        {
            delete menu;
        }
        case MenuAction_DrawItem:
        {
            int style;
            char info[32];
            menu.GetItem(param2, info, sizeof(info), style);
            return style;
        }
        case MenuAction_DisplayItem:
        {
            return 0;
        }
    }
    return 0;
}

public int MapMenu_Callback(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[64];
        /* Get item info */
        bool found = menu.GetItem(param2, info, sizeof(info));
        /* Tell the client */
        PrintToConsole(param1, "You selected item: %d (found? %d info: %s)", param2, found, info);
        /* Change the map */
        ServerCommand("changelevel %s", info);
    }
}

public int BotMenu_Callback(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) 
    {
        case MenuAction_Start:
        {
            PrintToServer("Displaying menu");
        }
        case MenuAction_Display:
        {
            char buffer[255];
            Format(buffer, sizeof(buffer), "%T", "Bot Menu", client); 
            Panel panel = view_as<Panel>(param2);
            panel.SetTitle(buffer);
            PrintToServer("Client %d was sent menu with panel %x", client, param2);
        }
        case MenuAction_Select:
        {
            char item[32];
            menu.GetItem(param2, item, sizeof(item));
            if(StrEqual(item, "option1"))
            {
                ServerCommand("bot_add_t");
                DisplayBotMenu(client);
            }
            else if (StrEqual(item, "option2"))
            {
                ServerCommand("bot_add_ct");
                DisplayBotMenu(client);
            }
            else if (StrEqual(item, "option3"))
            {
                botIgnorePlayersEnabled.SetString("1");
                DisplayBotMenu(client);
            }
            else if (StrEqual(item, "option4"))
            {
                ServerCommand("bot_kick");
            }
            else if (StrEqual(item, "option5"))
            {
                botIgnorePlayersEnabled.SetString("0");
                DisplayBotMenu(client);
            }
        }
        case MenuAction_Cancel:
        {
            PrintToServer("Client %d's menu was cancelled for reason %d", client, param2);
        }
        case MenuAction_End:
        {
            delete menu;
        }
        case MenuAction_DrawItem:
        {
            int style;
            char info[32];
            menu.GetItem(param2, info, sizeof(info), style);
            return style;
        }
        case MenuAction_DisplayItem:
        {
            return 0;
        }
    }
    return 0;
}

public int ColorCallback(Handle menu, MenuAction action, int client, int item)
{
    switch(action)
    {
        case MenuAction_Select:
        {
                        char item_name[64];
                        GetMenuItem(menu, item, item_name, sizeof(item_name));
                        if(StrEqual(item_name, "RC"))
                        {
                            if (colorteam == CS_TEAM_CT) 
                            {   
                                ctR = 255, ctG = 255, ctB = 255;
                            }
                            else if (colorteam == CS_TEAM_T)
                            {
                                tR = 255, tG = 255, tB = 255;
                            }
                            else
                            {
                                return;
                            }
                        }
                        else if(StrEqual(item_name, "GREEN"))
                        {
                            if (colorteam == CS_TEAM_CT) 
                            {   
                                ctR = 0, ctG = 255, ctB = 0;
                            }
                            else if (colorteam == CS_TEAM_T)
                            {
                                tR = 0, tG = 255, tB = 0;
                            }
                            else
                            {
                                return;
                            }
                        }
                        else if(StrEqual(item_name, "RED"))
                        {
                            if (colorteam == CS_TEAM_CT) 
                            {   
                                ctR = 255, ctG = 0, ctB = 0;
                            }
                            else if (colorteam == CS_TEAM_T)
                            {
                                tR = 255, tG = 0, tB = 0;
                            }
                            else
                            {
                                return;
                            }
                        }
                        else if(StrEqual(item_name, "BLUE"))
                        {
                            if (colorteam == CS_TEAM_CT) 
                            {   
                                ctR = 0, ctG = 0, ctB = 255;
                            }
                            else if (colorteam == CS_TEAM_T)
                            {
                                tR = 0, tG = 0, tB = 255;
                            }
                            else
                            {
                                return;
                            }
                        }
                        else if(StrEqual(item_name, "GOLD"))
                        {
                            if (colorteam == CS_TEAM_CT) 
                            {   
                                ctR = 255, ctG = 215, ctB = 0;
                            }
                            else if (colorteam == CS_TEAM_T)
                            {
                                tR = 255, tG = 215, tB = 0;
                            }
                            else
                            {
                                return;
                            }
                        }
                        else if(StrEqual(item_name, "BLACK"))
                        {
                            if (colorteam == CS_TEAM_CT) 
                            {   
                                ctR = 0, ctG = 0, ctB = 0;
                            }
                            else if (colorteam == CS_TEAM_T)
                            {
                                tR = 0, tG = 0, tB = 0;
                            }
                            else
                            {
                                return;
                            }
                        }
                        else if(StrEqual(item_name, "CYAN"))
                        {
                            if (colorteam == CS_TEAM_CT) 
                            {   
                                ctR = 0, ctG = 255, ctB = 255;
                            }
                            else if (colorteam == CS_TEAM_T)
                            {
                                tR = 0, tG = 255, tB = 255;
                            }
                            else
                            {
                                return;
                            }
                        }
                        else if(StrEqual(item_name, "TURQUOISE"))
                        {
                            if (colorteam == CS_TEAM_CT) 
                            {   
                                ctR = 64, ctG = 224, ctB = 208;
                            }
                            else if (colorteam == CS_TEAM_T)
                            {
                                tR = 64, tG = 224, tB = 208;
                            }
                            else
                            {
                                return;
                            }
                        }
                        else if(StrEqual(item_name, "SKYBLUE"))
                        {
                            if (colorteam == CS_TEAM_CT) 
                            {   
                                ctR = 0, ctG = 191, ctB = 255;
                            }
                            else if (colorteam == CS_TEAM_T)
                            {
                                tR = 0, tG = 191, tB = 255;
                            }
                            else
                            {
                                return;
                            }
                        }
                        else if(StrEqual(item_name, "DODGER"))
                        {
                            if (colorteam == CS_TEAM_CT) 
                            {   
                                ctR = 30, ctG = 144, ctB = 255;
                            }
                            else if (colorteam == CS_TEAM_T)
                            {
                                tR = 30, tG = 144, tB = 255;
                            }
                            else
                            {
                                return;
                            }
                        }
                        else if(StrEqual(item_name, "YELLOW"))
                        {
                            if (colorteam == CS_TEAM_CT) 
                            {   
                                ctR = 255, ctG = 255, ctB = 0;
                            }
                            else if (colorteam == CS_TEAM_T)
                            {
                                tR = 255, tG = 255, tB = 0;
                            }
                            else
                            {
                                return;
                            }
                        }
                        else if(StrEqual(item_name, "PINK"))
                        {
                            if (colorteam == CS_TEAM_CT) 
                            {   
                                ctR = 255, ctG = 105, ctB = 180;
                            }
                            else if (colorteam == CS_TEAM_T)
                            {
                                tR = 255, tG = 105, tB = 180;
                            }
                            else
                            {
                                return;
                            }
                        }
                        else if(StrEqual(item_name, "PURPLE"))
                        {
                            if (colorteam == CS_TEAM_CT) 
                            {   
                                ctR = 128, ctG = 0, ctB = 255;
                            }
                            else if (colorteam == CS_TEAM_T)
                            {
                                tR = 128, tG = 0, tB = 255;
                            }
                            else
                            {
                                return;
                            }
                        }
                        else if(StrEqual(item_name, "GRAY"))
                        {
                            if (colorteam == CS_TEAM_CT) 
                            {   
                                ctR = 128, ctG = 128, ctB = 128;
                            }
                            else if (colorteam == CS_TEAM_T)
                            {
                                tR = 128, tG = 128, tB = 128;
                            }
                            else
                            {
                                return;
                            }   
                        }
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
    }
}

public int SkinMenu_Callback(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) 
    {
        case MenuAction_Select:
        {
            char item[32];
            menu.GetItem(param2, item, sizeof(item));
            if(StrEqual(item, "option1"))
            {
                //ServerCommand("sm_ws #%d", GetClientUserId(client));// 
                FakeClientCommand(client, "sm_ws");
            }
            else if (StrEqual(item, "option2"))
            {
                FakeClientCommand(client, "sm_knife");
                //ServerCommand("sm_knife #%d", GetClientUserId(client));//
            }
            else if (StrEqual(item, "option3"))
            {
                FakeClientCommand(client, "sm_gloves");
                //ServerCommand("sm_knife #%d", GetClientUserId(client));//
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
}

public int ColorTeamMenu_Callback(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) 
    {
        case MenuAction_Select:
        {
            char item[32];
            menu.GetItem(param2, item, sizeof(item));

            if(StrEqual(item, "option1"))
            {
                skinColorEnabled.SetString("1");
                colorteam = CS_TEAM_CT;
                DisplayColorMenu(client);
            }
            else if (StrEqual(item, "option2"))
            {   
                skinColorEnabled.SetString("1");
                colorteam = CS_TEAM_T;
                DisplayColorMenu(client);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
}


void DisplayConfigMenu(int client)
{
    Menu configMenu = new Menu(ConfigMenu_Callback, MENU_ACTIONS_ALL);
    configMenu.SetTitle("%T","Configuration Menu", LANG_SERVER);
    configMenu.AddItem("option1", "Load 1v1 Rounds");
    configMenu.AddItem("option2", "Load 1v1 DM");
    configMenu.AddItem("option3", "Load AWP"); 
    configMenu.AddItem("option4", "Load USP");    
    if (GetConVarInt(fastEquipEnabled) == 1) 
    {
        configMenu.AddItem("option6", "Disable Fast Equip");
    }
    else
    {
        configMenu.AddItem("option5", "Enable Fast Equip");
    }
    if (GetConVarInt(freeForAllEnabled) == 1)
    {
        configMenu.AddItem("option8", "Disable FFA");
    }
    else
    {
        configMenu.AddItem("option7", "Enable FFA");
    }
    if (headshotOnlyEnabled.IntValue == 1)
    {
        configMenu.AddItem("option10", "Disable HS Only");
    }
    else
    {
        configMenu.AddItem("option9", "Enable HS Only");
    }
    if (hitSoundEnabled.IntValue == 1)
    {
        configMenu.AddItem("option12", "Disable Hitsound");
    }
    else
    {
        configMenu.AddItem("option11", "Enable Hitsound");
    }
    if (instantRespawnEnabled.IntValue == 1)
    {
        configMenu.AddItem("option14", "Disable Instant Respawn");
    }
    else
    {
        configMenu.AddItem("option13", "Enable Instant Respawn");
    }
    configMenu.ExitButton = true;
    configMenu.Display(client, MENU_TIME_FOREVER);
}

void DisplayMapMenu(int client)
{
    File file = OpenFile("maplist2.txt", "rt");
    Menu mapMenu = new Menu(MapMenu_Callback);
    char mapname[255];
    while (!file.EndOfFile() && file.ReadLine(mapname, sizeof(mapname)))
    {
        if (mapname[0] == ';' || !IsCharAlpha(mapname[0]))
        {
            continue;
        }
        int len = strlen(mapname);
        for (int i = 0; i < len; i++)
        {
            if (IsCharSpace(mapname[i]))
            {
                mapname[i] = '\0';
                break;
            }
        }
        if (!IsMapValid(mapname))
        {
            continue;
        }
        mapMenu.AddItem(mapname, mapname);
    }
    file.Close();
    mapMenu.SetTitle("Please select a map:");
    mapMenu.Display(client, 30);
}

void DisplayBotMenu(int client)
{
    Menu botMenu = new Menu(BotMenu_Callback, MENU_ACTIONS_ALL);
    botMenu.SetTitle("%T","Bot Menu", LANG_SERVER);
    botMenu.AddItem("option1", "Add Bot T");
    botMenu.AddItem("option2", "Add Bot CT");
    if (botIgnorePlayersEnabled.IntValue == 1)
    {
        botMenu.AddItem("option5", "Bot Ignore Players Off");
    }
    else
    {
        botMenu.AddItem("option3", "Bot Ignore Players"); 
    }
    botMenu.AddItem("option4", "Kick Bots");
    botMenu.ExitButton = true;
    botMenu.Display(client, MENU_TIME_FOREVER);
}

void DisplayColorMenu(int client)
{
    Handle colors = CreateMenu(ColorCallback, MenuAction_Select | MenuAction_End | MenuAction_DisplayItem);
    SetMenuTitle(colors, "Color Body Menu");
    AddMenuItem(colors, "x", "------------------", ITEMDRAW_DISABLED);
    AddMenuItem(colors, "RC", "Remove Color");
    AddMenuItem(colors, "GREEN", "Green");
    AddMenuItem(colors, "RED", "Red");
    AddMenuItem(colors, "BLUE", "Blue");
    AddMenuItem(colors, "GOLD", "Gold");
    AddMenuItem(colors, "BLACK", "Black");
    AddMenuItem(colors, "CYAN", "Cyan");
    AddMenuItem(colors, "TURQUOISE", "Turquoise");
    AddMenuItem(colors, "SKYBLUE", "Sky as Blue");
    AddMenuItem(colors, "DODGER", "Dodger Blue");
    AddMenuItem(colors, "YELLOW", "Yellow");
    AddMenuItem(colors, "PINK", "Pink");
    AddMenuItem(colors, "PURPLE", "Purple");
    AddMenuItem(colors, "GRAY", "Gray");
    DisplayMenu(colors, client, MENU_TIME_FOREVER);
}

void DisplaySkinMenu(int client)
{
    Menu skinMenu = new Menu(SkinMenu_Callback);
    skinMenu.AddItem("option1", "Pick Skin");
    skinMenu.AddItem("option2", "Pick Knife"); 
    skinMenu.AddItem("option3", "Pick Gloves"); 
    skinMenu.SetTitle("Skin Menu");
    skinMenu.Display(client, 30);
}

void DisplayColorMenuPickTeam(int client)
{
    Menu skinMenu = new Menu(ColorTeamMenu_Callback);
    skinMenu.AddItem("option1", "Pick CT Color");
    skinMenu.AddItem("option2", "Pick T Color"); 
    skinMenu.SetTitle("Color Menu");
    skinMenu.Display(client, 30);
}

