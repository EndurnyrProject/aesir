defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Area33 do
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
      %{map: "lhz_in01", x: 184, y: 48, dir: 0, sprite: 111, name: "Area 3-3", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    quest = get_char_var(ctx, :lhz_boss, 0)

    cond do
      quest > 28 and quest < 34 ->
        ctx
        |> mes("^3355FFThere's literally thousands")
        |> mes("of documents to sort through.")
        |> mes("There's no way you can find")
        |> mes("something of value here in")
        |> mes("just three minutes...^000000")
        |> close()

      quest == 34 ->
        ctx
        |> mes("[Classified Info]")
        |> mes("^8C1717...After negotiating with")
        |> mes("the existing residents, all of")
        |> mes("the property rights were sold")
        |> mes("and the city was renamed")
        |> mes("''Lighthalzen'' in 865.^000000")
        |> next()
        |> mes("[Classified Info]")
        |> mes("^8C1717The city was then separated")
        |> mes("into three districts. These are")
        |> mes("the common trade district, the")
        |> mes("old residential district and")
        |> mes("the Rekenber Headquarters.")
        |> mes(".................^000000")
        |> next()
        |> mes("^3355FFThis file covers")
        |> mes("Lighthalzen's history.")
        |> mes("However, the founding of")
        |> mes("the city is common knowlege,")
        |> mes("so this document probably won't")
        |> mes("have any significant evidence.^000000")
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
