defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Area17 do
  @moduledoc """
  An archive shelf holds classified records for the investigation.

  ## Behavior

  - Shows a classified file when the search reaches this shelf.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "lhz_in01", x: 184, y: 52, dir: 0, sprite: 111, name: "Area 1-7", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    quest = get_char_var(ctx, :lhz_boss, 0)

    cond do
      quest > 28 and quest < 32 ->
        ctx
        |> mes("^3355FFThere's literally thousands")
        |> mes("of documents to sort through.")
        |> mes("There's no way you can find")
        |> mes("something of value here in")
        |> mes("just three minutes...^000000")
        |> close()

      quest == 32 ->
        ctx
        |> mes("^3355FFThis looks like a file")
        |> mes("containing information")
        |> mes("on President Weierstrauss.")
        |> mes("Perhaps there's something")
        |> mes("in here that might be helpful.^000000")
        |> next()
        |> mes("[Classified Info]")
        |> mes("^8C1717Karl Weierstrass has")
        |> mes("been a long distinguished")
        |> mes("politician in the Schwarzwald")
        |> mes("Republic and was elected as")
        |> mes("its president in the year 984.^000000")
        |> next()
        |> mes("[Classified Info]")
        |> mes("^8C1717Although he has enjoyed")
        |> mes("high popularity ratings and")
        |> mes("success in his endorsing his")
        |> mes("policies, Wierstrass is rumored")
        |> mes("to be have some sort of feud")
        |> mes("against Rekenber.^000000")
        |> next()
        |> mes("[Classified Info]")
        |> mes("^8C1717Although there is no")
        |> mes("need to bring this to the")
        |> mes("attention of the media, it")
        |> mes("is highly recommended")
        |> mes("to monitor his activities")
        |> mes("throughout his term...^000000")
        |> next()
        |> mes("^3355FFThere's a great amount")
        |> mes("of information in this file,")
        |> mes("but it doesn't look like any")
        |> mes("of it will be of help to you.")
        |> mes("You should continue with")
        |> mes("your search for evidence.^000000")
        |> close()

      true ->
        ctx
        |> mes("^3355FFThis file doesn't")
        |> mes("look like it contains")
        |> mes("any evidence that will")
        |> mes("help you. You should")
        |> mes("continue your search")
        |> mes("through the rest of the files.^000000")
        |> close()
    end
  end
end
