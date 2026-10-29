defmodule Aesir.ZoneServer.Mmo.Skill.AfterCastDelayTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skill.AfterCastDelay
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  setup :setup_ets_tables

  test "combo skills start from 1000 ms when the table has none and lose 4 per AGI, 2 per DEX of the totals" do
    # AGI 40 + 10 from equipment, DEX 40: 1000 - 200 - 80.
    caster = caster(%{agi: 10})

    assert AfterCastDelay.resolve(caster, definition(263, []), 1) == 720
    assert AfterCastDelay.resolve(caster, definition(272, [900]), 1) == 620
    assert AfterCastDelay.resolve(caster, definition(6, [900]), 1) == 900
  end

  test "Bragi and the delay rate sum into one single-precision reduction, truncated" do
    # 720 x float32(1 - float32(0.3)) = 503.99..., not 504.
    assert AfterCastDelay.resolve(caster(%{delay_rate: -30}), definition(6, [720]), 1) == 503

    caster = caster(%{delay_rate: -10})
    bragi(caster, 20)
    assert AfterCastDelay.resolve(caster, definition(6, [720]), 1) == 503
  end

  test "the per-skill equipment delay is added before the reduction" do
    caster = caster(%{{:skill_delay, 6} => 100, delay_rate: -50})

    assert AfterCastDelay.resolve(caster, definition(6, [500]), 1) == 300
  end

  test "a skill ignoring statuses skips Bragi; one ignoring items skips both equipment bonuses" do
    caster = caster(%{{:skill_delay, 6} => 100, delay_rate: -50})
    bragi(caster, 50)

    assert AfterCastDelay.resolve(caster, %{definition(6, [500]) | ignore_status_delay: true}, 1) ==
             300

    assert AfterCastDelay.resolve(caster, %{definition(6, [500]) | ignore_item_delay: true}, 1) ==
             250
  end

  test "a reduction of 100% or more, or a negative delay, gives 0" do
    assert AfterCastDelay.resolve(caster(%{delay_rate: -150}), definition(6, [500]), 1) == 0
    assert AfterCastDelay.resolve(caster(%{agi: 500}), definition(272, [1_000]), 1) == 0
  end

  defp caster(equipment) do
    stats = %PlayerStats{
      base_stats: %{str: 1, agi: 40, vit: 1, int: 1, dex: 40, luk: 1},
      modifiers: %{equipment: equipment, status_effects: %{}, job_bonuses: %{}}
    }

    %PlayerState{character_id: System.unique_integer([:positive]), stats: stats}
  end

  defp bragi(caster, percent) do
    :ok =
      StatusStorage.apply_status(:player, caster.character_id, :sc_poembragi,
        state: %{delay_reduction: percent}
      )
  end

  defp definition(id, after_cast_delay) do
    %Definition{
      id: id,
      name: :test_skill,
      display_name: "Test Skill",
      max_level: 1,
      target_type: :self,
      after_cast_delay: after_cast_delay
    }
  end
end
