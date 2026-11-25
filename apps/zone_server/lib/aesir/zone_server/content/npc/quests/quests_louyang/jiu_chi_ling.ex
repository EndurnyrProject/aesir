defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.JiuChiLing do
  @moduledoc """
  A worried sister talks about her brother.

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
        x: 174,
        y: 150,
        dir: 5,
        sprite: 815,
        name: "Jiu Chi Ling",
        scope: :shared,
        unique_name: "Jiu Chi Ling#lou"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :ch_tre, 0) == 5 do
      ctx
      |> mes("[Jiu Chi Ling]")
      |> mes(
        "There's a strange rumor going around that the restaurant is no longer selling Dragon Soup..."
      )
      |> next()
      |> mes("[Jiu Chi Ling]")
      |> mes("Do you think")
      |> mes("my brother did")
      |> mes("something bad again!?")
      |> mes("I hope not! If he did...")
      |> mes("What am I supposed to do?!")
      |> close()
    else
      ctx
      |> mes("[Jiu Chi Ling]")
      |> mes("I'm worried about my brother.")
      |> mes("He's young, rebellious and doesn't listen to anybody...")
      |> next()
      |> mes("[Jiu Chi Ling]")
      |> mes("He just left the")
      |> mes("house while he was")
      |> mes("complaining about")
      |> mes("that restaurant...")
      |> next()
      |> mes("[Jiu Chi Ling]")
      |> mes("^666666*Sigh~~*^000000")
      |> mes("I'm not gonna let him")
      |> mes("get away this time!")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
