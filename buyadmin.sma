#include <amxmodx>

#if !defined MAX_PLAYERS
	#define MAX_PLAYERS 32
#endif

#define semicolon 1

enum _:AdminData
{
	aName[32],
	Float:aCost
}

enum _:cData
{
	cAcc,
	cTime
}

#define cTelegram "t.me/czarintax"
#define cWebsite "paypal.me/oscserver"

#define MAX_BUY 2
#define MAX_TIME 3

//#define PAYCALL

#if defined PAYCALL
new const Float:g_fPayCallOffset = 1.2;
#endif

new const g_aAdminData[MAX_BUY][AdminData] = {
	{ "VIP", 2 },
	{ "SVIP", 2.50 },
	{ "Admin", 5.00 }
};

new g_bCounter[MAX_PLAYERS + 1][cData];

public plugin_init() {
	register_plugin("Buy Admin","v1.0","Hyuna");
	
	register_saycmd("buy","ActionBuyAdmin");
}

public client_connect(client) {
	g_bCounter[client][cAcc] = 0;
	g_bCounter[client][cTime] = 0;
}

public ActionBuyAdmin(client) {
	static some[256], iMenu, iCallBack;
	iMenu = menu_create("Buy Privileges","mHandler");
	iCallBack = menu_makecallback("mCallBack");
	
	formatex(some,charsmax(some),^"Access: [ ^1%s \w]",g_aAdminData[g_bCounter[client][cAcc]][aName]);
	menu_additem(iMenu,some);
	
	formatex(some,charsmax(some),^"Time: [ ^1%d month%s \w]",(g_bCounter[client][cTime] + 1),(g_bCounter[client][cTime] == 0 ? "":"s"));
	menu_additem(iMenu,some);
	
	formatex(some,charsmax(some),^"Cost: [ ^1%-.2f EUR \w]",(g_aAdminData[g_bCounter[client][cAcc]][aCost] * (g_bCounter[client][cTime] + 1)));
	menu_additem(iMenu,some,.callback=iCallBack);
	
	#if defined PAYCALL
	formatex(some,charsmax(some),"PayCall Cost: \R[ \y%d NIS \w]",floatround((g_aAdminData[g_bCounter[client][cAcc]][aCost] * (g_bCounter[client][cTime] + 1)) * g_fPayCallOffset));
	menu_additem(iMenu,some,.callback=iCallBack);
	#endif
	
	formatex(some,charsmax(some),"^n\y%s^n\y%s",cTelegram,cWebsite);
	menu_addtext(iMenu,some);
	
	menu_display(client,iMenu);
	
	return PLUGIN_HANDLED;
}

public mCallBack(client, menu, item) {
	return ITEM_DISABLED;
}

public mHandler(client, menu, item) {
	switch (item)
	{
		case 0:
		{
			if (++g_bCounter[client][cAcc] == MAX_BUY)
				g_bCounter[client][cAcc] = 0;
		}
			
		case 1:
		{
			if (++g_bCounter[client][cTime] == MAX_TIME)
				g_bCounter[client][cTime] = 0;
		}
		
		case MENU_EXIT:
		{
			menu_destroy(menu);
			return PLUGIN_HANDLED;
		}
	}
	
	menu_destroy(menu);
	return ActionBuyAdmin(client);
}

stock register_saycmd(const cmd[], const function[]) {
	static const cmdsay[][] = { "say", "say_team" };
	static const marks[] = { '!', '/', '.' };
	static some[64], i, j;
	
	for (i = 0; i < 2; i++)
	{
		for (j = 0; j < 3; j++)
		{
			formatex(some,charsmax(some),"%s %c%s",cmdsay[i],marks[j],cmd);
			register_clcmd(some,function);
		}
	}
}
