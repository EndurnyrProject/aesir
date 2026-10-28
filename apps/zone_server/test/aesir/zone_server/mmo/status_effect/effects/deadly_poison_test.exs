defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DeadlyPoisonTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.DeadlyPoison
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private

  @instance %StatusEntry{type: :sc_dpoison, state: %{}}

  defp start(target, hp, max_hp, loaded \\ false),
    do:
      DeadlyPoison.on_apply(target, @instance, %{
        loaded: loaded,
        target: %{hp: hp, max_hp: max_hp}
      })

  describe "modifiers/2" do
    test "stops all regeneration unless Slow Poison holds it" do
      context = %{unit_type: :player, target_id: 41}

      stub(StatusStorage, :has_status?, fn :player, 41, :sc_slowpoison -> false end)
      assert DeadlyPoison.modifiers(@instance, context) == %{no_regen: true, def_rate: -25}

      stub(StatusStorage, :has_status?, fn :player, 41, :sc_slowpoison -> true end)
      assert DeadlyPoison.modifiers(@instance, context) == %{def_rate: -25}
    end
  end

  describe "on_apply/3" do
    test "a player loses 10% of Max HP at once, anyone else 15%" do
      expect(Helpers, :apply_passive_hp_loss, fn {:player, 1}, 100 -> :ok end)
      expect(Helpers, :apply_passive_hp_loss, fn {:mob, 2}, 150 -> :ok end)
      expect(Helpers, :apply_passive_hp_loss, fn {:homunculus, 3}, 150 -> :ok end)

      assert {:ok, @instance} = start({:player, 1}, 1_000, 1_000)
      assert {:ok, @instance} = start({:mob, 2}, 1_000, 1_000)
      assert {:ok, @instance} = start({:homunculus, 3}, 1_000, 1_000)
    end

    test "the loss stops at a quarter of Max HP" do
      expect(Helpers, :apply_passive_hp_loss, fn {:player, 1}, 50 -> :ok end)
      assert {:ok, @instance} = start({:player, 1}, 300, 1_000)
    end

    test "nothing is lost at a quarter of Max HP or below, or when restoring a saved status" do
      reject(&Helpers.apply_passive_hp_loss/2)

      assert {:ok, @instance} = start({:player, 1}, 250, 1_000)
      assert {:ok, @instance} = start({:player, 1}, 1_000, 1_000, true)
    end
  end

  describe "through the interpreter" do
    setup do
      Aesir.TestEtsSetup.setup_ets_tables(%{})

      :ok =
        UnitRegistry.register_player(
          PlayerStateFixture.build(%{
            character_id: 5_170,
            stats: %{combat_stats: %CombatStats{}}
          }),
          self()
        )
    end

    test "a new Deadly Poison takes its start loss" do
      expect(Helpers, :apply_passive_hp_loss, fn {:player, 5_170}, loss when loss > 0 -> :ok end)

      assert :ok =
               Interpreter.apply_status(:player, 5_170, :sc_dpoison,
                 no_avoid: true,
                 bypass_resistance: true,
                 duration: 30_000
               )
    end

    test "a restored Deadly Poison takes none" do
      reject(&Helpers.apply_passive_hp_loss/2)

      assert :ok =
               Interpreter.apply_status(:player, 5_170, :sc_dpoison,
                 loaded: true,
                 duration: 30_000
               )
    end
  end
end
