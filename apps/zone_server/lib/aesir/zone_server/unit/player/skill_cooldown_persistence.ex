defmodule Aesir.ZoneServer.Unit.Player.SkillCooldownPersistence do
  @moduledoc """
  Saves a player's running skill cooldowns at logout and resumes them at login.

  What persists is each cooldown's remaining time, since the in-memory expiry
  is a monotonic timestamp; time spent offline does not run a cooldown down.
  Rows are consumed on restore (loaded then deleted). A restored cooldown
  restarts for its remaining time and is shown to the client.

  Not saved: pre-renewal guild skill cooldowns (a relogging pre-renewal master
  gets the guild skill block instead), and the Homunculus lifecycle skills,
  whose cooldowns the Homunculus record keeps.
  """

  import Ecto.Query

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.CharacterSkillCooldown
  alias Aesir.Net.SkillCooldown
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Homunculus.LifecycleSkills
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.StateCommit

  @guild_skills 10_000..10_019

  @doc """
  Persists the cooldowns still running for `game_state`, replacing any saved
  rows.
  """
  @spec save_cooldowns(PlayerState.t()) :: :ok
  def save_cooldowns(%PlayerState{character_id: char_id, skill_cooldowns: cooldowns}) do
    now = System.monotonic_time(:millisecond)
    skipped = skipped_skills()

    rows =
      for {skill_id, expires_at} <- cooldowns,
          is_integer(expires_at) and expires_at > now,
          skill_id not in skipped,
          do: %{char_id: char_id, skill_id: skill_id, remaining_ms: expires_at - now}

    {:ok, _result} =
      Repo.transaction(fn ->
        Repo.delete_all(saved_query(char_id))
        Repo.insert_all(CharacterSkillCooldown, rows)
      end)

    :ok
  end

  @doc """
  Restarts the cooldowns saved at logout, consuming the saved rows, and shows
  each to the client. Takes and returns the session `state` map.
  """
  @spec restore_on_spawn(map()) :: map()
  def restore_on_spawn(%{game_state: %PlayerState{character_id: char_id} = game_state} = state) do
    case consume(char_id) do
      [] ->
        state

      rows ->
        now = System.monotonic_time(:millisecond)

        cooldowns =
          Enum.reduce(rows, game_state.skill_cooldowns, fn row, acc ->
            MessageRouter.send_to(state.connection_pid, %SkillCooldown{
              skill_id: row.skill_id,
              tick: row.remaining_ms
            })

            Map.put(acc, row.skill_id, now + row.remaining_ms)
          end)

        StateCommit.commit(state, %{game_state | skill_cooldowns: cooldowns})
    end
  end

  defp consume(char_id) do
    query = saved_query(char_id)

    {:ok, rows} =
      Repo.transaction(fn ->
        rows = Repo.all(query)
        Repo.delete_all(query)
        rows
      end)

    Enum.filter(rows, &(&1.remaining_ms > 0))
  end

  defp skipped_skills do
    lifecycle = LifecycleSkills.ids()

    case GameMode.mode() do
      :renewal -> lifecycle
      :pre_renewal -> lifecycle ++ Enum.to_list(@guild_skills)
    end
  end

  defp saved_query(char_id),
    do: from(c in CharacterSkillCooldown, where: c.char_id == ^char_id)
end
