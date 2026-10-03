defmodule Aesir.ZoneServer.Integration.SupportBuffRefreshIntegrationTest do
  @moduledoc """
  End-to-end coverage for support buffs cast on another player: the status is
  applied from the caster's session, so the recipient's session must be told to
  recalculate its stats. Drives real sessions through the `SkillCast` packet path.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.SkillCast
  alias Aesir.ZoneServer.Unit.Player.Stats

  @blessing 34
  @increase_agi 29

  # Explicit ids keep the players clear of mob instance ids: a bare target id
  # that also names a live mob is resolved as that mob by single-target skills.
  @caster_id 9_931_001
  @target_id 9_931_002

  test "Blessing cast on another player raises that player's STR, INT and DEX" do
    %{caster: caster, target: target} = world()
    before = effective(target, [:str, :int, :dex])

    cast(caster, @blessing, 1, target.character.id)

    assert_eventually(fn ->
      effective(target, [:str, :int, :dex]) == Enum.map(before, &(&1 + 1))
    end)
  end

  test "Increase AGI cast on another player raises that player's AGI" do
    %{caster: caster, target: target} = world()
    [agi] = effective(target, [:agi])

    cast(caster, @increase_agi, 1, target.character.id)

    assert_eventually(fn -> effective(target, [:agi]) == [agi + 3] end)
  end

  defp world do
    caster =
      start_player_session(
        id: @caster_id,
        position: {150, 150},
        base_level: 99,
        job_level: 50,
        int: 99,
        dex: 99,
        hp: 5_000,
        max_hp: 5_000,
        sp: 1_000,
        max_sp: 1_000,
        learned_skills: %{"#{@blessing}" => 1, "#{@increase_agi}" => 1}
      )

    target = start_player_session(id: @target_id, position: {151, 150}, base_level: 99)

    %{caster: caster, target: target}
  end

  defp cast(caster, skill_id, level, target_id) do
    simulate_incoming_message(caster.pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: target_id
    })
  end

  defp effective(player, stat_names) do
    stats = get_player_state(player.pid).stats
    Enum.map(stat_names, &Stats.get_effective_stat(stats, &1))
  end
end
