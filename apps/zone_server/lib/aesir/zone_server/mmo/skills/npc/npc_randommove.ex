defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcRandommove do
  @moduledoc """
  NPC Random Move (NPC_RANDOMMOVE).

  Requests a short walk to a random traversable cell through the mob session's
  normal movement path.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 331,
    name: :npc_randommove,
    requires: [],
    display_name: "NPC Random Move",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    range: 0

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @radius 5

  @impl Active
  def cast(%MobState{} = caster, _target, _level, _definition) do
    with {:ok, destination} <- destination(caster),
         {:ok, {_module, _state, pid}} <- UnitRegistry.get_unit(:mob, caster.instance_id) do
      {x, y} = destination
      MobSession.move_to(pid, x, y)
    end

    {:ok, caster}
  end

  defp destination(caster) do
    cells =
      for x <- (caster.x - @radius)..(caster.x + @radius),
          y <- (caster.y - @radius)..(caster.y + @radius),
          {x, y} != {caster.x, caster.y},
          do: {x, y}

    case Enum.find(Enum.shuffle(cells), fn {x, y} ->
           Cell.traversable?(caster.map_name, x, y)
         end) do
      nil -> {:error, :no_walkable_cell}
      cell -> {:ok, cell}
    end
  end
end
