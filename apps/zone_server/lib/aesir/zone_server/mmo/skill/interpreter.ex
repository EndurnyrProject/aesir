defmodule Aesir.ZoneServer.Mmo.Skill.Interpreter do
  @moduledoc """
  Orchestrates a skill cast across two phases.

  `begin_cast/4` runs the full validation chain and computes the renewal cast
  time; a zero-cast skill resolves immediately, a timed skill returns a
  `cast_info` for the caller to schedule and leaves the game state untouched
  (no SP deducted, no cooldown set). `complete_cast/4` re-validates the target,
  re-checks SP, runs the behavior, then deducts SP, sets the cooldown, and arms
  the after-cast act delay.

  Validate-then-cast-then-charge: SP is only consumed at castend, so a failed
  or interrupted cast never charges SP. Starting any cast is blocked while the
  act delay is pending (`validate_cast` rejects with `{:error, :act_delayed}`).

  `cast/4` is the synchronous wrapper preserving the legacy single-call
  semantics: instant casts execute immediately and timed casts run their
  behavior inline through `complete_cast/4`.
  """
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.CastTime
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cooldown
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Ammo
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @typedoc """
  Scheduling info for a timed cast, returned by `begin_cast/4` when the skill
  has a non-zero cast time. `fixed` is the uninterruptible leading window and
  `total` the full duration, both in milliseconds.
  """
  @type cast_info :: %{
          skill_id: integer(),
          level: pos_integer(),
          target: Active.target(),
          element: Definition.element(),
          fixed: non_neg_integer(),
          total: non_neg_integer()
        }

  @spec cast(PlayerState.t(), integer(), pos_integer(), Active.target()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(game_state, skill_id, level, target) when is_integer(level) and level > 0 do
    case begin_cast(game_state, skill_id, level, target) do
      {:instant, game_state} -> {:ok, game_state}
      {:casting, game_state, _info} -> complete_cast(game_state, skill_id, level, target)
      {:error, _reason} = error -> error
    end
  end

  def cast(_game_state, _skill_id, _level, _target), do: {:error, :invalid_level}

  @doc """
  Validates a cast and resolves its timing.

  Runs the full validation chain (without deducting SP or running the behavior)
  and computes the cast time from the caster's base DEX/INT. A zero cast time
  resolves immediately through `complete_cast/4` and returns `{:instant, gs}`;
  otherwise returns `{:casting, gs, cast_info}` with `gs` unchanged so the
  caller can schedule the cast.

  Variable-cast reduction sums the caster's status-sourced `:cast_time_reduction`
  values (Suffragium, Bragi) and passes the total into `CastTime` as a plain
  integer, keeping `CastTime` pure.

  NOTE: cast-time reduction uses base DEX/INT only; effective/buffed DEX/INT is a
  documented later refinement.
  """
  @spec begin_cast(PlayerState.t(), integer(), pos_integer(), Active.target()) ::
          {:instant, PlayerState.t()}
          | {:casting, PlayerState.t(), cast_info()}
          | {:error, atom()}
  def begin_cast(game_state, skill_id, level, target) when is_integer(level) and level > 0 do
    now = System.monotonic_time(:millisecond)

    with {:ok, definition, _module} <- validate_cast(game_state, skill_id, level, target, now) do
      base_stats = game_state.stats.base_stats

      timing =
        CastTime.compute(definition, level, %{
          dex: base_stats.dex,
          int: base_stats.int,
          varcast_reductions: status_reductions(game_state.character_id, :cast_time_reduction)
        })

      schedule(timing, game_state, skill_id, level, target, definition)
    end
  end

  def begin_cast(_game_state, _skill_id, _level, _target), do: {:error, :invalid_level}

  # Collects each active status's stored reduction percentage as a list, for the
  # variable-cast path that applies each as a separate multiplicative factor
  # (rAthena skill_vfcastfix). Statuses without the key are skipped.
  @spec status_reductions(integer(), atom()) :: [non_neg_integer()]
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

  # Sums a stored reduction percentage (`:delay_reduction`) across the caster's
  # active statuses, for the after-cast delay path (additive sum, one multiply -
  # rAthena skill_delayfix:10491).
  @spec sum_status_reduction(integer(), atom()) :: non_neg_integer()
  defp sum_status_reduction(character_id, state_key) do
    :player
    |> StatusStorage.get_unit_statuses(character_id)
    |> Enum.reduce(0, fn entry, acc ->
      acc + Map.get(entry.state || %{}, state_key, 0)
    end)
  end

  @doc """
  Runs a previously-validated cast to completion.

  Re-validates the target (it may have moved, died, or logged out during the
  cast) and re-checks SP, then runs the behavior, deducts SP, sets the
  cooldown, and arms the after-cast act delay. A target that is gone or out of
  range fizzles with `{:error, _}` and no SP is spent.
  """
  @spec complete_cast(PlayerState.t(), integer(), pos_integer(), Active.target()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def complete_cast(game_state, skill_id, level, target) when is_integer(level) and level > 0 do
    now = System.monotonic_time(:millisecond)

    with {:ok, definition} <- fetch_definition(skill_id),
         {:ok, module} <- fetch_active_module(definition),
         :ok <- check_target(game_state, target, definition),
         :ok <- check_range(game_state, target, definition),
         cost = Enum.at(definition.sp_cost, level - 1),
         :ok <- check_sp(game_state, cost),
         :ok <- check_catalysts(game_state, definition),
         :ok <- check_ammo(game_state, definition),
         {:ok, game_state} <- run_cast(module, game_state, target, level, definition) do
      {:ok,
       game_state
       |> deduct_sp(cost)
       |> consume_ammo(definition)
       |> put_cooldown(skill_id, definition, level, now)
       |> put_act_delay(definition, level, now)}
    end
  end

  def complete_cast(_game_state, _skill_id, _level, _target), do: {:error, :invalid_level}

  @spec validate_cast(PlayerState.t(), integer(), pos_integer(), Active.target(), integer()) ::
          {:ok, Definition.t(), module()} | {:error, atom()}
  defp validate_cast(game_state, skill_id, level, target, now) do
    with {:ok, definition} <- fetch_definition(skill_id),
         :ok <- check_max_level(definition, level),
         :ok <- check_castable(definition),
         :ok <- check_learned(game_state, skill_id, level),
         :ok <- check_target(game_state, target, definition),
         :ok <- check_range(game_state, target, definition),
         {:ok, module} <- fetch_active_module(definition),
         :ok <- check_cooldown(game_state, skill_id, now),
         :ok <- check_act_delay(game_state, now),
         :ok <- module.validate(game_state, target, level, definition),
         cost = Enum.at(definition.sp_cost, level - 1),
         :ok <- check_sp(game_state, cost) do
      {:ok, definition, module}
    end
  end

  @spec schedule(
          CastTime.result(),
          PlayerState.t(),
          integer(),
          pos_integer(),
          Active.target(),
          Definition.t()
        ) ::
          {:instant, PlayerState.t()}
          | {:casting, PlayerState.t(), cast_info()}
          | {:error, atom()}
  defp schedule(%{total: 0}, game_state, skill_id, level, target, _definition) do
    case complete_cast(game_state, skill_id, level, target) do
      {:ok, game_state} -> {:instant, game_state}
      {:error, _reason} = error -> error
    end
  end

  defp schedule(%{fixed: fixed, total: total}, game_state, skill_id, level, target, definition) do
    info = %{
      skill_id: skill_id,
      level: level,
      target: target,
      element: definition.element,
      fixed: fixed,
      total: total
    }

    {:casting, game_state, info}
  end

  defp fetch_definition(skill_id) do
    case Catalog.by_id(skill_id) do
      {:ok, definition} -> {:ok, definition}
      :error -> {:error, :unknown_skill}
    end
  end

  defp check_max_level(definition, level) when level <= definition.max_level, do: :ok
  defp check_max_level(_definition, _level), do: {:error, :invalid_level}

  defp check_castable(%{target_type: :passive}), do: {:error, :passive_skill}
  defp check_castable(_definition), do: :ok

  defp fetch_active_module(definition) do
    case Catalog.active_module_for(definition.name) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, :no_behavior}
    end
  end

  defp check_learned(game_state, skill_id, level) do
    learned = game_state.stats.progression.learned_skills

    if Learned.learned_level(learned, skill_id) >= level do
      :ok
    else
      {:error, :skill_not_learned}
    end
  end

  # Enemy skills reject self-target; ally skills accept any friendly unit (self included).
  defp check_target(%{character_id: caster_id}, {:unit, caster_id}, %{target_type: :target_enemy}),
       do: {:error, :invalid_target}

  # An enemy-targeted skill must not hit a friendly player. With PvP unimplemented,
  # only mobs are valid enemies; a player target is rejected. A target that cannot
  # be resolved falls through so `check_range` reports it as `:target_not_found`.
  defp check_target(_game_state, {:unit, target_id}, %{target_type: :target_enemy}) do
    case unit_type_of(target_id) do
      :player -> {:error, :invalid_target}
      _ -> :ok
    end
  end

  defp check_target(_game_state, {:unit, _id}, %{target_type: target_type})
       when target_type in [:target_ally, :target_any],
       do: :ok

  defp check_target(_game_state, {:ground, _x, _y}, %{target_type: :ground}), do: :ok

  defp check_target(_game_state, :self, _definition), do: :ok
  defp check_target(%{character_id: caster_id}, {:unit, caster_id}, _definition), do: :ok
  defp check_target(_game_state, _target, _definition), do: {:error, :invalid_target}

  defp check_range(_game_state, :self, _definition), do: :ok

  defp check_range(game_state, {:unit, target_id}, definition) do
    range = effective_range(definition, game_state)

    case resolve_unit_position(target_id) do
      {:ok, {tx, ty, target_map}} ->
        cond do
          target_map != game_state.map_name ->
            {:error, :different_map}

          Geometry.chebyshev_distance(game_state.x, game_state.y, tx, ty) <= range ->
            :ok

          true ->
            {:error, :out_of_range}
        end

      {:error, _} ->
        {:error, :target_not_found}
    end
  end

  defp check_range(game_state, {:ground, x, y}, definition) do
    with :ok <- check_ground_range(game_state, x, y, definition) do
      check_ground_walkable(game_state.map_name, x, y)
    end
  end

  defp check_ground_range(game_state, x, y, definition) do
    range = effective_range(definition, game_state)

    if Geometry.chebyshev_distance(game_state.x, game_state.y, x, y) <= range,
      do: :ok,
      else: {:error, :out_of_range}
  end

  @doc """
  The cast-range of a skill for a given caster, in cells (Chebyshev).

  rAthena encodes melee skills as `range: -1` ("use the weapon's range"); that is
  resolved to the caster's equipped-weapon attack range at cast time. Exposed so
  the session handler can size the move-to-range approach for an out-of-range cast.
  """
  @spec effective_range(Definition.t(), PlayerState.t()) :: non_neg_integer()
  def effective_range(%{range: range}, _game_state) when range >= 0, do: range

  def effective_range(_definition, %{stats: %{equipment: equipment}}) do
    equipment
    |> PlayerStats.weapon_type()
    |> WeaponTypes.get_attack_range()
  end

  defp check_ground_walkable(map_name, x, y) do
    with {:ok, map} <- MapCache.get(map_name),
         true <- MapData.walkable?(map, x, y) do
      :ok
    else
      _ -> {:error, :invalid_target}
    end
  end

  defp resolve_unit_position(unit_id) do
    case SpatialIndex.get_unit_position(:player, unit_id) do
      {:ok, _} = result -> result
      {:error, :not_found} -> SpatialIndex.get_unit_position(:mob, unit_id)
    end
  end

  defp unit_type_of(unit_id) do
    case SpatialIndex.get_unit_position(:mob, unit_id) do
      {:ok, _} ->
        :mob

      {:error, :not_found} ->
        case SpatialIndex.get_unit_position(:player, unit_id) do
          {:ok, _} -> :player
          {:error, :not_found} -> :not_found
        end
    end
  end

  defp check_cooldown(game_state, skill_id, now) do
    if Cooldown.ready?(game_state.skill_cooldowns, skill_id, now) do
      :ok
    else
      {:error, :on_cooldown}
    end
  end

  defp check_act_delay(game_state, now) do
    if PlayerState.act_ready?(game_state, now), do: :ok, else: {:error, :act_delayed}
  end

  defp check_sp(game_state, cost) do
    if game_state.stats.current_state.sp >= cost, do: :ok, else: {:error, :insufficient_sp}
  end

  # Verifies the caster holds every declared catalyst (summed across stacks)
  # before the behavior runs, so a failed catalyst check spends no SP.
  defp check_catalysts(game_state, %{item_cost: item_cost}) do
    if Enum.all?(item_cost, fn %{id: id, amount: amount} ->
         Inventory.held_amount(game_state.inventory, id) >= amount
       end) do
      :ok
    else
      {:error, :missing_catalyst}
    end
  end

  # Verifies an arrow is equipped before the behavior runs, so a failed ammo
  # check spends no SP (mirrors check_catalysts). Non-ammo skills always pass.
  defp check_ammo(game_state, definition) do
    if definition.requires_ammo and Ammo.equipped_ammo_index(game_state.inventory) == nil do
      {:error, :no_ammo}
    else
      :ok
    end
  end

  # Removes one equipped arrow on a successful cast, recording the change on
  # `:pending_inventory_persist` for the handler to write through (same shape as
  # consume_catalysts). Non-ammo skills are a no-op.
  defp consume_ammo(game_state, definition) do
    if definition.requires_ammo do
      take_one_arrow(game_state)
    else
      game_state
    end
  end

  defp take_one_arrow(game_state) do
    case Ammo.consume_one(game_state.inventory) do
      {:ok, new_inventory, change} ->
        game_state
        |> Map.put(:inventory, new_inventory)
        |> Map.update!(
          :pending_inventory_persist,
          &(&1 ++ [{game_state.inventory, new_inventory, change}])
        )

      {:error, _reason} ->
        game_state
    end
  end

  # Runs the behavior and, on a bare `{:ok, state}`, consumes the catalysts.
  # `{:ok, state, :no_consume}` completes the cast but spares them.
  defp run_cast(module, game_state, target, level, definition) do
    case module.cast(game_state, target, level, definition) do
      {:ok, game_state} -> {:ok, consume_catalysts(game_state, definition)}
      {:ok, game_state, :no_consume} -> {:ok, game_state}
      {:error, _reason} = error -> error
    end
  end

  # Purely removes each catalyst from `game_state.inventory`, accumulating the
  # per-step change descriptors onto `:pending_inventory_persist` for the
  # handler to write through (mirrors how deducted SP is persisted downstream).
  defp consume_catalysts(game_state, %{item_cost: item_cost}) do
    Enum.reduce(item_cost, game_state, fn %{id: id, amount: amount}, gs ->
      remove_item(gs, id, amount)
    end)
  end

  defp remove_item(game_state, _id, 0), do: game_state

  defp remove_item(game_state, id, amount) do
    case Inventory.stackable_index(game_state.inventory, id) do
      nil ->
        game_state

      index ->
        take = min(amount, game_state.inventory[index].amount)
        {:ok, new_inventory, change} = Inventory.remove(game_state.inventory, index, take)

        game_state
        |> Map.put(:inventory, new_inventory)
        |> Map.update!(
          :pending_inventory_persist,
          &(&1 ++ [{game_state.inventory, new_inventory, change}])
        )
        |> remove_item(id, amount - take)
    end
  end

  # Player SP lives in the nested current_state; mutate it inline (same pattern
  # as HealthHandler), since consume_sp is defined on Unit.Stats, not Player.Stats.
  defp deduct_sp(game_state, cost) do
    stats = game_state.stats
    current = %{stats.current_state | sp: stats.current_state.sp - cost}
    %{game_state | stats: %{stats | current_state: current}}
  end

  defp put_cooldown(game_state, skill_id, definition, level, now) do
    case Cooldown.duration(definition, level) do
      0 ->
        game_state

      duration ->
        cooldowns = Cooldown.put(game_state.skill_cooldowns, skill_id, now + duration)
        %{game_state | skill_cooldowns: cooldowns}
    end
  end

  # After-cast act delay (rAthena AfterCastActDelay) reduced by delay-rate sources
  # (Bragi `:delay_reduction`), not ASPD. Reduction floors the delay at 0.
  defp put_act_delay(game_state, definition, level, now) do
    case Enum.at(definition.after_cast_delay, level - 1) do
      nil ->
        game_state

      0 ->
        game_state

      base ->
        reduction = sum_status_reduction(game_state.character_id, :delay_reduction)
        delay = max(0, round(base * (100 - reduction) / 100))
        %{game_state | act_delay_until: now + delay}
    end
  end
end
