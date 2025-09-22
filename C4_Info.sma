#include <amxmodx>
#include <reapi>

#define SOUND // INFO SOUND

#define IsPlayer(%0) (1 <= %0 <= MaxClients)

new const g_szInfoSound[] = "events/task_complete.wav"

public plugin_init() {
	register_plugin("C4 Info", "2.0 [ReAPI]", "SCHOCKKWAVE & CHEL74")

	RegisterHookChain(RG_CBasePlayer_MakeBomber, "MakeBomber_Post", true)
}

public MakeBomber_Post(pPlayer)
	set_task(1.0, "C4Info_HUD", pPlayer)

public C4Info_HUD(pPlayer)
{
	set_hudmessage(255, 255, 0, -1.0, -0.70, 1, 6.0, 12.0, 0.1, 0.2, 4)
	show_hudmessage(pPlayer, "(C4): You carry the bomb!")

	#if defined SOUND
		rg_send_audio(pPlayer, g_szInfoSound)
	#endif
}