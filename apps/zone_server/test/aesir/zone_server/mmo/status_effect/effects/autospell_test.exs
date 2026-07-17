defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AutospellTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Autospell

  describe "proc_level/2 boundaries" do
    # battle.cpp:7496-7501. `i = rnd()%100`; the reduction applies only when
    # skill_lv > 1, so every boundary is asserted on both sides.
    test "a roll of 50 or more halves the level" do
      assert Autospell.proc_level(10, 50) == 5
      assert Autospell.proc_level(10, 99) == 5
      assert Autospell.proc_level(5, 50) == 2
    end

    test "a roll of 49 subtracts one instead of halving" do
      assert Autospell.proc_level(10, 49) == 9
    end

    test "a roll of 15 to 49 subtracts one" do
      assert Autospell.proc_level(10, 15) == 9
      assert Autospell.proc_level(10, 49) == 9
    end

    test "a roll of 14 or less leaves the level untouched" do
      assert Autospell.proc_level(10, 14) == 10
      assert Autospell.proc_level(10, 0) == 10
    end

    test "level 1 is never reduced, at any roll" do
      for roll <- [0, 14, 15, 49, 50, 99] do
        assert Autospell.proc_level(1, roll) == 1
      end
    end

    test "level 2 halves to 1 rather than to 0" do
      assert Autospell.proc_level(2, 50) == 1
      assert Autospell.proc_level(2, 15) == 1
    end
  end

  describe "on_dealt_damage/5 proc roll" do
    # rAthena rolls `rnd()%100 < val4`, so at chance 6 (autospell level 3) a roll
    # of 5 procs and a roll of 6 does not.
    test "a roll below the chance emits the auto-cast follow-up" do
      instance = armed(:mg_firebolt, 5, 6)

      assert {:ok, ^instance, [{:auto_cast, :mg_firebolt, 5, {:unit, 2001}}]} =
               hook(instance, rolls([5, 0]))
    end

    test "a roll equal to the chance does not proc" do
      instance = armed(:mg_firebolt, 5, 6)

      assert {:ok, ^instance} = hook(instance, rolls([6]))
    end

    test "a chance of 0 can never proc, even on a roll of 0" do
      instance = armed(:mg_firebolt, 5, 0)

      assert {:ok, ^instance} = hook(instance, rolls([0]))
    end

    test "the proc roll and the level roll are two independent draws" do
      instance = armed(:mg_coldbolt, 10, 100)

      assert {:ok, _, [{:auto_cast, :mg_coldbolt, 5, {:unit, 2001}}]} =
               hook(instance, rolls([0, 50]))

      assert {:ok, _, [{:auto_cast, :mg_coldbolt, 10, {:unit, 2001}}]} =
               hook(instance, rolls([0, 14]))
    end

    # The hook is handed `hit_info.target` as `{unit_type, id}`, but the auto-cast
    # follow-up names a cast target, which the skill interpreter reads as
    # `{:unit, id}` regardless of the victim's type.
    test "a player victim is named as a unit target just like a mob" do
      instance = armed(:mg_firebolt, 1, 100)

      assert {:ok, _, [{:auto_cast, :mg_firebolt, 1, {:unit, 42}}]} =
               hook(instance, rolls([0, 0]), %{target: {:player, 42}, damage: 10})
    end

    test "the level roll is threaded through proc_level, halving at 50" do
      instance = armed(:mg_thunderstorm, 4, 100)

      assert {:ok, _, [{:auto_cast, :mg_thunderstorm, 2, {:unit, 2001}}]} =
               hook(instance, rolls([0, 50]))
    end
  end

  describe "metadata" do
    test "survives dispel and is not persisted across logout" do
      assert Autospell.metadata().no_dispel == true
      assert Autospell.metadata().no_save == true
    end

    test "publishes the on_dealt_damage capability so the registry indexes it" do
      assert Autospell.__status_capabilities__() == [:on_dealt_damage]
    end
  end

  defp hook(instance, roll, hit_info \\ %{target: {:mob, 2001}, damage: 50, element: :neutral}) do
    Autospell.on_dealt_damage({:player, 1}, instance, hit_info, %{}, roll)
  end

  defp armed(skill, max_level, chance) do
    %Aesir.ZoneServer.Mmo.StatusEntry{
      type: :sc_autospell,
      state: %{skill: skill, max_level: max_level, chance: chance}
    }
  end

  # Hands the hook a scripted sequence of rolls, one per draw, so the proc roll
  # and the level roll can be pinned independently.
  defp rolls(values) do
    {:ok, agent} = Agent.start_link(fn -> values end)
    fn -> Agent.get_and_update(agent, fn [head | tail] -> {head, tail} end) end
  end
end
