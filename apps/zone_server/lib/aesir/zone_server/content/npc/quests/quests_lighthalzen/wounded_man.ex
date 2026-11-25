defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.WoundedMan do
  @moduledoc """
  A wounded agent waits for a Secret Wing contact.

  ## Behavior

  - Accepts a passphrase and hands over a file.
  - Disables itself after the encounter or initialization.

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
        map: "lhz_fild02",
        x: 228,
        y: 214,
        dir: 0,
        sprite: 849,
        name: "Wounded Man",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Wounded Man")

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{7343, 1}]) != 1 ->
        ctx
        |> mes("^3355FFWait a second!")
        |> mes("Right now, you're carrying")
        |> mes("too many things with you.")
        |> mes("Please come back after")
        |> mes("using the Kafra Service")
        |> mes("to store some of your items.^000000")
        |> close()

      get_char_var(ctx, :lhz_boss, 0) < 18 ->
        meet_stranger(ctx)

      get_char_var(ctx, :lhz_boss, 0) == 18 ->
        identify_agent(ctx)

      true ->
        disablenpc(ctx, "Wounded Man")
    end
  end

  defp meet_stranger(ctx) do
    ctx =
      ctx
      |> mes("[?????]")
      |> mes("^333333*Cough cough*^000000")
      |> mes("Can't hold out...")
      |> mes("Much longer. They...")
      |> mes("They better send")
      |> mes("someone soon...")
      |> next()
      |> mes("^3355FFIt's a wounded man...!^000000")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("H-hey...!")
    |> mes("Are you hurt?")
    |> mes("Do you need any he--")
    |> next()
    |> mes("[?????]")
    |> mes("N-no..!")
    |> mes("Get away, do-gooder!")
    |> mes("Don't attract attention,")
    |> mes("they're gonna find me!")
    |> mes("Don't worry, don't ask,")
    |> mes("j-just get the hell away!")
    |> close()
  end

  defp identify_agent(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[?????]")
      |> mes("^333333*Cough cough*^000000")
      |> mes("Can't hold out...")
      |> mes("Much longer. They...")
      |> mes("They better send")
      |> mes("someone soon...")
      |> next()
      |> select(["Jargeah?", "Ignore him."])

    case choice do
      1 ->
        ask_organization(ctx)

      2 ->
        ctx
        |> mes("^3355FFAnd so you left the")
        |> mes("wounded man alone. Not")
        |> mes("exactly the best moral choice.^000000")
        |> close()

      _ ->
        ctx
    end
  end

  defp ask_organization(ctx) do
    {ctx, organization} =
      ctx
      |> mes("[Jargeah]")
      |> mes("^333333*Cough Gasp*^000000")
      |> mes("H-how do you know my...")
      |> mes("Never mind that. Who...")
      |> mes("What... What organization")
      |> mes("are you working for...?")
      |> next()
      |> input(:string)

    ctx = set_temp_var(ctx, :"jargeah$", organization)

    if get_temp_var(ctx, :"jargeah$", "") in ["Kafra Corporation", "Secret Wing"] do
      ctx
      |> mes("[Jargeah]")
      |> mes("Th-thank goodness!")
      |> mes("You finally came for me.")
      |> mes("If you came a little later,")
      |> mes("I'd be a goner. H-here,")
      |> mes("t-take this with you...")
      |> set_char_var(:lhz_boss, 19)
      |> give_item(7343, 1)
      |> changequest(12_020, 12_021)
      |> next()
      |> mes("[Jargeah]")
      |> mes("Oh... Oh no.")
      |> mes("*Cough cough*")
      |> mes("I think... It might")
      |> mes("T-tell Cilantro that...")
      |> mes("Tell her I still lov-- ^333333*Huk*^000000")
      |> close2()
      |> disablenpc("Wounded Man")
    else
      ctx
      |> mes("[Jargeah]")
      |> mes("No... No, you're")
      |> mes("not the one who's")
      |> mes("supposed to come")
      |> mes("for m-me... ^333333*Huk*^000000")
      |> next()
      |> mes("^3355FFThis isn't good.")
      |> mes("Jargeah just passed")
      |> mes("out in a very ugly way.")
      |> close()
    end
  end
end
