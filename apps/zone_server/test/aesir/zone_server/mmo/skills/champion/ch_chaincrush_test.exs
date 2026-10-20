defmodule Aesir.ZoneServer.Mmo.Skills.Champion.ChChaincrushTest do
  use ExUnit.Case, async: false

  import Mimic
  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skills.Champion.ChChaincrush
  alias Aesir.ZoneServer.Mmo.Skills.Champion.Formulas
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  @caster_id 38_100
  @target_id 38_101

  setup do
    stub(Combat, :resolve_target_position, fn @target_id -> {:ok, :mob, {60, 50, "prontera"}} end)
    :ok
  end

  test "follows Raging Thrust or Glacier Fist, never itself" do
    assert :ok = validate(caster(:extremity))
    assert :ok = validate(caster(:tiger_fist))
    assert {:error, :invalid_combo} = validate(caster(:chain_crush))
  end

  test "strikes with its ratio, shown as one hit per two levels" do
    caster = caster(:tiger_fist)

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_id] == 372
      assert opts[:skill_level] == 7
      assert opts[:skill_ratio] == Formulas.chain_crush_ratio(7, 99)
      assert opts[:hit_divisions] == -4
      assert opts[:skip_crit]
      :ok
    end)

    assert {:ok, _updated} = cast(caster, 7)
  end

  @tag game_mode: :renewal
  test "renewal spends one sphere and opens Asura's window with one left and Fury" do
    assert Cost.from_definition(caster(:extremity), ChChaincrush.definition(), 1).spheres == 1

    fury!()
    ready = caster(:extremity, spheres: 2, learned: %{372 => 10, 271 => 5})
    stub(Combat, :execute_skill_attack, fn _caster, @target_id, _opts -> :ok end)
    assert {:ok, %{combo: %{stage: :chain_crush}}} = cast(ready, 1)

    glacier_only = caster(:extremity, spheres: 5, learned: %{372 => 10, 371 => 5})
    assert {:ok, %{combo: %{stage: :idle}}} = cast(glacier_only, 1)
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal spends two spheres and loops back toward Glacier Fist" do
    assert Cost.from_definition(caster(:extremity), ChChaincrush.definition(), 1).spheres == 2
    stub(Combat, :execute_skill_attack, fn _caster, @target_id, _opts -> :ok end)

    glacier = caster(:extremity, spheres: 1, learned: %{372 => 10, 371 => 5})
    assert {:ok, %{combo: %{stage: :chain_crush}}} = cast(glacier, 1)

    short = caster(:extremity, spheres: 0, learned: %{372 => 10, 371 => 5})
    assert {:ok, %{combo: %{stage: :idle}}} = cast(short, 1)
  end

  defp fury! do
    :ok =
      StatusStorage.apply_status(:player, @caster_id, :sc_explosionspirits, duration: 180_000)
  end

  defp validate(caster),
    do: ChChaincrush.validate(caster, {:unit, @target_id}, 1, ChChaincrush.definition())

  defp cast(caster, level),
    do: ChChaincrush.cast(caster, {:unit, @target_id}, level, ChChaincrush.definition())

  defp caster(stage, opts \\ []) do
    character = %Character{
      id: @caster_id,
      account_id: @caster_id,
      name: "Champion",
      last_map: "prontera",
      last_x: 50,
      last_y: 50,
      sex: "M",
      str: 40,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 99,
      job_level: 50,
      class: 4016
    }

    state = PlayerState.new(character)
    learned = Keyword.get(opts, :learned, %{372 => 10})
    stats = %{state.stats | progression: %{state.stats.progression | learned_skills: learned}}

    spheres =
      Enum.reduce(1..Keyword.get(opts, :spheres, 5)//1, SpiritSpheres.new(), fn _, acc ->
        acc |> SpiritSpheres.summon(future(), 5) |> elem(0)
      end)

    %{
      state
      | stats: stats,
        spirit_spheres: spheres,
        combo: Combo.open(Combo.new(), stage, {:mob, @target_id}, future())
    }
  end

  defp future, do: System.monotonic_time(:millisecond) + 10_000
end
