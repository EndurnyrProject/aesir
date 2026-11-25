defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.JiangRong do
  @moduledoc """
  Jiang Rong describes the benefits of Dragon Soup.

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
        map: "lou_in02",
        x: 43,
        y: 169,
        dir: 1,
        sprite: 827,
        name: "Jiang Rong",
        scope: :shared,
        unique_name: "Jiang Rong#lou"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Jiang Rong]")
    |> mes("Dragon Soup is known for its spicy, yet sweet and refreshing taste.")
    |> next()
    |> mes("[Jiang Rong]")
    |> mes("It's made with all sorts of medicinal herbs, so it's good")
    |> mes("for your health as well.")
    |> next()
    |> mes("[Jiang Rong]")
    |> mes("Dragon Soup draws out the unnecessary heat created inside")
    |> mes(
      "the body and circulates the blood. So it helps optimize the body's functions and promotes longevity."
    )
    |> next()
    |> mes("[Jiang Rong]")
    |> mes(
      "I've eaten Dragon Soup regularly ever since I was young. Look at me, don't you think I look so healthy considering my age?"
    )
    |> close()
  end
end
