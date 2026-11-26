defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsYuno.Kato do
  @moduledoc """
  Kato researches artificial intelligence and robotics.

  ## Behavior

  - Responds to the player’s warning during Metto’s research quest.

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
        x: 19,
        y: 183,
        dir: 5,
        sprite: 55,
        name: "Kato",
        scope: :shared,
        unique_name: "Kato#juno"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx = mes(ctx, "[Kato]")

    case get_char_var(ctx, :metto_q, 0) do
      4 ->
        {ctx, choice} =
          ctx
          |> mes("I am a scientist researching all sorts of things.")
          |> next()
          |> mes("[Kato]")
          |> mes(
            "Of course, my research is private and confidential. But is there anything I can do for you?"
          )
          |> next()
          |> select(["I want to stop you from making a mistake.", "Just saying hello."])

        if choice == 1 do
          ctx
          |> set_char_var(:metto_q, 5)
          |> mes("[Kato]")
          |> mes("What? Metto said, my Great Z is inferior to Stangckles research?!")
          |> next()
          |> mes("[Kato]")
          |> mes(
            "H-he said I should rename my invention to 'Lame Z?' *Sniff* I... I don't believe it... *Sob*"
          )
          |> next()
          |> mes("[Kato]")
          |> mes(
            "I-If my invention is no good, then I guess I should destroy my Great Z... *sigh*"
          )
          |> next()
          |> mes("[Kato]")
          |> mes("Thank you for letting me know. I know it wasn't easy to tell me.")
          |> close()
        else
          ctx
          |> mes("[Kato]")
          |> mes(".........................")
          |> mes("Okay...")
          |> mes("Um... Hey.")
          |> close()
        end

      stage when stage in [6, 7, 8, 9] ->
        ctx
        |> mes("I am interested in researching artificial intelligence. You know, like robots.")
        |> next()
        |> mes("[Kato]")
        |> mes(
          "I know it a very difficult feat to accomplish, but where there's a will, there's a way."
        )
        |> next()
        |> mes("[Kato]")
        |> mes(
          "If you ever see something really amazing like this, you'll know its my handiwork."
        )
        |> close()

      _ ->
        ctx
        |> mes("I am a scientist of Artificial Intelligence and Robotics.")
        |> next()
        |> mes("[Kato]")
        |> mes(
          "I don't have a specific project right now, but my latest creation, the 'Great Z,' is truly a product of sheer and utter genius."
        )
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
