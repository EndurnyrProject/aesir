defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsComodo.Manzi do
  @moduledoc """
  Manzi guides adventurers seeking Comodo Cheese.

  ## Behavior

  - Passes on a lucky coin and directs the adventurer to Hullaris.
  - Warns casino visitors, with a separate warning for novices.

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
        map: "cmd_in02",
        x: 189,
        y: 99,
        dir: 4,
        sprite: 85,
        name: "Manzi",
        scope: :shared,
        unique_name: "Manzi#cmd"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :dmdswrd_Q, 0)

    ctx =
      case progress do
        9 ->
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Excuse, but I'm")
          |> mes("looking for someone")
          |> mes("named Manzi. Do you")
          |> mes("know where I can find him?")
          |> next()
          |> mes("[Manzi]")
          |> mes("Hey guy, I'm right here.")
          |> mes("So what exactly do you")
          |> mes("want? I'm, um, not in")
          |> mes("trouble or anything, am I?")
          |> next()
          |> mes("^3355FFYou give Manzi the")
          |> mes("lucky bottle cap that you")
          |> mes("received from Magatsu.^000000")
          |> next()
          |> mes("[Manzi]")
          |> mes("Whoa, Magatsu gave you")
          |> mes("this? Ah, okay, so you must")
          |> mes("be looking for that Comodo")
          |> mes("Cheese he keeps talking about.")
          |> mes("Alright, I owe him a favor, so")
          |> mes("I'll tell you who to talk to...")
          |> next()
          |> mes("[Manzi]")
          |> mes("From the Casino, go north")
          |> mes("towards the center of the")
          |> mes("village, and then look to")
          |> mes("the right where you'll see")
          |> mes("the Dance Stage. You'll see")
          |> mes("this old woman right there.")
          |> next()
          |> mes("[Manzi]")
          |> mes("Don't be fooled by the")
          |> mes("way she looks--that old")
          |> mes("lady is one of Comodo's")
          |> mes("wisest elders. Ask her")
          |> mes("about the cheese, and")
          |> mes("let her know I sent you~")
          |> next()
          |> mes("[Manzi]")
          |> mes("Ah, she won't take you")
          |> mes("very seriously unless you")
          |> mes("show her this. Magatsu gave")
          |> mes("you his lucky bottle cap, so I'm gonna give you my lucky coin!")
          |> mes("The old crone'll recognize it~")
          |> next()
          |> set_char_var(:dmdswrd_Q, 10)
          |> mes("^3355FFYou received Manzi's")
          |> mes("''lucky coin.'' Strangely")
          |> mes("enough, both sides")
          |> mes("are heads.")

        10 ->
          ctx
          |> mes("[Manzi]")
          |> mes("Look for the old crone")
          |> mes("near the Dance Stage here")
          |> mes("in Comodo and ask her about")
          |> mes("Comodo Cheese, alright? Ah,")
          |> mes("and try not to insult her, kay?")
          |> mes("It'll make me look bad~")

        _ ->
          if Rathena.job_id(class(ctx)) == Rathena.job_id(:novice) do
            ctx
            |> mes("[Manzi]")
            |> mes("What th...?")
            |> mes("What's a kid like")
            |> mes("you doing in a Casino?")
            |> mes("Sure, it's not against the")
            |> mes("rules, but I think you oughta")
            |> mes("scram and play somewhere else!")
          else
            ctx
            |> mes("[Manzi]")
            |> mes("Hey, have a good time in")
            |> mes("the Casino, but don't go buck")
            |> mes("wild. You wanna walk out of")
            |> mes("here with the shirt on your back, you know? Some people don't")
            |> mes("even leave here with that...")
          end
      end

    close(ctx)
  end
end
