#pragma semicolon 1

#include <amxmodx>
#include <reapi>

#define PLUGIN_NAME		"Aug-SG552 Scope"
#define PLUGIN_VERS		"1.0"
#define PLUGIN_AUTH		"PurposeLess"

new const models[][] = {
	"models/v_aug_zoom.mdl",
	"models/v_sg552_zoom.mdl"
};

new modelsave[MAX_CLIENTS + 1][32];

public plugin_init() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH);

	register_event("SetFOV", "@Event_SetFOV_On", "be", "1=55");
	register_event("SetFOV", "@Event_SetFOV_Off", "be", "1=90");
}

public plugin_precache() {
	for(new i = 0; i < sizeof(models); i++) {
		precache_model(models[i]);
	}
}

@Event_SetFOV_On(const id) {
	get_entvar(id, var_viewmodel, modelsave[id], charsmax(modelsave[]));
	set_entvar(id, var_viewmodel, models[get_user_weapon(id) == CSW_AUG ? 0 : 1]);
}

@Event_SetFOV_Off(const id) {
	if(!modelsave[id][0]) {
		return;
	}

	set_entvar(id, var_viewmodel, modelsave[id]);
	modelsave[id][0] = EOS;
}