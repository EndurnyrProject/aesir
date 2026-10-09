defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.HermodeTest do
  use ExUnit.Case, async: false
  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat.MagicDefense
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  setup do
    for id <- [17, 18] do
      player =
        PlayerState.new(%Character{
          id: id,
          account_id: id,
          name: "Hermode #{id}",
          class: 19,
          base_level: 50,
          job_level: 50,
          sex: "M",
          last_map: "prontera",
          last_x: 100,
          last_y: 100,
          str: 10,
          agi: 10,
          vit: 0,
          int: 10,
          dex: 10,
          luk: 0
        })

      :ok = UnitRegistry.register_player(player, self())
    end

    :ok
  end

  test "Hermode strips Blessing from allies, keeps Endure, and resolves full immunity" do
    assert :ok = Interpreter.apply_status(:player, 18, :sc_blessing, caster_id: 18, val1: 10)
    assert :ok = Interpreter.apply_status(:player, 18, :sc_endure, caster_id: 18, val1: 1)

    assert :ok =
             Interpreter.apply_status(:player, 18, :sc_hermode,
               caster_id: 17,
               val1: 1,
               duration: 10_000
             )

    refute StatusStorage.has_status?(:player, 18, :sc_blessing)
    assert StatusStorage.has_status?(:player, 18, :sc_endure)
    {:ok, {PlayerState, player, _}} = UnitRegistry.get_unit(:player, 18)
    updated = %{player | stats: Calculator.calculate_stats(player.stats, 18)}
    :ok = UnitRegistry.update_unit_state(:player, 18, updated)
    assert updated.stats.modifiers.status_effects.no_magic_damage == 100
    assert MagicDefense.full_immunity?(PlayerState.to_combatant(updated))
    assert MagicDefense.immune?({:player, 18})
    assert MagicDefense.reduce(1234, :player, 18) == 0
    assert Interpreter.support_blocked?(:player, 18)
  end

  test "the caster keeps Blessing" do
    assert :ok = Interpreter.apply_status(:player, 17, :sc_blessing, caster_id: 17, val1: 10)

    assert :ok =
             Interpreter.apply_status(:player, 17, :sc_hermode,
               caster_id: 17,
               val1: 1,
               duration: 10_000
             )

    assert StatusStorage.has_status?(:player, 17, :sc_blessing)
  end

  test "every status in Hermode's removal set has a definition" do
    path =
      Path.expand(
        "../../../../../../lib/aesir/zone_server/mmo/status_effect/effects/hermode.ex",
        __DIR__
      )

    ast = path |> File.read!() |> Code.string_to_quoted!()

    {_, ids} =
      Macro.prewalk(ast, [], fn
        {:@, _, [{:cleared, _, [ids]}]} = node, _acc -> {node, ids}
        node, acc -> {node, acc}
      end)

    assert length(ids) == 66
    for id <- ids, do: assert(Registry.get_definition(id), "missing #{id}")
  end
end
