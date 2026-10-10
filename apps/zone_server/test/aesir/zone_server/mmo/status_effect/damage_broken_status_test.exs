defmodule Aesir.ZoneServer.Mmo.StatusEffect.DamageBrokenStatusTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup
  import Aesir.ZoneServer.SessionHelpers

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage

  setup :setup_ets_tables

  @damage_broken [:sc_stone, :sc_freeze, :sc_sleep, :sc_hiding, :sc_cloaking, :sc_trickdead]
  @hit %{damage: 5, dmg_type: :physical}

  describe "active damage" do
    test "ends every damage-broken status a mob holds" do
      mob = start_mob_session()

      for status <- @damage_broken do
        hold(:mob, mob.unit_id, status)
        Interpreter.on_damage(:mob, mob.unit_id, @hit)
        refute StatusStorage.has_status?(:mob, mob.unit_id, status), inspect(status)
      end
    end

    test "passive losses and hits that did not connect keep them" do
      mob = start_mob_session()
      hold(:mob, mob.unit_id, :sc_freeze)

      for info <- [
            %{damage: 5, passive?: true},
            %{damage: 5, status_tick?: true},
            %{damage: 0, dmg_type: :physical},
            %{damage: 0, dmg_type: :physical, blocked?: true},
            %{damage: 0, dmg_type: :magic, magic_rod_miss?: true}
          ] do
        Interpreter.on_damage(:mob, mob.unit_id, info)
        assert StatusStorage.has_status?(:mob, mob.unit_id, :sc_freeze), inspect(info)
      end
    end

    test "a non-player keeps Wink of Charm when no HP was dealt, a player does not" do
      mob = start_mob_session()
      hold(:mob, mob.unit_id, :sc_winkcharm)
      hold(:mob, mob.unit_id, :sc_sleep)

      Interpreter.on_damage(:mob, mob.unit_id, %{damage: 0})

      assert StatusStorage.has_status?(:mob, mob.unit_id, :sc_winkcharm)
      refute StatusStorage.has_status?(:mob, mob.unit_id, :sc_sleep)

      Interpreter.on_damage(:mob, mob.unit_id, %{damage: 0, coma?: true})
      refute StatusStorage.has_status?(:mob, mob.unit_id, :sc_winkcharm)

      player = start_player_session()
      hold(:player, player.character.id, :sc_winkcharm)
      Interpreter.on_damage(:player, player.character.id, %{damage: 0})
      refute StatusStorage.has_status?(:player, player.character.id, :sc_winkcharm)
    end

    test "ends only what the unit held when the hit was dealt" do
      mob = start_mob_session()
      dealt_awake = Interpreter.damage_broken_snapshot(:mob, mob.unit_id)
      hold(:mob, mob.unit_id, :sc_freeze)

      Interpreter.on_damage(:mob, mob.unit_id, Map.put(@hit, :damage_broken, dealt_awake))
      assert StatusStorage.has_status?(:mob, mob.unit_id, :sc_freeze)

      dealt_frozen = Interpreter.damage_broken_snapshot(:mob, mob.unit_id)
      hold(:mob, mob.unit_id, :sc_freeze)

      Interpreter.on_damage(:mob, mob.unit_id, Map.put(@hit, :damage_broken, dealt_frozen))
      assert StatusStorage.has_status?(:mob, mob.unit_id, :sc_freeze)

      Interpreter.on_damage(:mob, mob.unit_id, @hit)
      refute StatusStorage.has_status?(:mob, mob.unit_id, :sc_freeze)
    end

    test "runs on_damage callbacks for mobs" do
      mob = start_mob_session()

      assert :ok =
               Interpreter.apply_status(:mob, mob.unit_id, :sc_endure,
                 val1: 1,
                 duration: 10_000,
                 bypass_resistance: true
               )

      Interpreter.on_damage(:mob, mob.unit_id, Map.put(@hit, :attacker, {:mob, 1}))

      assert StatusStorage.get_status(:mob, mob.unit_id, :sc_endure).state.hits_remaining == 6
    end
  end

  describe "same-attack Fail guard" do
    test "a status broken while a body state is held fails its Fail list for 10 ms" do
      mob = start_mob_session()
      hold(:mob, mob.unit_id, :sc_freeze)

      Interpreter.on_damage(:mob, mob.unit_id, @hit)

      refute StatusStorage.has_status?(:mob, mob.unit_id, :sc_freeze)
      assert {:error, :prevented} = freeze(mob.unit_id)
      assert {:error, :conflict} = Interpreter.apply_status(:mob, mob.unit_id, :sc_aeterna)
    end

    test "a status broken without a body state records nothing" do
      mob = start_mob_session()
      hold(:mob, mob.unit_id, :sc_hiding)

      Interpreter.on_damage(:mob, mob.unit_id, @hit)

      assert StatusStorage.last_effect(:mob, mob.unit_id, System.monotonic_time(:millisecond)) ==
               nil

      assert :ok = freeze(mob.unit_id)
    end

    test "the record lasts 10 ms and is not replaced while it lasts" do
      now = 1_000

      assert :ok = StatusStorage.note_last_effect(:mob, 1, :sc_freeze, now)
      assert :ok = StatusStorage.note_last_effect(:mob, 1, :sc_sleep, now + 5)

      assert StatusStorage.last_effect(:mob, 1, now + 9) == :sc_freeze
      assert StatusStorage.last_effect(:mob, 1, now + 10) == nil

      assert :ok = StatusStorage.note_last_effect(:mob, 1, :sc_sleep, now + 10)
      assert StatusStorage.last_effect(:mob, 1, now + 10) == :sc_sleep

      StatusStorage.clear_unit_statuses(:mob, 1)
      assert StatusStorage.last_effect(:mob, 1, now + 10) == nil
    end
  end

  defp hold(unit_type, unit_id, status),
    do: StatusStorage.apply_status(unit_type, unit_id, status, duration: 30_000)

  defp freeze(mob_id) do
    Interpreter.apply_status(:mob, mob_id, :sc_freeze, duration: 5_000, bypass_resistance: true)
  end
end
