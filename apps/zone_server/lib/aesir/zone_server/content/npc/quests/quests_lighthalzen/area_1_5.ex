defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Area15 do
  @moduledoc """
  An archive shelf holds evidence for the investigation.

  ## Behavior

  - Gives the player a classified file after the search identifies it.

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
      %{map: "lhz_in01", x: 184, y: 40, dir: 0, sprite: 111, name: "Area 1-5", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{7344, 1}]) != 1 ->
        ctx
        |> mes("^3355FFWait a second!")
        |> mes("Right now, you're carrying")
        |> mes("too many things with you.")
        |> mes("Please come back after")
        |> mes("using the Kafra Service")
        |> mes("to store some of your items.^000000")
        |> close()

      get_char_var(ctx, :lhz_boss, 0) > 28 and get_char_var(ctx, :lhz_boss, 0) < 31 ->
        ctx
        |> mes("^3355FFThere's literally thousands")
        |> mes("of documents to sort through.")
        |> mes("There's no way you can find")
        |> mes("something of value here in")
        |> mes("just three minutes...^000000")
        |> close()

      get_char_var(ctx, :lhz_boss, 0) == 31 ->
        ctx
        |> mes("^3355FFWait, one of these files")
        |> mes("looks pretty incriminating.")
        |> mes("It seems to contain the")
        |> mes("kind of information that")
        |> mes("you've been looking for.^000000")
        |> next()
        |> mes("[Classified Info]")
        |> mes("^8C1717A piece of Ymir's Heart")
        |> mes("was uncovered in one of")
        |> mes("the mines in Einbech and")
        |> mes("immediately transported to")
        |> mes("the Laboratory for research.^000000")
        |> next()
        |> mes("[Classified Info]")
        |> mes("^8C1717However, something")
        |> mes("happened to the miners")
        |> mes("who discovered the piece")
        |> mes("of Ymir's Heart. Apparently,")
        |> mes("a beast from Einbroch folk")
        |> mes("lore inhabited the area...^000000")
        |> set_char_var(:lhz_boss, 35)
        |> give_item(7344, 1)
        |> close()

      true ->
        ctx
    end
  end
end
