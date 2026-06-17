defmodule Aesir.ZoneServer.Mmo.Skill.Active do
  @moduledoc """
  Capability behaviour for skills that are actively cast.

  A skill opts into this capability by declaring `@behaviour Skill.Active` and
  implementing `cast/4`. The single `use Skill` macro supplies the definition and
  registration; this module only declares the cast contract.

  `validate/4` is optional - the interpreter runs it only when the skill defines
  it - and lets a skill reject a cast (custom range/state checks) before SP is
  charged. Ground skills (`target_type: :ground`) get a `cast/4` auto-derived by
  `use Skill` that places the skill-unit, so they implement `Skill.Ground`
  instead of writing this callback by hand.
  """
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @typedoc "The resolved cast target handed to `cast/4`."
  @type target :: :self | {:unit, non_neg_integer()} | {:ground, integer(), integer()}

  @doc "Runs the skill's effect for a validated cast. Returns the updated caster state."
  @callback cast(PlayerState.t(), target(), pos_integer(), Definition.t()) ::
              {:ok, PlayerState.t()} | {:error, atom()}

  @doc "Optional pre-cast validation, run before SP is charged. Defaults to `:ok` when absent."
  @callback validate(PlayerState.t(), target(), pos_integer(), Definition.t()) ::
              :ok | {:error, atom()}

  @optional_callbacks validate: 4
end
