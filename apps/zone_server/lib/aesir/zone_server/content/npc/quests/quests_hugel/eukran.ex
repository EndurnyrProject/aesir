defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Eukran do
  @moduledoc """
  Eukran tells players where to find his sister Euslan’s fiancee.

  ## Behavior

  - Shares Thierry's whereabouts and sends the player out of the bingo room.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "que_bingo", x: 53, y: 190, dir: 7, sprite: 778, name: "Eukran", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :hg_ma1, 0) == 6 do
      {ctx, _} =
        ctx
        |> mes("[Eukran]")
        |> mes("Oh, weren't you just")
        |> mes("in the bingo room?")
        |> mes("I hope you enjoyed")
        |> mes("the game. Now, can")
        |> mes("I help you with anything?")
        |> next()
        |> select(["Talk about Euslan"])

      ctx
      |> mes("^3355FFYou tell Eukran about his")
      |> mes("sister's illness, and that")
      |> mes("she has sent you to search")
      |> mes("for her fiancee Thierry.^000000")
      |> next()
      |> mes("[Eukran]")
      |> mes("*Sob* I had no idea")
      |> mes("that my sister Euslan")
      |> mes("was so sick! No wonder")
      |> mes("Thierry looked so depressed")
      |> mes("the last time I saw him. Why")
      |> mes("didn't he tell me anything?")
      |> next()
      |> mes("[Eukran]")
      |> mes("You see, Thierry passed by")
      |> mes("here about a month ago, and")
      |> mes("told me that he had to visit")
      |> mes("the Odin Shrine. I wasn't")
      |> mes("sure then, but now I think")
      |> mes("he's trying to help my sister.")
      |> next()
      |> mes("[Eukran]")
      |> mes("There must be something")
      |> mes("there that can help my")
      |> mes("sister recover. Why else")
      |> mes("would Thierry go to such a")
      |> mes("dangerous place? No one goes to the Odin Shrine for no reason.")
      |> close()
      |> set_char_var(:hg_ma1, 8)
      |> changequest(8047, 8048)
      |> warp("que_bingo", 37, 24)
    else
      ctx
    end
  end
end
