defmodule Aesir.ZoneServer.Mmo.Skill.Caster.Player do
  @moduledoc false

  @behaviour Aesir.ZoneServer.Mmo.Skill.Caster
  @behaviour Aesir.ZoneServer.Mmo.Skill.Caster.Lifecycle

  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Mmo.Skill.Cooldown
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.Skill.Requirement
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Ammo
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator

  @waivable_gemstone_ids [715, 716, 717]
  @gem_floor_skills [:hw_ganbantein, :sa_abracadabra]
  @holy_light 156
  @identify 40
  @ki_translation 1_015

  # Guild skills (GD_*) are learned by the guild, not the character: their rank
  # resolves against the guild entry, never against the caster's progression.
  @guild_skill_range 10_000..10_019
  @emergency_calls [10_013, 10_015]

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

  # A guild skill is known by the guild's master at the guild's learned level;
  # anyone else's request is dropped silently. Nothing is checked again when
  # the cast ends.
  #
  # A skill granted by worn equipment is authoritative while equipped: it is
  # castable at its granted level without a learned entry or quest lineage.
  @impl true
  def knows?(caster, %{id: skill_id} = _definition, level, :begin)
      when skill_id in @guild_skill_range do
    guild_knows?(caster, skill_id, level)
  end

  def knows?(_caster, %{id: skill_id} = _definition, _level, :completion)
      when skill_id in @guild_skill_range,
      do: :ok

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

  defp learned_level(caster, skill_id) do
    learned = caster.stats.progression && caster.stats.progression.learned_skills
    Learned.learned_level(learned || %{}, skill_id)
  end

  defp guild_knows?(%PlayerState{guild_id: guild_id}, _skill_id, _level)
       when guild_id in [nil, 0],
       do: {:error, :guild_skill_unavailable}

  defp guild_knows?(%PlayerState{guild_id: guild_id, character_id: char_id}, skill_id, level) do
    case GuildManager.get(guild_id) do
      {:ok, %GuildState{master_char_id: ^char_id} = guild} ->
        if GuildState.skill_level(guild, skill_id) >= level,
          do: :ok,
          else: {:error, :guild_skill_unavailable}

      _not_master_or_missing ->
        {:error, :guild_skill_unavailable}
    end
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
  def castable_state(%PlayerState{map_name: map_name}, skill_id, phase)
      when phase in [:begin, :completion] do
    cond do
      not Rules.skill_allowed?(skill_id, map_name) -> {:error, :skill_not_allowed}
      phase == :begin and emergency_call_refused?(skill_id, map_name) -> {:error, :not_gvg_ground}
      true -> :ok
    end
  end

  # Urgent Call works in and out of War of Emperium, on GvG ground only.
  defp emergency_call_refused?(skill_id, map_name),
    do: skill_id in @emergency_calls and not Rules.ground?(map_name)

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
    with {:ok, definition, cost, zeny} <-
           resolve_requirement(caster, module, target, definition, level) do
      prepare_begin_cost(caster, module, definition, cost, zeny)
    end
  end

  @impl true
  def castend_cost(caster, module, target, %{name: :al_warp} = definition, level) do
    with {:ok, definition, cost, zeny} <-
           resolve_requirement(caster, module, target, definition, level) do
      {:ok, prepared(caster, module, definition, cost, min(zeny, caster.zeny))}
    end
  end

  def castend_cost(caster, module, target, definition, level) do
    with {:ok, definition, cost, zeny} <-
           resolve_requirement(caster, module, target, definition, level) do
      prepare_castend_cost(caster, module, target, level, definition, cost, zeny)
    end
  end

  defp resolve_requirement(caster, module, target, definition, level) do
    definition = item_cost_definition(caster, module, target, level, definition)

    with {:ok, cost} <- resolve_cost(caster, module, target, level, definition) do
      zeny = effective_zeny_cost(caster, Enum.at(definition.zeny_cost, level - 1, 0))
      {:ok, definition, cost, zeny}
    end
  end

  @doc """
  Checks a resolved cost's cast-begin requirements in order: SP, zeny, then
  spirit spheres. HP, ammo and items wait for the cast end.
  """
  @spec prepare_begin_cost(PlayerState.t(), module(), map(), Cost.t(), non_neg_integer()) ::
          {:ok, map()} | {:error, atom()}
  def prepare_begin_cost(caster, module, definition, cost, zeny) do
    with :ok <- check_weight(caster),
         :ok <- Cost.check_sp(caster, cost),
         :ok <- check_zeny(caster, zeny),
         :ok <- Cost.check_spheres(caster, cost) do
      {:ok, prepared(caster, module, definition, cost, zeny)}
    end
  end

  @doc """
  Checks a resolved cost's cast-end requirements in order: the skill's own
  cast-end requirement, HP, weapon, ammo, then items. SP, zeny and spheres are
  not checked again; the commitment spends each up to what the caster holds.
  """
  @spec prepare_castend_cost(
          PlayerState.t(),
          module(),
          term(),
          pos_integer(),
          map(),
          Cost.t(),
          non_neg_integer()
        ) :: {:ok, map()} | {:error, atom()}
  def prepare_castend_cost(caster, module, target, level, definition, cost, zeny) do
    with :ok <- check_weight(caster),
         :ok <- castend_requirement(module, caster, target, level, definition),
         :ok <- Cost.check_hp(caster, cost),
         :ok <- check_weapon(caster, definition),
         :ok <- check_ammo(caster, definition),
         :ok <- check_catalysts(caster, definition) do
      {:ok, prepared(caster, module, definition, cost, min(zeny, caster.zeny))}
    end
  end

  @doc "Checks a menu-delayed skill's cast-end requirements and spends only its catalysts."
  @spec consume_menu_items(PlayerState.t(), module(), term(), map(), pos_integer()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def consume_menu_items(caster, module, target, definition, level) do
    with {:ok, definition, cost, zeny} <-
           resolve_requirement(caster, module, target, definition, level),
         {:ok, _prepared} <-
           prepare_castend_cost(caster, module, target, level, definition, cost, zeny) do
      {:ok, maybe_consume_catalysts(caster, definition, true)}
    end
  end

  defp castend_requirement(module, caster, target, level, definition) do
    if function_exported?(module, :castend_requirement, 4),
      do: module.castend_requirement(caster, target, level, definition),
      else: :ok
  end

  defp prepared(caster, module, definition, cost, zeny) do
    %{
      definition: definition,
      module: module,
      cost: cost,
      commitment: Cost.prepare_clamped(caster, cost),
      zeny: zeny,
      consume_catalysts?: true
    }
  end

  @doc "Fails a player whose equipped weapon type the skill does not allow."
  @spec check_weapon(map(), map()) :: :ok | {:error, :wrong_weapon}
  def check_weapon(_caster, %{require_weapon: []}), do: :ok

  def check_weapon(%{stats: %{equipment: equipment}}, %{require_weapon: allowed}) do
    if PlayerStats.weapon_type(equipment) in allowed,
      do: :ok,
      else: {:error, :wrong_weapon}
  end

  def check_weapon(_caster, _definition), do: :ok

  @doc """
  Consumes a skill's requirement for an equipment proc, before its effect.

  The proc's autocast flag waives the SP; Holy Light's explicit requirement
  branch keeps its SP instead. The HP, spheres and zeny the skill owes are
  spent up to what the caster has, with no affordability check and no item
  consumption. A zero-HP result is the owner's to settle.
  """
  @spec charge_proc_requirement(PlayerState.t(), module(), term(), map(), pos_integer()) ::
          {:ok, PlayerState.t()} | {:error, :invalid_cost}
  def charge_proc_requirement(caster, module, target, definition, level) do
    with {:ok, cost} <- resolve_cost(caster, module, target, level, definition) do
      cost = waive_proc_sp(cost, definition)

      zeny =
        min(effective_zeny_cost(caster, Enum.at(definition.zeny_cost, level - 1, 0)), caster.zeny)

      {:ok,
       caster
       |> Cost.apply_commitment(Cost.prepare_clamped(caster, cost))
       |> deduct_zeny(zeny)}
    end
  end

  defp waive_proc_sp(cost, %{id: @holy_light}), do: cost
  defp waive_proc_sp(cost, _definition), do: %{cost | sp: 0, sp_requirement: 0}

  @doc """
  Prepares a deferred cast's settlement without checking anything again: its
  requirements were checked when the cast ended, so the SP, HP, spheres and
  zeny are each spent up to what the caster holds.
  """
  @spec prepare_settlement(PlayerState.t(), module(), map(), Cost.t(), non_neg_integer()) ::
          map()
  def prepare_settlement(caster, module, definition, cost, zeny),
    do: prepared(caster, module, definition, cost, min(zeny, caster.zeny))

  @doc """
  Pays a prepared cost's HP, SP, spirit spheres and zeny before the effect.

  Item Appraisal's HP and SP and Ki Translation's spheres are not part of it:
  the appraisal pays them once the effect has run and the transfer spends its
  sphere itself. The returned prepared cost keeps only what is left, so a
  deferred cast settles it without paying the primary part twice.
  """
  @impl true
  def commit_primary(caster, %{commitment: commitment, zeny: zeny, cost: cost} = prepared) do
    {primary, remaining} = split_commitment(commitment, prepared.definition)
    paid = caster |> Cost.apply_commitment(primary) |> deduct_zeny(zeny)

    {paid,
     %{
       prepared
       | commitment: remaining,
         zeny: 0,
         cost: remaining_cost(cost, prepared.definition)
     }}
  end

  defp split_commitment(commitment, %{id: @identify}),
    do: {%{commitment | hp: 0, sp: 0}, %{commitment | write_spheres?: false}}

  defp split_commitment(commitment, %{id: @ki_translation}),
    do: {%{commitment | write_spheres?: false}, %{commitment | hp: 0, sp: 0}}

  defp split_commitment(commitment, _definition),
    do: {commitment, %{commitment | hp: 0, sp: 0, write_spheres?: false}}

  defp remaining_cost(cost, %{id: @identify}), do: %{cost | spheres: 0}

  defp remaining_cost(cost, %{id: @ki_translation}),
    do: %{cost | hp: 0, sp: 0, sp_requirement: 0}

  defp remaining_cost(cost, _definition),
    do: %{cost | hp: 0, sp: 0, sp_requirement: 0, spheres: 0}

  @doc """
  Settles what a prepared cost has left after the effect. A cast that spares its
  requirement (`consume_catalysts?: false`) skips the items and whatever else is
  paid after the effect (Item Appraisal's SP); the ammo is spent either way.
  """
  @impl true
  def commit(caster, %{
        commitment: commitment,
        zeny: zeny,
        definition: definition,
        consume_catalysts?: consume_catalysts?
      }) do
    caster
    |> apply_remaining(commitment, consume_catalysts?)
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

  @doc """
  Dispatches the cast start to the caster's statuses (Mystical Amplification,
  Foresight, Suffragium, Cloaking) and recalculates stats when one changed, so
  an instant cast's effect sees them.
  """
  @impl true
  def on_cast_start(%PlayerState{character_id: id} = caster, skill_id) do
    case StatusInterpreter.on_committed_action(:player, id, {:skill, skill_id}) do
      :changed ->
        stats = Calculator.calculate_stats(caster.stats, id)
        %{caster | stats: stats, walk_speed: StatusManager.walk_speed_for(stats)}

      :unchanged ->
        caster
    end
  end

  @doc "Refreshes the owning player's snapshot after cast-time status consumption."
  @spec refresh_after_cast_reactions(PlayerState.t()) :: PlayerState.t()
  def refresh_after_cast_reactions(%PlayerState{stats: %PlayerStats{}} = caster) do
    stats = Calculator.calculate_stats(caster.stats, caster.character_id)
    %{caster | stats: stats, walk_speed: StatusManager.walk_speed_for(stats)}
  end

  def refresh_after_cast_reactions(caster), do: caster

  @impl true
  def act_ready?(caster, now) do
    PlayerState.act_ready?(caster, now)
  end

  @impl true
  def cast_stats(caster, skill_id) do
    rate =
      equip_modifier(caster, :varcast_rate) + merged_modifier(caster.character_id, :varcast_rate)

    skill_rate = equip_modifier(caster, {:skill_varcast_rate, skill_id})

    %{
      caster_kind: :player,
      dex: PlayerStats.get_effective_stat(caster.stats, :dex),
      int: PlayerStats.get_effective_stat(caster.stats, :int),
      base_level: Map.get(caster.stats.progression || %{}, :base_level, 0),
      effective_skill?: effective_skill?(caster, skill_id),
      radius_level: effective_skill_level(caster, 2_208),
      item_global_rate: -rate,
      item_skill_rate: skill_rate,
      item_global_var_flat: equip_modifier(caster, :variable_cast),
      item_skill_var_flat: equip_modifier(caster, {:skill_variable_cast, skill_id}),
      item_global_fixed_rate: -equip_modifier(caster, :fixcast_rate),
      item_skill_fixed_rate: skill_fixed_rate(caster, skill_id),
      item_global_fixed_flat: equip_modifier(caster, :fixed_cast),
      item_skill_fixed_flat: equip_modifier(caster, {:skill_fixed_cast, skill_id}),
      statuses: cast_statuses(caster.character_id)
    }
  end

  defp effective_skill?(caster, skill_id), do: effective_skill_level(caster, skill_id) > 0

  @doc """
  The caster's level in a skill: the higher of its learned and equipment-granted
  levels, or the guild's level for a guild skill.
  """
  @spec skill_level(PlayerState.t(), integer()) :: non_neg_integer()
  def skill_level(%PlayerState{} = caster, skill_id), do: effective_skill_level(caster, skill_id)

  defp effective_skill_level(caster, skill_id) when skill_id in @guild_skill_range do
    with guild_id when guild_id not in [nil, 0] <- caster.guild_id,
         {:ok, guild} <- GuildManager.get(guild_id) do
      GuildState.skill_level(guild, skill_id)
    else
      _ -> 0
    end
  end

  defp effective_skill_level(caster, skill_id) do
    max(learned_level(caster, skill_id), granted_level(caster, skill_id))
  end

  defp quest_lineage?(caster, %{quest_skill: true} = definition) do
    SkillTree.quest_skill_available?(caster.stats.progression.job_id, definition)
  end

  defp quest_lineage?(_caster, _definition), do: true

  # The optional `dynamic_item_cost/4` replaces the catalysts on a cast-local
  # definition, which both the check here and the consumption at commit read.
  defp item_cost_definition(caster, module, target, level, definition) do
    if function_exported?(module, :dynamic_item_cost, 4),
      do: %{definition | item_cost: module.dynamic_item_cost(caster, target, level, definition)},
      else: definition
  end

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

  defp check_weight(%PlayerState{
         stats: %PlayerStats{progression: %{job_id: job_id}} = stats,
         inventory: inventory
       })
       when is_map(inventory) and is_integer(job_id) do
    maximum = Weight.max_weight(stats)

    if maximum > 0 and Weight.current_weight(inventory) * 10 >= maximum * 9,
      do: {:error, :overweight},
      else: :ok
  end

  defp check_weight(_caster), do: :ok

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
    if equip_modifier(caster, :no_gemstone) > 0 or
         StatusStorage.has_status?(:player, caster.character_id, :sc_intoabyss),
       do: waive_gemstones(definition),
       else: definition.item_cost
  end

  # Hocus Pocus and Ganbantein only drop one of each gemstone, never below one.
  defp waive_gemstones(%{name: name, item_cost: cost}) when name in @gem_floor_skills do
    Enum.map(cost, fn
      %{id: id, amount: amount} = entry when id in @waivable_gemstone_ids ->
        %{entry | amount: max(amount - 1, 1)}

      entry ->
        entry
    end)
  end

  defp waive_gemstones(%{item_cost: cost}),
    do: Enum.reject(cost, &(&1.id in @waivable_gemstone_ids))

  defp check_ammo(caster, definition) do
    if definition.requires_ammo and Ammo.equipped_ammo_index(caster.inventory) == nil do
      {:error, :no_ammo}
    else
      :ok
    end
  end

  defp apply_remaining(caster, commitment, true), do: Cost.apply_commitment(caster, commitment)
  defp apply_remaining(caster, _commitment, false), do: caster

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

  defp cast_statuses(character_id) do
    :player
    |> StatusStorage.get_unit_statuses(character_id)
    |> Enum.reduce(%{}, fn entry, statuses ->
      reduction = Map.get(entry.state || %{}, :cast_time_reduction, 0)

      case entry.type do
        :sc_memorize -> Map.put(statuses, :memorize, true)
        :sc_suffragium -> Map.put(statuses, :suffragium, reduction)
        :sc_poembragi -> Map.put(statuses, :bragi, reduction)
        _ -> statuses
      end
    end)
  end

  defp skill_fixed_rate(caster, skill_id) do
    equipment = caster.stats |> Map.get(:modifiers, %{}) |> Map.get(:equipment, %{})

    case Map.fetch(equipment, {:skill_fixcast_rate, skill_id}) do
      {:ok, value} -> -value
      :error -> nil
    end
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
