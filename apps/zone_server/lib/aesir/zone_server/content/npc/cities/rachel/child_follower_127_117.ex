defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.ChildFollower127117 do
  @moduledoc """
  Explains Deno's understanding of faith and human responsibility.

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
        map: "rachel",
        x: 127,
        y: 117,
        dir: 4,
        sprite: 914,
        name: "Child Follower",
        scope: :shared,
        unique_name: "Child Follower#2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Deno]")
    |> mes("Although we pray to")
    |> mes("the goddess Freya and")
    |> mes("ask her for all sorts of")
    |> mes("things, we can't expect")
    |> mes("her to do everything for us.")
    |> next()
    |> mes("[Deno]")
    |> mes("As humans, it is our")
    |> mes("responsibility to do all")
    |> mes("in our power to conceive")
    |> mes("our own happiness. We")
    |> mes("believe that if it is Freya's")
    |> mes("will, then it shall be realized.")
    |> next()
    |> emotion(:question)
    |> mes("[Deno]")
    |> mes("I know it might seem")
    |> mes("a little confusing to")
    |> mes("an outsider, the idea of")
    |> mes("being reliant on our goddess")
    |> mes("while relying our ourselves.")
    |> close()
  end
end
