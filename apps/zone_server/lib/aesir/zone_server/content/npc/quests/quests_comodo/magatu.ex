defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsComodo.Magatu do
  @moduledoc """
  Magatu searches for the legendary Comodo Cheese.

  ## Behavior

  - Directs an interested adventurer to Manzi with his lucky bottle cap.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Evera
    - Samuray22
    - Brainstorm

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "comodo",
        x: 163,
        y: 280,
        dir: 4,
        sprite: 55,
        name: "Magatu",
        scope: :shared,
        unique_name: "Magatu#cmd"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      case get_char_var(ctx, :dmdswrd_Q, 0) do
        8 ->
          ctx
          |> mes("[Magatu]")
          |> mes("Comodo Cheese...")
          |> mes("It really exists...!")
          |> mes("And I'm so close to")
          |> mes("having the proof! Oh...")
          |> mes("That look in your eyes...")
          |> mes("Y-you really believe me!")
          |> next()
          |> mes("[Magatu]")
          |> mes("At long last, not only")
          |> mes("someone who believes me,")
          |> mes("but an adventurer to boot!")
          |> mes("Great, this is perfect! Now,")
          |> mes("listen, you want to learn more")
          |> mes("about Comodo Cheese, right?")
          |> next()
          |> mes("[Magatu]")
          |> mes("Well, I happen to know")
          |> mes("someone who knows someone")
          |> mes("that might be able to give you")
          |> mes(
            "the chance to try it for yourself! His name is ^3355FFManzi^000000 , and you can"
          )
          |> mes("find him in Comodo's Casino.")
          |> next()
          |> mes("[Magatu]")
          |> mes("Oh, here, before I forget,")
          |> mes("take my lucky bottle cap!")
          |> mes("Show this to Manzi, and he'll")
          |> mes("know that I sent you, and that")
          |> mes("you want to learn more about")
          |> mes("the elusive Comodo Cheese.")
          |> next()
          |> mes("^3355FFYou have received")
          |> mes("Magatu's lucky bottle")
          |> mes("cap to present to Manzi.")
          |> set_char_var(:dmdswrd_Q, 9)

        9 ->
          ctx
          |> mes("[Magatu]")
          |> mes("Oh, don't forget to")
          |> mes("show my lucky bottle cap")
          |> mes("to Manzi, okay? You can find")
          |> mes("him inside Comodo's Casino~")
          |> mes("Good luck, and I hope you get")
          |> mes("to try that Comodo Cheese~")

        _ ->
          ctx
          |> mes("[Magatu]")
          |> mes("It's true, it really")
          |> mes("exists... Comodo Cheese!")
          |> mes("Its flavor must be incomparably")
          |> mes("delicious if adventurers have")
          |> mes("quested to obtain it for so")
          |> mes("many generations...")
      end

    close(ctx)
  end
end
