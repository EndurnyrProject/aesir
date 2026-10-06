defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BlacksmithPassiveCastTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Stats.BaseStats

  setup do
    :ok = Catalog.reload()
  end

  test "passive phase-2 skills remain uncastable while Adrenaline Rush is active" do
    game_state = caster(105)

    assert {:error, :passive_skill} = Interpreter.cast(game_state, 105, 1, :self)
  end

  test "Skin Temper is a passive skill and cannot be cast" do
    game_state = caster(109)

    assert {:error, :passive_skill} = Interpreter.cast(game_state, 109, 1, :self)
  end

  defp caster(skill_id) do
    %PlayerState{
      character_id: 1000,
      map_name: "prontera",
      stats: %Stats{
        base_stats: %BaseStats{dex: 1, int: 1},
        progression: %Stats.PlayerProgression{learned_skills: %{skill_id => 1}}
      }
    }
  end
end
