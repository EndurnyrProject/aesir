defmodule Aesir.ZoneServer.Config do
  @moduledoc """
  Accessors for zone-server runtime configuration (`config :zone_server, ...`).

  Centralizes tunables that were previously duplicated as per-module constants so
  there is a single source of truth in `config/zone_server/main.exs`.
  """

  @default_view_range 20
  @default_max_party 12
  @default_party_share_level 15
  @default_party_even_share_bonus 0
  @default_exp_bonus_attacker 25
  @default_exp_bonus_max_attacker 12
  @default_death_penalty_base 1
  @default_death_penalty_job 1
  @default_natural_break_rate 0
  @default_boss_respawn_delay_percentage 100

  @doc """
  Player view range (rAthena `AREA_SIZE`): the cell radius a client is told about.

  Used for entity visibility, combat/skill/effect broadcasts, and the radius
  within which a client may acquire an attack or skill target.
  """
  @spec view_range() :: pos_integer()
  def view_range, do: Application.get_env(:zone_server, :view_range, @default_view_range)

  @doc """
  Maximum number of characters in a party (rAthena `MAX_PARTY`).
  """
  @spec max_party() :: pos_integer()
  def max_party, do: Application.get_env(:zone_server, :max_party, @default_max_party)

  @doc """
  Maximum online-member base-level spread allowed while even-share EXP is
  enabled (rAthena `inter_athena.conf party_share_level`).
  """
  @spec party_share_level() :: pos_integer()
  def party_share_level,
    do: Application.get_env(:zone_server, :party_share_level, @default_party_share_level)

  @doc """
  Percentage bonus applied to pooled EXP per extra party member beyond the
  first when even-share is enabled (rAthena `party.conf party_even_share_bonus`).
  """
  @spec party_even_share_bonus() :: non_neg_integer()
  def party_even_share_bonus,
    do:
      Application.get_env(:zone_server, :party_even_share_bonus, @default_party_even_share_bonus)

  @doc """
  Percentage bonus applied to a damage-based kill-EXP share per additional
  distinct attacker beyond the first (rAthena `battle.conf exp_bonus_attacker`).
  """
  @spec exp_bonus_attacker() :: non_neg_integer()
  def exp_bonus_attacker,
    do: Application.get_env(:zone_server, :exp_bonus_attacker, @default_exp_bonus_attacker)

  @doc """
  Maximum number of attackers counted toward `exp_bonus_attacker/0`'s bonus
  (rAthena `battle.conf exp_bonus_max_attacker`).
  """
  @spec exp_bonus_max_attacker() :: pos_integer()
  def exp_bonus_max_attacker,
    do:
      Application.get_env(
        :zone_server,
        :exp_bonus_max_attacker,
        @default_exp_bonus_max_attacker
      )

  @doc """
  Death EXP penalty applied to the base track, as a percentage of the exp needed
  to reach the next base level (rAthena `exp.conf death_penalty_base`, renewal
  default 1%). Set to 0 to disable the base-track penalty.
  """
  @spec death_penalty_base() :: non_neg_integer()
  def death_penalty_base,
    do: Application.get_env(:zone_server, :death_penalty_base, @default_death_penalty_base)

  @doc """
  Death EXP penalty applied to the job track, as a percentage of the exp needed
  to reach the next job level (rAthena `exp.conf death_penalty_job`, renewal
  default 1%). Set to 0 to disable the job-track penalty.
  """
  @spec death_penalty_job() :: non_neg_integer()
  def death_penalty_job,
    do: Application.get_env(:zone_server, :death_penalty_job, @default_death_penalty_job)

  @doc """
  Natural equipment-break rate rolled on a confirmed hit, in 1/10000 units
  (rAthena `battle.conf equip_natural_break_rate`; 100 = 1%). Default 0 disables
  natural breaking entirely. Collapses rAthena's `equip_self_break_rate` /
  `equip_skill_break_rate` multipliers into a single knob.
  """
  @spec natural_break_rate() :: non_neg_integer()
  def natural_break_rate,
    do: Application.get_env(:zone_server, :natural_break_rate, @default_natural_break_rate)

  @doc """
  Percentage applied to a boss's randomized respawn delay
  (`respawn_time + rand(respawn_variance)`) before the 1000 ms floor. Default
  100 leaves the imported delay unchanged; a value below 100 shortens boss
  respawns, above 100 lengthens them. Not applied to non-boss mobs.
  """
  @spec boss_respawn_delay_percentage() :: pos_integer()
  def boss_respawn_delay_percentage,
    do:
      Application.get_env(
        :zone_server,
        :boss_respawn_delay_percentage,
        @default_boss_respawn_delay_percentage
      )
end
