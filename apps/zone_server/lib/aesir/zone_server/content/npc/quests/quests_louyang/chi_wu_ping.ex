defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.ChiWuPing do
  @moduledoc """
  Chi Wu Ping recommends the restaurant’s soup.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "louyang",
        x: 261,
        y: 123,
        dir: 3,
        sprite: 824,
        name: "Chi Wu Ping",
        scope: :shared,
        unique_name: "Chi Wu Ping#lou"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Chi Wu Ping]")
    |> mes("I don't feel good...")
    |> mes("So... Totally out of it...")
    |> next()
    |> mes("[Chi Wu Ping]")
    |> mes("Oh, my aching body!")
    |> mes("All my muscles are sore...")
    |> mes("There's only one thing that could cure all of this agonizing... pain...")
    |> next()
    |> emotion(:surprise)
    |> mes("[Chi Wu Ping]")
    |> mes("Hey kid~!")
    |> mes("You don't look like a local!")
    |> mes("Why don't you follow the road ahead and check out the big restaurant?")
    |> next()
    |> mes("[Chi Wu Ping]")
    |> mes("The soup that they sell there is probably the healthiest food you can ever find.")
    |> next()
    |> mes("[Chi Wu Ping]")
    |> recommend_soup()
    |> close()
  end

  defp recommend_soup(ctx) do
    if base_level(ctx) < 80 do
      ctx |> mes("I guess you could eat") |> mes("some of that soup") |> mes("for your health.")
    else
      ctx
      |> mes("You seem to need")
      |> mes("that soup to ease")
      |> mes("the fatigue of your")
      |> mes("body and mind.")
    end
  end
end
