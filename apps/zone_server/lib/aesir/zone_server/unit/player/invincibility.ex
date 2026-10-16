defmodule Aesir.ZoneServer.Unit.Player.Invincibility do
  @moduledoc """
  A player's invincibility after a map load or a revive.

  While it runs, nothing that checks its target can pick the player: enemy and
  field target checks, ground-unit strikes, monster AI and the completion of
  attack skills refuse them. It lasts the map's invincible time, or
  `default_time/0` when the map sets none, and restarts in full when started
  again. It ends at its deadline, or early when the player asks to walk,
  attack or use a skill and that request gets past its own preconditions
  (`end_on_request/2`). Either way the ground units under the player then act
  on its arrival, as long as the player stands on a map.

  The owning session is the only writer: every lifecycle function takes and
  returns its state. The timer reference is published on the player's registry
  snapshot, so `active?/1` answers from any process.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cooldown
  alias Aesir.ZoneServer.Mmo.Skill.Ground.Trigger
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Npc.Proximity
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @default_time 3000
  @vending 41
  @teleport 26
  @warp 27
  @cast_cancel 275
  @emergency_calls [10_013, 10_015]
  @autospell 279
  @basilica 361
  @stone_wait 6
  @burning 7

  @typedoc """
  A client request that may end the invincibility: a walk, a normal attack, or
  a skill aimed at a unit or at the ground.
  """
  @type request :: :walk | :attack | {:skill, integer()} | {:ground_skill, integer()}

  @doc "The invincible time of a map that sets none, in milliseconds."
  @spec default_time() :: non_neg_integer()
  def default_time, do: @default_time

  @doc """
  Whether the player is invincible. Accepts the player's own state, a typed
  reference, or any map naming the unit; a non-player is never invincible.
  """
  @spec active?(PlayerState.t() | {atom(), term()} | map() | nil) :: boolean()
  def active?(%PlayerState{invincible_timer: timer}), do: timer != nil
  def active?({:player, id}), do: registered_active?(id)
  def active?(%{unit_type: :player, unit_id: id}), do: registered_active?(id)
  def active?(_unit), do: false

  defp registered_active?(id) do
    case UnitRegistry.get_unit(:player, id) do
      {:ok, {_module, %PlayerState{} = state, _pid}} -> active?(state)
      _missing -> false
    end
  end

  @doc """
  Starts the invincibility for the map the player is on, replacing a running
  one. A non-positive time starts nothing and leaves a running one alone.
  """
  @spec start(SessionState.t()) :: SessionState.t()
  def start(%{game_state: %PlayerState{} = game_state} = state) do
    case duration(game_state.map_name) do
      time when time > 0 -> arm(state, time)
      _none -> state
    end
  end

  @doc """
  Starts the invincibility on a finished map load. When none runs afterwards,
  the ground units under the player act on its arrival right away, once the
  player has re-entered the map.
  """
  @spec start_on_map_load(SessionState.t()) :: SessionState.t()
  def start_on_map_load(state) do
    state = start(state)
    unless active?(state.game_state), do: send(self(), {:invincibility, :appear})
    state
  end

  @doc "Ends a running invincibility early; a player without one is unchanged."
  @spec stop(SessionState.t()) :: SessionState.t()
  def stop(%{game_state: %PlayerState{invincible_timer: nil}} = state), do: state

  def stop(%{game_state: %PlayerState{invincible_timer: timer} = game_state} = state) do
    Process.cancel_timer(timer)
    state |> clear(game_state) |> appear()
  end

  @doc """
  Ends the invincibility when the request gets past the preconditions that
  come before the end for that kind of request. A request refused earlier
  (a stunned walk, a skill while sitting or casting, any act while a dialog,
  shop, storage or vending window is open) leaves it running.
  """
  @spec end_on_request(SessionState.t(), request()) :: SessionState.t()
  def end_on_request(%{game_state: %PlayerState{invincible_timer: timer}} = state, request)
      when timer != nil do
    if ends_on?(state, request), do: stop(state), else: state
  end

  def end_on_request(state, _request), do: state

  @doc """
  Handles the session's `{:invincibility, event}` messages: the timer's
  deadline (stale generations are ignored) and the deferred arrival of a map
  load that started no timer.
  """
  @spec handle_info(term(), SessionState.t()) :: {:noreply, SessionState.t()}
  def handle_info(
        {:expire, generation},
        %{
          game_state:
            %PlayerState{invincible_generation: generation, invincible_timer: timer} = game_state
        } = state
      )
      when timer != nil,
      do: {:noreply, state |> clear(game_state) |> appear()}

  def handle_info({:expire, _stale}, state), do: {:noreply, state}

  def handle_info(:appear, state) do
    if active?(state.game_state), do: {:noreply, state}, else: {:noreply, appear(state)}
  end

  def handle_info(_event, state), do: {:noreply, state}

  defp duration(map_name) do
    case MapFlags.invincible_time(map_name) do
      time when is_integer(time) and time > 0 -> time
      _none -> __MODULE__.default_time()
    end
  end

  defp arm(%{game_state: game_state} = state, time) do
    if game_state.invincible_timer, do: Process.cancel_timer(game_state.invincible_timer)
    generation = game_state.invincible_generation + 1
    timer = Process.send_after(self(), {:invincibility, {:expire, generation}}, time)

    StateCommit.commit(state, %{
      game_state
      | invincible_timer: timer,
        invincible_generation: generation
    })
  end

  defp clear(state, game_state) do
    StateCommit.commit(state, %{
      game_state
      | invincible_timer: nil,
        invincible_generation: game_state.invincible_generation + 1
    })
  end

  # Only a player standing on its map has ground units to arrive on.
  defp appear(%{game_state: %PlayerState{pending_map_load: nil} = game_state} = state) do
    %PlayerState{character_id: id, map_name: map_name} = game_state

    case SpatialIndex.get_unit_position(:player, id) do
      {:ok, {x, y, ^map_name}} -> Trigger.on_appear({:player, id}, map_name, x, y)
      _off_map -> :ok
    end

    state
  end

  defp appear(state), do: state

  defp ends_on?(state, :walk) do
    alive?(state) and
      (body_state(state) in [@stone_wait, @burning] or can_act?(state, [0, @burning]))
  end

  defp ends_on?(state, :attack), do: alive?(state) and can_act?(state, [0, @burning])

  defp ends_on?(state, {:skill, skill_id}) do
    item? = item_skill?(state, skill_id)

    target_type(skill_id) not in [nil, :ground, :passive] and
      skill_act_allowed?(state, skill_id) and not sitting?(state) and
      not skill_not_ok?(state, skill_id) and
      skill_ready?(state, skill_id, item?, [@cast_cancel]) and
      not basilica_locked?(state, skill_id) and
      not menu_open?(state) and
      not (item? and target_type(skill_id) == :self)
  end

  defp ends_on?(state, {:ground_skill, skill_id}) do
    can_act?(state, [0, @burning]) and not sitting?(state) and
      target_type(skill_id) == :ground and
      not skill_not_ok?(state, skill_id) and
      skill_ready?(state, skill_id, item_skill?(state, skill_id), []) and
      not basilica_locked?(state, skill_id) and
      not menu_open?(state)
  end

  # The cooldown and map restrictions that refuse a skill request outright; an
  # item skill passes the map restrictions.
  defp skill_not_ok?(state, skill_id) do
    %PlayerState{map_name: map_name, skill_cooldowns: cooldowns} = state.game_state

    cond do
      not Cooldown.ready?(cooldowns, skill_id, System.monotonic_time(:millisecond)) -> true
      item_skill_bypass?(state, skill_id) -> false
      skill_id == @warp -> MapFlags.get(map_name, :nowarp)
      skill_id == @teleport -> MapFlags.get(map_name, :noteleport)
      skill_id in @emergency_calls -> not Rules.ground?(map_name)
      skill_id == @vending -> npc_near?(state.game_state)
      true -> false
    end
  end

  defp item_skill_bypass?(%{pending_item_skill: %{skill_id: skill_id} = item}, skill_id),
    do: not item.keep_requirement?

  defp item_skill_bypass?(_state, _skill_id), do: false

  # Any request but a walk is refused while a dialog, chat room, trade, vending
  # stall or storage window is open, or while a body state other than those
  # listed holds the player.
  defp can_act?(state, free_body_states),
    do: not dialog_open?(state) and not busy?(state, free_body_states)

  defp busy?(state, free_body_states) do
    state.trade != nil or state.game_state.waiting_room != nil or
      state.game_state.action_state == :vending or storage_open?(state) or
      body_state(state) not in free_body_states
  end

  # A skill aimed at a unit gets past every busy state while a storage window
  # is open, as long as it targets the caster itself. An open dialog lets
  # nothing through that would end the invincibility.
  defp skill_act_allowed?(state, skill_id) do
    not dialog_open?(state) and
      (not busy?(state, [0, @burning]) or (storage_open?(state) and self_skill?(skill_id)))
  end

  defp skill_ready?(state, skill_id, item?, cast_exceptions) do
    if state.game_state.casting do
      skill_id in cast_exceptions
    else
      item? or PlayerState.act_ready?(state.game_state, System.monotonic_time(:millisecond))
    end
  end

  defp basilica_locked?(state, skill_id) do
    id = state.game_state.character_id

    GameMode.mode() == :pre_renewal and
      (StatusStorage.has_status?(:player, id, :sc_basilica) or
         (skill_id != @basilica and StatusStorage.has_status?(:player, id, :sc_basilica_caster)))
  end

  defp menu_open?(%{pending_skill_menu: %{skill_id: @autospell}}), do: false
  defp menu_open?(%{pending_skill_menu: menu}), do: menu != nil

  defp item_skill?(%{pending_item_skill: %{skill_id: skill_id}}, skill_id), do: true
  defp item_skill?(_state, _skill_id), do: false

  defp npc_near?(%PlayerState{map_name: map_name, x: x, y: y}),
    do: Proximity.npc_near?(map_name, x, y)

  defp self_skill?(skill_id), do: target_type(skill_id) == :self

  # Vending is a self skill whose use the shop-open request carries.
  defp target_type(@vending), do: :self

  defp target_type(skill_id) do
    case Catalog.by_id(skill_id) do
      {:ok, %{target_type: target_type}} -> target_type
      :error -> nil
    end
  end

  defp dialog_open?(state), do: state.interaction_lock != nil

  defp storage_open?(state),
    do: state.game_state.storage != nil or state.guild_storage_ctx != nil

  defp sitting?(state), do: state.game_state.action_state == :sitting
  defp alive?(state), do: state.game_state.action_state != :dead

  defp body_state(state),
    do: StatusDisplay.spawn_state(:player, state.game_state.character_id).body_state
end
