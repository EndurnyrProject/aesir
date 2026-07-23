defmodule Aesir.ZoneServer.Unit.Player.Handlers.MountHandler do
  @moduledoc """
  Mounts/dismounts the Peco-Peco and restores the mount on spawn (design
  "Mount / dismount / restore lifecycle").

  `PlayerSession` is the single writer; every public function takes and returns
  the session `state` map and runs inside a `handle_cast` (or, for
  `load_on_spawn/2`, inside `init/1`). The `SC_RIDING` status apply/remove is
  routed through `StatusManager` so the speed + ASPD recalc and the option
  sprite broadcast happen exactly as for any other status.

  ## State model

  `SC_RIDING` carries the static `:riding` option, so the generic status display
  path (`StatusDisplay.on_applied/on_removed`) broadcasts the mounted sprite on
  its own; no explicit `broadcast_state/2` is needed here. Runtime riding truth
  is the `:riding` bit of `game_state.option`, the single writer's authoritative
  in-memory copy of the persisted `Character.option`. Mount/dismount flip that
  one bit and persist the whole recomputed option value; because the session is
  the sole writer of its character's option, the in-memory value is never a
  stale snapshot, so writing it back can never clobber another bit.

  `load_on_spawn/2` is an exception to the GenServer-native dispatch contract:
  it runs inside `init/1`, before the GenServer loop starts, so it takes and
  returns bare session `state` rather than a GenServer tuple.
  """

  import Bitwise

  require Logger

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.MountResult
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.Skills.Knight.KnCavaliermastery
  alias Aesir.ZoneServer.Mmo.Skills.Knight.KnRiding
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatsManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @status_id :sc_riding
  @kn_riding_id KnRiding.definition().id
  @kn_cavaliermastery_id KnCavaliermastery.definition().id
  @riding_bit Option.id(:riding)

  @doc """
  Mounts the Peco-Peco.

  Requires `KN_RIDING` learned, the player alive, and not already mounted;
  each failed gate replies with the matching `MountResult` code and leaves the
  state untouched. On success it applies the permanent `SC_RIDING` (`val1` =
  the learned Cavalier Mastery level, which buys back the ASPD penalty), sets
  the `:riding` option bit, persists the recomputed `Character.option`, and
  confirms with `MountResult{MOUNT_OK}`.
  """
  @spec mount(map()) :: {:noreply, map()}
  def mount(%{game_state: game_state} = state) do
    cond do
      not riding_learned?(game_state) ->
        reject(state, :MOUNT_SKILL_NOT_LEARNED)

      not PlayerState.living?(game_state) ->
        reject(state, :MOUNT_DEAD)

      riding?(state) ->
        reject(state, :MOUNT_ALREADY_MOUNTED)

      true ->
        do_mount(state)
    end
  end

  @doc """
  Dismounts the Peco-Peco.

  When mounted it removes `SC_RIDING`, clears the `:riding` option bit, persists
  the recomputed option, and confirms with `MountResult{MOUNT_OK}`. A dismount
  request while not mounted is a no-op success reported as `MOUNT_NOT_MOUNTED`.
  """
  @spec dismount(map()) :: {:noreply, map()}
  def dismount(state) do
    if riding?(state) do
      do_dismount(state)
    else
      reject(state, :MOUNT_NOT_MOUNTED)
    end
  end

  @doc """
  Restores a mounted Peco-Peco on spawn.

  When the persisted `character.option` has the `:riding` bit it re-applies
  `SC_RIDING` (`val1` = learned Cavalier Mastery level) so the sprite folds into
  the spawn `effect_state` and the speed/ASPD modifiers are recomputed. It does
  not re-persist: `game_state.option` already carries the bit via
  `PlayerState.new/1`. Returns the committed session state.
  """
  @spec load_on_spawn(Character.t(), map()) :: map()
  def load_on_spawn(%Character{option: option}, state) when (option &&& @riding_bit) != 0 do
    apply_riding_status(state)
  end

  def load_on_spawn(%Character{}, state), do: state

  @doc """
  Re-applies `SC_RIDING` with a fresh `val1` while mounted, for the moment
  Cavalier Mastery is learned or raised mid-ride so the ASPD penalty updates
  immediately. A no-op when the player is not mounted.
  """
  @spec recompute(map()) :: map()
  def recompute(state) do
    if riding?(state), do: apply_riding_status(state), else: state
  end

  @doc """
  Whether the player is currently mounted, read from the `:riding` bit of
  `game_state.option` (the single writer's authoritative in-memory copy).
  """
  @spec riding?(map()) :: boolean()
  def riding?(%{game_state: %{option: option}}), do: (option &&& @riding_bit) != 0

  @spec do_mount(map()) :: {:noreply, map()}
  defp do_mount(%{game_state: game_state} = state) do
    char_id = game_state.character_id
    new_option = game_state.option ||| @riding_bit

    case StatusManager.handle_apply_status(@status_id, [val1: cavalier_level(game_state)], state) do
      {:reply, :ok, applied} ->
        persist_option(char_id, new_option)
        committed = commit_option(applied, new_option)
        MessageRouter.send_to(committed.connection_pid, %MountResult{result: :MOUNT_OK})
        {:noreply, committed}

      {:reply, {:error, reason}, unchanged} ->
        Logger.warning("Mount: SC_RIDING apply failed for #{char_id}: #{inspect(reason)}")
        {:noreply, unchanged}
    end
  end

  @spec do_dismount(map()) :: {:noreply, map()}
  defp do_dismount(%{game_state: game_state} = state) do
    char_id = game_state.character_id
    new_option = game_state.option &&& bnot(@riding_bit)

    {:reply, :ok, removed} = StatusManager.handle_remove_status(@status_id, state)
    persist_option(char_id, new_option)
    committed = commit_option(removed, new_option)
    MessageRouter.send_to(committed.connection_pid, %MountResult{result: :MOUNT_OK})
    {:noreply, committed}
  end

  @spec apply_riding_status(map()) :: map()
  defp apply_riding_status(%{game_state: game_state} = state) do
    case StatusManager.handle_apply_status(@status_id, [val1: cavalier_level(game_state)], state) do
      {:reply, :ok, applied} ->
        applied

      {:reply, {:error, reason}, _unchanged} ->
        Logger.warning(
          "Mount restore: SC_RIDING apply failed for #{game_state.character_id}: #{inspect(reason)}"
        )

        state
    end
  end

  @spec commit_option(map(), non_neg_integer()) :: map()
  defp commit_option(%{game_state: game_state} = state, option) do
    StatsManager.update_game_state(state, %{game_state | option: option})
  end

  @spec reject(map(), atom()) :: {:noreply, map()}
  defp reject(%{connection_pid: connection_pid} = state, code) do
    MessageRouter.send_to(connection_pid, %MountResult{result: code})
    {:noreply, state}
  end

  @spec persist_option(integer(), non_neg_integer()) :: :ok
  defp persist_option(char_id, option) do
    CharacterPersistence.update_character(char_id, %{option: option}, async: true)
    :ok
  end

  @spec riding_learned?(map()) :: boolean()
  defp riding_learned?(game_state) do
    learned_level(game_state, @kn_riding_id) > 0
  end

  @spec cavalier_level(map()) :: non_neg_integer()
  defp cavalier_level(game_state) do
    learned_level(game_state, @kn_cavaliermastery_id)
  end

  @spec learned_level(map(), integer()) :: non_neg_integer()
  defp learned_level(%{stats: %{progression: %{learned_skills: learned}}}, skill_id) do
    Learned.learned_level(learned, skill_id)
  end
end
