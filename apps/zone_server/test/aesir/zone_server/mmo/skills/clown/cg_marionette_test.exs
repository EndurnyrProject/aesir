defmodule Aesir.ZoneServer.Mmo.Skills.Clown.CgMarionetteTest do
  use ExUnit.Case, async: true
  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skills.Clown.CgMarionette
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  setup do
    caster = player(17, class: 4020, str: 80, sex: "M")
    target = player(18, str: 60, sex: "F")

    for p <- [caster, target, player(19, sex: "F")] do
      :ok = UnitRegistry.register_player(p, self())
      :ok = SpatialIndex.add_player(p.character_id, p.x, p.y, p.map_name)
    end

    %{caster: caster, target: target}
  end

  test "link freezes halves and capped gains, then recasting ends both", %{
    caster: caster,
    target: target
  } do
    baseline = Calculator.calculate_stats(caster.stats, 17)
    assert :ok = CgMarionette.validate(caster, {:unit, 18}, 1, CgMarionette.definition())
    assert {:ok, ^caster} = CgMarionette.cast(caster, {:unit, 18}, 1, CgMarionette.definition())
    master = StatusStorage.get_status(:player, 17, :sc_marionette)
    puppet = StatusStorage.get_status(:player, 18, :sc_marionette2)
    assert master.state.link_id == puppet.state.link_id
    assert master.state.halves.str == 40
    assert puppet.state.gains.str == 39
    updated = Calculator.calculate_stats(caster.stats, 17)

    assert Stats.get_effective_stat(updated, :str) ==
             Stats.get_effective_stat(baseline, :str) - 40

    assert updated.derived_stats.max_hp == baseline.derived_stats.max_hp - 1000
    puppet_stats = Calculator.calculate_stats(target.stats, 18)
    assert Stats.get_effective_stat(puppet_stats, :str) == 99
    assert {:ok, ^caster} = CgMarionette.cast(caster, {:unit, 18}, 1, CgMarionette.definition())
    refute StatusStorage.has_status?(:player, 17, :sc_marionette)
    refute StatusStorage.has_status?(:player, 18, :sc_marionette2)
  end

  test "validation refuses self, another party and dead targets before the cost", %{
    caster: caster
  } do
    assert {:error, :invalid_target} =
             CgMarionette.validate(caster, {:unit, 17}, 1, CgMarionette.definition())

    :ok = UnitRegistry.update_unit_state(:player, 18, %{player(18) | party_id: 3})

    assert {:error, :not_same_party} =
             CgMarionette.validate(caster, {:unit, 18}, 1, CgMarionette.definition())

    :ok =
      UnitRegistry.update_unit_state(:player, 18, put_in(player(18).stats.current_state.hp, 0))

    assert {:error, :invalid_target} =
             CgMarionette.validate(caster, {:unit, 18}, 1, CgMarionette.definition())
  end

  test "a same-sex performer target is refused after the requirement is paid", %{caster: caster} do
    :ok = UnitRegistry.update_unit_state(:player, 18, player(18, class: 4021, sex: "M"))

    assert {:failed, ^caster, :invalid_target, :spare_items} =
             CgMarionette.cast(caster, {:unit, 18}, 1, CgMarionette.definition())
  end

  test "Curse and Quagmire block the target after the requirement is paid", %{caster: caster} do
    for status <- [:sc_curse, :sc_quagmire] do
      :ok = StatusStorage.apply_status(:player, 18, status)

      assert {:failed, ^caster, :target_blocked, :spare_items} =
               CgMarionette.cast(caster, {:unit, 18}, 1, CgMarionette.definition())

      StatusStorage.remove_status(:player, 18, status)
    end
  end

  test "already-linked participants cannot establish a second link", %{caster: caster} do
    assert {:ok, _} = CgMarionette.cast(caster, {:unit, 19}, 1, CgMarionette.definition())

    assert {:failed, ^caster, :already_linked, :spare_items} =
             CgMarionette.cast(caster, {:unit, 18}, 1, CgMarionette.definition())

    :ok = Interpreter.remove_status(:player, 17, :sc_marionette)

    :ok =
      StatusStorage.apply_status(:player, 18, :sc_marionette2,
        state: %{peer: {:player, 19}, link_id: make_ref(), gains: %{}}
      )

    assert {:failed, ^caster, :already_linked, :spare_items} =
             CgMarionette.cast(caster, {:unit, 18}, 1, CgMarionette.definition())
  end

  test "a puppet cannot cast Marionette while a master can be made one", %{caster: caster} do
    :ok =
      StatusStorage.apply_status(:player, 17, :sc_marionette2,
        state: %{peer: {:player, 19}, link_id: make_ref(), gains: %{}}
      )

    # Wearing a puppet's half blocks the skill before the cost is spent.
    assert {:error, :invalid_target} =
             CgMarionette.validate(caster, {:unit, 18}, 1, CgMarionette.definition())

    StatusStorage.remove_status(:player, 17, :sc_marionette2)

    # Only the caster's marionette and the target's marionette2 gate the pair,
    # so a target that is another link's master joins this one.
    :ok =
      StatusStorage.apply_status(:player, 18, :sc_marionette,
        state: %{peer: {:player, 19}, link_id: make_ref(), halves: %{}}
      )

    assert {:ok, ^caster} =
             CgMarionette.cast(caster, {:unit, 18}, 1, CgMarionette.definition())

    assert StatusStorage.has_status?(:player, 17, :sc_marionette)
  end

  defp player(id, opts \\ []) do
    PlayerState.new(%Character{
      id: id,
      account_id: id,
      name: "Marionette #{id}",
      class: Keyword.get(opts, :class, 0),
      base_level: 80,
      job_level: 1,
      party_id: 2,
      sex: Keyword.get(opts, :sex, "F"),
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      str: Keyword.get(opts, :str, 10),
      agi: 0,
      vit: 0,
      int: 0,
      dex: 0,
      luk: 0
    })
  end
end
