defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsYuno.Cici do
  @moduledoc """
  CiCi researches the Riding Engine.

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
        map: "yuno_in03",
        x: 178,
        y: 43,
        dir: 0,
        sprite: 121,
        name: "CiCi",
        scope: :shared,
        unique_name: "CiCi#juno"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :metto_q, 0) do
      6 ->
        {ctx, choice} =
          ctx
          |> mes("[CiCi]")
          |> mes("My name is CiCi. I am one of the three great scientists in this city.")
          |> next()
          |> mes("[CiCi]")
          |> mes(
            "There are many great scientists in this city, but being in the top three is a true honor. Don't you agree?"
          )
          |> next()
          |> mes("[CiCi]")
          |> mes("Well, I think I've bragged a little too much now, what can I do for you?")
          |> next()
          |> select(["I want to warn you.", "Nothing, just saying Hi."])

        case choice do
          1 ->
            ctx
            |> set_char_var(:metto_q, 7)
            |> mes("[CiCi]")
            |> mes(
              "Hm? Metto said that he doesn't need my Riding Engine theory?! Hmpf, what an ingrate!"
            )
            |> next()
            |> mes("[CiCi]")
            |> mes(
              "I have half a mind to teach him a little something about true science and intelligent research."
            )
            |> next()
            |> mes("[CiCi]")
            |> mes("He thinks that I owe him an apology?! For what? Why should I apologize...?!")
            |> next()
            |> mes("[CiCi]")
            |> mes(
              "Whatever, I really didn't have the necessary parts to help him anyway. I guess, either way, he would not have had a chance."
            )
            |> next()
            |> mes("[CiCi]")
            |> mes(
              "Let him know I really don't want to be a part of what he is doing. He isn't even doing the type of research that we would be able to publicize."
            )
            |> close()

          2 ->
            ctx
            |> mes("[CiCi]")
            |> mes(
              "What? That's it? I was bored before you came, but you've managed to bore me even more."
            )

          _ ->
            ctx
        end

      stage when stage < 6 ->
        ctx
        |> mes("[CiCi]")
        |> mes("My name is CiCi. I am one of the three great scientists in this city.")
        |> next()
        |> mes("[CiCi]")
        |> mes(
          "There are many great scientists here, but being in the top three is a true honor, wouldn't you agree?"
        )
        |> close()

      _ ->
        ctx
        |> mes("[CiCi]")
        |> mes("Hmmm...")
        |> mes("I want to improve the Riding Engine in a new way, but I lack the parts I need...")
        |> next()
        |> mes("[CiCi]")
        |> mes(
          "What a headache~ And Metto has never offered me any help at all. This will not be easy."
        )
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
