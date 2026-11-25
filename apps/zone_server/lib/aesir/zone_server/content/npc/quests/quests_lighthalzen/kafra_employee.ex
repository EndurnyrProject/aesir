defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.KafraEmployee do
  @moduledoc """
  Directs visitors at Kafra Headquarters.

  ## Behavior

  - Helps the player locate Benith during the president quest.

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
        map: "aldebaran",
        x: 58,
        y: 225,
        dir: 4,
        sprite: 116,
        name: "Kafra Employee",
        scope: :shared,
        unique_name: "Kafra Employee#l1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :lhz_boss, 0) != 17 do
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Welcome to the")
      |> mes("Kafra Headquarters.")
      |> mes("Here in the heart of")
      |> mes("Kafra's operations, you")
      |> mes("can be provided with special")
      |> mes("services offered nowhere else!")
      |> next()
      |> mes("[Kafra Employee]")
      |> mes("If you need anything,")
      |> mes("please inquire the Kafra")
      |> mes("Employees inside the building.")
      |> mes("Thank you and have a good day~")
      |> close()
    else
      ask_question(ctx)
    end
  end

  defp ask_question(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Good day~")
      |> mes("The Kafra Corporation is")
      |> mes("always working to ensure")
      |> mes("our customers' satisfaction.")
      |> mes("How may I help you today?")
      |> next()
      |> select(["I have a question.", "I'm fine, thanks."])

    case choice do
      1 ->
        {ctx, answer} =
          ctx
          |> mes("[Kafra Employee]")
          |> mes("Sure, I'll answer your")
          |> mes("question to the best of")
          |> mes("my ability. However, I may")
          |> mes("need to reference you to")
          |> mes("another employee for")
          |> mes("specialized information.")
          |> next()
          |> select(["Do you know where I can find Benith?"])

        case answer do
          1 ->
            ctx
            |> mes("[Kafra Employee]")
            |> mes("Oh, Benith? Sure, you")
            |> mes("can find her here inside")
            |> mes("Kafra Headquarters to the")
            |> mes("right somewhere. She wears")
            |> mes("a special uniform, so you")
            |> mes("can spot her easily.")
            |> next()
            |> mes("[Kafra Employee]")
            |> mes("Okay then,")
            |> mes("have a good day!")
            |> mes("Always remember")
            |> mes("that the Kafra Service")
            |> mes("will be on your side~")
            |> close()

          _ ->
            ctx
        end

      2 ->
        ctx
        |> mes("[Kafra Employee]")
        |> mes("Feel free to ask any")
        |> mes("one of our conveniently")
        |> mes("located employees if you")
        |> mes("ever have need of Kafra's")
        |> mes("special services. Thank")
        |> mes("you and have a nice day~")
        |> close()

      _ ->
        ctx
    end
  end
end
