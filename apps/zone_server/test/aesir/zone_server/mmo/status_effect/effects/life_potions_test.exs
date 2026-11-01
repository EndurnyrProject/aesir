defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.LifePotionsTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.MediumLifePotion
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.SmallLifePotion
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @id 88_101

  setup :set_mimic_private

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})

    player =
      PlayerStateFixture.build(%{
        character_id: @id,
        account_id: @id,
        stats: %{combat_stats: %CombatStats{}}
      })

    :ok = UnitRegistry.register_unit(:player, @id, PlayerState, player, self())
    :ok
  end

  test "both potions retain their independent percentage and interval values" do
    assert :ok =
             Interpreter.apply_status(:player, @id, :sc_s_lifepotion,
               val1: -5,
               val2: 5,
               duration: 600_000
             )

    assert :ok =
             Interpreter.apply_status(:player, @id, :sc_l_lifepotion,
               val1: -7,
               val2: 4,
               duration: 600_000
             )

    assert ModifierCalculator.get_all_modifiers(:player, @id) == %{
             {:percent_hp_regen_bonus, {:sc_s_lifepotion, 5_000}} => 5,
             {:percent_hp_regen_bonus, {:sc_l_lifepotion, 4_000}} => 7
           }

    assert :ok = StatusStorage.apply_status(:player, @id, :sc_berserk)
    context = %{unit_type: :player, target_id: @id}
    entry = StatusStorage.get_status(:player, @id, :sc_s_lifepotion)
    assert SmallLifePotion.modifiers(entry, context) == %{}
    entry = StatusStorage.get_status(:player, @id, :sc_l_lifepotion)
    assert MediumLifePotion.modifiers(entry, context) == %{}
  end

  test "reapplication refuses in pre-renewal but refreshes in renewal, and death follows the mode" do
    params = [val1: -5, val2: 5, duration: 600_000]
    assert :ok = Interpreter.apply_status(:player, @id, :sc_s_lifepotion, params)
    held = StatusStorage.get_status(:player, @id, :sc_s_lifepotion)

    if GameMode.mode() == :pre_renewal do
      assert {:error, :prevented} =
               Interpreter.apply_status(:player, @id, :sc_s_lifepotion, params)

      assert StatusStorage.get_status(:player, @id, :sc_s_lifepotion) == held
    else
      assert :ok = Interpreter.apply_status(:player, @id, :sc_s_lifepotion, params)
      refreshed = StatusStorage.get_status(:player, @id, :sc_s_lifepotion)
      assert refreshed.generation != held.generation
    end

    assert :ok = Interpreter.remove_on_death(:player, @id)

    assert StatusStorage.has_status?(:player, @id, :sc_s_lifepotion) ==
             (GameMode.mode() == :pre_renewal)
  end

  test "restoration retains the saved percentage and interval and ignores the pre-renewal repeat gate" do
    params = [val1: -9, val2: 6, duration: 123_000, loaded: true]
    assert :ok = Interpreter.apply_status(:player, @id, :sc_l_lifepotion, params)
    assert :ok = Interpreter.apply_status(:player, @id, :sc_l_lifepotion, params)

    assert ModifierCalculator.get_all_modifiers(:player, @id) == %{
             {:percent_hp_regen_bonus, {:sc_l_lifepotion, 6_000}} => 9
           }
  end
end
