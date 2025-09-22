#include <amxmodx>
#include <reapi>
 
#define PLUGIN_NAME    "First Person Death"
#define PLUGIN_VERSION "1.0"
#define PLUGIN_AUTHOR  "Numb"
 
#define SPECMODE_ALIVE 0
 
//new g_msgScreenFade
 
public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
   
    // Hookchains
    RegisterHookChain(RG_CBasePlayer_Killed, "Fw_PlayerKilled_Post", 1)
   
    // Messages
    //g_msgScreenFade = get_user_msgid("ScreenFade")
}
 
public Fw_PlayerKilled_Post(id)
{
    if(!is_user_connected(id))
        return HC_CONTINUE
   
    // Screen fade effect
    /* message_begin(MSG_ONE_UNRELIABLE, g_msgScreenFade, {0,0,0}, id)
    write_short(12288)  // Duration
    write_short(12288)  // Hold time
    write_short(0x0001) // Fade type
    write_byte (0)      // Red
    write_byte (0)      // Green
    write_byte (0)      // Blue
    write_byte (255)    // Alpha
    message_end() */
   
    //client_cmd(id, "spk fvox/flatline");
    set_entvar(id, var_iuser1, SPECMODE_ALIVE);
   
    return HC_CONTINUE
}