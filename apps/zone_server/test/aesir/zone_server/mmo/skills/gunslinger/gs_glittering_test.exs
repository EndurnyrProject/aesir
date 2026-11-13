defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsGlitteringTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsGlittering
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  test "the coin lands on a roll up to 20 plus 10 per level" do
    assert GsGlittering.coin_lands?(1, 30)
    refute GsGlittering.coin_lands?(1, 31)
    assert GsGlittering.coin_lands?(5, 70)
    refute GsGlittering.coin_lands?(5, 71)
  end

  test "a landed flip adds a coin and a missed one removes the oldest" do
    for seed <- 1..30, level <- [1, 5] do
      caster = caster(coins(2))
      [oldest, newest] = SpiritSpheres.entries(caster.spirit_spheres)
      :rand.seed(:exsss, {seed, 2, 3})
      roll = :rand.uniform(100)
      :rand.seed(:exsss, {seed, 2, 3})

      assert {:ok, updated} = GsGlittering.cast(caster, :self, level, GsGlittering.definition())
      entries = SpiritSpheres.entries(updated.spirit_spheres)

      if GsGlittering.coin_lands?(level, roll) do
        assert [^oldest, ^newest, added] = entries
        assert added.expires_at > System.monotonic_time(:millisecond) + 599_000
      else
        assert entries == [newest]
      end
    end
  end

  test "a missed flip keeps every coin for a Rich's Coin learner and an empty hand stays empty" do
    :rand.seed(:exsss, {1, 2, 3})
    rich = put_in(caster(coins(2)).stats.progression.learned_skills[2552], 1)
    empty = caster(SpiritSpheres.new())

    for _ <- 1..20 do
      {:ok, kept} = GsGlittering.cast(rich, :self, 1, GsGlittering.definition())
      assert SpiritSpheres.count(kept.spirit_spheres) >= 2
      {:ok, flipped} = GsGlittering.cast(empty, :self, 1, GsGlittering.definition())
      assert SpiritSpheres.count(flipped.spirit_spheres) in [0, 1]
    end
  end

  test "a caster holding 10 coins is refused at cast begin and spends nothing" do
    state = caster(coins(10))

    assert {:error, :skill_failed} = Interpreter.begin_cast(state, 500, 1, :self)

    assert :instant ==
             caster(coins(9)) |> Interpreter.begin_cast(500, 1, :self) |> elem(0)
  end

  test "a non-player caster does nothing" do
    mob = %{instance_id: 7, hp: 10}
    assert {:ok, ^mob} = GsGlittering.cast(mob, :self, 5, GsGlittering.definition())
  end

  defp coins(n) do
    now = System.monotonic_time(:millisecond)

    Enum.reduce(1..n//1, SpiritSpheres.new(), fn i, spheres ->
      spheres |> SpiritSpheres.summon(now + 60_000 + i, 10) |> elem(0)
    end)
  end

  defp caster(spheres) do
    PlayerStateFixture.build(%{
      character_id: 4000,
      x: 10,
      y: 10,
      map_name: "prontera",
      zeny: 100,
      skill_cooldowns: %{},
      act_delay_until: 0,
      spirit_spheres: spheres,
      stats: %{progression: %{job_id: 24, learned_skills: %{500 => 5}}}
    })
  end
end
