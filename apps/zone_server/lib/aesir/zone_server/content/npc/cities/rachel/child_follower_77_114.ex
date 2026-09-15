defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.ChildFollower77114 do
  @moduledoc """
  Hides from other children in Rachel's temple.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Tsuyuki and Harp
    - L0ne_W0lf
    - Lupus
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ra_temple",
        x: 77,
        y: 114,
        dir: 7,
        sprite: 921,
        name: "Child Follower",
        scope: :shared,
        unique_name: "Child Follower#5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Emmet]")
    |> mes("Oh my Freya! You scared me!")
    |> mes("I thought you were one of the")
    |> mes("kids playing Hide-and-Seek!")
    |> mes("Ack! Get away, get away!")
    |> mes("Can't let them find me!")
    |> close()
  end
end
