defmodule Aesir.ZoneServer.Mmo.Skill.Caster.Homunculus do
  @moduledoc false

  @behaviour Aesir.ZoneServer.Mmo.Skill.Caster
  @behaviour Aesir.ZoneServer.Mmo.Skill.Caster.Lifecycle

  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Homunculus.Catalog, as: HomunculusCatalog
  alias Aesir.ZoneServer.Mmo.Homunculus.SkillTree, as: HomunculusSkillTree
  alias Aesir.ZoneServer.Mmo.Skill.Cooldown
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
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
  def sp(%HomunculusState{sp: sp}), do: sp

  @impl true
  def deduct_sp(%HomunculusState{} = caster, amount), do: %{caster | sp: caster.sp - amount}

  @impl true
  def knows?(caster, definition, level, _phase) do
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
  def castable_state(%HomunculusState{} = caster, _skill_id, phase) do
    expected_action = if phase == :begin, do: :idle, else: :casting

    cond do
      not Unit.living?(caster) ->
        {:error, :dead}

      caster.movement_state != :standing ->
        {:error, :moving}

      caster.action_state != expected_action ->
        {:error, :busy}

      true ->
        :ok
    end
  end

  @impl true
  def castable_status(%HomunculusState{} = caster, skill_id) do
    if StatusInterpreter.can_use_skill?(:homunculus, caster.world_gid, skill_id),
      do: :ok,
      else: {:error, :status_blocked}
  end

  @impl true
  def completion_revalidates_definition?, do: true

  @impl true
  def valid_caster_result?(%HomunculusState{}), do: true
  def valid_caster_result?(_caster), do: false

  @impl true
  def cast_origin(%HomunculusState{}), do: :homunculus

  @impl true
  def validate_target(caster, :self, %{target_type: target_type})
      when target_type in [:self, :target_ally, :target_any],
      do: if(Unit.living?(caster), do: :ok, else: {:error, :dead})

  def validate_target(caster, {:unit, {:homunculus, gid}}, definition)
      when gid == caster.world_gid,
      do: validate_target(caster, :self, definition)

  def validate_target(caster, {:unit, target_ref}, definition) when is_tuple(target_ref) do
    with {:ok, _pid, target, target_type} <- TargetResolver.resolve(target_ref),
         :ok <- TargetResolver.ensure_targetable(target, target_type) do
      validate_relationship(caster, target, definition.target_type)
    else
      {:error, :not_found} -> {:error, :target_not_found}
      {:error, _reason} = error -> error
    end
  end

  def validate_target(_caster, {:ground, _x, _y}, %{target_type: :ground}), do: :ok
  def validate_target(_caster, _target, _definition), do: {:error, :invalid_target}

  @impl true
  def cost_before_validation?, do: true

  @impl true
  def cost(caster, module, _target, definition, level) do
    with {:ok, sp_cost} <- homunculus_sp_cost(caster, definition, level),
         :ok <- check_sp(caster, sp_cost) do
      {:ok,
       %{
         definition: definition,
         module: module,
         sp_cost: sp_cost,
         deferred_error: :unsupported_homunculus_deferred,
         instant_effects: []
       }}
    end
  end

  @impl true
  def commit(%HomunculusState{} = caster, %{sp_cost: sp_cost}) do
    %{caster | sp: caster.sp - sp_cost}
  end

  @impl true
  def cooldown_ready?(%HomunculusState{cooldowns: cooldowns}, skill_id, now, _phase) do
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
    {varcast_reductions, classic_status_early_rate, classic_late_reductions} =
      cast_status_channels(caster.world_gid)

    varcast_rate = merged_modifier(caster.world_gid, :varcast_rate)

    %{
      dex: max(caster.dex, 0),
      int: max(caster.int, 0),
      varcast_reductions: varcast_reductions,
      varcast_rate: varcast_rate,
      fixed_cast: 0,
      classic_early_rate: varcast_rate + classic_status_early_rate,
      classic_skill_rate: 0,
      classic_late_reductions: classic_late_reductions
    }
  end

  defp validate_relationship(caster, target, :target_enemy),
    do: Targeting.validate_enemy(caster, target)

  defp validate_relationship(caster, target, :target_ally) do
    if Targeting.exact_ally?(caster, target), do: :ok, else: {:error, :invalid_target}
  end

  defp validate_relationship(_caster, _target, :target_any), do: :ok
  defp validate_relationship(_caster, _target, _target_type), do: {:error, :invalid_target}

  defp cast_status_channels(world_gid) do
    {renewal, classic_early_rate, classic_late} =
      :homunculus
      |> StatusStorage.get_unit_statuses(world_gid)
      |> Enum.reduce({[], 0, []}, fn entry, {renewal, early_rate, late} ->
        case {entry.type, Map.get(entry.state || %{}, :cast_time_reduction)} do
          {_type, nil} ->
            {renewal, early_rate, late}

          {:sc_poembragi, reduction} ->
            {[reduction | renewal], early_rate - reduction, late}

          {:sc_suffragium, reduction} ->
            {[reduction | renewal], early_rate, [reduction | late]}

          {_type, reduction} ->
            {[reduction | renewal], early_rate, [reduction | late]}
        end
      end)

    {Enum.reverse(renewal), classic_early_rate, Enum.reverse(classic_late)}
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
