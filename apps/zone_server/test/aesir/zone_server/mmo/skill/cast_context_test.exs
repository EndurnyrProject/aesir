defmodule Aesir.ZoneServer.Mmo.Skill.CastContextTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skill.CastContext
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlIncagi
  alias Aesir.ZoneServer.Mmo.Skills.Homunculus.HlifHeal
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers

  setup :setup_ets_tables

  test "builds a begin context from a real player state" do
    caster = player()
    {:ok, definition} = Catalog.by_id(29)

    context = CastContext.build(caster, definition, 2, {:unit, 202}, :begin)

    assert context.caster == caster
    assert context.kind == :player
    assert context.adapter == Caster.Player
    assert context.id == 101
    assert context.position == {"prontera", 10, 20}
    assert context.definition == definition
    assert context.module == AlIncagi
    assert context.level == 2
    assert context.target == {:unit, 202}
    assert context.phase == :begin
    assert context.cost == nil

    assert context.stats == %{
             dex: 20,
             int: 30,
             varcast_reductions: [],
             varcast_rate: 0,
             fixed_cast: 0,
             fixcast_rate: 0
           }
  end

  test "rebuilds a completion context from a real homunculus state" do
    caster = homunculus()
    {:ok, definition} = Catalog.by_id(8_001)

    begin_context = CastContext.build(caster, definition, 1, :self, :begin)
    completion_context = CastContext.build(caster, definition, 1, :self, :completion)

    assert completion_context.caster == caster
    assert completion_context.kind == :homunculus
    assert completion_context.adapter == Caster.Homunculus
    assert completion_context.id == 301
    assert completion_context.position == {"prontera", 11, 21}
    assert completion_context.definition == definition
    assert completion_context.module == HlifHeal
    assert completion_context.level == 1
    assert completion_context.target == :self
    assert completion_context.phase == :completion
    assert completion_context.cost == nil

    assert completion_context.stats == %{
             dex: 12,
             int: 18,
             varcast_reductions: [],
             varcast_rate: 0,
             fixed_cast: 0
           }

    assert Map.delete(begin_context, :phase) == Map.delete(completion_context, :phase)
  end

  defp player do
    %PlayerState{
      character_id: 101,
      map_name: "prontera",
      x: 10,
      y: 20,
      stats: %PlayerStats{
        base_stats: %{str: 1, agi: 1, vit: 1, int: 30, dex: 20, luk: 1},
        modifiers: %Modifiers{equipment: %{}}
      }
    }
  end

  defp homunculus do
    %HomunculusState{
      id: 201,
      owner_character_id: 101,
      class_id: 6_001,
      name: "Lif",
      world_gid: 301,
      map_name: "prontera",
      x: 11,
      y: 21,
      dex: 12,
      int: 18
    }
  end
end
