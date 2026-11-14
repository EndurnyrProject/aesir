defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.MagicalbulletPreReTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack.PreRenewal
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsMagicalbullet
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @moduletag game_mode: :pre_renewal

  setup :set_mimic_private
  setup :verify_on_exit!

  defp cast_with_band(matk_min, matk_max) do
    caster = %PlayerState{character_id: 1}

    stub(PlayerState, :to_combatant, fn _ ->
      %{combat_stats: %{matk: matk_max, matk_min: matk_min, matk_max: matk_max}}
    end)

    expect(Combat, :execute_skill_attack, fn ^caster, {:mob, 2}, opts ->
      send(self(), {:opts, opts})
      :ok
    end)

    assert {:ok, ^caster} =
             GsMagicalbullet.cast(caster, {:unit, {:mob, 2}}, 1, GsMagicalbullet.definition())

    assert_received {:opts, opts}
    opts
  end

  test "a Ghost, 100% weapon hit that forces its element over the ammo's and never crits" do
    opts = cast_with_band(10, 20)

    assert opts[:element] == :ghost
    assert opts[:skill_ratio] == 100
    assert opts[:skip_crit]
    assert opts[:skip_range]
  end

  test "the MATK roll is half-open and a degenerate band gives matk_min" do
    for _ <- 1..30, do: assert(cast_with_band(100, 101)[:bonus_atk] == 100)
    assert cast_with_band(80, 80)[:bonus_atk] == 80
    assert cast_with_band(80, 50)[:bonus_atk] == 80
  end

  test "the rolled MATK lands after the skill ratio and before defence" do
    parts = %{
      status_atk: 0,
      flat_atk: 0,
      weapon_atk: 100,
      refine_atk: 0,
      overrefine_atk: 0,
      mastery_atk: 0,
      hand: :right_hand,
      source: :weapon
    }

    context = %{
      size_rate: 100,
      skill_id: 507,
      skill_ratio: 200,
      defense: %{hard_def: 50, soft_def: 0, attacker_level: nil, ignore_soft_def?: false}
    }

    with_bonus = PreRenewal.pre_element(parts, Map.put(context, :bonus_atk, 40))
    without = PreRenewal.pre_element(parts, context)

    assert with_bonus - without == 20
  end
end
