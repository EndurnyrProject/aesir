defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaCastcancel do
  @moduledoc """
  Cast Cancel (SA_CASTCANCEL). Aborts the caster's own in-flight cast for 2 SP,
  paying 90% minus 20% per level above one of the cancelled skill's SP cost instead
  of its full cost. The abort runs in the caster's session; this module only
  contributes the definition and the not-casting guard.

  Renewal and pre-renewal agree.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 275,
    name: :sa_castcancel,
    display_name: "Cast Cancel",
    max_level: 5,
    target_type: :self,
    damage_kind: :magic,
    sp_cost: [2, 2, 2, 2, 2]

  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @impl Active
  def validate(%{casting: nil}, _target, _level, _definition), do: {:error, :not_casting}
  def validate(_caster, _target, _level, _definition), do: :ok

  @impl Active
  def cast(caster, :self, _level, _definition), do: {:ok, caster}
end
