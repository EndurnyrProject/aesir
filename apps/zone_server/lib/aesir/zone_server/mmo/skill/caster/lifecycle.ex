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
          optional(:fixcast_rate) => integer()
        }

  @callback knows?(state(), Definition.t(), pos_integer(), phase()) ::
              :ok | {:error, atom()}
  @callback castable_state(state(), integer(), phase()) :: :ok | {:error, atom()}
  @callback castable_status(state(), integer()) :: :ok | {:error, atom()}
  @callback completion_revalidates_definition?() :: boolean()
  @callback valid_caster_result?(state()) :: boolean()
  @callback cast_origin(state()) :: :normal | :homunculus
  @callback validate_target(state(), Active.target(), Definition.t()) ::
              :continue | :ok | {:error, atom()}
  @callback cost_before_validation?() :: boolean()
  @callback cost(state(), module(), Active.target(), Definition.t(), pos_integer()) ::
              {:ok, prepared()} | {:error, atom()}
  @callback commit(state(), prepared()) :: state()
  @callback cooldown_ready?(state(), integer(), integer(), phase()) :: boolean()
  @callback put_cooldown(state(), integer(), integer()) :: state()
  @callback act_ready?(state(), integer()) :: boolean()
  @callback cast_stats(state(), integer()) :: cast_stats()
end
