defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.LiMin do
  @moduledoc """
  A visitor reminisces about a favorite dish.

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
        x: 80,
        y: 173,
        dir: 3,
        sprite: 746,
        name: "Li Min",
        scope: :shared,
        unique_name: "Li Min#lou"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :ch_tre, 0) == 5 do
      ctx
      |> mes("[Li Min]")
      |> mes(
        "^666666*Sigh*^000000 I am so disappointed. I came all the way down here to taste the food! I can't believe they don't sell it anymore!"
      )
      |> next()
      |> mes("[Li Min]")
      |> mes("The worst part is that I'm already addicted to the taste! ^666666*Sob...*^000000")
      |> close()
    else
      ctx
      |> mes("[Li Min]")
      |> mes("Well, I don't really")
      |> mes("live here in Luoyang.")
      |> mes("Still, I come here often")
      |> mes("enough to visit.")
      |> next()
      |> mes("[Li Min]")
      |> mes("I just returned")
      |> mes("because I've got")
      |> mes("a huge craving for the")
      |> mes("food I tasted here")
      |> mes("a while ago.")
      |> next()
      |> mes("[Li Min]")
      |> mes("For some reason, I can't forget it. I can't get it out of my mind!")
      |> next()
      |> mes("[Li Min]")
      |> mes("The taste, the texture.")
      |> mes(
        "The sweetness, melting down into my mouth, and its tempting scent lingering on my lips..."
      )
      |> next()
      |> mes("[Li Min]")
      |> mes("Ummmmm...")
      |> mes("Royal Jelly!")
      |> mes("It makes my")
      |> mes("mouth water~")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
