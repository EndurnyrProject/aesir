defmodule Aesir.ZoneServer.Unit.Homunculus.NaturalRegenTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Homunculus.Stats
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.NaturalRegen
  alias Aesir.ZoneServer.Unit.Homunculus.Runtime

  test "Adamantium Skin ranks one and five increase actual HP recovery" do
    assert recover_hp(amistr(1)) == 7
    assert recover_hp(amistr(5)) == 8
  end

  test "Brain Surgery increases actual SP recovery" do
    homunculus = lif(5)
    {_, armed} = NaturalRegen.tick(homunculus, runtime(), 1_000)
    {recovered, _runtime} = NaturalRegen.tick(homunculus, armed, 5_000)

    assert recovered.sp - homunculus.sp == 14
  end

  test "full, moving, rested, and dead Homunculi do not recover" do
    base = amistr(5)

    full = %{base | hp: base.max_hp, sp: base.max_sp}
    moving = %{base | movement_state: :moving}
    rested = %{base | lifecycle: :rested}
    dead = %{base | lifecycle: :dead, action_state: :dead, hp: 0}

    for homunculus <- [full, moving, rested, dead] do
      {first, runtime} = NaturalRegen.tick(homunculus, runtime(), 1_000)
      {second, runtime} = NaturalRegen.tick(first, runtime, 10_000)
      assert second == homunculus

      if homunculus.lifecycle != :active or homunculus.movement_state == :moving do
        assert runtime.hp_regen_deadline_ms == nil
        assert runtime.sp_regen_deadline_ms == nil
      end
    end
  end

  defp recover_hp(homunculus) do
    {_, armed} = NaturalRegen.tick(homunculus, runtime(), 1_000)
    {recovered, _runtime} = NaturalRegen.tick(homunculus, armed, 3_000)
    recovered.hp - homunculus.hp
  end

  defp amistr(rank) do
    homunculus(6002, %{8007 => rank})
    |> Stats.recompute()
  end

  defp lif(rank) do
    homunculus(6001, %{8003 => rank})
    |> Stats.recompute()
  end

  defp homunculus(class_id, learned_skills) do
    %HomunculusState{
      id: 1,
      owner_character_id: 2,
      class_id: class_id,
      name: "Regen",
      lifecycle: :active,
      hp: 500,
      max_hp: 1_000,
      raw_max_hp: 1_000,
      sp: 50,
      max_sp: 200,
      raw_max_sp: 200,
      str: 10,
      raw_str: 10,
      agi: 10,
      raw_agi: 10,
      vit: 10,
      raw_vit: 10,
      int: 60,
      raw_int: 60,
      dex: 10,
      raw_dex: 10,
      luk: 10,
      raw_luk: 10,
      attack_delay_ms: 500,
      raw_attack_delay_ms: 500,
      learned_skills: learned_skills,
      world_gid: 1_500_001,
      map_name: "regen_test",
      x: 1,
      y: 1
    }
  end

  defp runtime, do: %Runtime{private_dirty: false}
end
