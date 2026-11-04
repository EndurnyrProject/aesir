defmodule Aesir.ZoneServer.Mmo.StatusEffect.Interpreter do
  @moduledoc """
  The public entry point of the status effect engine.

  Status effects are plain Elixir modules implementing
  `Aesir.ZoneServer.Mmo.StatusEffect.Definition`, registered in
  `Aesir.ZoneServer.Mmo.StatusEffect.Effects`. Every caller reaches the engine
  through this module; the work is split by concern across its siblings:

  - `StatusEffect.Applier` starts a status (`apply_status/4`), behind the gates
    of `StatusEffect.StartChecks`.
  - `StatusEffect.Removal` ends statuses (`remove_status/4`, the
    `expire_*_if_current` entries and the lifecycle batches).
  - `StatusEffect.CombatHooks` dispatches combat and movement events to held
    statuses, including the damage stages (`absorb_hit/4`).
  - `StatusEffect.Permissions` answers what a unit's statuses let it do.
  - `StatusEffect.Notifications` tells the holder's session about mutations.

  This module itself drives the periodic ticks (`process_tick_if_current/4`,
  `run_timeout/4`) and the in-place restarts (`restart_status_if_current/5`,
  `update_link_status/4`).
  """
  require Logger

  alias Aesir.ZoneServer.Mmo.StatusEffect.Applier
  alias Aesir.ZoneServer.Mmo.StatusEffect.CombatHooks
  alias Aesir.ZoneServer.Mmo.StatusEffect.ContextBuilder
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusEffect.Notifications
  alias Aesir.ZoneServer.Mmo.StatusEffect.Permissions
  alias Aesir.ZoneServer.Mmo.StatusEffect.PropertyChecker
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEffect.Removal
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @type unit_type :: Unit.unit_type()
  @type remove_option :: Notifications.remove_option()

  @typedoc "An actual status mutation committed for the application or removal's holder."
  @type status_event() :: Notifications.status_event()

  @doc """
  Initializes the status effect system by loading all definitions.
  """
  @spec init() :: :ok
  def init do
    Registry.load_definitions()
  end

  @doc "Applies a status effect to a unit; see `StatusEffect.Applier.apply_status/4`."
  defdelegate apply_status(unit_type, unit_id, status_id, status_params \\ []), to: Applier

  @doc "Applies a status and returns its committed mutations; see `StatusEffect.Applier.apply_status_with_events/4`."
  defdelegate apply_status_with_events(unit_type, unit_id, status_id, status_params),
    to: Applier

  @doc """
  Runs the on_tick callback for an active status.
  """
  @spec process_tick(unit_type(), integer(), atom()) :: :ok
  def process_tick(unit_type, unit_id, status_id) do
    case StatusStorage.get_status(unit_type, unit_id, status_id) do
      %StatusEntry{generation: generation} when is_integer(generation) ->
        process_tick_if_current(unit_type, unit_id, status_id, generation)
        :ok

      _missing ->
        :ok
    end
  end

  @doc """
  Runs an exact tick only when the expected status generation is still current.

  Returns `:continue` when the callback retained the current status, otherwise
  returns `:stop` so an exact-timer owner does not schedule another deadline.
  A callback may publish interim changes to its generation; removal ends that
  generation's latest entry, never a replacement application.
  """
  @spec process_tick_if_current(unit_type(), integer(), atom(), pos_integer()) ::
          :continue | :stop
  def process_tick_if_current(unit_type, unit_id, status_id, expected_generation) do
    with %{module: module} when not is_nil(module) <- Registry.get_definition(status_id),
         %StatusEntry{generation: ^expected_generation} = instance <-
           StatusStorage.get_status(unit_type, unit_id, status_id) do
      case UnitRegistry.get_unit_info(unit_type, unit_id) do
        {:ok, %{stats: target_stats}} when not is_nil(target_stats) ->
          process_current_exact_tick(
            module,
            unit_type,
            unit_id,
            status_id,
            expected_generation,
            instance,
            target_stats
          )

        unexpected ->
          Logger.warning(
            "Stopping exact tick for #{status_id}: invalid #{unit_type} #{unit_id} lookup #{inspect(unexpected)}"
          )

          Removal.remove_current_status_and_notify(unit_type, unit_id, status_id, instance)
          :stop
      end
    else
      _ -> :stop
    end
  end

  defp process_current_exact_tick(
         module,
         unit_type,
         unit_id,
         status_id,
         expected_generation,
         instance,
         target_stats
       ) do
    context =
      ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance, target_stats)

    case module.on_tick({unit_type, unit_id}, instance, context) do
      {:ok, new_instance} ->
        store_instance_changes_if_current(
          unit_type,
          unit_id,
          status_id,
          expected_generation,
          new_instance
        )

        :continue

      :remove ->
        Removal.end_generation(unit_type, unit_id, status_id, expected_generation)
        :stop

      {:error, reason} ->
        Logger.warning("Status #{status_id} exact on_tick failed: #{inspect(reason)}")
        :stop
    end
  end

  defp store_instance_changes_if_current(
         unit_type,
         unit_id,
         status_id,
         expected_generation,
         new_instance
       ) do
    StatusStorage.update_status(unit_type, unit_id, status_id, fn
      %StatusEntry{generation: ^expected_generation} = entry ->
        %{
          entry
          | val1: new_instance.val1,
            val2: new_instance.val2,
            val3: new_instance.val3,
            val4: new_instance.val4,
            state: new_instance.state || %{},
            phase: new_instance.phase
        }

      current ->
        current
    end)
  end

  @doc """
  Runs the timeout of a status that was just removed for running out its duration.

  Calls the definition's `on_timeout` callback with the expired `instance` and
  applies the `{status_id, params}` follow-ups it returns to the same holder.
  Call it only after the expiry actually removed `instance`.
  """
  @spec run_timeout(unit_type(), integer(), atom(), StatusEntry.t()) :: :ok
  def run_timeout(unit_type, unit_id, status_id, instance) do
    if MapSet.member?(Registry.statuses_implementing(:on_timeout), status_id) do
      %{module: module} = Registry.get_definition(status_id)
      context = ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)

      {unit_type, unit_id}
      |> module.on_timeout(instance, context)
      |> Enum.each(fn {follow_up_id, params} ->
        apply_status(unit_type, unit_id, follow_up_id, params)
      end)
    else
      :ok
    end
  end

  @doc "Notifies a unit's statuses of delivered damage; see `StatusEffect.CombatHooks.on_damage/3`."
  defdelegate on_damage(unit_type, unit_id, damage_info), to: CombatHooks

  @doc "The damage-broken statuses a unit holds; see `StatusEffect.CombatHooks.damage_broken_snapshot/2`."
  defdelegate damage_broken_snapshot(unit_type, unit_id), to: CombatHooks

  @doc "Dispatches swing reactions; see `StatusEffect.CombatHooks.before_weapon_hit/3`."
  defdelegate before_weapon_hit(unit_type, unit_id, attack_info), to: CombatHooks

  @doc "Claims one bounded swing modifier; see `StatusEffect.CombatHooks.before_normal_attack/3`."
  defdelegate before_normal_attack(unit_type, unit_id, attack_info), to: CombatHooks

  @doc "Asks the attacker's statuses to replace its swing; see `StatusEffect.CombatHooks.attack_replacement/2`."
  defdelegate attack_replacement(unit_type, unit_id), to: CombatHooks

  @doc "Notifies the attacker's statuses of a landed hit; see `StatusEffect.CombatHooks.on_dealt_damage/3`."
  defdelegate on_dealt_damage(unit_type, unit_id, hit_info), to: CombatHooks

  @doc "Dispatches the victim's post-damage statuses; see `StatusEffect.CombatHooks.after_damage_taken/3`."
  defdelegate after_damage_taken(unit_type, unit_id, hit_info), to: CombatHooks

  @doc "Dispatches a validated player action; see `StatusEffect.CombatHooks.on_committed_action/3`."
  defdelegate on_committed_action(unit_type, unit_id, action), to: CombatHooks

  @doc "Whether `status_id` stops its holder's attack when it starts; see `StatusEffect.PropertyChecker.stops_attacking?/1`."
  defdelegate stops_attacking?(status_id), to: PropertyChecker

  @doc "Whether the unit holds a status indexed for `flag`; see `StatusEffect.Permissions.has_active_flag?/3`."
  defdelegate has_active_flag?(unit_type, unit_id, flag), to: Permissions

  @doc "Dispatches movement intent; see `StatusEffect.CombatHooks.on_movement_intent/3`."
  defdelegate on_movement_intent(unit_type, unit_id, position), to: CombatHooks

  @doc "Notifies statuses of movement contact; see `StatusEffect.CombatHooks.on_movement_contact/3`."
  defdelegate on_movement_contact(unit_type, unit_id, contact), to: CombatHooks

  @doc "Runs the damage stages over one hit; see `StatusEffect.CombatHooks.absorb_damage/4`."
  defdelegate absorb_damage(unit_type, unit_id, damage, hit_info), to: CombatHooks

  @doc "Runs the damage stages and classifies the hit; see `StatusEffect.CombatHooks.absorb_hit/4`."
  defdelegate absorb_hit(unit_type, unit_id, damage, hit_info), to: CombatHooks

  @doc "Runs only the blockers over one point of damage; see `StatusEffect.CombatHooks.block_hit/3`."
  defdelegate block_hit(unit_type, unit_id, hit_info), to: CombatHooks

  @doc "Intercepts a same-source magic hit; see `StatusEffect.CombatHooks.intercept_magic/3`."
  defdelegate intercept_magic(unit_type, unit_id, hit_info), to: CombatHooks

  @doc "Every status id with a damage stage, in stage order; see `StatusEffect.CombatHooks.absorb_stages/0`."
  defdelegate absorb_stages(), to: CombatHooks

  @doc "Runs the final weapon stage over one hit; see `StatusEffect.CombatHooks.final_weapon_hit/4`."
  defdelegate final_weapon_hit(unit_type, unit_id, damage, hit_info), to: CombatHooks

  @doc "Every status id in the final weapon stage; see `StatusEffect.CombatHooks.final_weapon_stages/0`."
  defdelegate final_weapon_stages(), to: CombatHooks

  @doc "Removes a status through its end logic; see `StatusEffect.Removal.remove_status/4`."
  defdelegate remove_status(unit_type, unit_id, status_id, opts \\ []), to: Removal

  @doc "Removes a status and returns its committed mutations; see `StatusEffect.Removal.remove_status_with_events/4`."
  defdelegate remove_status_with_events(unit_type, unit_id, status_id, opts), to: Removal

  @doc "Removes a status while `instance` is current; see `StatusEffect.Removal.remove_status_if_current/5`."
  defdelegate remove_status_if_current(unit_type, unit_id, status_id, instance, opts \\ []),
    to: Removal

  @doc """
  Restarts a held status as `replacement` only while `held` is still its current
  entry: stores it, arms its new deadline and refreshes its icon. Returns whether
  `replacement` was stored; a caller losing the race reads the status again.
  """
  @spec restart_status_if_current(
          unit_type(),
          integer(),
          atom(),
          StatusEntry.t(),
          StatusEntry.t()
        ) ::
          boolean()
  def restart_status_if_current(unit_type, unit_id, status_id, held, replacement) do
    if StatusStorage.replace_status_if_current(unit_type, unit_id, status_id, held, replacement) do
      StatusTickManager.arm(unit_type, unit_id, replacement)
      StatusDisplay.on_applied(unit_type, unit_id, status_id, replacement)
      Notifications.notify_mob_status_write(unit_type, unit_id, status_id, :apply)
      true
    else
      false
    end
  end

  @doc """
  Updates Close Confine link bookkeeping without starting a status or calculating stats.

  The pure callback may change only `val1`, `val2` and the expiry, or return
  `:keep`. Missing entries remain missing. A winning update preserves the held
  FLEE value and original start time and re-arms the exact deadline, without
  refreshing the icon or notifying a calculated-stat owner.
  """
  @spec update_link_status(
          unit_type(),
          integer(),
          :sc_closeconfine | :sc_closeconfine2,
          (StatusEntry.t() -> StatusEntry.t() | :keep)
        ) :: StatusEntry.t() | nil
  def update_link_status(unit_type, unit_id, status_id, update)
      when status_id in [:sc_closeconfine, :sc_closeconfine2] do
    decide = fn
      nil -> :keep
      current -> link_update_decision(current, update)
    end

    case StatusStorage.apply_status_with_entry(unit_type, unit_id, status_id, [], decide) do
      {:stored, replacement, _prior} ->
        StatusTickManager.arm(unit_type, unit_id, replacement)
        replacement

      _not_stored ->
        nil
    end
  end

  defp link_update_decision(current, update) do
    case update.(current) do
      :keep ->
        :keep

      updated ->
        {:store,
         fn incoming ->
           %{
             current
             | val1: updated.val1,
               val2: updated.val2,
               expires_at: updated.expires_at,
               generation: incoming.generation
           }
         end}
    end
  end

  @doc "Removes the supplied statuses as one batch; see `StatusEffect.Removal.remove_statuses/4`."
  defdelegate remove_statuses(unit_type, unit_id, status_ids, opts \\ []), to: Removal

  @doc "Removes the statuses death ends; see `StatusEffect.Removal.remove_on_death/3`."
  defdelegate remove_on_death(unit_type, unit_id, opts \\ []), to: Removal

  @doc "Ends the statuses a map change ends; see `StatusEffect.Removal.remove_on_map_change/2`."
  defdelegate remove_on_map_change(unit_type, unit_id), to: Removal

  @doc "Ends statuses whose weapon requirement broke; see `StatusEffect.Removal.enforce_weapon_requirements/3`."
  defdelegate enforce_weapon_requirements(unit_type, unit_id, weapon_type), to: Removal

  @doc "Removes every active status; see `StatusEffect.Removal.remove_all_statuses/3`."
  defdelegate remove_all_statuses(unit_type, unit_id, opts \\ []), to: Removal

  @doc "Ends every status of a unit leaving the world; see `StatusEffect.Removal.end_removed_unit_statuses/2`."
  defdelegate end_removed_unit_statuses(unit_type, unit_id), to: Removal

  @doc "Ends the statuses a logout does not save; see `StatusEffect.Removal.end_unsaved_statuses/2`."
  defdelegate end_unsaved_statuses(unit_type, unit_id), to: Removal

  @doc """
  Toggles a status effect on a unit.

  If the status is currently active, removes it and returns `{:ok, :removed}`.
  If the status is not active, applies it and returns `{:ok, :applied}`.
  On application failure, propagates `{:error, reason}` unchanged.
  """
  @spec toggle_status(unit_type(), integer(), atom(), StatusEntry.status_params()) ::
          {:ok, :applied | :removed} | {:error, atom()}
  def toggle_status(unit_type, unit_id, status_id, params \\ []) do
    if StatusStorage.has_status?(unit_type, unit_id, status_id) do
      remove_status(unit_type, unit_id, status_id)
      {:ok, :removed}
    else
      case apply_status(unit_type, unit_id, status_id, params) do
        :ok -> {:ok, :applied}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Returns the aggregated stat modifiers from all active statuses on a unit.
  """
  @spec get_all_modifiers(unit_type(), integer()) :: map()
  def get_all_modifiers(unit_type, unit_id) do
    ModifierCalculator.get_all_modifiers(unit_type, unit_id)
  end

  @doc """
  Checks if a status has a specific property.
  """
  @spec has_property?(atom(), atom()) :: boolean()
  defdelegate has_property?(status_id, property), to: PropertyChecker

  @doc """
  Checks if a status is a debuff.
  """
  @spec debuff?(atom()) :: boolean()
  defdelegate debuff?(status_id), to: PropertyChecker

  @doc """
  Checks if a status is a buff.
  """
  @spec buff?(atom()) :: boolean()
  defdelegate buff?(status_id), to: PropertyChecker

  @doc """
  Checks if a status prevents movement.
  """
  @spec prevents_movement?(atom()) :: boolean()
  defdelegate prevents_movement?(status_id), to: PropertyChecker

  @doc """
  Checks if a status prevents skill usage.
  """
  @spec prevents_skills?(atom()) :: boolean()
  defdelegate prevents_skills?(status_id), to: PropertyChecker

  @doc """
  Checks if a status prevents attacking.
  """
  @spec prevents_attack?(atom()) :: boolean()
  defdelegate prevents_attack?(status_id), to: PropertyChecker

  @doc """
  Returns all properties of a status.
  """
  @spec get_properties(atom()) :: [atom()]
  defdelegate get_properties(status_id), to: PropertyChecker

  @doc "Whether a unit may move; see `StatusEffect.Permissions.can_move?/2`."
  defdelegate can_move?(unit_type, unit_id), to: Permissions

  @doc "Whether a unit may attack; see `StatusEffect.Permissions.can_attack?/2`."
  defdelegate can_attack?(unit_type, unit_id), to: Permissions

  @doc "Whether a status blocks equipping `slot`; see `StatusEffect.Permissions.equip_blocked?/3`."
  defdelegate equip_blocked?(unit_type, unit_id, slot), to: Permissions

  @doc "Whether a unit may use skills; see `StatusEffect.Permissions.can_use_skill?/2`."
  defdelegate can_use_skill?(unit_type, unit_id), to: Permissions

  @doc "Whether a unit may use items; see `StatusEffect.Permissions.can_use_item?/2`."
  defdelegate can_use_item?(unit_type, unit_id), to: Permissions

  @doc "Whether a skill hit may be calculated; see `StatusEffect.Permissions.can_deal_skill_damage?/4`."
  defdelegate can_deal_skill_damage?(unit_type, unit_id, skill_id, autocast?), to: Permissions

  @doc "`can_deal_skill_damage?/4` for a combatant; see `StatusEffect.Permissions.authorize_skill_damage/2`."
  defdelegate authorize_skill_damage(combatant, skill_id), to: Permissions

  @doc "Whether a player may sit; see `StatusEffect.Permissions.can_sit?/1`."
  defdelegate can_sit?(unit_id), to: Permissions

  @doc "Whether a player may stand; see `StatusEffect.Permissions.can_stand?/1`."
  defdelegate can_stand?(unit_id), to: Permissions

  @doc "Whether a monster's statuses drop its target; see `StatusEffect.Permissions.loses_target?/2`."
  defdelegate loses_target?(unit_type, unit_id), to: Permissions

  @doc "Whether a unit may send area chat; see `StatusEffect.Permissions.can_chat?/2`."
  defdelegate can_chat?(unit_type, unit_id), to: Permissions

  @doc "Whether statuses block equipment changes; see `StatusEffect.Permissions.equip_change_blocked?/2`."
  defdelegate equip_change_blocked?(unit_type, unit_id), to: Permissions

  @doc "Whether a unit may cast `skill_id`; see `StatusEffect.Permissions.can_use_skill?/4`."
  defdelegate can_use_skill?(unit_type, unit_id, skill_id, item? \\ false), to: Permissions

  @doc "Whether a performance lock lets `skill_id` through; see `StatusEffect.Permissions.performance_allows_skill?/3`."
  defdelegate performance_allows_skill?(unit_type, unit_id, skill_id), to: Permissions

  @doc "Whether a status prevents support skills; see `StatusEffect.Permissions.support_blocked?/2`."
  defdelegate support_blocked?(unit_type, unit_id), to: Permissions

  @doc "Whether a unit may be targeted; see `StatusEffect.Permissions.targetable?/2`."
  defdelegate targetable?(unit_type, unit_id), to: Permissions

  @doc "Whether a unit is charmed against `target_id`; see `StatusEffect.Permissions.charmed_against?/3`."
  defdelegate charmed_against?(unit_type, unit_id, target_id), to: Permissions

  @doc "Expires a status while `instance` is current; see `StatusEffect.Removal.expire_status_if_current/4`."
  defdelegate expire_status_if_current(unit_type, unit_id, status_id, instance), to: Removal

  @doc "Expires the current entry and returns its removals; see `StatusEffect.Removal.expire_status_events_if_current/4`."
  defdelegate expire_status_events_if_current(unit_type, unit_id, status_id, instance),
    to: Removal
end
