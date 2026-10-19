defmodule Aesir.ZoneServer.Mmo.ItemManagement.GemstoneBonusTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.EquipCodegen
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Player
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlWarp
  alias Aesir.ZoneServer.Npc.Transpiler.Parser
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers

  test "NoGemStone is a non-stacking flag even with zero arguments, and ammunition cannot grant it" do
    assert {:ok, statements} = Parser.parse_body("bonus bNoGemStone; bonus bNoGemStone,0;")
    assert {:ok, program} = EquipCodegen.generate(statements, :equip)
    assert EquipScript.eval(program, %{}) == %{no_gemstone: 1}
    assert EquipScript.eval(program, %{lr_flag: :arrow}) == %{}
  end

  test "equipment waives normal gemstones but Hocus Pocus and Ganbantein retain their floor" do
    caster = %PlayerState{
      stats: %Stats{modifiers: %Modifiers{equipment: %{no_gemstone: 1}}}
    }

    assert Player.effective_item_cost(caster, AlWarp.definition()) == []

    for name <- [:sa_abracadabra, :hw_ganbantein] do
      definition = %{name: name, item_cost: [%{id: 715, amount: 2}, %{id: 716, amount: 1}]}

      assert Player.effective_item_cost(caster, definition) == [
               %{id: 715, amount: 1},
               %{id: 716, amount: 1}
             ]
    end
  end
end
