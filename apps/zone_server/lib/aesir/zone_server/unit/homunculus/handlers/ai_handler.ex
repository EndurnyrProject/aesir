defmodule Aesir.ZoneServer.Unit.Homunculus.Handlers.AiHandler do
  @moduledoc """
  Builds live Homunculus AI snapshots and executes one pure decision per tick.
  """

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.Decision
  alias Aesir.ZoneServer.Mmo.Skill.Catalog, as: SkillCatalog
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Homunculus.Clock
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CastingHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CombatHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CommandHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.HungerHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.StateCommit
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @tick_interval 500

  @doc "Arms exactly one AI timer for an active living Homunculus."
  @spec arm(SessionState.t()) :: SessionState.t()
  def arm(%SessionState{} = session) do
    session = cancel(session)

    if eligible?(session) do
      ref = :erlang.start_timer(@tick_interval, self(), {:homunculus, :ai_tick})
      %{session | homunculus_runtime: %{session.homunculus_runtime | ai_timer_ref: ref}}
    else
      session
    end
  end

  @doc "Cancels the current AI chain without affecting other Homunculus clocks."
  @spec cancel(SessionState.t()) :: SessionState.t()
  def cancel(%SessionState{} = session) do
    Clock.cancel(session.homunculus_runtime.ai_timer_ref)
    %{session | homunculus_runtime: %{session.homunculus_runtime | ai_timer_ref: nil}}
  end

  @doc "Consumes one matching timer, executes at most one intent, and rearms once."
  @spec tick(reference(), SessionState.t()) ::
          {:noreply, SessionState.t()} | {:stop, term(), SessionState.t()}
  def tick(ref, %SessionState{} = session) do
    if session.homunculus_runtime.ai_timer_ref == ref and eligible?(session) do
      session = %{session | homunculus_runtime: %{session.homunculus_runtime | ai_timer_ref: nil}}
      candidates = candidates(session)

      intent =
        Decision.next(
          owner_snapshot(session, candidates),
          homunculus_snapshot(session, candidates),
          candidates
        )

      case execute(intent, session) do
        {:noreply, updated} ->
          updated =
            updated
            |> MovementHandler.sync_separation()
            |> arm()
            |> CommandHandler.publish_private_state_if_dirty()

          {:noreply, updated}

        {:stop, _reason, _state} = stop ->
          stop
      end
    else
      {:noreply, session}
    end
  end

  defp execute(:idle, session), do: {:noreply, session}

  defp execute(:feed, session) do
    inventory = session.game_state.inventory

    case HungerHandler.food_index(session.homunculus.class_id, inventory) do
      {:ok, index} ->
        case HungerHandler.auto_feed(
               session.homunculus,
               session.homunculus_runtime,
               inventory
             ) do
          {:ok, homunculus, runtime, new_inventory} ->
            session = %{
              session
              | game_state: %{session.game_state | inventory: new_inventory},
                homunculus_runtime: runtime
            }

            committed = StateCommit.commit(session, homunculus)
            MessageRouter.send_to(session.connection_pid, InventoryView.item_removed(index, 1))
            {:noreply, committed}

          {:noop, _homunculus, runtime, ^inventory} ->
            {:noreply, %{session | homunculus_runtime: runtime}}

          {:error, _reason, _homunculus, runtime, ^inventory} ->
            {:noreply, %{session | homunculus_runtime: runtime}}
        end

      {:error, _reason} ->
        {:noreply, session}
    end
  end

  defp execute({:follow, _owner_ref}, session), do: {:noreply, MovementHandler.follow(session)}

  defp execute({:chase, target_ref}, session),
    do: {:noreply, MovementHandler.chase(session, target_ref)}

  defp execute({:attack, target_ref}, session) do
    CombatHandler.handle(
      {:basic_attack, session.homunculus.world_gid, target_ref},
      session
    )
  end

  defp execute({:cast, id, level, target_ref}, session) do
    target =
      if target_ref == {:homunculus, session.homunculus.world_gid},
        do: :self,
        else: {:unit, target_ref}

    case CastingHandler.begin(session, id, level, target) do
      {:ok, updated} -> {:noreply, updated}
      {:error, _reason, unchanged} -> {:noreply, unchanged}
      {:stop, _reason, _state} = stop -> stop
    end
  end

  defp eligible?(%SessionState{} = session) do
    match?(%HomunculusState{}, session.homunculus) and
      HomunculusState.living?(session.homunculus)
  end

  defp owner_snapshot(session, candidates) do
    owner = session.game_state
    {hp, max_hp} = owner_health(owner.stats)

    %{
      ref: {:player, owner.character_id},
      position: {owner.x, owner.y},
      hp: hp,
      max_hp: max_hp,
      alive?: Unit.living?(owner),
      target: owner_target(owner.combat_target_id, candidates)
    }
  end

  defp owner_health(%{current_state: %{hp: hp}, derived_stats: %{max_hp: max_hp}})
       when is_integer(hp) and is_integer(max_hp),
       do: {hp, max_hp}

  defp owner_health(_stats), do: {0, 1}

  defp homunculus_snapshot(session, candidates) do
    homunculus = session.homunculus

    %{
      ref: {:homunculus, homunculus.world_gid},
      lifecycle: homunculus.lifecycle,
      alive?: HomunculusState.living?(homunculus),
      busy?: homunculus.action_state == :casting,
      position: {homunculus.x, homunculus.y},
      hp: homunculus.hp,
      max_hp: homunculus.max_hp,
      sp: homunculus.sp,
      max_sp: homunculus.max_sp,
      hunger: homunculus.hunger,
      food_available?:
        HungerHandler.food_available?(homunculus.class_id, session.game_state.inventory),
      standby?: homunculus.standby?,
      target: retained_target(homunculus.target, candidates),
      retaliation_target: retaliation_target(session, candidates),
      attack_range: homunculus.attack_range,
      separated_ms: nil,
      ai_config: homunculus.ai_config,
      skills: skill_snapshots(homunculus)
    }
  end

  defp candidates(%SessionState{} = session) do
    homunculus = session.homunculus
    range = Config.view_range()

    :mob
    |> SpatialIndex.get_units_in_range(homunculus.map_name, homunculus.x, homunculus.y, range)
    |> Enum.sort()
    |> Enum.flat_map(&candidate(&1, homunculus, range))
  end

  defp candidate(id, homunculus, range) do
    with {:ok, {MobState, %MobState{} = mob, _pid}} <- UnitRegistry.get_unit(:mob, id),
         {:ok, {x, y, map}} <- SpatialIndex.get_unit_position(:mob, id),
         true <- map == homunculus.map_name,
         true <- distance({homunculus.x, homunculus.y}, {x, y}) <= range do
      [
        %{
          ref: {:mob, id},
          position: {x, y},
          hp: mob.hp,
          max_hp: mob.max_hp,
          class_id: mob.mob_id,
          boss?: MobState.is_boss?(mob),
          claim_root: claim_root(mob)
        }
      ]
    else
      _invalid -> []
    end
  end

  defp claim_root(mob) do
    case MobState.typed_damage_log(mob) do
      [%{reward_owner_id: owner_id} | _rest] when is_integer(owner_id) -> {:player, owner_id}
      _none -> nil
    end
  end

  defp owner_target(id, candidates) when is_integer(id) do
    case Enum.find(candidates, &(elem(&1.ref, 1) == id)) do
      %{ref: ref} -> ref
      nil -> nil
    end
  end

  defp owner_target(_id, _candidates), do: nil

  defp retained_target(target, candidates) when is_tuple(target) do
    if Enum.any?(candidates, &(&1.ref == target)), do: target
  end

  defp retained_target(_target, _candidates), do: nil

  defp retaliation_target(session, candidates) do
    owner_ref = {:player, session.game_state.character_id}
    homunculus_ref = {:homunculus, session.homunculus.world_gid}

    Enum.find_value(candidates, fn %{ref: {:mob, id} = ref} ->
      case UnitRegistry.get_unit(:mob, id) do
        {:ok, {MobState, %MobState{target_ref: target_ref}, _pid}}
        when target_ref == owner_ref or target_ref == homunculus_ref ->
          ref

        _other ->
          nil
      end
    end)
  end

  defp skill_snapshots(homunculus) do
    homunculus.learned_skills
    |> Enum.sort()
    |> Enum.flat_map(fn {id, level} -> skill_snapshot(id, level, homunculus) end)
  end

  defp skill_snapshot(id, level, homunculus) do
    case SkillCatalog.by_id(id) do
      {:ok, definition} ->
        case ai_target(definition.target_type) do
          {:ok, target} -> [build_skill_snapshot(id, level, target, definition, homunculus)]
          :error -> []
        end

      :error ->
        []
    end
  end

  defp build_skill_snapshot(id, level, target, definition, homunculus) do
    cost =
      case Enum.at(definition.sp_cost, level - 1, 0) do
        :all -> homunculus.sp
        value -> value
      end

    %{
      id: id,
      level: level,
      target: target,
      sp_cost: cost,
      cooldown_ready?:
        not Map.has_key?(homunculus.cooldowns, id) or
          homunculus.cooldowns[id] <= Clock.now_ms()
    }
  end

  defp ai_target(:self), do: {:ok, :self}
  defp ai_target(type) when type in [:target_ally, :target_any], do: {:ok, :owner}
  defp ai_target(:target_enemy), do: {:ok, :enemy}
  defp ai_target(_type), do: :error

  defp distance({x1, y1}, {x2, y2}), do: max(abs(x1 - x2), abs(y1 - y2))
end
