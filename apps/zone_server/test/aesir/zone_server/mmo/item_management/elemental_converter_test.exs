defmodule Aesir.ZoneServer.Mmo.ItemManagement.ElementalConverterTest do
  @moduledoc """
  The four Elemental Converters (12114-12117) endow the user's weapon.

  Runs each converter's real `on_use` source out of `priv/db/re/items/usable.yml`
  through the real script compiler, DSL and status storage, then attacks and
  asserts the element the damage pipeline hands the element table. Asserting the
  applied status alone would not catch an endow that no combat code reads -
  which is exactly how `SA_CREATECON` would ship inert converters.
  """

  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.CriticalHits
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.ItemManagement.CompiledItemScripts
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @char_id 1002

  # {item id, endowed element}. rAthena `itemskill "ITEM_ENCHANTARMS",<lv>`,
  # where the skill's level-to-element table maps lv 2/3/4/5 to water/earth/
  # fire/wind (`db/re/skill_db.yml`, ITEM_ENCHANTARMS).
  @converters [
    {12_114, :fire},
    {12_115, :water},
    {12_116, :earth},
    {12_117, :wind}
  ]

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})

    Mimic.copy(CriticalHits)
    Mimic.copy(ElementModifiers)
    Mimic.copy(UnitRegistry)

    stub(CriticalHits, :calculate_critical_hit, fn _, damage ->
      %{damage: damage, is_critical: false}
    end)

    stub(ElementModifiers, :get_modifier, fn attack_element,
                                             defense_element,
                                             defense_level,
                                             ratio_bonus ->
      send(self(), {:attack_element, attack_element})

      call_original(ElementModifiers, :get_modifier, [
        attack_element,
        defense_element,
        defense_level,
        ratio_bonus
      ])
    end)

    stub(UnitRegistry, :get_unit_info, fn _, _ -> {:ok, %{stats: %{}}} end)

    # A sibling async: false test may have swapped the boot-compiled catalog for
    # a single-item set; recompile the real one so the converters' on_use is the
    # source shipped in usable.yml.
    ScriptCompiler.compile_all!()

    on_exit(fn -> StatusStorage.remove_status(:player, @char_id, :sc_watk_element) end)

    :ok
  end

  defp ctx do
    %Ctx{
      char_id: @char_id,
      account_id: 100,
      connection_pid: self(),
      game_state: %PlayerState{character_id: @char_id},
      source: {:item, 0}
    }
  end

  defp attack_undead do
    attacker = CombatTestHelper.create_player_combatant(unit_id: @char_id, str: 50)
    defender = CombatTestHelper.create_mob_combatant(element: {:undead, 1})

    assert {:ok, _} = DamageCalculator.calculate_damage(attacker, defender)
  end

  for {item_id, element} <- @converters do
    test "converter #{item_id} endows the weapon with the #{element} element" do
      assert %Ctx{status: :ok} = CompiledItemScripts.on_use(unquote(item_id), ctx())

      attack_undead()

      assert_received {:attack_element, unquote(element)}
    end

    test "converter #{item_id} endows for ITEM_ENCHANTARMS's Duration1 of 20 minutes" do
      CompiledItemScripts.on_use(unquote(item_id), ctx())

      instance = StatusStorage.get_status(:player, @char_id, :sc_watk_element)

      remaining = instance.expires_at - System.monotonic_time(:millisecond)

      assert_in_delta remaining, 1_200_000, 100
    end
  end
end
