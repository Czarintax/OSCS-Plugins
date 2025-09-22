#include <amxmodx>
#include <reapi>
#include <hamsandwich>

/**
 * info: https://github.com/s1lentq/ReGameDLL_CS/issues/678
 */

new bool: mp_disconnect_kills_players;

public plugin_init() {
  register_plugin("mp_disconnect_kills_players", "1.0.0", "SergeyShorokhov")

  bind_pcvar_num(create_cvar("mp_disconnect_kills_players", "1",
    .description = "Turning this command on causes players to die in game if they disconnect. \
      This means rather than just vanishing, they'll drop items they \
      have equipped and a death will be added to the scoreboard for them."),
    mp_disconnect_kills_players)
}

public client_disconnected(id, bool: drop, message[], maxlen) {
  if (!mp_disconnect_kills_players)
    return

  if (!is_user_alive(id) || is_user_bot(id))
    return

  for (new InventorySlotType: slot = PRIMARY_WEAPON_SLOT; slot < InventorySlotType; slot++)
    rg_drop_items_by_slot(id, slot)

  if (get_member(id, m_bHasDefuser))
    rg_drop_item(id, "item_thighpack") // wtf, why it need?!

  ExecuteHamB(Ham_Killed, id, id, false)
}
