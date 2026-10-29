defmodule Aesir.ZoneServer.Mmo.Skills.AssassinCross.AscBreakerTest do
  use ExUnit.Case, async: false
  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.AssassinCross.AscBreaker
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    previous = Application.get_env(:zone_server, :soul_destroyer_rng)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:zone_server, :soul_destroyer_rng, previous),
        else: Application.delete_env(:zone_server, :soul_destroyer_rng)
    end)

    {:ok, definition} = Catalog.by_id(379)
    %{definition: definition, caster: player(%{str: 60, int: 40}, 150)}
  end

  @tag game_mode: :renewal
  test "renewal ratio is 150 per level plus STR and INT, scaled above base level 99" do
    assert AscBreaker.skill_ratio(10, 100, 99) == 1600
    # 1600 * 150 / 100
    assert AscBreaker.skill_ratio(10, 100, 150) == 2400
  end

  @tag game_mode: :pre_renewal
  test "classic ratio is 100 per level" do
    assert AscBreaker.skill_ratio(7, 100, 150) == 700
  end

  @tag game_mode: :renewal
  test "renewal strikes as a critical skill at half the critical chance", %{
    caster: caster,
    definition: definition
  } do
    expect(Combat, :execute_skill_attack, fn ^caster, 2001, opts ->
      assert opts[:skill_id] == 379
      assert opts[:skill_level] == 10
      assert opts[:critical] == true
      assert opts[:critical_divisor] == 2
      assert opts[:skip_range] == true
      # (150 * 10 + 60 + 40) * 150 / 100
      assert opts[:skill_ratio] == 2400
      refute Keyword.has_key?(opts, :misc_part)
      :ok
    end)

    assert {:ok, ^caster} = AscBreaker.cast(caster, {:unit, 2001}, 10, definition)
  end

  @tag game_mode: :pre_renewal
  test "classic adds the misc part from INT and never crits", %{
    caster: caster,
    definition: definition
  } do
    Application.put_env(:zone_server, :soul_destroyer_rng, fn 500 -> 123 end)

    expect(Combat, :execute_skill_attack, fn ^caster, 2001, opts ->
      assert opts[:skip_crit] == true
      refute opts[:critical]
      assert opts[:skill_ratio] == 700
      # 500 + (123 - 1) + 5 * 7 * 40
      assert opts[:misc_part] == 2022
      :ok
    end)

    assert {:ok, ^caster} = AscBreaker.cast(caster, {:unit, 2001}, 7, definition)
  end

  @tag game_mode: :renewal
  test "a monster uses its own STR, INT and level", %{definition: definition} do
    mob = %MobState{
      instance_id: 77,
      mob_id: 1_002,
      spawn_ref: nil,
      map_name: "prontera",
      hp: 100,
      sp: 0,
      spawned_at: 0,
      x: 3,
      y: 4,
      mob_data: %{level: 120},
      calculated: %{str: 80, int: 20}
    }

    expect(Combat, :execute_skill_attack, fn ^mob, {:player, 1}, opts ->
      # (150 * 10 + 80 + 20) * 120 / 100
      assert opts[:skill_ratio] == 1920
      :ok
    end)

    assert {:ok, ^mob} = AscBreaker.cast(mob, {:unit, {:player, 1}}, 10, definition)
  end

  defp player(stats, base_level) do
    base =
      PlayerState.new(%Character{
        id: 1,
        account_id: 1,
        name: "Breaker",
        class: 4013,
        sex: "M",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        base_level: base_level,
        hp: 1_000,
        sp: 1_000
      })

    base = put_in(base.stats.base_stats.str, stats.str)
    base = put_in(base.stats.base_stats.int, stats.int)
    base = put_in(base.stats.modifiers.job_bonuses, %{})
    put_in(base.stats.progression.base_level, base_level)
  end
end
