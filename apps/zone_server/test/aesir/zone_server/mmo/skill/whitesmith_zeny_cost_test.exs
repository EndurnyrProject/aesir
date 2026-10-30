defmodule Aesir.ZoneServer.Mmo.Skill.WhitesmithZenyCostTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Player
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.PlayerStateFixture

  setup :setup_ets_tables

  test "unfair_trick_uses_skill_and_mode" do
    costs =
      case GameMode.mode() do
        :renewal -> [{42, 800}, {485, 800}, {486, 1_000}, {999, 1_000}]
        :pre_renewal -> [{42, 900}, {485, 1_000}, {486, 1_000}, {999, 1_000}]
      end

    for {id, expected} <- costs do
      caster = caster(2_000)
      assert {:ok, prepared} = Player.cost(caster, __MODULE__, :self, definition(id, 1_000), 1)
      {paid, _remaining} = Player.commit_primary(caster, prepared)
      assert paid.zeny == 2_000 - expected
    end

    caster = caster(2_000, %{})
    assert {:ok, prepared} = Player.cost(caster, __MODULE__, :self, definition(42, 1_000), 1)
    {paid, _remaining} = Player.commit_primary(caster, prepared)
    assert paid.zeny == 1_000
  end

  test "discount_keeps_reference_subtraction_rounding" do
    caster = caster(101)
    expected = if GameMode.mode() == :renewal, do: 19, else: 9
    assert {:ok, prepared} = Player.cost(caster, __MODULE__, :self, definition(42, 99), 1)
    {paid, _remaining} = Player.commit_primary(caster, prepared)
    assert paid.zeny == 2 + expected
  end

  test "proc_requirement_uses_same_discount_eligibility" do
    caster = caster(2_000)
    mammonite = if GameMode.mode() == :renewal, do: 1_200, else: 1_100
    cart = if GameMode.mode() == :renewal, do: 1_200, else: 1_000

    for {id, balance} <- [{42, mammonite}, {485, cart}, {486, 1_000}, {999, 1_000}] do
      assert {:ok, paid} =
               Player.charge_proc_requirement(caster, __MODULE__, :self, definition(id, 1_000), 1)

      assert paid.zeny == balance
    end

    poor = caster(1)

    assert {:error, :insufficient_zeny} =
             Player.cost(poor, __MODULE__, :self, definition(42, 1_000), 1)

    assert {:ok, paid} =
             Player.charge_proc_requirement(poor, __MODULE__, :self, definition(42, 1_000), 1)

    assert paid.zeny == 0

    assert {:ok, unchanged} =
             Player.charge_proc_requirement(poor, __MODULE__, :self, definition(42, 0), 1)

    assert unchanged.zeny == 1
  end

  defp caster(zeny, skills \\ %{1_012 => 1}) do
    PlayerStateFixture.build(%{
      character_id: 101,
      zeny: zeny,
      inventory: %{},
      stats: %{progression: %{job_id: 10, learned_skills: skills}}
    })
  end

  defp definition(id, zeny) do
    %Definition{
      id: id,
      name: :test_zeny_skill,
      display_name: "Test Zeny Skill",
      max_level: 1,
      sp_cost: [0],
      zeny_cost: [zeny]
    }
  end
end
