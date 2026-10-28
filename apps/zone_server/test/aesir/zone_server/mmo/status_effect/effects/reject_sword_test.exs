defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.RejectSwordTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.MobSkill.Importer
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.RejectSword
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  @holder 10

  setup do
    register_player(@holder, nil)
    :ok
  end

  test "starts with a 15 percent per level chance and three charges, which a restore keeps" do
    :ok = Interpreter.apply_status(:player, @holder, :sc_rejectsword, val1: 4)
    assert %{val2: 60, val3: 3} = StatusStorage.get_status(:player, @holder, :sc_rejectsword)

    StatusStorage.clear_unit_statuses(:player, @holder)

    :ok =
      Interpreter.apply_status(:player, @holder, :sc_rejectsword,
        val1: 4,
        val2: 60,
        val3: 1,
        loaded: true
      )

    assert %{val2: 60, val3: 1} = StatusStorage.get_status(:player, @holder, :sc_rejectsword)
  end

  test "lasts until its charges are spent, but ends on death" do
    :ok = Interpreter.apply_status(:player, @holder, :sc_rejectsword, val1: 1)
    assert %{expires_at: nil} = StatusStorage.get_status(:player, @holder, :sc_rejectsword)

    :ok = Interpreter.remove_on_death(:player, @holder)
    refute StatusStorage.has_status?(:player, @holder, :sc_rejectsword)
  end

  test "monsters and dagger or sword wielders are countered, other weapons are not" do
    for {id, weapon} <- [{21, 1201}, {22, 1101}, {23, 1116}, {24, 1701}, {25, nil}] do
      register_player(id, weapon)
    end

    for {attacker, expected} <- [
          {{:mob, 30}, {:counter, 50, 50}},
          {{:player, 21}, {:counter, 50, 50}},
          {{:player, 22}, {:counter, 50, 50}},
          {{:player, 23}, {:counter, 50, 50}},
          {{:player, 24}, :continue},
          {{:player, 25}, :continue}
        ] do
      assert RejectSword.final_weapon_hit({:player, @holder}, holder(99), 101, hit(attacker)) ==
               expected
    end
  end

  test "a roll above the chance does not counter" do
    assert RejectSword.final_weapon_hit({:player, @holder}, holder(3, 0), 100, hit({:mob, 30})) ==
             :continue

    assert %{val3: 3} = StatusStorage.get_status(:player, @holder, :sc_rejectsword)
  end

  test "each counter spends a charge and the third ends the status" do
    holder(3)

    for _ <- 1..3 do
      assert {50, 50} = Interpreter.final_weapon_hit(:player, @holder, 100, hit({:mob, 30}))
    end

    refute StatusStorage.has_status?(:player, @holder, :sc_rejectsword)
    assert {100, 0} = Interpreter.final_weapon_hit(:player, @holder, 100, hit({:mob, 30}))
  end

  test "two attackers racing for the last charge counter once and end it once" do
    entry = holder(1)
    test_pid = self()

    results =
      for _ <- 1..2 do
        Task.async(fn ->
          send(test_pid, {:ready, self()})

          receive do
            :go -> RejectSword.final_weapon_hit({:player, @holder}, entry, 100, hit({:mob, 30}))
          end
        end)
      end

    for _ <- 1..2, do: assert_receive({:ready, _pid})
    Enum.each(results, &send(&1.pid, :go))
    outcomes = Task.await_many(results)

    assert Enum.count(outcomes, &match?({:counter, 50, 50}, &1)) == 1
    assert Enum.count(outcomes, &(&1 == :continue)) == 1
    refute StatusStorage.has_status?(:player, @holder, :sc_rejectsword)
  end

  test "monster skill rows can cast Counter Instinct" do
    assert Importer.classify(390) == :castable
  end

  defp holder(charges, chance \\ 100) do
    :ok =
      StatusStorage.apply_status(:player, @holder, :sc_rejectsword,
        val1: 5,
        val2: chance,
        val3: charges
      )

    StatusStorage.get_status(:player, @holder, :sc_rejectsword)
  end

  defp hit(attacker), do: %{dmg_type: :physical, attacker: attacker}

  defp register_player(id, right_hand) do
    player =
      PlayerState.new(%Character{
        id: id,
        account_id: id,
        name: "Player #{id}",
        last_map: "prontera",
        last_x: 50,
        last_y: 50,
        sex: "M",
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        base_level: 99,
        job_level: 50,
        class: 4018
      })

    player = put_in(player.stats.equipment.right_hand, right_hand)
    :ok = UnitRegistry.register_player(player, self())
  end
end
