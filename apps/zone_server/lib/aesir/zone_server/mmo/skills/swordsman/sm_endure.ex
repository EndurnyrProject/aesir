defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmEndure do
  @moduledoc """
  Endure (SM_ENDURE). Self-buff that shrugs off incoming blows.

  Renewal: grants MDEF equal to the skill level for a duration that grows from
  10 seconds at level 1 to 37 seconds at level 10, on a 10 second cooldown. The
  buff also wears off early once the carrier has absorbed seven hits.

  Pre-renewal: identical MDEF, identical per-level durations, identical
  cooldown and the same seven hit budget. Nothing about the skill is
  era-gated.

  In the source the hit budget is only spent by non-player attackers outside
  arena and siege maps; here every hit spends one, which shortens the buff in
  player-versus-player.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 8,
    name: :sm_endure,
    requires: [],
    status: :sc_endure,
    display_name: "Endure",
    max_level: 10,
    target_type: :self,
    sp_cost: List.duplicate(10, 10),
    cooldown: List.duplicate(10_000, 10),
    duration: [
      10_000,
      13_000,
      16_000,
      19_000,
      22_000,
      25_000,
      28_000,
      31_000,
      34_000,
      37_000
    ]

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

  def cast(caster, :self, level, definition) do
    adapter = Caster.for(caster)
    caster_id = adapter.id(caster)
    duration = Enum.at(definition.duration, level - 1)
    params = [val1: level, caster_id: caster_id, duration: duration]

    case StatusInterpreter.apply_status(adapter.unit_type(caster), caster_id, :sc_endure, params) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
