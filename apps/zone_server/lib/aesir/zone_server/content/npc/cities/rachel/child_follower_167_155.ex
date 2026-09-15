defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.ChildFollower167155 do
  @moduledoc """
  Tries to keep Lewei's Hide-and-Seek hiding place secret.

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
        x: 167,
        y: 155,
        dir: 4,
        sprite: 914,
        name: "Child Follower",
        scope: :shared,
        unique_name: "Child Follower#3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lewei]")
      |> mes("Shushh!")
      |> mes("Be quiet.")
      |> next()
      |> mes("[Lewei]")
      |> mes("......")
      |> mes(".........")
      |> next()
      |> mes("[Lewei]")
      |> mes("Go away! If someone!")
      |> mes("sees you, I'm gonna")
      |> mes("get caught, you jerk!")
      |> next()
      |> select(["What are you doing?", "Alright."])

    case choice do
      1 ->
        ctx
        |> mes("[Lewei]")
        |> mes("Hellooo~?")
        |> mes("Can't you see?")
        |> mes("It's called Hide-and-")
        |> mes("Go-Seek. Gee whiz!")
        |> mes("Hurry, get away!")
        |> close()

      _ ->
        ctx |> mes("[Lewei]") |> mes("Hurry, and get") |> mes("outta here!") |> close()
    end
  end
end
