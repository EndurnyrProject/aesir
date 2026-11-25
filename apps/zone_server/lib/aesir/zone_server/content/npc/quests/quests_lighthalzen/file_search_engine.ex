defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.FileSearchEngine do
  @moduledoc """
  The archive search engine locates or restricts confidential files.

  ## Behavior

  - Searches keywords and updates the player’s investigation progress.
  - Allows repeated searches for the restricted Rekenber keyword.

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
      %{
        map: "lhz_in01",
        x: 182,
        y: 35,
        dir: 0,
        sprite: 111,
        name: "File Search Engine",
        scope: :shared
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :lhz_boss, 0) > 28 and get_char_var(ctx, :lhz_boss, 0) < 35 do
      ctx
      |> mes("^3355FFThis machine can be")
      |> mes("used to locate specific")
      |> mes("documents within the")
      |> mes("Secret Archive. However,")
      |> mes("you must enter the correct")
      |> mes("keywords to in order to find")
      |> mes("specific file locations.")
      |> next()
      |> search()
    else
      ctx
      |> mes("^3355FFThis machine can be")
      |> mes("used to locate specific")
      |> mes("documents within the")
      |> mes("Secret Archive, However,")
      |> mes("you no longer need to")
      |> mes("search through the files.^000000")
      |> close()
    end
  end

  defp search(ctx) do
    {ctx, choice} = select(ctx, ["Search Engine.", "Cancel."])

    case choice do
      1 ->
        enter_keyword(ctx)

      2 ->
        ctx
        |> mes("^663300[Search Engine Close]")
        |> mes("File search has been")
        |> mes("canceled. Please be aware")
        |> mes("that sudden shutdown may")
        |> mes("cause system errors.^000000")
        |> close()

      _ ->
        ctx
    end
  end

  defp enter_keyword(ctx) do
    {ctx, keyword} =
      ctx
      |> mes("^663300- Search Engine Initiated -")
      |> mes("- Please enter a keyword -")
      |> mes(" ")
      |> mes("*Search Engine")
      |> mes("is case sensitve.")
      |> mes("Please do not use")
      |> mes("capital letters.^000000")
      |> next()
      |> input(:string)

    ctx = set_temp_var(ctx, :"sneaksearch$", keyword)

    case get_temp_var(ctx, :"sneaksearch$", "") do
      keyword when keyword in ["kafra", "cool event"] ->
        ctx
        |> mes("^663300[Search Result]")
        |> mes("Documents regarding")
        |> mes("Kafra Corporation and")
        |> mes("Cool Event Corp are")
        |> mes("located in Arena 3-2.^000000")
        |> set_char_var(:lhz_boss, 30)
        |> close()

      "shinokas" ->
        ctx
        |> mes("^663300[Search Result]")
        |> mes("Documents regarding")
        |> mes("Shinokas are located")
        |> mes("in Arena 1-5.^000000")
        |> set_char_var(:lhz_boss, 31)
        |> close()

      keyword when keyword in ["stein", "STEIN", "S.T.E.I.N"] ->
        ctx
        |> mes("^663300[Search Result]")
        |> mes("Documents regarding")
        |> mes("S.T.E.I.N are considered")
        |> mes("highly classified and")
        |> mes("cannot be accessed")
        |> mes("through this system.^000000")
        |> close()

      "ymir" ->
        ctx
        |> mes("^663300[Search Result]")
        |> mes("Documents regarding")
        |> mes("Ymir's Heart are ranked")
        |> mes("as highly classified and")
        |> mes("cannot be accessed")
        |> mes("through this system.^000000")
        |> close()

      keyword when keyword in ["president", "karl", "weierstrass"] ->
        ctx
        |> mes("^663300[Search Result]")
        |> mes("2nd Class documents on")
        |> mes("President Karl Weierstrass")
        |> mes("are located in Area 1-7. For")
        |> mes("more highly classified files")
        |> mes("on Weierstrass, please use")
        |> mes("a higher security archive.^000000")
        |> set_char_var(:lhz_boss, 32)
        |> close()

      "einbroch" ->
        ctx
        |> mes("^663300[Search Result]")
        |> mes("Documents regarding")
        |> mes("Einbroch are stored")
        |> mes("in Area 6-1.^000000")
        |> set_char_var(:lhz_boss, 33)
        |> close()

      "lighthalzen" ->
        ctx
        |> mes("^663300[Search Result]")
        |> mes("Documents regarding")
        |> mes("Lighthalzen are stored")
        |> mes("in Area 3-3.^000000")
        |> set_char_var(:lhz_boss, 34)
        |> close()

      "rekenber" ->
        ctx
        |> mes("^663300[Search Result]")
        |> mes("Documents regarding")
        |> mes("Rekenber are highly classified and cannot be accessed by this system.^000000")
        |> next()
        |> search()

      _ ->
        ctx
        |> mes("^663300[Search Result]")
        |> mes("Keyword not found.")
        |> mes("Please search another")
        |> mes("archive or increase")
        |> mes("access permissions.^000000")
        |> close()
    end
  end
end
