defmodule Aesir.ZoneServer.Npc.ContentScope do
  @moduledoc """
  Defines NPC content provenance and whether it participates in a game mode.
  """

  alias Aesir.Commons.GameMode

  @type t() :: :shared | GameMode.t()

  @spec active?(t(), GameMode.t()) :: boolean()
  def active?(:shared, _mode), do: true
  def active?(mode, mode), do: true
  def active?(_scope, _mode), do: false
end
