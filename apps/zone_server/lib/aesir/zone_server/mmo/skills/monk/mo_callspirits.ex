defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoCallspirits do
  @moduledoc """
  Summon Spirit Sphere (MO_CALLSPIRITS).

  The player session commits the returned sphere collection and owns its timer,
  revision, and broadcasts through `SpiritSphereHandler`.

  Summons one sphere, holding at most as many as the cast level: at the cap the
  oldest sphere is replaced. A cast is refused when it begins while the caster
  already holds that many spheres.

  Renewal: a 0.5 s cast plus 0.5 s fixed. Pre-renewal: a 1 s cast. Spheres last 10
  minutes and cost 8 SP in both modes.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 261,
    name: :mo_callspirits,
    cast_cancel: false,
    display_name: "Summon Spirit Sphere",
    max_level: 5,
    target_type: :self,
    sp_cost: List.duplicate(8, 5),
    cast_time: [renewal: List.duplicate(500, 5), pre_renewal: List.duplicate(1_000, 5)],
    fixed_cast_time: [renewal: List.duplicate(500, 5), pre_renewal: []],
    damage_kind: :none

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  @behaviour Active

  @impl Active
  def begin_attempt(caster, :self, level, _definition) do
    if SpiritSpheres.count(spheres(caster)) >= level,
      do: {:error, :spheres_full},
      else: {:ok, caster}
  end

  @impl Active
  def cast(caster, :self, level, _definition) do
    expires_at = System.monotonic_time(:millisecond) + Formulas.spirit_sphere_duration()

    {%SpiritSpheres{} = updated_spheres, %SpiritSpheres.Entry{}} =
      SpiritSpheres.summon(spheres(caster), expires_at, level)

    {:ok, Map.put(caster, :spirit_spheres, updated_spheres)}
  end

  defp spheres(caster), do: Map.get(caster, :spirit_spheres, SpiritSpheres.new())
end
