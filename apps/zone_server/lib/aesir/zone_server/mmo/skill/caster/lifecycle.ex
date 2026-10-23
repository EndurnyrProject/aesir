defmodule Aesir.ZoneServer.Mmo.Skill.Caster.Lifecycle do
  @moduledoc """
  Cast lifecycle interface implemented by owned-unit caster adapters.

  Cooldown values passed to `put_cooldown/3` are absolute monotonic-millisecond
  expiry timestamps; `0` means no cooldown.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  @type state :: any()
  @type phase :: :begin | :completion
  @type prepared :: map()
  @type cast_stats :: %{
          :dex => integer(),
          :int => integer(),
          :varcast_reductions => [non_neg_integer()],
          :varcast_rate => integer(),
          :fixed_cast => integer(),
          :classic_early_rate => integer(),
          :classic_skill_rate => integer(),
          :classic_late_reductions => [non_neg_integer()],
          optional(:fixcast_rate) => integer()
        }

  @callback knows?(state(), Definition.t(), pos_integer(), phase()) ::
              :ok | {:error, atom()}
  @callback castable_state(state(), integer(), phase()) :: :ok | {:error, term()}
  @callback castable_status(state(), integer()) :: :ok | {:error, atom()}
  @callback completion_revalidates_definition?() :: boolean()
  @callback valid_caster_result?(state()) :: boolean()
  @callback cast_origin(state()) :: :normal | :homunculus
  @callback validate_target(state(), Active.target(), Definition.t()) ::
              :continue | :ok | {:error, atom()}
  @callback cost_before_validation?() :: boolean()
  @callback cost(state(), module(), Active.target(), Definition.t(), pos_integer()) ::
              {:ok, prepared()} | {:error, atom()}
  @doc """
  Optional cast-end requirement check: prepares the cost a cast spends when it
  ends, checking only the requirements due there. An adapter without it
  prepares the cast end with `cost/5`.
  """
  @callback castend_cost(state(), module(), Active.target(), Definition.t(), pos_integer()) ::
              {:ok, prepared()} | {:error, atom()}
  @doc """
  Pays a prepared cost's primary requirements (HP, SP, spirit spheres, zeny),
  which a cast spends before its effect runs. Returns the paid caster and the
  prepared cost left to settle after the effect, with the primary part zeroed
  so it cannot be paid twice.
  """
  @callback commit_primary(state(), prepared()) :: {state(), prepared()}
  @doc "Settles what is left of a prepared cost once the effect has run."
  @callback commit(state(), prepared()) :: state()
  @callback cooldown_ready?(state(), integer(), integer(), phase()) :: boolean()
  @callback put_cooldown(state(), integer(), integer()) :: state()
  @callback act_ready?(state(), integer()) :: boolean()
  @callback cast_stats(state(), integer()) :: cast_stats()

  @optional_callbacks castend_cost: 5
end
