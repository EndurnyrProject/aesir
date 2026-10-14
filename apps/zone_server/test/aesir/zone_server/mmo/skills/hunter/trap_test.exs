defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.TrapTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.ZoneServer.TrapTestHelper

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @stats %{dex: 10, int: 10, base_level: 10}

  setup :verify_on_exit!

  setup do
    caster = %PlayerState{character_id: 10, map_name: "prontera"}
    target = %{instance_id: 20, map_name: "prontera", hp: 100}

    stub(UnitRegistry, :get_unit, fn
      :player, 10 -> {:ok, {PlayerState, caster, self()}}
      :mob, 20 -> {:ok, {Map, target, self()}}
      _type, _id -> {:error, :not_found}
    end)

    :ok
  end

  defp group(caster_type, origin, paid_return? \\ false, skill_name \\ :ht_landmine) do
    %Group{
      group_id: 1,
      skill_id: 116,
      skill_name: skill_name,
      caster_id: 10,
      caster_type: caster_type,
      map_name: "prontera",
      state: %{cast_origin: origin, paid_return?: paid_return?}
    }
  end

  test "writes only typed lifecycle metadata" do
    state = Trap.place_state(1, @stats, group(:player, :direct))

    assert %TrapState{phase: :armed, reclaim_item_id: 1065} = state.trap
    refute Map.has_key?(state, :armed)
    refute Map.has_key?(state, :reclaimable)
    refute Map.has_key?(state, :trap_item)
    assert state.ignore_land_protector
  end

  test "exact Claymore-spendable trap metadata includes Sandman" do
    for skill_name <- [
          :ht_landmine,
          :ht_blastmine,
          :ht_shockwave,
          :ht_flasher,
          :ht_sandman,
          :ht_freezingtrap,
          :ht_claymoretrap
        ] do
      state = Trap.place_state(1, @stats, group(:player, :normal, true, skill_name))
      assert state.trap.claymore_spendable?
    end

    refute Trap.place_state(1, @stats, group(:player, :normal, true, :ht_anklesnare)).trap.claymore_spendable?
  end

  test "only normal player placements carry paid natural return" do
    for {caster_type, origin, paid_return?, expected} <- [
          {:player, :normal, true, true},
          {:player, :normal, false, false},
          {:player, :item, true, false},
          {:player, :auto, true, false},
          {:player, :direct, true, false},
          {:mob, :mob, true, false},
          {:mob, :normal, true, false}
        ] do
      state = Trap.place_state(1, @stats, group(caster_type, origin, paid_return?))
      assert state.trap.return_item_on_expiry? == expected
    end
  end

  test "harmful PvE policy is relative to the caster side" do
    assert Trap.enemy?(group(:player, :normal), {:mob, 20})
    refute Trap.enemy?(group(:player, :normal), {:player, 20})
    assert Trap.enemy?(group(:mob, :mob), {:player, 20})
    refute Trap.enemy?(group(:mob, :mob), {:mob, 20})
  end

  @tag game_mode: :renewal
  test "renewal trap damage is level times DEX scaled by base level and INT for every mine" do
    stats = %{dex: 100, int: 35, base_level: 100}
    assert Trap.base_damage(2, stats, :ht_landmine) == 1600
    assert Trap.base_damage(2, stats, :ht_claymoretrap) == 1600
  end

  @tag game_mode: :pre_renewal
  test "classic trap damage has its own formula per mine" do
    stats = %{dex: 100, int: 100, base_level: 99}
    assert Trap.base_damage(2, stats, :ht_landmine) == 700
    assert Trap.base_damage(2, stats, :ht_blastmine) == 400
    assert Trap.base_damage(2, stats, :ht_claymoretrap) == 500
  end

  @hidden [
    :ht_skidtrap,
    :ht_landmine,
    :ht_anklesnare,
    :ht_shockwave,
    :ht_sandman,
    :ht_flasher,
    :ht_freezingtrap,
    :ht_talkiebox
  ]

  @tag game_mode: :renewal
  test "renewal hides the flagged traps from all but the caster's party" do
    for skill_name <- @hidden, do: assert(Trap.visibility(skill_name) == :party_only)
    assert Trap.visibility(:ht_blastmine) == :public
    assert Trap.visibility(:ht_claymoretrap) == :public
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal shows every trap" do
    for skill_name <- [:ht_blastmine, :ht_claymoretrap | @hidden],
        do: assert(Trap.visibility(skill_name) == :public)
  end

  test "a sprung trap is used for 1.5 seconds, never past its own lifetime" do
    armed = %{group(:player, :normal) | expires_at: 20_000, state: %{trap: armed_trap()}}

    assert %Group{expires_at: 11_500, state: %{trap: %TrapState{phase: :used}}} =
             Trap.spring(armed, 10_000)

    assert %Group{expires_at: 20_000, state: %{trap: %TrapState{phase: :used}}} =
             Trap.spring(armed, 19_000)
  end

  test "only an armed trap with a present caster keeps living enemies" do
    armed = %{group(:player, :normal) | state: %{trap: armed_trap()}}
    dead = %{mob(21) | hp: 0, is_dead: true}
    stub_units([player(10), mob(20), dead])

    assert [{:mob, 20}] = Trap.unit_targets(armed, [{:mob, 20}, {:mob, 21}])

    used = %{armed | state: %{trap: armed_trap(phase: :used)}}
    assert [] = Trap.unit_targets(used, [{:mob, 20}])

    stub_units([mob(20)])
    assert [] = Trap.unit_targets(armed, [{:mob, 20}])
  end
end
