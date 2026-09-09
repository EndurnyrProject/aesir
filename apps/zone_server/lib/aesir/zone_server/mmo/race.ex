defmodule Aesir.ZoneServer.Mmo.Race do
  @moduledoc """
  Shared unit and combat races.

  Player-human and player-Doram are distinct races, including on monsters such
  as training dummies. Boss classification and script selectors are separate.
  """

  alias Aesir.Commons.GameMode

  @typedoc "A primary race, independent of boss class or secondary groups."
  @type t ::
          :formless
          | :undead
          | :brute
          | :plant
          | :insect
          | :fish
          | :demon
          | :demi_human
          | :angel
          | :dragon
          | :player_human
          | :player_doram

  @doc "Returns the human-player race for the active game mode."
  @spec player_race() :: :player_human | :demi_human
  def player_race do
    case GameMode.mode() do
      :renewal -> :player_human
      :pre_renewal -> :demi_human
    end
  end
end
