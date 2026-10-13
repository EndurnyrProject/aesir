defmodule Aesir.ZoneServer.Mmo.StatusEffect.OverlapTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Jointbeat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @holder 5_160
  @other 5_161

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})

    for id <- [@holder, @other] do
      :ok =
        UnitRegistry.register_player(
          PlayerStateFixture.build(%{character_id: id, stats: %{combat_stats: %CombatStats{}}}),
          self()
        )
    end

    :ok
  end

  defp start(status, params),
    do:
      Interpreter.apply_status(
        :player,
        @holder,
        status,
        [no_avoid: true, bypass_resistance: true] ++ params
      )

  defp held(status), do: StatusStorage.get_status(:player, @holder, status)

  describe "the level rule" do
    test "a weaker application keeps the held instance and still succeeds" do
      assert :ok = start(:sc_increaseagi, val1: 10, duration: 60_000)
      stored = held(:sc_increaseagi)

      assert :ok = start(:sc_increaseagi, val1: 3, duration: 1_000)
      assert held(:sc_increaseagi) === stored
    end

    test "an equal or stronger application replaces it" do
      assert :ok = start(:sc_increaseagi, val1: 5, duration: 60_000)
      assert :ok = start(:sc_increaseagi, val1: 5, duration: 1_000)
      assert %{val1: 5} = equal = held(:sc_increaseagi)

      assert :ok = start(:sc_increaseagi, val1: 7, duration: 1_000)
      assert %{val1: 7} = held(:sc_increaseagi)
      refute held(:sc_increaseagi) === equal
    end

    test "a kept application still ends what it ends on start" do
      assert :ok = start(:sc_increaseagi, val1: 10, duration: 60_000)

      :ok =
        StatusStorage.apply_status(:player, @holder, :sc_decreaseagi, val1: 1, duration: 60_000)

      assert :ok = start(:sc_increaseagi, val1: 1, duration: 1_000)
      assert %{val1: 10} = held(:sc_increaseagi)
      refute held(:sc_decreaseagi)
    end

    test "a status that ignores levels is always replaced" do
      assert :ok = start(:sc_atkpotion, val1: 20, duration: 60_000)
      assert :ok = start(:sc_atkpotion, val1: 5, duration: 60_000)
      assert %{val1: 5} = held(:sc_atkpotion)
    end
  end

  describe "body states" do
    test "a new body state ends every held one" do
      assert :ok = start(:sc_sleep, val1: 10, duration: 60_000)
      assert :ok = start(:sc_stun, val1: 1, duration: 60_000)

      refute held(:sc_sleep)
      assert held(:sc_stun)
    end

    test "a stunned unit cannot be stunned again" do
      assert :ok = start(:sc_stun, val1: 1, duration: 60_000)
      stored = held(:sc_stun)

      assert {:error, :prevented} = start(:sc_stun, val1: 10, duration: 60_000)
      assert held(:sc_stun) === stored
    end
  end

  test "a recipient's Over Thrust fails against the Blacksmith's own cast" do
    assert :ok = start(:sc_overthrust, val1: 25, val2: 1, caster_id: @holder, duration: 60_000)

    assert {:error, :overlap_refused} =
             start(:sc_overthrust, val1: 25, val2: 0, caster_id: @other)

    assert %{val2: 1} = held(:sc_overthrust)

    assert :ok = start(:sc_overthrust, val1: 5, val2: 1, caster_id: @holder, duration: 60_000)
    assert %{val1: 5} = held(:sc_overthrust)
  end

  test "an Over Thrust not cast by its holder's own skill is replaced by a recipient copy" do
    assert :ok = start(:sc_overthrust, val1: 25, val2: 0, caster_id: @holder, duration: 60_000)
    assert :ok = start(:sc_overthrust, val1: 5, val2: 0, caster_id: @other, duration: 60_000)
    assert %{val1: 5, source_id: @other} = held(:sc_overthrust)
  end

  test "a finite Endure never replaces an infinite one" do
    assert :ok = start(:sc_endure, val1: 1, val4: 1, duration: 60_000)
    assert :ok = start(:sc_endure, val1: 10, val4: 0, duration: 60_000)
    assert %{val1: 1, val4: 1} = held(:sc_endure)
  end

  describe "Joint Beat" do
    test "a new break joins the held ones" do
      assert :ok = start(:sc_jointbeat, val1: 5, val2: Jointbeat.flag(:ankle), duration: 30_000)
      assert :ok = start(:sc_jointbeat, val1: 5, val2: Jointbeat.flag(:wrist), duration: 30_000)

      assert held(:sc_jointbeat).val2 == Jointbeat.flag(:ankle) + Jointbeat.flag(:wrist)
    end

    test "a broken neck refuses every new break" do
      assert :ok = start(:sc_jointbeat, val1: 5, val2: Jointbeat.flag(:neck), duration: 30_000)

      assert {:error, :overlap_refused} =
               start(:sc_jointbeat, val1: 10, val2: Jointbeat.flag(:ankle), duration: 30_000)

      assert held(:sc_jointbeat).val2 == Jointbeat.flag(:neck)
    end

    test "stacked breaks add their penalties" do
      wounds = Jointbeat.flag(:ankle) + Jointbeat.flag(:knee) + Jointbeat.flag(:waist)

      assert Jointbeat.modifiers(%StatusEntry{val2: wounds}, %{}) == %{
               movement_speed: 80,
               aspd_rate: -10,
               def2_rate: -25,
               atk_rate: -25
             }
    end
  end
end
