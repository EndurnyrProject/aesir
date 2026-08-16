defmodule Aesir.ZoneServer.Unit.Player.Handlers.FalconHandler do
  @moduledoc """
  Owns the Falcon lifecycle: equip, dismiss, spawn restoration, and forced
  cleanup when Falconry Mastery is lost.

  Follows the `MountHandler` lifecycle shape minus mount-specific concerns:
  there is no stat denormalization (the Falcon grants no stats) and no
  client-facing result message, so every public function is a plain state
  transform returning `{:ok, state} | {:error, reason}` (or bare `state` for
  the init/progression hooks).

  `PlayerSession` is the single writer; every function takes and returns the
  session `state` map. The `:falcon` bit of `game_state.option` is the
  authoritative in-memory copy of the persisted `Character.option`; equip and
  dismiss flip that one bit and persist the whole recomputed value, which can
  never clobber another bit because the session is the sole writer.

  `SC_FALCON` is a permanent display mirror only: applying/removing it goes
  through `StatusManager` so the generic status display path broadcasts the
  Falcon sprite in `effect_state`. Enabling commits nothing (option,
  persistence) if the status application fails, so ownership and display can
  never split.

  `load_on_spawn/2` runs inside `init/1` (bare state, GenServer loop not yet
  started). `force_dismiss/1` is the same bare-state exception for the
  skill-reset/job-change hooks in `ProgressionHandler`.
  """

  import Bitwise

  require Logger

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtFalcon
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatsManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @status_id :sc_falcon
  @falcon_bit Option.id(:falcon)

  @doc """
  Equips (`true`) or dismisses (`false`) the Falcon.

  Enabling requires Falconry Mastery learned; an invalid enable returns
  `{:error, :falcon_skill_not_learned}` and changes no option, status, or
  persistence state. Both directions are idempotent: a request matching the
  current state is `{:ok, state}` with no side effects. Unrelated option bits
  are always preserved.
  """
  @spec set_falcon(map(), boolean()) :: {:ok, map()} | {:error, atom()}
  def set_falcon(%{game_state: game_state} = state, true) do
    cond do
      falcon?(state) ->
        {:ok, state}

      falconry_level(game_state) == 0 ->
        {:error, :falcon_skill_not_learned}

      true ->
        do_enable(state)
    end
  end

  def set_falcon(state, false) do
    if falcon?(state), do: {:ok, dismiss_core(state)}, else: {:ok, state}
  end

  @doc """
  Dismisses the Falcon as a lifecycle side effect (skill reset or job change
  dropping Falconry Mastery): same status removal, option-bit clear, and
  persisted option as `set_falcon(state, false)`, but as a bare state
  transform with no domain result. A no-op when no Falcon is equipped.
  """
  @spec force_dismiss(map()) :: map()
  def force_dismiss(state) do
    if falcon?(state), do: dismiss_core(state), else: state
  end

  @doc """
  Whether the player currently has a Falcon equipped, read from the `:falcon`
  bit of the authoritative option state. Accepts the session state map or a
  bare `PlayerState`.
  """
  @spec falcon?(map() | PlayerState.t()) :: boolean()
  def falcon?(%{game_state: game_state}), do: falcon?(game_state)
  def falcon?(%PlayerState{option: option}), do: (option &&& @falcon_bit) != 0

  @spec do_enable(map()) :: {:ok, map()} | {:error, atom()}
  defp do_enable(%{game_state: game_state} = state) do
    char_id = game_state.character_id
    new_option = game_state.option ||| @falcon_bit

    case StatusManager.handle_apply_status(@status_id, [], state) do
      {:reply, :ok, applied} ->
        persist_option(char_id, new_option)
        {:ok, commit_option(applied, new_option)}

      {:reply, {:error, reason}, _unchanged} ->
        Logger.warning("Falcon: SC_FALCON apply failed for #{char_id}: #{inspect(reason)}")
        {:error, :status_apply_failed}
    end
  end

  @spec dismiss_core(map()) :: map()
  defp dismiss_core(%{game_state: game_state} = state) do
    char_id = game_state.character_id
    new_option = game_state.option &&& bnot(@falcon_bit)

    {:reply, :ok, removed} = StatusManager.handle_remove_status(@status_id, state)
    persist_option(char_id, new_option)
    commit_option(removed, new_option)
  end

  @doc """
  Validates the persisted Falcon bit on spawn and restores the display mirror.

  When `character.option` carries the `:falcon` bit and Falconry Mastery is
  learned, re-applies `SC_FALCON` so the sprite folds into the spawn
  `effect_state`; the option bit is already in `game_state.option` via
  `PlayerState.new/1`, so nothing is re-persisted. A stale bit without
  Falconry Mastery (old data, or a reset/job change that raced a logout) is
  cleared from the session state and persisted instead of being mirrored.
  """
  @spec load_on_spawn(Character.t(), map()) :: map()
  def load_on_spawn(%Character{option: option}, state) when (option &&& @falcon_bit) != 0 do
    if falconry_level(state.game_state) > 0 do
      apply_falcon_status(state)
    else
      clear_stale_bit(state)
    end
  end

  def load_on_spawn(%Character{}, state), do: state

  @spec apply_falcon_status(map()) :: map()
  defp apply_falcon_status(%{game_state: game_state} = state) do
    case StatusManager.handle_apply_status(@status_id, [], state) do
      {:reply, :ok, applied} ->
        applied

      {:reply, {:error, reason}, _unchanged} ->
        Logger.warning(
          "Falcon restore: SC_FALCON apply failed for #{game_state.character_id}: #{inspect(reason)}"
        )

        state
    end
  end

  @spec clear_stale_bit(map()) :: map()
  defp clear_stale_bit(%{game_state: game_state} = state) do
    new_option = game_state.option &&& bnot(@falcon_bit)
    persist_option(game_state.character_id, new_option)
    commit_option(state, new_option)
  end

  @spec commit_option(map(), non_neg_integer()) :: map()
  defp commit_option(%{game_state: game_state} = state, option) do
    StatsManager.update_game_state(state, %{game_state | option: option})
  end

  @spec persist_option(integer(), non_neg_integer()) :: :ok
  defp persist_option(char_id, option) do
    CharacterPersistence.update_character(char_id, %{option: option}, async: true)
    :ok
  end

  @spec falconry_level(map()) :: non_neg_integer()
  defp falconry_level(%{stats: %{progression: %{learned_skills: learned}}}) do
    Learned.learned_level(learned, HtFalcon.definition().id)
  end
end
