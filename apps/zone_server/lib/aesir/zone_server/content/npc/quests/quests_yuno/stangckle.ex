defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsYuno.Stangckle do
  @moduledoc """
  Stangckle is a scientist and Metto’s colleague.

  ## Behavior

  - Responds to the player’s claim during Metto’s research quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf
    - kobra_k88
    - Darkchild
    - Lupus
    - Samuray22
    - akrus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in01",
        x: 17,
        y: 95,
        dir: 5,
        sprite: 99,
        name: "Stangckle",
        scope: :shared,
        unique_name: "Stangckle#juno"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx = mes(ctx, "[Stangckle]")

    case get_char_var(ctx, :metto_q, 0) do
      2 ->
        {ctx, choice} =
          ctx
          |> mes(
            "What can I do for you? My colleague Metto is coming here soon, so I don't have much time. So what did you say you needed?"
          )
          |> next()
          |> select(["I'm here to stop your research.", "I don't need anything."])

        if choice == 1 do
          ctx
          |> set_char_var(:metto_q, 3)
          |> mes("[Stangckle]")
          |> mes("...")
          |> next()
          |> mes("[Stangckle]")
          |> mes("...")
          |> mes("......")
          |> next()
          |> mes("[Stangckle]")
          |> mes("...")
          |> mes("......")
          |> mes(".........")
          |> next()
          |> mes("[Stangckle]")
          |> mes(
            "Is that true?? Metto doesn't think of me as a colleague, but still wants me to help him?!"
          )
          |> next()
          |> mes("[Stangckle]")
          |> mes(
            "He only sees me as an assistant and is going to steal all the credit for our discoveries?!"
          )
          |> next()
          |> mes("[Stangckle]")
          |> mes("This guy can't be trusted! The rumors were true: he really is mad!")
          |> next()
          |> mes("[Stangckle]")
          |> mes(
            "And to think, I really respected that traitor! I can't even stand to see that guy's face anymore."
          )
          |> next()
          |> mes("[Stangckle]")
          |> mes(
            "I'm glad that an honest, trustworthy person such as yourself had the guts to tell me. Thank you."
          )
          |> next()
          |> mes("[Stangckle]")
          |> mes("Now if you'll excuse me, I have work to do.")
          |> close()
        else
          ctx
          |> mes("[Stangckle]")
          |> mes("What are you doing then? Stop wasting my time.")
          |> close()
        end

      stage when stage in [0, 1] ->
        ctx
        |> mes("I am one of the scientists in this city. My name is Stangckle.")
        |> next()
        |> mes("[Stangckle]")
        |> mes("You should remember my name, it may be useful to you in the future.")
        |> close()

      _ ->
        ctx
        |> mes(
          "So Metto has become one of those mad scientists. I guess that is the choice he has ultimately made for his life."
        )
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
