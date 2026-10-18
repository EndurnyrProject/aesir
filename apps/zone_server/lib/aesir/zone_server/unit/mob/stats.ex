defmodule Aesir.ZoneServer.Unit.Mob.Stats do
  @moduledoc """
  Pure construction and selective calculation of a monster's status snapshot.

  The raw base belongs to the current form and its captured spawn adjustments.
  First calculation copies that seed without consulting held status entries.
  """

  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Unit.Mob.Calculated
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @doc "Returns the prepared raw base, or constructs the form's database seed."
  @spec base(MobState.t()) :: Calculated.t()
  def base(%{base: %Calculated{} = base}), do: base
  def base(state), do: Mechanics.mob_formulas().base(state)

  @doc "Builds a form base from transient spawn inputs without retaining a bonus channel."
  @spec prepare_base(MobState.t(), keyword()) :: Calculated.t()
  def prepare_base(state, opts), do: Mechanics.mob_formulas().base(state, opts)
end
