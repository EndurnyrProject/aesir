defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Area61 do
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
      %{map: "lhz_in01", x: 177, y: 56, dir: 0, sprite: 111, name: "Area 6-1", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    quest = get_char_var(ctx, :lhz_boss, 0)

    cond do
      quest > 28 and quest < 33 ->
        ctx
        |> mes("^3355FFThere's literally thousands")
        |> mes("of documents to sort through.")
        |> mes("There's no way you can find")
        |> mes("something of value here in")
        |> mes("just three minutes...^000000")
        |> close()

      quest == 33 ->
        ctx
        |> mes("[Classified Info]")
        |> mes("^8C1717........")
        |> mes("Our organization purchased")
        |> mes("all of western Einbech and")
        |> mes("began construction of Einbroch")
        |> mes("in 927 in order to obtain more")
        |> mes("pieces of Ymir's Heart.^000000")
        |> next()
        |> mes("[Classified Info]")
        |> mes("^8C1717Unofficially, each and")
        |> mes("every single factory belongs")
        |> mes("to the Rekenber Corporation.")
        |> mes("Their highest priority is")
        |> mes("to uncover Ymir Heart Pieces...^000000")
        |> next()
        |> mes("^3355FFAlthough this file contains")
        |> mes("surprising information about")
        |> mes("Einbroch, none of it can be")
        |> mes("considered to be incriminating")
        |> mes("evidence against Rekenber.")
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
