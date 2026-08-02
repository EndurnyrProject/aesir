defmodule Aesir.ZoneServer.Config do
  @moduledoc """
  Accessors for zone-server runtime configuration (`config :zone_server, ...`).

  Centralizes tunables that were previously duplicated as per-module constants so
  there is a single source of truth in `config/zone_server/main.exs`.
  """

  @default_view_range 20
  @default_frost_joker_area_size 14
  @default_max_party 12
  @default_party_share_level 15
  @default_party_even_share_bonus 0
  @default_exp_bonus_attacker 25
  @default_exp_bonus_max_attacker 12
  @default_item_first_get_time 3000
  @default_item_second_get_time 2000
  @default_item_third_get_time 2000
  @default_mvp_item_first_get_time 10_000
  @default_mvp_item_second_get_time 10_000
  @default_mvp_item_third_get_time 2000
  @default_first_attack_loot_bonus 30
  @default_death_penalty_base 1
  @default_death_penalty_job 1
  @default_natural_break_rate 0
  @default_boss_respawn_delay_percentage 100
  @default_boss_respawn_reconcile_on_boot true

  @doc """
  Player view range (rAthena `AREA_SIZE`): the cell radius a client is told about.

  Used for entity visibility, combat/skill/effect broadcasts, and the radius
  within which a client may acquire an attack or skill target.
  """
  @spec view_range() :: pos_integer()
  def view_range, do: Application.get_env(:zone_server, :view_range, @default_view_range)

  @doc "The half-width of Frost Joker's global square around its captured cast origin."
  @spec frost_joker_area_size() :: pos_integer()
  def frost_joker_area_size,
    do:
      Application.get_env(
        :zone_server,
        :frost_joker_area_size,
        @default_frost_joker_area_size
      )

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

  @doc "First loot-owner exclusive pickup window for dropped items, in milliseconds."
  @spec item_first_get_time() :: pos_integer()
  def item_first_get_time,
    do: Application.get_env(:zone_server, :item_first_get_time, @default_item_first_get_time)

  @doc "Additional pickup window for the second loot owner, in milliseconds."
  @spec item_second_get_time() :: pos_integer()
  def item_second_get_time,
    do: Application.get_env(:zone_server, :item_second_get_time, @default_item_second_get_time)

  @doc "Additional pickup window for the third loot owner, in milliseconds."
  @spec item_third_get_time() :: pos_integer()
  def item_third_get_time,
    do: Application.get_env(:zone_server, :item_third_get_time, @default_item_third_get_time)

  @doc "First loot-owner exclusive pickup window for MVP drops, in milliseconds."
  @spec mvp_item_first_get_time() :: pos_integer()
  def mvp_item_first_get_time,
    do:
      Application.get_env(
        :zone_server,
        :mvp_item_first_get_time,
        @default_mvp_item_first_get_time
      )

  @doc "Additional pickup window for the second MVP loot owner, in milliseconds."
  @spec mvp_item_second_get_time() :: pos_integer()
  def mvp_item_second_get_time,
    do:
      Application.get_env(
        :zone_server,
        :mvp_item_second_get_time,
        @default_mvp_item_second_get_time
      )

  @doc "Additional pickup window for the third MVP loot owner, in milliseconds."
  @spec mvp_item_third_get_time() :: pos_integer()
  def mvp_item_third_get_time,
    do:
      Application.get_env(
        :zone_server,
        :mvp_item_third_get_time,
        @default_mvp_item_third_get_time
      )

  @doc "Bonus percentage of total damage credited to a mob's first loot attacker."
  @spec first_attack_loot_bonus() :: non_neg_integer()
  def first_attack_loot_bonus,
    do:
      Application.get_env(
        :zone_server,
        :first_attack_loot_bonus,
        @default_first_attack_loot_bonus
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

  @doc """
  Whether persisted boss respawn deadlines are reconciled during boot.

  Disabled under test, where the OTP application starts before ExUnit installs
  the Ecto sandbox: a boot-time query would run unsandboxed against the real
  test database and its orphan cleanup would delete rows permanently.
  """
  @spec boss_respawn_reconcile_on_boot?() :: boolean()
  def boss_respawn_reconcile_on_boot?,
    do:
      Application.get_env(
        :zone_server,
        :boss_respawn_reconcile_on_boot,
        @default_boss_respawn_reconcile_on_boot
      )
end
