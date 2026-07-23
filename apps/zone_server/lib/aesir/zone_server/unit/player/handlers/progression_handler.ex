defmodule Aesir.ZoneServer.Unit.Player.Handlers.ProgressionHandler do
  @moduledoc """
  Applies GM-driven progression changes to a player session: adding base levels,
  adding job levels, and changing the character's job.

  These mirror rAthena's `@baselvlup`/`@joblvlup`/`@job` commands. Level gains
  clamp to the job's caps, grant the matching status/skill points, and (for base
  levels) full-heal the character, matching `pc_baselevelup`. A job change follows
  rAthena's `pc_jobchange` cleanup (drop out-of-tree skills without refunding,
  reset job level, close vending, unequip what the new job cannot wear, end
  statuses tied to dropped skills) and updates the class sprite for the player and
  nearby observers. A change (or `reset_skills/1` refund) that would drop
  `MC_PUSHCART` while a cart is mounted is rejected with `{:error, :cart_active}`
  before any mutation, so the player unloads and removes the cart first. Unlike
  the cart, a mounted Peco-Peco never blocks a change or reset that drops
  `KN_RIDING`: `MountHandler.force_dismount/1` runs up front instead, before the
  stats recompute, so the new job's derived stats never carry the riding ASPD
  buyback.
  `reset_skills/1` implements the separate `resetskill` refund and `reset_stats/1`
  the separate `resetstate` stat reset.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.StatusParams
  alias Aesir.Net.SpriteChange
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.JobManagement.TraitJobs
  alias Aesir.ZoneServer.Mmo.Leveling
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.Skills.Knight.KnRiding
  alias Aesir.ZoneServer.Mmo.Skills.Merchant.McPushcart
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Mmo.StatPoint
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.LookType
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.MountHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.VendingHandler
  alias Aesir.ZoneServer.Unit.Player.SkillListView
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.Stats, as: UnitStats

  @mc_pushcart_id McPushcart.definition().id
  @kn_riding_id KnRiding.definition().id

  @doc """
  Adds `amount` base levels, clamped to the job's `max_base_level`. Grants the
  status points earned across the gained levels and full-heals the character.
  """
  @spec handle_add_base_level(pos_integer(), map()) :: {:noreply, map()}
  def handle_add_base_level(amount, %{game_state: game_state} = state) do
    progression = game_state.stats.progression
    {:ok, job} = job_for(progression)
    old_level = progression.base_level
    new_level = min(old_level + amount, job.max_base_level)
    status_gained = StatPoint.gain(old_level, new_level)
    trait_gained = StatPoint.trait_gain(old_level, new_level)

    progression = %{
      progression
      | base_level: new_level,
        base_exp: 0,
        status_point: progression.status_point + status_gained,
        trait_point: progression.trait_point + trait_gained
    }

    stats =
      %{game_state.stats | progression: progression}
      |> Stats.calculate_stats(game_state.character_id)
      |> full_heal()

    commit(state, %{game_state | stats: stats}, progression)
  end

  @doc """
  Adds `amount` job levels, clamped to the job's `max_job_level`. Grants one skill
  point per gained level.
  """
  @spec handle_add_job_level(pos_integer(), map()) :: {:noreply, map()}
  def handle_add_job_level(amount, %{game_state: game_state} = state) do
    progression = game_state.stats.progression
    {:ok, job} = job_for(progression)
    old_level = progression.job_level
    new_level = min(old_level + amount, job.max_job_level)

    progression = %{
      progression
      | job_level: new_level,
        job_exp: 0,
        skill_point: progression.skill_point + (new_level - old_level)
    }

    stats =
      Stats.calculate_stats(
        %{game_state.stats | progression: progression},
        game_state.character_id
      )

    commit(state, %{game_state | stats: stats}, progression)
  end

  @doc """
  Routes a `:progression`-enveloped session message to its handler.
  `PlayerSession`'s `handle_info({:progression, msg}, state)` clause delegates
  here for job changes and stat/skill resets; each head returns the
  GenServer-native `{:noreply, state}` tuple, unwrapping the `{:ok, _}` /
  `{:error, _}` cores of `reset_skills/1` and `reset_stats/1`.
  """
  @spec info(term(), map()) :: {:noreply, map()}
  def info({:change_job, job_id}, state), do: handle_change_job(job_id, state)

  def info({:reset_skills}, state) do
    case reset_skills(state) do
      {:ok, new_state} -> {:noreply, new_state}
      {:error, _reason} -> {:noreply, state}
    end
  end

  def info({:reset_stats}, state) do
    {:ok, new_state} = reset_stats(state)
    {:noreply, new_state}
  end

  @doc """
  Changes the character's job to `job_id`, recomputes job-dependent stats,
  full-heals, and broadcasts the new class sprite to the player and nearby
  observers.

  Thin wrapper over `apply_job_change/2` kept as the `{:noreply, _}` entry
  point for `PlayerSession`'s `{:change_job, _}` info handler (driven by
  `JobChange.request/2`); an unknown `job_id` leaves `state` untouched.
  """
  @spec handle_change_job(non_neg_integer(), map()) :: {:noreply, map()}
  def handle_change_job(job_id, state) do
    case apply_job_change(job_id, state) do
      {:ok, new_state} -> {:noreply, new_state}
      {:error, _reason} -> {:noreply, state}
    end
  end

  @doc """
  Authoritative core for a job change (rAthena `pc_jobchange`): validates
  `job_id`, force-closes vending, drops learned skills outside the new job's tree
  (no skill-point refund, unspent points kept), resets job level/exp to `1`/`0`,
  recomputes job-dependent stats, full-heals, unequips items the new job cannot
  wear, ends statuses granted by dropped skills, notifies the client (class
  sprite, refreshed skill list, stat/param sync), persists
  `class`/`learned_skills`/job level, and updates the `UnitRegistry`.

  A change to the current job is a no-op returning `{:ok, state}` unchanged
  (rAthena rejects an unchanged job). Returns `{:error, :unknown_job}` without
  mutating `state` when `job_id` does not resolve to a known job. Returns
  `{:error, :cart_active}` without mutating `state` when the change would drop
  `MC_PUSHCART` (the new job's tree lacks it) while a cart is mounted — the
  player must unload and remove the cart first.
  """
  @spec apply_job_change(non_neg_integer(), map()) ::
          {:ok, map()} | {:error, :unknown_job | :cart_active | :requirements_not_met}
  def apply_job_change(job_id, %{game_state: game_state} = state) do
    case AvailableJobs.job_id_to_name(job_id) do
      {:ok, _job_name} -> do_apply_job_change(job_id, state, game_state)
      {:error, :unknown_job_id} -> {:error, :unknown_job}
    end
  end

  @doc """
  Whether a change to `job_id` is blocked by a mounted cart: the player has an
  active cart (`cart_type > 0`) and the new job's tree does not include
  `MC_PUSHCART`, so the change would drop the cart-gating skill. Used by the core
  and by `@job` to reject before any mutation.
  """
  @spec cart_blocks_job_change?(map(), non_neg_integer()) :: boolean()
  def cart_blocks_job_change?(%{cart_type: cart_type}, job_id) do
    cart_type > 0 and @mc_pushcart_id not in Map.keys(SkillTree.tree_for(job_id))
  end

  @doc """
  Whether a skill reset is blocked by a mounted cart: a reset refunds
  `MC_PUSHCART`, so any active cart (`cart_type > 0`) blocks it.
  """
  @spec cart_blocks_reset?(map()) :: boolean()
  def cart_blocks_reset?(%{cart_type: cart_type}), do: cart_type > 0

  @doc """
  Refunds the player's learned skills into `skill_point` (rAthena `resetskill` /
  `@resetskill`).

  Reduces `learned_skills` to the exempt set (`SkillTree.reset_skills/1`),
  force-dismounts a mounted Peco-Peco (`KN_RIDING` is never exempt), ends
  statuses granted by the refunded skills, recomputes stats so passive bonuses
  from refunded skills drop (a final recompute after all cleanup, since status
  removals bypass `game_state.stats`), refreshes the client's skill window and
  full stat/param set, persists `learned_skills`/`skill_point`/vitals, and updates
  the `UnitRegistry`.

  Returns `{:error, :cart_active}` without mutating `state` when a cart is mounted
  (a reset refunds `MC_PUSHCART`) — the player must remove the cart first.
  """
  @spec reset_skills(map()) :: {:ok, map()} | {:error, :cart_active}
  def reset_skills(%{game_state: game_state} = state) do
    if cart_blocks_reset?(game_state) do
      {:error, :cart_active}
    else
      do_reset_skills(state, game_state)
    end
  end

  @doc """
  Resets the player's stat allocation (rAthena `resetstate` / `@resetstat`):
  classic stats (STR..LUK) drop to `1` and `status_point` is restored to
  `StatPoint.points_at(base_level)`; trait stats (POW..CRT) drop to `0` and
  `trait_point` is restored to `StatPoint.trait_points_at(base_level)` plus the
  flat `+7` trait-job grant when the character currently holds a trait job.
  Recomputes stats, clamps vitals (a lower VIT/INT can drop max HP/SP below the
  current value), then syncs and persists all twelve stat columns and both pools
  through the shared `commit/4` path.
  """
  @spec reset_stats(map()) :: {:ok, map()}
  def reset_stats(%{game_state: game_state} = state) do
    progression = game_state.stats.progression
    base_level = progression.base_level
    job_id = progression.job_id

    new_progression = %{
      progression
      | status_point: StatPoint.points_at(base_level),
        trait_point: StatPoint.trait_points_at(base_level) + trait_reset_bonus(job_id)
    }

    base_stats = %{
      game_state.stats.base_stats
      | str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        pow: 0,
        sta: 0,
        wis: 0,
        spl: 0,
        con: 0,
        crt: 0
    }

    stats =
      %{game_state.stats | progression: new_progression, base_stats: base_stats}
      |> Stats.calculate_stats(game_state.character_id)
      |> clamp_vitals()

    {:noreply, new_state} = commit(state, %{game_state | stats: stats}, new_progression)
    {:ok, new_state}
  end

  defp trait_reset_bonus(job_id) do
    if TraitJobs.trait_job?(job_id), do: 7, else: 0
  end

  defp do_reset_skills(state, game_state) do
    previous_game_state = game_state
    progression = game_state.stats.progression
    new_progression = SkillTree.reset_skills(progression)
    dropped_ids = Map.keys(progression.learned_skills) -- Map.keys(new_progression.learned_skills)

    dismounted_state = dismount_if_losing_riding(state, dropped_ids)
    game_state = dismounted_state.game_state

    stats =
      %{game_state.stats | progression: new_progression}
      |> Stats.calculate_stats(game_state.character_id)

    %{dismounted_state | game_state: %{game_state | stats: stats}}
    |> cleanup_dropped_skills(dropped_ids)
    |> finish_reset_skills(previous_game_state)
  end

  defp do_apply_job_change(job_id, state, game_state) do
    progression = game_state.stats.progression

    cond do
      job_id == progression.job_id ->
        {:ok, state}

      TraitJobs.change_allowed?(progression, job_id) != :ok ->
        {:error, :requirements_not_met}

      cart_blocks_job_change?(game_state, job_id) ->
        {:error, :cart_active}

      true ->
        change_to_job(job_id, state)
    end
  end

  # rAthena `pc_jobchange` order: force-close vending, drop skills outside the new
  # tree (no refund, unspent points kept), force-dismount a Peco-Peco the new
  # tree can no longer ride, reset job level, recompute stats (so passives from
  # dropped skills, and the riding ASPD buyback, stop applying) BEFORE the
  # cart/equipment/status cleanup, then notify and persist.
  defp change_to_job(job_id, state) do
    previous_game_state = state.game_state
    {:ok, closed_state} = VendingHandler.close_shop(state, :job_change)
    game_state = closed_state.game_state
    progression = game_state.stats.progression

    {kept_skills, dropped_ids} = prune_skills(progression.learned_skills, job_id)
    old_job_id = progression.job_id

    dismounted_state = dismount_if_losing_riding(closed_state, dropped_ids)
    game_state = dismounted_state.game_state

    new_progression = %{
      progression
      | job_id: job_id,
        learned_skills: kept_skills,
        job_level: 1,
        job_exp: 0,
        trait_point: adjust_trait_point(progression.trait_point, old_job_id, job_id)
    }

    base_stats = adjust_trait_base_stats(game_state.stats.base_stats, old_job_id, job_id)

    stats =
      Stats.calculate_stats(
        %{game_state.stats | progression: new_progression, base_stats: base_stats},
        game_state.character_id
      )

    %{dismounted_state | game_state: %{game_state | stats: stats}}
    |> cleanup_dropped_skills(dropped_ids)
    |> recheck_equipment(job_id)
    |> enforce_weapon_requirements()
    |> finish_job_change(job_id, previous_game_state)
  end

  @spec prune_skills(Learned.t(), non_neg_integer()) :: {Learned.t(), [non_neg_integer()]}
  defp prune_skills(learned_skills, job_id) do
    tree_ids = job_id |> SkillTree.tree_for() |> Map.keys()
    {kept, dropped} = Map.split(learned_skills, tree_ids)
    {kept, Map.keys(dropped)}
  end

  # Grant +7 on entering a trait job from a non-trait job (row 24); zero the pool
  # when leaving a trait job for a non-trait job. Trait->trait (alt-variant) and
  # non-trait->non-trait leave the pool untouched.
  @spec adjust_trait_point(non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          non_neg_integer()
  defp adjust_trait_point(trait_point, old_job_id, new_job_id) do
    cond do
      TraitJobs.trait_job?(new_job_id) and not TraitJobs.trait_job?(old_job_id) ->
        trait_point + 7

      TraitJobs.trait_job?(old_job_id) and not TraitJobs.trait_job?(new_job_id) ->
        0

      true ->
        trait_point
    end
  end

  # Leaving a trait job for a non-trait job zeroes the six trait base stats
  # (deliberate simplification of rAthena's forced resetstate, Section 5.7).
  @spec adjust_trait_base_stats(
          UnitStats.BaseStats.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: UnitStats.BaseStats.t()
  defp adjust_trait_base_stats(base_stats, old_job_id, new_job_id) do
    if TraitJobs.trait_job?(old_job_id) and not TraitJobs.trait_job?(new_job_id) do
      %{base_stats | pow: 0, sta: 0, wis: 0, spl: 0, con: 0, crt: 0}
    else
      base_stats
    end
  end

  # Force-dismounts a mounted Peco-Peco when KN_RIDING is among the dropped
  # skills, shared by job change (dropped via prune_skills/2 against the new
  # job's tree) and skill reset (dropped via SkillTree.reset_skills/1's
  # refund). Unlike the cart gate this never blocks the change/reset - it only
  # runs the dismount side effect before the caller's stats recompute.
  @spec dismount_if_losing_riding(map(), [non_neg_integer()]) :: map()
  defp dismount_if_losing_riding(state, dropped_ids) do
    if @kn_riding_id in dropped_ids and MountHandler.riding?(state) do
      MountHandler.force_dismount(state)
    else
      state
    end
  end

  # Ends the statuses granted by the dropped/refunded skills, on the player only,
  # shared by job change and skill reset. Cart handling is not needed here: a
  # change/reset that would drop MC_PUSHCART while a cart is mounted is rejected
  # up front (see `cart_blocks_job_change?/2` / `cart_blocks_reset?/1`).
  defp cleanup_dropped_skills(%{game_state: gs} = state, dropped_ids) do
    end_dropped_statuses(gs.character_id, dropped_ids)
    state
  end

  # rAthena `skill_get_sc`: a skill's granted SC is a field on its skill_db
  # record. For each dropped skill, look up its `Definition.status` in the catalog
  # and end that status on the player if the skill grants one.
  defp end_dropped_statuses(char_id, dropped_ids) do
    for skill_id <- dropped_ids,
        {:ok, %{status: status}} when not is_nil(status) <- [Catalog.by_id(skill_id)] do
      StatusInterpreter.remove_status(:player, char_id, status)
    end
  end

  # Force-unequips every worn item the new job can no longer wear (job check only,
  # not level or other requirements), routing each through the equipment handler's
  # persist + client sync path.
  defp recheck_equipment(%{game_state: game_state} = state, job_id) do
    game_state.inventory
    |> Inventory.equipped_items()
    |> Map.keys()
    |> Enum.reduce(state, fn index, acc -> maybe_unequip(acc, index, job_id) end)
  end

  defp maybe_unequip(%{game_state: gs} = state, index, job_id) do
    with %InventoryItem{nameid: nameid} <- Map.get(gs.inventory, index),
         {:ok, item_def} <- ItemManagement.get_item_by_id(nameid),
         {:error, :requirement_unmet} <- Inventory.validate_job(item_def, job_id) do
      {:noreply, new_state} = EquipmentHandler.handle_unequip(index, state)
      new_state
    else
      _ -> state
    end
  end

  # Ends any active status whose `require_weapon` list no longer includes the
  # currently wielded weapon type, derived the same way `Stats` derives it.
  defp enforce_weapon_requirements(%{game_state: game_state} = state) do
    weapon_type = Stats.weapon_type(game_state.stats.equipment)
    StatusInterpreter.enforce_weapon_requirements(:player, game_state.character_id, weapon_type)
    state
  end

  # Unconditionally recomputes stats against the final state (after cart,
  # equipment and status cleanup) before healing/persisting: status removals go
  # straight to StatusStorage without touching `game_state.stats`, so the modifier
  # snapshot is only correct after this recompute. Then full-heals so the
  # deliberate job-change heal reflects the new max HP/SP.
  defp finish_job_change(%{game_state: game_state} = state, job_id, previous_game_state) do
    stats =
      game_state.stats
      |> Stats.calculate_stats(game_state.character_id)
      |> full_heal()
      |> fill_ap()

    game_state = %{game_state | stats: stats}
    progression = stats.progression

    StatusSync.send_param(state.connection_pid, StatusParams.job_level(), progression.job_level)
    push_ap_params(state.connection_pid, stats)
    broadcast_sprite(game_state, job_id)
    MessageRouter.send_to(state.connection_pid, SkillListView.build(progression))

    {:noreply, new_state} =
      commit_from(previous_game_state, state, game_state, progression,
        class: job_id,
        learned_skills: Learned.dump(progression.learned_skills)
      )

    {:ok, new_state}
  end

  # Same unconditional final recompute as the job-change path (dropped-skill
  # status removals bypass `game_state.stats`). No full heal on a reset, but the
  # vitals are clamped in case a removed buff (e.g. Angelus) lowered max HP/SP
  # below the current values, then the recomputed stats are synced to the client
  # and persisted through the shared `commit/4` path.
  defp finish_reset_skills(%{game_state: game_state} = state, previous_game_state) do
    stats =
      game_state.stats
      |> Stats.calculate_stats(game_state.character_id)
      |> clamp_vitals()

    game_state = %{game_state | stats: stats}
    progression = stats.progression

    MessageRouter.send_to(state.connection_pid, SkillListView.build(progression))

    {:noreply, new_state} =
      commit_from(previous_game_state, state, game_state, progression,
        learned_skills: Learned.dump(progression.learned_skills)
      )

    {:ok, new_state}
  end

  defp broadcast_sprite(game_state, job_id) do
    sprite = %SpriteChange{
      gid: game_state.character_id,
      type: LookType.base(),
      val: job_id,
      val2: 0
    }

    Broadcast.to_player(game_state.character_id, sprite)
    Broadcast.to_visible_players(game_state, sprite, exclude_id: game_state.character_id)
  end

  defp commit(state, game_state, progression, extra_persist \\ []) do
    commit_from(state.game_state, state, game_state, progression, extra_persist)
  end

  defp commit_from(previous_game_state, state, game_state, progression, extra_persist) do
    new_state = %{state | game_state: game_state}

    sync_client(new_state, progression)
    persist(game_state, extra_persist)
    new_state = StateCommit.commit(%{state | game_state: previous_game_state}, game_state)

    {:noreply, new_state}
  end

  defp full_heal(stats) do
    current = %{
      stats.current_state
      | hp: stats.derived_stats.max_hp,
        sp: stats.derived_stats.max_sp
    }

    %{stats | current_state: current}
  end

  # A job change starts AP full at the recomputed max (spec: AP starts full).
  # Non-trait jobs have max_ap 0, so this clears any stale AP on leaving.
  defp fill_ap(stats) do
    %{stats | current_state: %{stats.current_state | ap: stats.derived_stats.max_ap}}
  end

  # Pushes the AP pool and the flat trait-stat raise-cost indicators (upow..ucrt = 1)
  # after a job change; trait_point itself already flows through sync_client.
  defp push_ap_params(connection_pid, stats) do
    StatusSync.send_params(connection_pid, %{
      StatusParams.ap() => stats.current_state.ap,
      StatusParams.max_ap() => stats.derived_stats.max_ap,
      StatusParams.upow() => 1,
      StatusParams.usta() => 1,
      StatusParams.uwis() => 1,
      StatusParams.uspl() => 1,
      StatusParams.ucon() => 1,
      StatusParams.ucrt() => 1
    })
  end

  # Caps current HP/SP at the (possibly reduced) maxima without healing, for the
  # skill-reset path where a removed buff can lower max HP/SP below the current
  # value.
  defp clamp_vitals(stats) do
    current = %{
      stats.current_state
      | hp: min(stats.current_state.hp, stats.derived_stats.max_hp),
        sp: min(stats.current_state.sp, stats.derived_stats.max_sp)
    }

    %{stats | current_state: current}
  end

  defp sync_client(state, progression) do
    game_state = state.game_state
    StatusSync.send_stat_updates(state.connection_pid, game_state.stats)

    StatusSync.send_params(state.connection_pid, %{
      StatusParams.next_base_exp() => Leveling.next_base_exp(progression),
      StatusParams.next_job_exp() => Leveling.next_job_exp(progression),
      StatusParams.skill_point() => progression.skill_point,
      StatusParams.status_point() => progression.status_point,
      StatusParams.trait_point() => progression.trait_point,
      StatusParams.weight() => Weight.current_weight(game_state.inventory),
      StatusParams.max_weight() => Weight.max_weight(game_state.stats)
    })
  end

  defp persist(game_state, extra) do
    stats = game_state.stats

    fields =
      %{
        base_level: stats.progression.base_level,
        job_level: stats.progression.job_level,
        base_exp: stats.progression.base_exp,
        job_exp: stats.progression.job_exp,
        hp: stats.current_state.hp,
        sp: stats.current_state.sp,
        max_hp: stats.derived_stats.max_hp,
        max_sp: stats.derived_stats.max_sp,
        skill_point: stats.progression.skill_point,
        status_point: stats.progression.status_point,
        trait_point: stats.progression.trait_point,
        str: stats.base_stats.str,
        agi: stats.base_stats.agi,
        vit: stats.base_stats.vit,
        int: stats.base_stats.int,
        dex: stats.base_stats.dex,
        luk: stats.base_stats.luk,
        ap: stats.current_state.ap,
        max_ap: stats.derived_stats.max_ap,
        pow: stats.base_stats.pow,
        sta: stats.base_stats.sta,
        wis: stats.base_stats.wis,
        spl: stats.base_stats.spl,
        con: stats.base_stats.con,
        crt: stats.base_stats.crt
      }
      |> Map.merge(Map.new(extra))

    CharacterPersistence.update_character(game_state.character_id, fields, async: true)
  end

  defp job_for(progression) do
    with {:ok, name} <- AvailableJobs.job_id_to_name(progression.job_id) do
      JobManagement.get_job_by_name(name)
    end
  end
end
