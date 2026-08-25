defmodule Aesir.ZoneServer.Mmo.Skill.Caster.Player do
  @moduledoc false

  @behaviour Aesir.ZoneServer.Mmo.Skill.Caster
  @behaviour Aesir.ZoneServer.Mmo.Skill.Caster.Lifecycle

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Map.MapFlags
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

  # Guild skills (GD_*) are learned by the guild, not the character: rank and
  # cooldowns resolve against the guild entry, never against the caster's
  # progression or per-character cooldown map.
  @guild_skill_range 10_000..10_019

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
  def sp(%PlayerState{stats: %{current_state: %{sp: sp}}}), do: sp

  @impl true
  def deduct_sp(%PlayerState{stats: stats} = caster, amount) do
    current_state = %{stats.current_state | sp: stats.current_state.sp - amount}
    %{caster | stats: %{stats | current_state: current_state}}
  end

  # A skill granted by worn equipment is authoritative while equipped: it is
  # castable at its granted level without a learned entry or quest lineage.
  @impl true
  def knows?(caster, %{id: skill_id} = _definition, level, _phase)
      when skill_id in @guild_skill_range do
    guild_knows?(caster, skill_id, level)
  end

  def knows?(caster, definition, level, :begin) do
    cond do
      granted_level(caster, definition.id) >= level ->
        :ok

      learned_level(caster, definition.id) >= level and quest_lineage?(caster, definition) ->
        :ok

      true ->
        {:error, :skill_not_learned}
    end
  end

  def knows?(caster, definition, _level, :completion) do
    if granted_level(caster, definition.id) >= 1 or quest_lineage?(caster, definition),
      do: :ok,
      else: {:error, :skill_not_learned}
  end

  defp learned_level(caster, skill_id),
    do: Learned.learned_level(caster.stats.progression.learned_skills, skill_id)

  defp guild_knows?(%PlayerState{guild_id: guild_id}, _skill_id, _level)
       when guild_id in [nil, 0],
       do: {:error, :skill_not_learned}

  defp guild_knows?(%PlayerState{} = caster, skill_id, level) do
    with {:ok, guild} <- fetch_guild(caster.guild_id),
         :ok <- check_guild_master(guild, caster.character_id),
         :ok <- check_gvg_gate(caster) do
      if GuildState.skill_level(guild, skill_id) >= level,
        do: :ok,
        else: {:error, :skill_not_learned}
    end
  end

  defp fetch_guild(guild_id) do
    case GuildManager.get(guild_id) do
      {:ok, guild} -> {:ok, guild}
      {:error, :not_found} -> {:error, :skill_not_learned}
    end
  end

  defp check_guild_master(%GuildState{master_char_id: char_id}, char_id), do: :ok
  defp check_guild_master(%GuildState{}, _char_id), do: {:error, :not_guild_master}

  # Guild actives are restricted to GvG ground only when the config flag is on;
  # the shipped default is relaxed (castable anywhere) until the flip.
  defp check_gvg_gate(%PlayerState{map_name: map_name}) do
    if Config.guild_skills_gvg_only() and not MapFlags.get(map_name, :gvg),
      do: {:error, :not_gvg_ground},
      else: :ok
  end

  # Reads the equipment-granted level, tolerating the bare-map `stats` shape used
  # by handler fixtures (which lack the field) as no grant.
  defp granted_level(caster, skill_id) do
    caster.stats
    |> Map.get(:granted_skills)
    |> Kernel.||(%{})
    |> Map.get(skill_id, 0)
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
  def cooldown_ready?(%PlayerState{guild_id: guild_id}, skill_id, now, :begin)
      when skill_id in @guild_skill_range do
    case GuildManager.get(guild_id || 0) do
      {:ok, %GuildState{skill_cooldowns: cooldowns}} ->
        case Map.get(cooldowns, skill_id) do
          expiry when is_integer(expiry) -> expiry <= now
          nil -> true
        end

      {:error, :not_found} ->
        true
    end
  end

  def cooldown_ready?(%PlayerState{skill_cooldowns: cooldowns}, skill_id, now, :begin) do
    Cooldown.ready?(cooldowns, skill_id, now)
  end

  def cooldown_ready?(%PlayerState{}, _skill_id, _now, :completion), do: true

  @impl true
  def put_cooldown(caster, _skill_id, 0), do: caster

  def put_cooldown(%PlayerState{guild_id: guild_id} = caster, skill_id, expires_at)
      when skill_id in @guild_skill_range do
    duration = max(expires_at - System.monotonic_time(:millisecond), 0)

    # The arm result is deliberately ignored: only one master exists per guild
    # and a session serializes its own casts, so a concurrent losing arm has no
    # real interleaving - and effects have already run by cooldown-write time.
    _result = GuildManager.check_and_arm_skill_cooldown(guild_id || 0, skill_id, duration)
    caster
  end

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

    {varcast_reductions, classic_status_early_rate, classic_late_reductions} =
      cast_status_channels(caster.character_id)

    global_varcast_rate =
      merged_modifier(caster.character_id, :varcast_rate) +
        equip_modifier(caster, :varcast_rate)

    classic_early_rate = global_varcast_rate + classic_status_early_rate
    classic_skill_rate = equip_modifier(caster, {:skill_varcast_rate, skill_id})
    varcast_rate = global_varcast_rate + classic_skill_rate

    %{
      dex: base_stats.dex,
      int: base_stats.int,
      varcast_reductions: varcast_reductions,
      varcast_rate: varcast_rate,
      fixed_cast: equip_modifier(caster, :fixed_cast),
      fixcast_rate:
        equip_modifier(caster, :fixcast_rate) +
          equip_modifier(caster, {:skill_fixcast_rate, skill_id}),
      classic_early_rate: classic_early_rate,
      classic_skill_rate: classic_skill_rate,
      classic_late_reductions: classic_late_reductions
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

  defp cast_status_channels(character_id) do
    {renewal, classic_early_rate, classic_late} =
      :player
      |> StatusStorage.get_unit_statuses(character_id)
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
