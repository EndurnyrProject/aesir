defmodule Aesir.ZoneServer.Mmo.Skill.Caster.Homunculus do
  @moduledoc false

  @behaviour Aesir.ZoneServer.Mmo.Skill.Caster
  @behaviour Aesir.ZoneServer.Mmo.Skill.Caster.Lifecycle

  alias Aesir.ZoneServer.Mmo.Homunculus.Catalog, as: HomunculusCatalog
  alias Aesir.ZoneServer.Mmo.Homunculus.SkillTree, as: HomunculusSkillTree
  alias Aesir.ZoneServer.Mmo.Skill.Cooldown
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState

  @impl true
  def kind, do: :homunculus

  @impl true
  def provides, do: [:homunculus_state]

  @impl true
  def id(%HomunculusState{world_gid: world_gid}), do: world_gid

  @impl true
  def unit_type(%HomunculusState{}), do: :homunculus

  @impl true
  def position(%HomunculusState{map_name: map_name, x: x, y: y}), do: {map_name, x, y}

  @impl true
  def attack_range(%HomunculusState{attack_range: attack_range}), do: attack_range

  @impl true
  def broadcast_source(%HomunculusState{world_gid: world_gid}), do: {:homunculus, world_gid}

  @impl true
  def knows?(caster, definition, level) do
    with {:ok, entry} <- homunculus_tree_entry(caster.class_id, definition.id),
         {:ok, species} <- homunculus_species(caster.class_id),
         true <- entry.form == :any or species.form == :evolved,
         true <- Map.get(caster.learned_skills, definition.id, 0) >= level,
         true <- level <= entry.max_level do
      :ok
    else
      false -> {:error, :skill_not_learned}
      {:error, _reason} = error -> error
    end
  end

  @impl true
  def castable_state(%HomunculusState{} = caster, phase) do
    expected_action = if phase == :begin, do: :idle, else: :casting

    cond do
      not Unit.living?(caster) -> {:error, :dead}
      caster.movement_state != :standing -> {:error, :moving}
      caster.action_state != expected_action -> {:error, :busy}
      true -> :ok
    end
  end

  @impl true
  def cost(caster, module, _target, definition, level) do
    with {:ok, sp_cost} <- homunculus_sp_cost(caster, definition, level),
         :ok <- check_sp(caster, sp_cost) do
      {:ok, %{definition: definition, module: module, sp_cost: sp_cost}}
    end
  end

  @impl true
  def commit(%HomunculusState{} = caster, %{sp_cost: sp_cost}) do
    %{caster | sp: caster.sp - sp_cost}
  end

  @impl true
  def cooldown_ready?(%HomunculusState{cooldowns: cooldowns}, skill_id, now) do
    Cooldown.ready?(cooldowns, skill_id, now)
  end

  @impl true
  def put_cooldown(caster, _skill_id, 0), do: caster

  def put_cooldown(%HomunculusState{cooldowns: cooldowns} = caster, skill_id, expires_at) do
    %{caster | cooldowns: Cooldown.put(cooldowns, skill_id, expires_at)}
  end

  @impl true
  def act_ready?(%HomunculusState{action_state: :idle}, _now), do: true
  def act_ready?(%HomunculusState{}, _now), do: false

  @impl true
  def cast_stats(caster, _skill_id) do
    %{
      dex: max(caster.dex, 0),
      int: max(caster.int, 0),
      varcast_reductions: status_reductions(caster.world_gid, :cast_time_reduction),
      varcast_rate: merged_modifier(caster.world_gid, :varcast_rate),
      fixed_cast: 0
    }
  end

  defp status_reductions(world_gid, state_key) do
    :homunculus
    |> StatusStorage.get_unit_statuses(world_gid)
    |> Enum.flat_map(fn entry ->
      case Map.get(entry.state || %{}, state_key) do
        nil -> []
        value -> [value]
      end
    end)
  end

  defp merged_modifier(world_gid, key) do
    :homunculus
    |> ModifierCalculator.get_all_modifiers(world_gid)
    |> Map.get(key, 0)
  end

  defp homunculus_tree_entry(class_id, skill_id) do
    case HomunculusSkillTree.entry(class_id, skill_id) do
      {:ok, entry} -> {:ok, entry}
      :error -> {:error, :wrong_species}
    end
  end

  defp homunculus_species(class_id) do
    case HomunculusCatalog.by_id(class_id) do
      {:ok, species} -> {:ok, species}
      :error -> {:error, :wrong_species}
    end
  end

  defp homunculus_sp_cost(caster, definition, level) do
    case Enum.at(definition.sp_cost, level - 1, 0) do
      :all -> {:ok, caster.sp}
      cost when is_integer(cost) and cost >= 0 -> {:ok, cost}
      _invalid -> {:error, :invalid_cost}
    end
  end

  defp check_sp(%HomunculusState{sp: sp}, cost) when sp >= cost, do: :ok
  defp check_sp(%HomunculusState{}, _cost), do: {:error, :insufficient_sp}
end
