defmodule Aesir.ZoneServer.Mmo.Skills.Champion.ChSoulcollectTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  test "Zen leaves exactly five fresh spheres for 20 SP from any held count" do
    for held <- [0, 3, 5] do
      before = System.monotonic_time(:millisecond)
      {:ok, state} = Interpreter.cast(caster(spheres(held)), 401, 1, :self)

      entries = SpiritSpheres.entries(state.spirit_spheres)
      assert length(entries) == 5
      assert state.stats.current_state.sp == 80

      assert Enum.all?(
               entries,
               &(&1.expires_at >= before + Formulas.spirit_sphere_duration())
             )
    end
  end

  defp spheres(count) do
    expires_at = System.monotonic_time(:millisecond) + 1_000

    Enum.reduce(List.duplicate(expires_at, count), SpiritSpheres.new(), fn at, acc ->
      acc |> SpiritSpheres.summon(at, 5) |> elem(0)
    end)
  end

  defp caster(spirit_spheres) do
    PlayerStateFixture.build(%{
      character_id: 4100,
      x: 10,
      y: 10,
      map_name: "prontera",
      skill_cooldowns: %{},
      act_delay_until: 0,
      spirit_spheres: spirit_spheres,
      stats: %{
        base_stats: %{dex: 1, int: 1},
        current_state: %{hp: 100, sp: 100},
        derived_stats: %{max_sp: 200, max_hp: 100},
        progression: %{learned_skills: %{401 => 1}},
        equipment: %{}
      }
    })
  end
end
