defmodule Aesir.ZoneServer.Integration.EquipDrainSplashTest do
  @moduledoc """
  End-to-end coverage for the two normal-attack equipment mechanics that have no
  skill equivalent, driven through the live combat path against real mob
  sessions:

    1. `bSplashRange` extends a landed swing to every valid enemy inside the
       radius around the primary target, hits the primary exactly once, and is
       inert at radius 0.
    2. `bonus2 bHPDrainRate` recovers a percent of the damage dealt as HP,
       applied by the attacker's own session rather than written in place.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.DamageDealt
  alias Aesir.ZoneServer.Mmo.Combat

  @map "prontera"

  describe "bSplashRange on a normal attack" do
    test "splashes the neighbours of the primary target and hits the primary once" do
      player = start_attacker()

      primary = spawn_mob(2_101, {151, 150})
      neighbour = spawn_mob(2_102, {152, 150})
      bystander = spawn_mob(2_103, {156, 150})

      packets = attack_until_landed(player, primary.unit_id, %{splash_range: 1})

      assert length(damage_for(packets, primary.unit_id)) == 1
      assert [_ | _] = damage_for(packets, neighbour.unit_id)
      assert damage_for(packets, bystander.unit_id) == []

      assert get_mob_state(neighbour.pid).hp < neighbour.mob_state.max_hp
      assert get_mob_state(bystander.pid).hp == bystander.mob_state.max_hp
    end

    test "a zero splash range leaves the neighbour untouched" do
      player = start_attacker()

      primary = spawn_mob(2_111, {151, 150})
      neighbour = spawn_mob(2_112, {152, 150})

      packets = attack_until_landed(player, primary.unit_id, %{})

      assert length(damage_for(packets, primary.unit_id)) == 1
      assert damage_for(packets, neighbour.unit_id) == []
      assert get_mob_state(neighbour.pid).hp == neighbour.mob_state.max_hp
    end
  end

  describe "bonus2 bHPDrainRate on a normal attack" do
    test "the attacker's session applies the drained HP" do
      player = start_attacker(hp: 1)
      mob = spawn_mob(2_121, {151, 150})

      packets =
        attack_until_landed(player, mob.unit_id, %{hp_drain_rate: 1_000, hp_drain_percent: 100})

      [%DamageDealt{damage: damage}] = damage_for(packets, mob.unit_id)
      expected = min(1 + damage, get_player_state(player.pid).stats.derived_stats.max_hp)

      assert eventually(fn -> current_hp(player) >= expected end),
             "drained HP never reached the attacker's session (hp #{current_hp(player)})"
    end

    test "an attacker without the drain bonus takes no drain-sized heal" do
      player = start_attacker(hp: 1)
      mob = spawn_mob(2_131, {151, 150})

      packets = attack_until_landed(player, mob.unit_id, %{})
      [%DamageDealt{damage: damage}] = damage_for(packets, mob.unit_id)

      Process.sleep(100)
      assert current_hp(player) < 1 + damage
    end
  end

  defp start_attacker(opts \\ []) do
    player =
      start_player_session(
        Keyword.merge([str: 99, dex: 99, map_name: @map, position: {150, 150}], opts)
      )

    Process.sleep(50)
    flush_packets()
    player
  end

  defp spawn_mob(unit_id, position) do
    start_mob_session(
      unit_id: unit_id,
      map_name: @map,
      position: position,
      hp: 5_000,
      max_hp: 5_000
    )
  end

  # A swing can still miss, so the attack is repeated (with a clean packet
  # window each time) until the primary target takes damage. The returned
  # packets are the ones a single landed swing produced.
  #
  # The collector stops after that many milliseconds of silence. Each splash
  # victim broadcasts from its own MobSession, so a busy neighbour can trail the
  # primary by more than a couple of frames under full-suite load - too short a
  # window drops its packet and the splash assertions read as "never hit".
  @packet_quiet_ms 500

  defp attack_until_landed(player, target_id, equip_modifiers) do
    Enum.reduce_while(1..30, nil, fn _, _acc ->
      flush_packets()

      stats = with_equip_modifiers(get_player_stats(player.pid), equip_modifiers)
      assert Combat.execute_attack(stats, get_player_state(player.pid), target_id) == :ok

      packets = collect_packets_of_type(DamageDealt, @packet_quiet_ms)

      case damage_for(packets, target_id) do
        [] -> {:cont, nil}
        _ -> {:halt, packets}
      end
    end)
    |> case do
      nil -> flunk("the attacker never landed a hit on #{target_id}")
      packets -> packets
    end
  end

  defp with_equip_modifiers(stats, equip_modifiers) do
    %{stats | modifiers: %{stats.modifiers | equipment: equip_modifiers}}
  end

  defp damage_for(packets, unit_id) do
    Enum.filter(packets, &(&1.target_id == unit_id and &1.damage > 0))
  end

  defp current_hp(player), do: get_player_state(player.pid).stats.current_state.hp
end
