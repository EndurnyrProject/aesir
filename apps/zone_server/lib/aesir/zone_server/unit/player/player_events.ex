defmodule Aesir.ZoneServer.Unit.Player.PlayerEvents do
  @moduledoc """
  Publishes per-player domain events to the `"player:<char_id>"` PubSub topic
  the `PlayerSession` subscribes to.

  These are facts about what a subsystem just did to a player ("inventory
  changed", "leveled/job changed", "quest log changed"), not instructions to
  any particular consumer. Emitters stay decoupled from reactors: the session
  (and any future subscriber, e.g. an achievement tracker) reacts on its own.
  The player session currently reacts by re-evaluating quest-icon bubbles and,
  for inventory changes, reconciling statuses derived from equipped items.

  Emitters run inside the owning `PlayerSession` process; the event round-trips
  through PubSub back to that session as a `handle_info` message, matching the
  existing `player:<id>` event bus (`StatusTickManager`, combat, job change).
  """

  alias Phoenix.PubSub

  @typedoc "A player-state change fact broadcast on the player's topic."
  @type event :: :inventory_changed | :progression_changed | :quest_changed | :vars_changed

  @doc "Announces a committed inventory, equipment, or equipment-break change."
  @spec inventory_changed(non_neg_integer()) :: :ok
  def inventory_changed(char_id), do: broadcast(char_id, :inventory_changed)

  @doc "Announces that the player's base/job level or job class changed."
  @spec progression_changed(non_neg_integer()) :: :ok
  def progression_changed(char_id), do: broadcast(char_id, :progression_changed)

  @doc "Announces that the player's quest log changed."
  @spec quest_changed(non_neg_integer()) :: :ok
  def quest_changed(char_id), do: broadcast(char_id, :quest_changed)

  @doc "Announces that a player script variable (char/temp) changed."
  @spec vars_changed(non_neg_integer()) :: :ok
  def vars_changed(char_id), do: broadcast(char_id, :vars_changed)

  @spec broadcast(non_neg_integer(), event()) :: :ok
  defp broadcast(char_id, event) do
    PubSub.broadcast(Aesir.PubSub, "player:#{char_id}", event)
    :ok
  end
end
