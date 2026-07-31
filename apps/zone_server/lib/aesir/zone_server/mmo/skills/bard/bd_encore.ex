defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BdEncore do
  @moduledoc "Encore (BD_ENCORE)."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 305,
    name: :bd_encore,
    display_name: "Encore",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    range: 0,
    sp_cost: [1],
    cast_time: [0],
    fixed_cast_time: [0],
    after_cast_delay: [300],
    cooldown: [10_000],
    require_weapon: [:musical, :whip]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Cost, as: PerformanceCost

  @behaviour Active

  @impl Active
  def validate(caster, :self, _level, _definition) do
    with {:ok, memory} <- replay_memory(caster) do
      Interpreter.encore_replay_preflight(caster, memory, :self)
    end
  end

  @impl Active
  def dynamic_cast_time(caster, :self, _level, _definition) do
    {:ok, memory} = replay_memory(caster)
    {:ok, timing} = Interpreter.encore_replay_timing(caster, memory, :self)
    timing
  end

  @impl Active
  def dynamic_cost(caster, :self, _level, _definition) do
    {:ok, %{skill_id: skill_id, level: level}} = replay_memory(caster)
    {:ok, remembered_definition} = Catalog.by_id(skill_id)
    raw_base = remembered_definition.sp_cost |> Enum.fetch!(level - 1) |> div(2)

    cost =
      if Catalog.performance?(skill_id) do
        PerformanceCost.resolve(caster, remembered_definition, level, raw_base)
      else
        sp = Cost.resolve_sp(caster, remembered_definition, level, raw_base)
        Cost.from_definition(caster, remembered_definition, level, sp: sp)
      end

    %Cost{sp_requirement: requirement, sp: sp} = cost
    %{cost | sp_requirement: max(1, max(requirement, sp))}
  end

  @impl Active
  def cast(caster, :self, _level, _definition) do
    with {:ok, memory} <- replay_memory(caster) do
      Interpreter.complete_encore_replay(caster, memory, :self)
    end
  end

  defp replay_memory(%{last_song: nil}), do: {:error, :no_song_to_replay}
  defp replay_memory(%{last_song: memory}) when is_map(memory), do: {:ok, memory}
end
