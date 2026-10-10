defmodule Aesir.ZoneServer.Integration.DamageBrokenStatusIntegrationTest do
  @moduledoc """
  Damage-broken statuses end in their holder's own session: a mob and a player
  lose Freeze, Sleep and Stone to active damage, and keep them through passive
  ticks and blocked hits.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.StatusStorage

  setup do
    player = start_player_session(position: {150, 150}, vit: 0, luk: 0)
    mob = start_mob_session(position: {151, 150}, max_hp: 50_000, hp: 50_000, dex: 999)
    %{player: player, mob: mob}
  end

  test "a mob loses Freeze, Sleep and Stone to an active hit but not to a tick or a block",
       %{player: player, mob: mob} do
    source = player.character.id

    for status <- [:sc_freeze, :sc_sleep, :sc_stone] do
      StatusStorage.apply_status(:mob, mob.unit_id, status, duration: 30_000)
      hp = get_mob_state(mob.pid).hp

      deliver(mob, 1, %{status_tick?: true}, nil)
      assert eventually(fn -> get_mob_state(mob.pid).hp == hp - 1 end)
      assert StatusStorage.has_status?(:mob, mob.unit_id, status)

      StatusStorage.apply_status(:mob, mob.unit_id, :sc_pneuma, duration: 30_000)
      hit = %{dmg_type: :physical, is_short: false}

      {0, blocked} =
        DamageApplication.prepare_unit_damage(:mob, mob.unit_id, 100, hit, source)

      deliver(mob, 0, blocked, source)
      get_mob_state(mob.pid)
      assert StatusStorage.has_status?(:mob, mob.unit_id, status)
      StatusStorage.remove_status(:mob, mob.unit_id, :sc_pneuma)

      deliver(mob, 10, %{dmg_type: :physical, is_short: true}, source)
      assert eventually(fn -> not StatusStorage.has_status?(:mob, mob.unit_id, status) end)
    end
  end

  test "a frozen player thaws when a monster's attack lands", %{player: player, mob: mob} do
    id = player.character.id
    StatusStorage.apply_status(:player, id, :sc_freeze, duration: 30_000)
    hp = get_player_state(player.pid).stats.current_state.hp

    # The first roll clears natural perfect dodge; DEX 999 guarantees the accuracy check.
    :rand.seed(:exsss, {17, 19, 23})
    assert :ok = Combat.execute_mob_attack(get_mob_state(mob.pid), id)

    assert eventually(fn -> get_player_state(player.pid).stats.current_state.hp < hp end)
    assert eventually(fn -> not StatusStorage.has_status?(:player, id, :sc_freeze) end)
  end

  defp deliver(mob, damage, hit_info, source),
    do: DamageApplication.apply_unit_damage(:mob, mob.pid, mob.unit_id, damage, hit_info, source)
end
