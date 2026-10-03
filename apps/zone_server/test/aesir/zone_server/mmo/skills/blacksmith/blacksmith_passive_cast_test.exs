defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BlacksmithPassiveCastTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter

  setup do
    :ok = Catalog.reload()
  end

  test "passive phase-2 skills remain uncastable while Adrenaline Rush is active" do
    game_state = %{stats: %{progression: %{learned_skills: %{105 => 1}}}}

    assert {:error, :passive_skill} = Interpreter.cast(game_state, 105, 1, :self)
  end

  test "Skin Temper is a passive skill and cannot be cast" do
    game_state = %{stats: %{progression: %{learned_skills: %{109 => 1}}}}

    assert {:error, :passive_skill} = Interpreter.cast(game_state, 109, 1, :self)
  end
end
