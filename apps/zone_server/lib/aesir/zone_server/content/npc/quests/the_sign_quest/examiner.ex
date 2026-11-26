defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Examiner do
  @moduledoc """
  Explains and grades the rhythm exam for The Sign quest.

  ## Behavior

  - Guides participants to the test and reports their results.
  - Sends unauthorized visitors outside.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "cmd_in01",
        x: 33,
        y: 25,
        dir: 5,
        sprite: 724,
        name: "Examiner",
        scope: :shared,
        unique_name: "Examiner#sign"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = mes(ctx, "[Lamadin]")

    case get_char_var(ctx, :sign_q, 0) do
      30 ->
        ctx
        |> mes("Welcome to")
        |> mes("Part Two of Dearles'")
        |> mes("exam where your sense")
        |> mes("of rhythm will be tested~")
        |> next()
        |> mes("[Lamadin]")
        |> exam_instructions()

      31 ->
        ctx |> set_char_var(:sign_q, 30) |> exam_instructions()

      32 ->
        ctx
        |> identify_player()
        |> mes("Oh, what a shame!")
        |> mes("You failed this time.")
        |> mes("But don't you worry...")
        |> next()
        |> mes("[Lamadin]")
        |> mes("You're welcome to")
        |> mes("try again whenever")
        |> mes("you want, alright?")
        |> mes("Thank you~")
        |> set_char_var(:sign_q, 30)
        |> close()

      33 ->
        ctx
        |> identify_player()
        |> mes("Congratulations!")
        |> mes("You passed the test!")
        |> next()
        |> mes("[Lamadin]")
        |> mes("I'll send a message to")
        |> mes("Mister Dearles right away,")
        |> mes("so please go speak to him")
        |> mes("again. Once again, great job~ ")
        |> close()

      34 ->
        ctx
        |> identify_player()
        |> mes("Congratulations!")
        |> mes("You got a perfect")
        |> mes("score on this test!")
        |> next()
        |> mes("[Lamadin]")
        |> mes("I'll send a message to")
        |> mes("Mister Dearles right away,")
        |> mes("so please go speak to him")
        |> mes("again. He may even give")
        |> mes("you a reward since you")
        |> mes("did such a great job~")
        |> close()

      _ ->
        ctx
        |> mes("H-how did you")
        |> mes("find your way here?")
        |> mes("This is private property,")
        |> mes("owned by Mister Dearles.")
        |> mes("Please leave immediately!")
        |> next()
        |> warp("comodo", 187, 164)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp identify_player(ctx) do
    ctx = mes(ctx, "Let's see...")
    mes(ctx, Rathena.concat(Rathena.concat("You're ", char_name(ctx, 0)), "?"))
  end

  defp exam_instructions(ctx) do
    ctx
    |> mes("Please click on the")
    |> mes("Chat Room to enter the")
    |> mes("Standby Room. When it's")
    |> mes("your turn, the test will begin!")
    |> next()
    |> mes("[Lamadin]")
    |> mes("The top left pole")
    |> mes("means 'Up,' and there")
    |> mes("are a total of four marks")
    |> mes("designated as Upper, Lower")
    |> mes("Left and Right. Hitting each")
    |> mes("mark will produce a sound.")
    |> next()
    |> mes("[Lamadin]")
    |> mes("During the test,")
    |> mes("you must hit the marks")
    |> mes("according to the given")
    |> mes("instructions in order to")
    |> mes("play music. Nifty, huh?")
    |> next()
    |> mes("[Lamadin]")
    |> mes("I'm in charge of grading")
    |> mes(
      "your performance and determining your qualification. Please do your best and come back to me when"
    )
    |> mes("you finish the test. Good luck~")
    |> mes("Please do your best.")
    |> close()
  end
end
