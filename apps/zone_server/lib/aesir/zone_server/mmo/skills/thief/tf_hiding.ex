defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfHiding do
  @moduledoc """
  Hiding (TF_HIDING). Toggles SC_HIDING on the caster.

  rAthena: SP 10, self-targeted. Re-casting removes the status; a fresh
  application lasts `30000 * level` ms.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 51,
    name: :tf_hiding,
    requires: [],
    status: :sc_hiding,
    display_name: "Hiding",
    max_level: 10,
    target_type: :self,
    sp_cost: List.duplicate(10, 10)

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, caster_id}, level, definition) do
    if Caster.for(caster).id(caster) == caster_id,
      do: cast(caster, :self, level, definition),
      else: {:error, :invalid_target}
  end

  def cast(caster, :self, level, _definition) do
    adapter = Caster.for(caster)

    case StatusInterpreter.toggle_status(
           adapter.unit_type(caster),
           adapter.id(caster),
           :sc_hiding,
           duration: 30_000 * level
         ) do
      {:ok, _} -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
