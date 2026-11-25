defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Representative27247 do
  @moduledoc """
  A representative provides information about Rekenber.

  ## Behavior

  - Explains the corporation or guides visitors around the building.
  - Advances the curse quest after discussing the corporation.

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
        x: 27,
        y: 247,
        dir: 5,
        sprite: 71,
        name: "Representative",
        scope: :shared,
        unique_name: "Representative#li_02"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    corporation_menu? = get_char_var(ctx, :lhz_curse, 0) > 6

    {ctx, choice} =
      ctx
      |> mes("[Representative]")
      |> mes("Welcome to the")
      |> mes("Rekenber Corporation.")
      |> mes("How may I help you?")
      |> next()
      |> select(
        if(corporation_menu?,
          do: ["Corporation History", "Rekenber's Businesses"],
          else: ["Building Information."]
        )
      )

    if corporation_menu? do
      case choice do
        1 -> ctx |> corporation_history() |> finish_corporation()
        2 -> ctx |> corporation_businesses() |> finish_corporation()
        _ -> ctx
      end
    else
      case choice do
        1 -> ctx |> building_information() |> floor_menu()
        _ -> ctx
      end
    end
  end

  defp corporation_history(ctx) do
    ctx
    |> mes("[Representative]")
    |> mes("Rekenber was established")
    |> mes("400 years ago, around the")
    |> mes("same time as the foundation")
    |> mes("of the Schwarzwald Republic.")
    |> next()
    |> mes("[Representative]")
    |> mes("We began as the ''Zent Zerter")
    |> mes("Lighthal Research Center,''")
    |> mes("named after our first chairman.")
    |> mes("In 560 A.W. (After War), our")
    |> mes("organization was renamed after")
    |> mes("our new chairman, Mr. Rekenber.")
    |> next()
    |> mes("[Representative]")
    |> mes("Mr. Rekenber expanded the")
    |> mes("Corporation's purposes, but")
    |> mes("also founded the Regenschirm")
    |> mes("Laboratory to continue this")
    |> mes("company's original goal of")
    |> mes("scientific research.")
    |> next()
    |> mes("[Representative]")
    |> mes("In the year 700 A.W.,")
    |> mes("^FF0000Doctor Varmunt^000000 joined")
    |> mes("Regenschirm. It was his work")
    |> mes("in science that enabled the")
    |> mes("Rekenber Corporation to grow into the nation's biggest company.")
  end

  defp corporation_businesses(ctx) do
    ctx
    |> mes("[Representative]")
    |> mes("In addition to merchandising,")
    |> mes("freight transport and trading,")
    |> mes("the Rekenber Corporation is")
    |> mes("also heavily involved with")
    |> mes("providing the Airship service,")
    |> mes("one of our major projects.")
    |> next()
    |> mes("[Representative]")
    |> mes("Rekenber is involved in")
    |> mes("almost any business that")
    |> mes("you can imagine. Remember")
    |> mes("that Rekenber is the name")
    |> mes("that you can trust.")
  end

  defp building_information(ctx) do
    ctx
    |> mes("[Representative]")
    |> mes("Please tell me")
    |> mes("which floor you'd like")
    |> mes("to know more about.")
    |> next()
  end

  defp finish_corporation(ctx) do
    ctx =
      case get_char_var(ctx, :lhz_curse, 0) do
        8 -> set_char_var(ctx, :lhz_curse, 9)
        9 -> set_char_var(ctx, :lhz_curse, 10)
        _ -> ctx
      end

    ctx =
      ctx
      |> next()
      |> mes("[Representative]")
      |> mes("If you'd like to know more")
      |> mes("about our mission statement,")
      |> mes("please refer to the Rekenber")
      |> mes("Guidebook located to my side.")
      |> mes("Thank you and have a nice day.")

    ctx =
      if Rathena.truthy?(isbegin_quest(ctx, 2088)), do: changequest(ctx, 2088, 2089), else: ctx

    close(ctx)
  end

  defp floor_menu(ctx) do
    {ctx, floor} = select(ctx, ["1F", "2F", "B1", "Cancel"])

    case floor do
      1 ->
        ctx
        |> mes("[Representative]")
        |> mes("The ^3131FFRekenber Library^000000 can")
        |> mes("be found at the end of the")
        |> mes("left hallway. Our library is")
        |> mes("a great resource of innovative")
        |> mes("ideas and information for our")
        |> mes("system development employees.")
        |> next()
        |> mes("[Representative]")
        |> mes("The ^3131FFBall Room^000000, where")
        |> mes("various official events are")
        |> mes("usually held, can be accessed")
        |> mes("through the right hallway.")
        |> next()
        |> floor_menu()

      2 ->
        ctx
        |> mes("[Representative]")
        |> mes("Please use the stairs")
        |> mes("located on both sides of")
        |> mes("the Help Desk to go to the")
        |> mes("Second Floor. The Second")
        |> mes("Floor is mostly used for")
        |> mes("administrative purposes.")
        |> next()
        |> mes("[Representative]")
        |> mes("There, you can find")
        |> mes("the ^3131FFConference Room^000000,")
        |> mes("^3131FFSecretary's Office^000000, the")
        |> mes("^3131FFAuditorium^000000 and the")
        |> mes("^3131FFChairman's Office^000000.")
        |> next()
        |> floor_menu()

      3 ->
        ctx
        |> mes("[Representative]")
        |> mes("The first underground floor")
        |> mes("is used by ^3131FFRegenschirm^000000,")
        |> mes("our laboratory affiliate. For")
        |> mes("security reasons, this floor")
        |> mes("is not accessible to visitors.")
        |> next()
        |> floor_menu()

      4 ->
        ctx
        |> mes("[Representative]")
        |> mes("We are always doing our")
        |> mes("best to provide the best")
        |> mes("services to our customers.")
        |> mes("Remember that Rekenber")
        |> mes("is the name you can trust.")
        |> mes("Thank you and have a nice day.")
        |> close()

      _ ->
        ctx
    end
  end
end
