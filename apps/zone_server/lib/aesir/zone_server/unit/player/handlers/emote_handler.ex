defmodule Aesir.ZoneServer.Unit.Player.Handlers.EmoteHandler do
  @moduledoc """
  Handles player emote requests (protobuf analogue of CZ_REQ_EMOTION 0x00BF).

  All rejects are silent drops (no error packet), applied in order: the
  learned Basic Skill gate (level >= 2), out-of-range ids, the muted
  `:chat_prohibit` emote, and a 1-second flood window. A dice emote is
  reshuffled to a random face before display. On pass the bubble is
  broadcast to view range (which includes the sender) via `Unit.Emote.show/2`,
  and the flood timestamp is stamped on the player state.

  The Basic Skill gate level and the fact that emoting is gated at all are
  mode-independent (identical in renewal and pre-renewal).
  """

  alias Aesir.ZoneServer.Mmo.Emotion
  alias Aesir.ZoneServer.Mmo.Skills.Novice.NvBasic
  alias Aesir.ZoneServer.Unit.Emote
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @flood_window_ms 1000
  @max Emotion.id(:max)
  @chat_prohibit Emotion.id(:chat_prohibit)
  @dice_low Emotion.id(:dice1)
  @dice_high Emotion.id(:dice6)

  @doc """
  Processes an emote request, returning the (possibly updated) session state.
  """
  @spec handle_emote(integer(), map()) :: {:noreply, map()}
  def handle_emote(type, %{game_state: game_state} = state) do
    now = System.monotonic_time(:millisecond)

    if nv_basic_allows?(game_state) and allowed?(type, game_state.last_emote_at, now) do
      Emote.show({:player, game_state.character_id}, resolve(type))
      {:noreply, %{state | game_state: %{game_state | last_emote_at: now}}}
    else
      {:noreply, state}
    end
  end

  # Returns `:ok` when the player lacks a stats struct (e.g. pre-spawn), so an
  # early client action never crashes the session.
  defp nv_basic_allows?(%PlayerState{
         stats: %Stats{progression: %{learned_skills: learned_skills}}
       })
       when is_map(learned_skills) do
    NvBasic.allows_action?(learned_skills, :emotion) == :ok
  end

  defp nv_basic_allows?(_game_state), do: true

  defp allowed?(type, _last_emote_at, _now) when type >= @max, do: false
  defp allowed?(type, _last_emote_at, _now) when type == @chat_prohibit, do: false
  defp allowed?(_type, nil, _now), do: true

  defp allowed?(_type, last_emote_at, now) do
    now - last_emote_at >= @flood_window_ms
  end

  defp resolve(type) when type in @dice_low..@dice_high do
    @dice_low + :rand.uniform(@dice_high - @dice_low + 1) - 1
  end

  defp resolve(type), do: type
end
