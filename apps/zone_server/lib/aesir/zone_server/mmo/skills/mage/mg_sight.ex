defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgSight do
  @moduledoc """
  Sight (MG_SIGHT). Applies the sight aura to the caster: a 10-second self buff
  that keeps sweeping radius 3 around wherever the caster currently stands and
  strips concealment from anyone it finds.

  Renewal and pre-renewal are identical: single level, self cast, no damage, no
  cast time, 10 SP, radius 3, 10 seconds. The aura's pulse rate and reveal rules
  live with the status effect.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 10,
    name: :mg_sight,
    requires: [],
    display_name: "Sight",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :magic,
    element: :fire,
    range: 0,
    splash_radius: 3,
    sp_cost: [10]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @duration 10_000

  @impl Active
  def cast(caster, {:unit, caster_id}, level, definition) do
    if Caster.for(caster).id(caster) == caster_id,
      do: cast(caster, :self, level, definition),
      else: {:error, :invalid_target}
  end

  def cast(caster, :self, _level, _definition) do
    adapter = Caster.for(caster)
    caster_id = adapter.id(caster)
    params = [caster_id: caster_id, duration: @duration]

    case StatusInterpreter.apply_status(adapter.unit_type(caster), caster_id, :sc_sight, params) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
