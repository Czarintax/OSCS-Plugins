#include <amxmodx>
#include <reapi>

new const sound_fireinhole[] = "radio/ct_fireinhole.wav"

public plugin_precache()
{
	precache_sound(sound_fireinhole)
}

public plugin_init() 
{
	register_plugin( "'Fire in the hole' Real Voice", "1.0", "Leo_[BH]" );
    
	register_message( get_user_msgid( "TextMsg" ),   "MessageTextMsg" );
	register_message( get_user_msgid( "SendAudio" ), "MessageSendAudio" );
	
	RegisterHookChain( RG_CBasePlayer_ThrowGrenade, "CBasePlayer_ThrowGrenade_Post", true );
}

public CBasePlayer_ThrowGrenade_Post(const id, const grenade, const Float:vecSrc[3], const Float:vecThrow[3])
{
	if(is_user_alive(id)) emit_sound(id, CHAN_VOICE, sound_fireinhole, 1.0, ATTN_NORM, 0, PITCH_NORM );
}

public MessageTextMsg()
{
	if(get_msg_args() == 5)
	{
		if(EqualValue( 5, "#Fire_in_the_hole" ))
		{
			return PLUGIN_HANDLED;
		}
	}
	
	return PLUGIN_CONTINUE
}

public MessageSendAudio()
{
	if(EqualValue( 2, "%!MRAD_FIREINHOLE" ))
	{
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

EqualValue( const iParam, const szString[ ] ) 
{
    new szTemp[ 18 ];
    get_msg_arg_string( iParam, szTemp, 17 );
    
    return ( equal( szTemp, szString ) ) ? 1 : 0;
}