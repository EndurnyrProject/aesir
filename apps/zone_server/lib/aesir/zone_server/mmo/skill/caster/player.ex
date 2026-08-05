defmodule Aesir.ZoneServer.Mmo.Skill.Caster.Player do
  @moduledoc false

  @behaviour Aesir.ZoneServer.Mmo.Skill.Caster
  @behaviour Aesir.ZoneServer.Mmo.Skill.Caster.Lifecycle

  alias Aesir.ZoneServer.Mmo.Skill.Cooldown
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.Skill.Requirement
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Ammo
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @waivable_gemstone_ids [715, 716, 717]

  @impl true
  def kind, do: :player

  @impl true
  def provides, do: Requirement.all()

  @impl true
  def id(%PlayerState{character_id: character_id}), do: character_id

  @impl true
  def unit_type(%PlayerState{}), do: :player

  @impl true
  def position(%PlayerState{map_name: map_name, x: x, y: y}), do: {map_name, x, y}

  @impl true
  def attack_range(%PlayerState{stats: %{equipment: equipment}}) do
    equipment
    |> PlayerStats.weapon_type()
    |> WeaponTypes.get_attack_range()
  end

  @impl true
  def broadcast_source(%PlayerState{character_id: character_id}), do: character_id

  @impl true
  def knows?(caster, definition, level, :begin) do
    learned = caster.stats.progression.learned_skills

    with true <- Learned.learned_level(learned, definition.id) >= level,
         true <- quest_lineage?(caster, definition) do
      :ok
    else
      false -> {:error, :skill_not_learned}
    end
  end

  def knows?(caster, definition, _level, :completion) do
    if quest_lineage?(caster, definition), do: :ok, else: {:error, :skill_not_learned}
  end

  @impl true
  def castable_state(%PlayerState{}, _skill_id, phase) when phase in [:begin, :completion],
    do: :ok

  @impl true
  def castable_status(%PlayerState{}, _skill_id), do: :ok

  @impl true
  def completion_revalidates_definition?, do: false

  @impl true
  def valid_caster_result?(_caster), do: true

  @impl true
  def cast_origin(%PlayerState{}), do: :normal

  @impl true
  def validate_target(%PlayerState{}, _target, _definition), do: :continue

  @impl true
  def cost_before_validation?, do: false

  @impl true
  def cost(caster, module, target, definition, level) do
    with {:ok, cost} <- resolve_cost(caster, module, target, level, definition) do
      zeny = effective_zeny_cost(caster, Enum.at(definition.zeny_cost, level - 1, 0))
      prepare_cost(caster, module, definition, cost, zeny)
    end
  end

  @doc false
  @spec prepare_cost(PlayerState.t(), module(), map(), Cost.t(), non_neg_integer()) ::
          {:ok, map()} | {:error, atom()}
  def prepare_cost(caster, module, definition, cost, zeny) do
    with {:ok, commitment} <- Cost.prepare(caster, cost),
         :ok <- check_zeny(caster, zeny),
         :ok <- check_catalysts(caster, definition),
         :ok <- check_ammo(caster, definition) do
      {:ok,
       %{
         definition: definition,
         module: module,
         cost: cost,
         commitment: commitment,
         zeny: zeny,
         consume_catalysts?: true
       }}
    end
  end

  @impl true
  def commit(caster, %{
        commitment: commitment,
        zeny: zeny,
        definition: definition,
        consume_catalysts?: consume_catalysts?
      }) do
    caster
    |> Cost.apply_commitment(commitment)
    |> deduct_zeny(zeny)
    |> maybe_consume_catalysts(definition, consume_catalysts?)
    |> consume_ammo(definition)
  end

  @impl true
  def cooldown_ready?(%PlayerState{skill_cooldowns: cooldowns}, skill_id, now, :begin) do
    Cooldown.ready?(cooldowns, skill_id, now)
  end

  def cooldown_ready?(%PlayerState{}, _skill_id, _now, :completion), do: true

  @impl true
  def put_cooldown(caster, _skill_id, 0), do: caster

  def put_cooldown(%PlayerState{skill_cooldowns: cooldowns} = caster, skill_id, expires_at) do
    %{caster | skill_cooldowns: Cooldown.put(cooldowns, skill_id, expires_at)}
  end

  @impl true
  def act_ready?(caster, now) do
    PlayerState.act_ready?(caster, now)
  end

  @impl true
  def cast_stats(caster, skill_id) do
    base_stats = caster.stats.base_stats

    %{
      dex: base_stats.dex,
      int: base_stats.int,
      varcast_reductions: status_reductions(caster.character_id, :cast_time_reduction),
      varcast_rate:
        merged_modifier(caster.character_id, :varcast_rate) +
          equip_modifier(caster, :varcast_rate) +
          equip_modifier(caster, {:skill_varcast_rate, skill_id}),
      fixed_cast: equip_modifier(caster, :fixed_cast)
    }
  end

  defp quest_lineage?(caster, %{quest_skill: true} = definition) do
    SkillTree.quest_skill_available?(caster.stats.progression.job_id, definition)
  end

  defp quest_lineage?(_caster, _definition), do: true

  defp resolve_cost(caster, module, target, level, definition) do
    cost =
      if function_exported?(module, :dynamic_cost, 4) do
        module.dynamic_cost(caster, target, level, definition)
      else
        Cost.from_definition(caster, definition, level,
          sp: Cost.resolve_sp(caster, definition, level)
        )
      end

    Cost.validate_resolved(cost)
  end

  defp effective_zeny_cost(_caster, 0), do: 0

  defp effective_zeny_cost(caster, cost) do
    reduction = caster |> Passives.zeny_cost_reduction() |> min(100) |> max(0)
    div(cost * (100 - reduction), 100)
  end

  defp check_zeny(_caster, 0), do: :ok

  defp check_zeny(caster, cost) do
    if caster.zeny >= cost, do: :ok, else: {:error, :insufficient_zeny}
  end

  defp check_catalysts(caster, definition) do
    if Enum.all?(effective_item_cost(caster, definition), fn %{id: id, amount: amount} ->
         Inventory.held_amount(caster.inventory, id) >= amount
       end) do
      :ok
    else
      {:error, :missing_catalyst}
    end
  end

  @doc "Returns the item requirements owed by a player for a skill."
  @spec effective_item_cost(PlayerState.t(), map()) :: [map()]
  def effective_item_cost(_caster, %{item_cost: []}), do: []

  def effective_item_cost(caster, definition) do
    if StatusStorage.has_status?(:player, caster.character_id, :sc_intoabyss) do
      Enum.reject(definition.item_cost, &(&1.id in @waivable_gemstone_ids))
    else
      definition.item_cost
    end
  end

  defp check_ammo(caster, definition) do
    if definition.requires_ammo and Ammo.equipped_ammo_index(caster.inventory) == nil do
      {:error, :no_ammo}
    else
      :ok
    end
  end

  defp deduct_zeny(caster, 0), do: caster
  defp deduct_zeny(caster, cost), do: %{caster | zeny: caster.zeny - cost}

  defp maybe_consume_catalysts(caster, _definition, false), do: caster

  defp maybe_consume_catalysts(caster, definition, true) do
    Enum.reduce(effective_item_cost(caster, definition), caster, fn
      %{id: id, amount: amount}, state -> remove_item(state, id, amount)
    end)
  end

  defp consume_ammo(caster, %{requires_ammo: false}), do: caster

  defp consume_ammo(caster, %{requires_ammo: true}) do
    case Ammo.consume_one(caster.inventory) do
      {:ok, inventory, change} -> record_inventory_change(caster, inventory, change)
      {:error, _reason} -> caster
    end
  end

  defp remove_item(caster, _id, 0), do: caster

  defp remove_item(caster, id, amount) do
    case Inventory.stackable_index(caster.inventory, id) do
      nil ->
        caster

      index ->
        take = min(amount, caster.inventory[index].amount)
        {:ok, inventory, change} = Inventory.remove(caster.inventory, index, take)

        caster
        |> record_inventory_change(inventory, change)
        |> remove_item(id, amount - take)
    end
  end

  defp record_inventory_change(caster, inventory, change) do
    %{
      caster
      | inventory: inventory,
        pending_inventory_persist:
          caster.pending_inventory_persist ++ [{caster.inventory, inventory, change}]
    }
  end

  defp status_reductions(character_id, state_key) do
    :player
    |> StatusStorage.get_unit_statuses(character_id)
    |> Enum.flat_map(fn entry ->
      case Map.get(entry.state || %{}, state_key) do
        nil -> []
        value -> [value]
      end
    end)
  end

  defp merged_modifier(character_id, key) do
    :player
    |> ModifierCalculator.get_all_modifiers(character_id)
    |> Map.get(key, 0)
  end

  defp equip_modifier(caster, key) do
    caster.stats
    |> Map.get(:modifiers, %{})
    |> Map.get(:equipment, %{})
    |> Map.get(key, 0)
  end
end
