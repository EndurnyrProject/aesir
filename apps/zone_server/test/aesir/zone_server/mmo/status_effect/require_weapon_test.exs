defmodule Aesir.ZoneServer.Mmo.StatusEffect.RequireWeaponTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule TwoHandSwordStatus do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_require_two_handed_sword,
      no_dispel: false,
      properties: [:buff],
      require_weapon: [:two_handed_sword]
  end

  defmodule PlainStatus do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_no_weapon_requirement,
      no_dispel: false,
      properties: [:buff]
  end

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  defp setup_player_mock(char_id) do
    stub(UnitRegistry, :get_unit_info, fn :player, ^char_id ->
      {:ok,
       %{
         unit_id: char_id,
         unit_type: :player,
         race: :formless,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{
           max_hp: 100,
           max_sp: 50,
           hp: 100,
           sp: 50,
           level: 1,
           base_level: 1,
           str: 1,
           agi: 1,
           vit: 1,
           int: 1,
           dex: 1,
           luk: 1,
           mdef: 0
         }
       }}
    end)
  end

  describe "enforce_weapon_requirements/3" do
    test "removes a status when the wielded weapon does not satisfy require_weapon" do
      setup_player_mock(1)
      Registry.register_module(TwoHandSwordStatus)
      :ok = Interpreter.apply_status(:player, 1, :sc_test_require_two_handed_sword)

      Interpreter.enforce_weapon_requirements(:player, 1, :dagger)

      refute status_active?(1, :sc_test_require_two_handed_sword)
    end

    test "keeps a status when the wielded weapon satisfies require_weapon" do
      setup_player_mock(1)
      Registry.register_module(TwoHandSwordStatus)
      :ok = Interpreter.apply_status(:player, 1, :sc_test_require_two_handed_sword)

      Interpreter.enforce_weapon_requirements(:player, 1, :two_handed_sword)

      assert status_active?(1, :sc_test_require_two_handed_sword)
    end

    test "leaves a status without require_weapon untouched regardless of weapon" do
      setup_player_mock(1)
      Registry.register_module(PlainStatus)
      :ok = Interpreter.apply_status(:player, 1, :sc_test_no_weapon_requirement)

      Interpreter.enforce_weapon_requirements(:player, 1, :dagger)

      assert status_active?(1, :sc_test_no_weapon_requirement)
    end
  end

  defp status_active?(char_id, status_id) do
    StatusStorage.has_status?(:player, char_id, status_id)
  end
end
