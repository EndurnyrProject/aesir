defmodule Aesir.ZoneServer.Mmo.Skill.Passive do
  @moduledoc """
  Capability behaviour for passive skills.

  A skill opts into this capability by declaring `@behaviour Skill.Passive` and
  implementing only the channels it participates in. All three callbacks are
  optional; `Skill.Passives` aggregates every learned passive and folds the
  channels each one implements (the rest are treated as no-ops).
  """

  @typedoc """
  Context passed to passive callbacks, describing the player's current state
  relevant for passive skill computations.
  """
  @type ctx :: %{
          weapon_type: atom(),
          base_level: pos_integer(),
          job_level: non_neg_integer(),
          max_hp: pos_integer(),
          max_sp: pos_integer(),
          vit: non_neg_integer(),
          int: non_neg_integer(),
          riding: boolean()
        }

  @doc "Returns a flat ATK bonus contributed by this passive at the given level."
  @callback atk_bonus(level :: pos_integer(), ctx()) :: integer()

  @doc "Returns a flat critical bonus in rAthena tenths contributed by this passive at the given level."
  @callback critical_bonus(level :: pos_integer(), ctx()) :: integer()

  @doc "Returns a flat FLEE bonus contributed by this passive at the given level."
  @callback flee_bonus(level :: pos_integer(), ctx()) :: integer()

  @doc "Returns a flat DEX bonus contributed by this passive at the given level."
  @callback dex_bonus(level :: pos_integer(), ctx()) :: integer()

  @doc "Returns a flat HIT bonus contributed by this passive at the given level."
  @callback hit_bonus(level :: pos_integer(), ctx()) :: integer()

  @doc "Returns a flat attack-range bonus contributed by this passive at the given level."
  @callback range_bonus(level :: pos_integer(), ctx()) :: integer()

  @doc "Returns a flat max-weight bonus contributed by this passive at the given level."
  @callback max_weight_bonus(level :: pos_integer(), ctx()) :: integer()

  @doc "Returns a flat ASPD bonus contributed by this passive at the given level."
  @callback aspd_bonus(level :: pos_integer(), ctx()) :: integer()

  @doc "Returns a flat INT bonus contributed by this passive at the given level."
  @callback int_bonus(level :: pos_integer(), ctx()) :: integer()

  @doc """
  Returns the procs this passive triggers on a normal attack at the given level.

  Aggregated by `Skill.Passives.attack_procs/1` and queried in the normal-attack
  path. A `:multi_hit` value of `n` delivers the basic attack as `n` hits;
  `:chance` (1-100) is the percent chance the multi-hit rolls, defaulting to 100
  (always) when absent.
  """
  @callback attack_proc(level :: pos_integer(), ctx()) :: %{
              optional(:multi_hit) => pos_integer(),
              optional(:chance) => 1..100
            }

  @typedoc "A complete normal-attack replacement selected before hit calculation."
  @type attack_replacement :: :normal | {:skill_attack, keyword(), atom()}

  @doc "Returns a replacement for the pending normal attack, or `:normal`."
  @callback attack_replacement(level :: pos_integer(), ctx()) :: attack_replacement()

  @doc "Returns a map of regen contributions from this passive at the given level."
  @callback regen_contribution(level :: pos_integer(), ctx()) ::
              %{
                optional(:skill_hp_regen) => integer(),
                optional(:skill_sp_regen) => integer(),
                optional(:sitting_hp_regen) => integer(),
                optional(:sitting_sp_regen) => integer(),
                optional(:allow_while_moving) => boolean()
              }

  @doc """
  Returns a skill rider to apply after `target_skill` is used, or `:none` if
  this passive does not modify the given skill.
  """
  @callback skill_rider(
              target_skill :: atom(),
              target_skill_level :: pos_integer(),
              passive_level :: pos_integer(),
              ctx()
            ) :: :none | {:apply_status, atom(), keyword()}

  @optional_callbacks atk_bonus: 2,
                      critical_bonus: 2,
                      flee_bonus: 2,
                      dex_bonus: 2,
                      hit_bonus: 2,
                      range_bonus: 2,
                      max_weight_bonus: 2,
                      aspd_bonus: 2,
                      int_bonus: 2,
                      attack_proc: 2,
                      attack_replacement: 2,
                      regen_contribution: 2,
                      skill_rider: 4
end
