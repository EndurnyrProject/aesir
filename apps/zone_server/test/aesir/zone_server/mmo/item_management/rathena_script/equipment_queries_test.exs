defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.EquipmentQueriesTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler

  test "slot queries survive serialization and preserve empty-slot return values" do
    script = """
    bonus bStr,getequipid(EQI_HAND_R);
    bonus bDex,getequiprefinerycnt(EQI_HAND_R);
    bonus bInt,getiteminfo(getequipid(EQI_HAND_R),ITEMINFO_VIEW);
    """

    assert {:ok, program} = Transpiler.transpile_equip(script)
    assert program == EquipScript.parse!(EquipScript.to_source(program))

    assert EquipScript.eval(program, %{
             refine: 99,
             equipped_slots: %{9 => %{id: 1101, refine: 7, view: 2}}
           }) == %{str: 1101, dex: 7, int: 2}

    assert EquipScript.eval(program, %{equipped_slots: %{}}) == %{str: -1, dex: 0, int: -1}
  end

  test "equipment-view conditions use weapon ordinals and reject other weapons" do
    script = """
    if (getiteminfo(getequipid(EQI_HAND_R),ITEMINFO_VIEW) == W_1HSWORD ||
        getiteminfo(getequipid(EQI_HAND_R),ITEMINFO_VIEW) == W_2HSWORD) {
      bonus bHit,5;
      bonus bCritical,5;
    }
    """

    assert {:ok, program} = Transpiler.transpile_equip(script)
    assert program == EquipScript.parse!(EquipScript.to_source(program))

    for view <- [2, 3] do
      assert EquipScript.eval(program, %{equipped_slots: %{9 => %{view: view}}}) ==
               %{hit: 5, critical: 5}
    end

    assert EquipScript.eval(program, %{equipped_slots: %{9 => %{view: 11}}}) == %{}
    assert EquipScript.eval(program, %{equipped_slots: %{}}) == %{}
  end

  test "numeric skill conditions select the learned or fallback autocast level" do
    script = """
    bonus2 bSkillAtk,"AS_GRIMTOOTH",10;
    if (getskilllv("AS_SONICBLOW")) {
      bonus3 bAutoSpell,"AS_SONICBLOW",getskilllv("AS_SONICBLOW"),5;
    } else {
      bonus3 bAutoSpell,"AS_SONICBLOW",1,5;
    }
    """

    assert {:ok, program} = Transpiler.transpile_equip(script)
    assert program == EquipScript.parse!(EquipScript.to_source(program))

    for {learned, level} <- [{%{}, 1}, {%{136 => 7}, 7}] do
      result = EquipScript.evaluate(program, %{learned_skills: learned})
      assert result.modifiers == %{{:skill_atk, 137} => 10}
      assert [%{skill_id: 136, level: ^level, rate: 5}] = result.auto_casts
    end
  end

  test "numeric truthiness also works under negation" do
    assert {:ok, program} =
             Transpiler.transpile_equip("if (!getskilllv(136)) bonus bHit,5;")

    assert EquipScript.eval(program, %{learned_skills: %{}}) == %{hit: 5}
    assert EquipScript.eval(program, %{learned_skills: %{136 => 1}}) == %{}
  end

  test "unsupported item-info fields and malformed serialized reads remain rejected" do
    assert {:error, {:unsupported, _}} =
             Transpiler.transpile_equip(
               "bonus bStr,1; bonus bDex,getiteminfo(getequipid(EQI_HAND_R),ITEMINFO_WEIGHT);"
             )

    assert_raise ArgumentError, fn ->
      EquipScript.parse!("bonus(ctx, :str, equip_item(ctx, :unknown, 9))")
    end
  end
end
