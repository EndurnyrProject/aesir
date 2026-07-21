defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoCallspirits do
  @moduledoc """
  Summon Spirit Sphere (MO_CALLSPIRITS).

  The player session commits the returned sphere collection and owns its timer,
  revision, and broadcasts through `SpiritSphereHandler`.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 261,
    name: :mo_callspirits,
    display_name: "Summon Spirit Sphere",
    max_level: 5,
    target_type: :self,
    sp_cost: List.duplicate(8, 5),
    cast_time: List.duplicate(500, 5),
    fixed_cast_time: List.duplicate(500, 5)

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  @behaviour Active

  @impl Active
  def validate(caster, :self, requested_level, definition) do
    case validated_cap(caster, requested_level, definition) do
      {:ok, _cap} -> :ok
      {:error, :skill_not_learned} = error -> error
    end
  end

  @impl Active
  def cast(caster, :self, requested_level, definition) do
    spheres = Map.get(caster, :spirit_spheres, SpiritSpheres.new())
    expires_at = System.monotonic_time(:millisecond) + Formulas.spirit_sphere_duration()

    with {:ok, cap} <- validated_cap(caster, requested_level, definition) do
      {%SpiritSpheres{} = updated_spheres, %SpiritSpheres.Entry{}} =
        SpiritSpheres.summon(spheres, expires_at, cap)

      {:ok, Map.put(caster, :spirit_spheres, updated_spheres)}
    end
  end

  defp validated_cap(caster, requested_level, definition) do
    with {:ok, cap} <- sphere_cap(caster, definition),
         true <- requested_level <= cap do
      {:ok, cap}
    else
      _invalid -> {:error, :skill_not_learned}
    end
  end

  defp sphere_cap(
         %{stats: %{progression: %{learned_skills: learned}}},
         %{id: skill_id, max_level: max_level}
       )
       when is_map(learned) do
    case Learned.learned_level(learned, skill_id) do
      level when is_integer(level) and level > 0 and level <= max_level -> {:ok, level}
      _level -> {:error, :skill_not_learned}
    end
  end

  defp sphere_cap(_caster, _definition), do: {:error, :skill_not_learned}
end
