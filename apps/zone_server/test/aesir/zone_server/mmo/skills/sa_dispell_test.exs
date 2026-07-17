defmodule Aesir.ZoneServer.Mmo.Skills.SaDispellTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.SaDispell
  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context

  @target_id 2000

  defp caster, do: %PlayerState{character_id: 1000}

  defp definition do
    {:ok, definition} = Catalog.by_name(:sa_dispell)
    definition
  end

  describe "catalog registration" do
    test "by_id/1 resolves id 289" do
      assert {:ok, %{name: :sa_dispell}} = Catalog.by_id(289)
    end

    test "active_module_for/1 resolves the module" do
      assert {:ok, SaDispell} = Catalog.active_module_for(:sa_dispell)
    end
  end

  describe "metadata" do
    test "matches the rAthena renewal table" do
      definition = definition()

      assert definition.max_level == 5
      assert definition.damage_type == :no_damage
      assert definition.range == 9
      assert definition.cast_time == List.duplicate(1_600, 5)
      assert definition.fixed_cast_time == List.duplicate(400, 5)
      assert definition.item_cost == [%{id: 715, amount: 1}]
    end
  end

  describe "cast/5" do
    setup do
      Mimic.copy(Dispel)
      Mimic.copy(UnitRegistry)
      stub(UnitRegistry, :unit_exists?, fn :mob, _id -> false end)
      :ok
    end

    test "dispels the target when the roll succeeds" do
      test_pid = self()

      stub(Dispel, :dispel, fn target ->
        send(test_pid, {:dispelled, target})
        :ok
      end)

      # 50 + 10*3 = 80: a roll of 80 is the last success.
      assert {:ok, %PlayerState{}} =
               SaDispell.cast(caster(), {:unit, @target_id}, 3, definition(),
                 rng: fn 100 -> 80 end
               )

      assert_received {:dispelled, {:player, @target_id}}
    end

    test "does nothing when the roll fails" do
      reject(&Dispel.dispel/1)

      # 50 + 10*3 = 80: a roll of 81 is the first failure.
      assert {:ok, %PlayerState{}} =
               SaDispell.cast(caster(), {:unit, @target_id}, 3, definition(),
                 rng: fn 100 -> 81 end
               )
    end
  end
end
