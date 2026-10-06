defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MemorizeTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Mmo.Mechanics.CastTime.PreRenewal
  alias Aesir.ZoneServer.Mmo.Mechanics.CastTime.Renewal
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Memorize
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  @id 7_001
  @target {:player, @id}

  defp applied do
    {:ok, instance} =
      Memorize.on_apply(@target, %StatusEntry{type: :sc_memorize, val1: 1, state: %{}}, %{})

    instance
  end

  test "begins with five displayed charges and a 50 percent reduction" do
    assert %{val2: 5, state: %{cast_time_reduction: 50, charges: 5}} = applied()
  end

  test "each eligible timing reaction spends a charge and the fifth ends it" do
    stub(UnitRegistry, :get_unit_info, fn :player, @id -> {:ok, %{stats: %{}}} end)
    instance = applied()

    :ok =
      StatusStorage.apply_status(:player, @id, :sc_memorize,
        val2: instance.val2,
        state: instance.state
      )

    Enum.each(4..1//-1, fn remaining ->
      :ok = Memorize.consume_charge(:player, @id)

      assert %{val2: ^remaining, state: %{charges: ^remaining}} =
               StatusStorage.get_status(:player, @id, :sc_memorize)
    end)

    :ok = Memorize.consume_charge(:player, @id)
    refute StatusStorage.has_status?(:player, @id, :sc_memorize)
  end

  test "the fifth charge still shortens its cast before expiring" do
    stub(UnitRegistry, :get_unit_info, fn :player, @id -> {:ok, %{stats: %{}}} end)

    :ok =
      StatusStorage.apply_status(:player, @id, :sc_memorize,
        val2: 1,
        state: %{charges: 1, cast_time_reduction: 50}
      )

    definition = %Definition{
      id: 14,
      name: :mg_coldbolt,
      display_name: "Cold Bolt",
      max_level: 1,
      cast_time: [1_000],
      fixed_cast_time: [0]
    }

    inputs = %{dex: 0, int: 0, effective_skill?: true, statuses: %{memorize: true}}

    assert %{timing: %{total: 500}, reactions: [:consume_memorize]} =
             Renewal.late(definition, 1, inputs, 1_000)

    assert %{time: 500, reactions: [:consume_memorize]} =
             PreRenewal.early(definition, 1, inputs)

    :ok = Memorize.consume_charge(:player, @id)
    refute StatusStorage.has_status?(:player, @id, :sc_memorize)
  end

  test "unlearned skills and pure preflight leave every charge intact" do
    :ok = StatusStorage.apply_status(:player, @id, :sc_memorize, state: applied().state)
    {:ok, skill} = Catalog.by_id(14)
    inputs = %{dex: 50, int: 1, effective_skill?: false, statuses: %{memorize: true}}

    assert PreRenewal.early(skill, 1, inputs).reactions == []
    assert Renewal.late(skill, 1, inputs, 1_000).reactions == []
    assert StatusStorage.get_status(:player, @id, :sc_memorize).state.charges == 5
  end

  test "renewal IgnoreStatus neither reduces nor spends Foresight" do
    {:ok, skill} = Catalog.by_id(403)
    inputs = %{dex: 50, int: 1, effective_skill?: true, statuses: %{memorize: true}}
    assert %{reactions: [], timing: %{total: _}} = Renewal.late(skill, 1, inputs, 1_000)
  end

  @tag game_mode: :pre_renewal
  test "classic IgnoreStatus spends a charge without halving timing" do
    {:ok, skill} = Catalog.by_id(403)
    inputs = %{dex: 50, int: 1, effective_skill?: true, statuses: %{memorize: true}}
    assert %{reactions: [:consume_memorize], time: time} = PreRenewal.early(skill, 1, inputs)
    assert time == 5_000
  end

  test "classic DEX-instant cast never reaches Foresight" do
    {:ok, skill} = Catalog.by_id(14)
    inputs = %{dex: 150, int: 1, effective_skill?: true, statuses: %{memorize: true}}
    assert %{reactions: [], time: 0} = PreRenewal.early(skill, 1, inputs)
  end
end
