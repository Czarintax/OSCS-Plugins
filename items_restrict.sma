#include <amxmodx>
#include <reapi>

// uncomment that you need to restrict these item's.
new const ItemID:g_rRestrictWeapons[] =
{
	ITEM_SHIELDGUN,
	// ITEM_P228,
	// ITEM_GLOCK,
	// ITEM_SCOUT,
	// ITEM_HEGRENADE,
	//ITEM_XM1014,
	// ITEM_C4,
	// ITEM_MAC10,
	// ITEM_AUG,
	//ITEM_SMOKEGRENADE,
	// ITEM_ELITE,
	// ITEM_FIVESEVEN,
	// ITEM_UMP45,
	ITEM_SG550,
	// ITEM_GALIL,
	// ITEM_FAMAS,
	// ITEM_USP,
	// ITEM_GLOCK18,
	// ITEM_AWP,
	// ITEM_MP5N,
	//ITEM_M249,
	//ITEM_M3,
	// ITEM_M4A1,
	// ITEM_TMP,
	ITEM_G3SG1,
	//ITEM_FLASHBANG,
	// ITEM_DEAGLE,
	// ITEM_SG552,
	// ITEM_AK47,
	// ITEM_KNIFE,
	// ITEM_P90,

	// don't touch it!!
	ITEM_NONE
};

new const ItemID:g_rRestrictItems[] =
{
	// ITEM_NVG,
	// ITEM_DEFUSEKIT,
	// ITEM_KEVLAR,
	// ITEM_ASSAULT,
	// ITEM_LONGJUMP,
	// ITEM_HEALTHKIT,
	// ITEM_ANTIDOTE,
	// ITEM_SECURITY,
	// ITEM_BATTERY,
	// ITEM_SUIT,

	// don't touch it!!
	ITEM_NONE
};

enum SectionBits
{
	SECTION_WEAPONS = 0,
	SECTION_ITEMS
};

new g_bitsRestrict[SectionBits] = {};

public plugin_init()
{
	register_plugin("Items Restrict", "1.1", "s1lent");

	if (g_rRestrictWeapons[0] == ITEM_NONE && g_rRestrictItems[0] == ITEM_NONE) {
		set_fail_state("Arrays g_rRestrictWeapons and g_rRestrictItems are empty!");
		return;
	}

	new i;
	for (i = 0; g_rRestrictWeapons[i] != ITEM_NONE; i++)
		g_bitsRestrict[SECTION_WEAPONS] |= (1 << any:g_rRestrictWeapons[i]);

	for (i = 0; g_rRestrictItems[i] != ITEM_NONE; i++)
		g_bitsRestrict[SECTION_ITEMS] |= (1 << any:(g_rRestrictItems[i] % ITEM_NVG));

	RegisterHookChain(RG_CBasePlayer_HasRestrictItem, "CBasePlayer_HasRestrictItem");
}

public CBasePlayer_HasRestrictItem(const id, const ItemID:item, const ItemRestType:type)
{
	if ((item < ITEM_NVG) ? g_bitsRestrict[SECTION_WEAPONS] & (1 << any:item) :
			g_bitsRestrict[SECTION_ITEMS] & (1 << any:(item % ITEM_NVG)))
	{
		if (type == ITEM_TYPE_BUYING) {
			client_print(id, print_center, "* This item is restricted *");
			
			//client_cmd(id, "spk buttons/button8.wav");
		}

		// return true, let's restrict up this item
		SetHookChainReturn(ATYPE_BOOL, true);
		return HC_SUPERCEDE;
	}

	return HC_CONTINUE;
}
