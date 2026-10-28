defmodule Aesir.ZoneServer.Unit.Player.Logout do
  @moduledoc """
  The combat logout window, in both modes.

  A player's session records the time of its last combat action in
  `canlog_at` (monotonic ms): an attack step against a target in range, a skill
  use that began, or HP damage taken from a source. For 10 s after it (the
  10_000th millisecond included) the player cannot return to character select,
  and a dropped connection leaves the character in the world for 10 s. Death
  moves the stamp 10 s into the past, so the window closes 1 ms after death.

  Hiding, Cloaking, Chase Walk, Cloaking Exceed, Su Hide and New Moon also
  refuse character select, whatever the window says.
  """

  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @window_ms 10_000
  @concealing_statuses [
    :sc_cloaking,
    :sc_hiding,
    :sc_chasewalk,
    :sc_cloakingexceed,
    :sc_suhide,
    :sc_newmoon
  ]

  @doc "Opens the window at the current time."
  @spec stamp(SessionState.t()) :: SessionState.t()
  def stamp(state), do: Map.put(state, :canlog_at, now_ms())

  @doc "Moves the stamp 10 s into the past, as death does."
  @spec reset_on_death(SessionState.t()) :: SessionState.t()
  def reset_on_death(state), do: Map.put(state, :canlog_at, now_ms() - @window_ms)

  @doc "Whether `now` is within 10 s of the stamp `at`; never before the first stamp."
  @spec within_window?(integer() | nil, integer()) :: boolean()
  def within_window?(nil, _now), do: false
  def within_window?(at, now), do: now - at <= @window_ms

  @doc "Whether a request to return to character select is refused."
  @spec refuse_char_select?(SessionState.t()) :: boolean()
  def refuse_char_select?(%{game_state: %{character_id: character_id}} = state) do
    concealed?(character_id) or within_window?(Map.get(state, :canlog_at), now_ms())
  end

  defp concealed?(character_id),
    do: Enum.any?(@concealing_statuses, &StatusStorage.has_status?(:player, character_id, &1))

  defp now_ms, do: System.monotonic_time(:millisecond)
end
