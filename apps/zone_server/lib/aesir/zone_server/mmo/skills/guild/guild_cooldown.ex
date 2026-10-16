defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GuildCooldown do
  @moduledoc """
  The cooldowns guild skills arm themselves, on the casting master's own
  cooldown map.

  After a guild skill's effect, renewal re-arms that skill for its plain
  cooldown, replacing the generic cooldown armed at the cast end (an equipment
  cooldown bonus does not survive it). Pre-renewal instead blocks Battle Orders,
  Regeneration, Restore and Urgent Call together for 5 minutes, the casting
  skill's second duration.

  Pre-renewal also blocks the same four for 5 minutes when a master logs in and
  when a guild is created.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Cooldown
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @blocked_skills [10_010, 10_011, 10_012, 10_013]
  @block_time 300_000

  @doc """
  Re-arms the caster's cooldowns after a guild skill's effect, as of `now`
  (monotonic milliseconds).
  """
  @spec rearm(PlayerState.t(), Definition.t(), pos_integer(), integer()) :: PlayerState.t()
  def rearm(%PlayerState{} = caster, %Definition{} = definition, level, now) do
    case GameMode.mode() do
      :renewal -> put(caster, definition.id, Cooldown.duration(definition, level), now)
      :pre_renewal -> block(caster, now)
    end
  end

  @doc """
  Blocks the four guild skills of a master who just logged in or created a
  guild, in pre-renewal; renewal blocks nothing.
  """
  @spec relog_block(PlayerState.t(), integer()) :: PlayerState.t()
  def relog_block(%PlayerState{} = master, now) do
    case GameMode.mode() do
      :renewal -> master
      :pre_renewal -> block(master, now)
    end
  end

  defp block(caster, now),
    do: Enum.reduce(@blocked_skills, caster, &put(&2, &1, @block_time, now))

  defp put(caster, _skill_id, duration, _now) when duration < 1, do: caster

  defp put(%PlayerState{skill_cooldowns: cooldowns} = caster, skill_id, duration, now),
    do: %{caster | skill_cooldowns: Cooldown.put(cooldowns, skill_id, now + duration)}
end
