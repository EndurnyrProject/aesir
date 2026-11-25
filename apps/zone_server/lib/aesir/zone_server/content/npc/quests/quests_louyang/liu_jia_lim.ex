defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.LiuJiaLim do
  @moduledoc """
  A diner praises the restaurant’s Dragon Soup.

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
        x: 42,
        y: 186,
        dir: 5,
        sprite: 816,
        name: "Liu Jia Lim",
        scope: :shared,
        unique_name: "Liu Jia Lim#lou"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :ch_tre, 0) == 5 do
      ctx
      |> mes("[Liu Jia Lim]")
      |> mes(
        "Do you know what was this restaurant's best dish throughout all of its history? Dragon Soup!"
      )
      |> next()
      |> emotion(:throb)
      |> describe_soup()
      |> next()
      |> mes("[Liu Jia Lim]")
      |> mes("I'm not sure what happened,")
      |> mes("but people say this restaurant no longer sells Dragon Soup.")
      |> mes("Was it because of the price...?")
      |> close()
    else
      ctx
      |> mes("[Liu Jia Lim]")
      |> mes(
        "Do you know what's the best dish at this restaurant? It's Dragon Soup! They've been selling it here for as long as this restaurant has been around."
      )
      |> next()
      |> describe_soup()
      |> next()
      |> mes("[Liu Jia Lim]")
      |> mes(
        "It's tasty and really good for your health. Why don't you order a bowl? I've never known anyone to taste Dragon Soup and not love it!"
      )
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp describe_soup(ctx) do
    ctx
    |> mes("[Liu Jia Lim]")
    |> mes("Its delicate taste comes from")
    |> mes(
      "a broth extracted from pure meat that does not contain any fat. So it's also a very popular diet food for the ladies."
    )
  end
end
