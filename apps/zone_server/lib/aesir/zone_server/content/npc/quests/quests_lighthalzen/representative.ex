defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Representative do
  @moduledoc """
  A representative welcomes visitors to Rekenber.

  ## Behavior

  - Directs visitors to the library or explains the building layout.
  - Advances the curse quest when asked about the corporation.

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
        x: 114,
        y: 181,
        dir: 5,
        sprite: 71,
        name: "Representative",
        scope: :shared,
        unique_name: "Representative#li_01"
      }
    ]

  @impl true
  def on_talk(ctx) do
    quest_stage = get_char_var(ctx, :lhz_curse, 0)

    options =
      if quest_stage == 7,
        do: ["Building Information", "Corporation History"],
        else: ["Building Information."]

    {ctx, choice} =
      ctx
      |> mes("[Representative]")
      |> mes("Greetings, and welcome")
      |> mes("to the Rekenber Corporation.")
      |> mes("How may I be of service today?")
      |> next()
      |> select(options)

    case choice do
      1 -> ctx |> building_information() |> floor_menu()
      2 when quest_stage == 7 -> direct_to_library(ctx)
      _ -> ctx
    end
  end

  defp direct_to_library(ctx) do
    ctx
    |> mes("[Representative]")
    |> mes("If you're interested in")
    |> mes("learning the history of")
    |> mes("our corporation, please")
    |> mes("speak to the representative")
    |> mes("inside our Library. Thank you.")
    |> next()
    |> mes("[Representative]")
    |> mes("Please head down")
    |> mes("the hallway to the left in")
    |> mes("order to find our Library.")
    |> mes("Thank you and have a nice day.")
    |> set_char_var(:lhz_curse, 8)
    |> changequest(2087, 2088)
    |> close()
  end

  defp building_information(ctx) do
    ctx
    |> mes("[Representative]")
    |> mes("Please tell me")
    |> mes("which floor you'd like")
    |> mes("to know more about.")
    |> next()
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
