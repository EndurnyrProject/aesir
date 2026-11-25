defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Area32 do
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
      %{map: "lhz_in01", x: 184, y: 46, dir: 0, sprite: 111, name: "Area 3-2", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    quest = get_char_var(ctx, :lhz_boss, 0)

    cond do
      quest > 28 and quest < 30 ->
        ctx
        |> mes("^3355FFThere's literally thousands")
        |> mes("of documents to sort through.")
        |> mes("There's no way you can find")
        |> mes("something of value here in")
        |> mes("just three minutes...^000000")
        |> close()

      quest == 30 ->
        ctx
        |> mes("^3355FFYou've found a file")
        |> mes("containing information")
        |> mes("on the Kafra Corporation")
        |> mes("and Cool Event Corp.^000000")
        |> next()
        |> mes("[Classified Info]")
        |> mes("^8C1717Rekenber Corporation.")
        |> mes("in an effort to expand its")
        |> mes("power into the Rune-Midgarts")
        |> mes("Kingdom, will cooperate with")
        |> mes("and support Cool Event Corp.^000000")
        |> next()
        |> mes("[Classified Info]")
        |> mes("^8C1717Although this partnership")
        |> mes("has been greatly successful,")
        |> mes("Kafra Corporation has been")
        |> mes("working to check Cool Event")
        |> mes("Corp's explosive growth.^000000")
        |> next()
        |> mes("[Classified Info]")
        |> mes("^8C1717More than Kafra Corporation's")
        |> mes("lobbying, Kafra's 3rd Security")
        |> mes("Team stands as a formidable")
        |> mes("threat to our success. One of")
        |> mes("our highest priorities is to")
        |> mes("investigate their activities.^000000")
        |> next()
        |> mes("[Classified Info]")
        |> mes("^8C1717It is believed that Kafra's")
        |> mes("3rd Security Team has alrady")
        |> mes("placed secret agents in key")
        |> mes("strategic locations within")
        |> mes("the Schwarzwald Republic.^000000")
        |> next()
        |> mes("^3355FFThis file is very intriguing,")
        |> mes("but it doesn't really cover")
        |> mes("any information that can be")
        |> mes("considered incriminating.^000000")
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
