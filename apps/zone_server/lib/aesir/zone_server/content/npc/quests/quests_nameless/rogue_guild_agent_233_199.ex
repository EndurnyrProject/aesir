defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.RogueGuildAgent233199 do
  @moduledoc """
  Trains a supposed Rogue recruit while investigating rumors.

  ## Behavior

  - Assigns the player a mask-gathering task and rewards its completion.
  - Directs the player to the Morocc agent and responds to quest progress.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "comodo",
        x: 233,
        y: 199,
        dir: 5,
        sprite: 810,
        name: "Rogue Guild Agent",
        scope: :shared,
        unique_name: "Rogue Guild Agent#nd3"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{907, 200}]) == 0 ->
        ctx
        |> mes("[Agent]")
        |> mes("You've got too many")
        |> mes("things on you. Why")
        |> mes("don't you put some")
        |> mes("of it in Kafra Storage")
        |> mes("before talking to me, eh?")
        |> close()

      get_char_var(ctx, :rumour_nd, 0) < 1 ->
        ctx |> mes("[Agent]") |> mes("......") |> mes("......") |> close()

      get_char_var(ctx, :rumour_nd, 0) > 0 and get_char_var(ctx, :rumour_nd, 0) < 16 ->
        if get_char_var(ctx, :zdan_edq, 0) > 12 do
          ctx
          |> mes("[Agent]")
          |> mes("You're the one")
          |> mes("that helped take")
          |> mes("down the Z Gang?")
          |> mes("Heh! Good work~")
          |> close()
        else
          ctx |> mes("[Agent]") |> mes("Who are you? Hm.") |> close()
        end

      get_char_var(ctx, :rumour_nd, 0) == 16 or get_char_var(ctx, :rumour_nd, 0) == 18 ->
        assign_training(ctx)

      get_char_var(ctx, :rumour_nd, 0) == 19 ->
        check_masks(ctx)

      get_char_var(ctx, :rumour_nd, 0) == 20 ->
        ctx
        |> mes("[Agent]")
        |> mes("Oh, hey, you're back?")
        |> mes("Weren't you already on")
        |> mes("your way to Morocc?")
        |> close()

      get_char_var(ctx, :rumour_nd, 0) == 22 ->
        ctx =
          ctx |> mes("[Agent]") |> mes("Heh, looks like we") |> mes("solved this case~") |> next()

        if get_char_var(ctx, :zdan_edq, 0) > 12 do
          ctx
          |> mes("[Agent]")
          |> mes("Thanks to you,")
          |> mes("we don't have to")
          |> mes("worry about that")
          |> mes("crummy ol' Z Gang.")
          |> close()
        else
          ctx
          |> mes("[Agent]")
          |> mes("Until the world is")
          |> mes("free of evil and all")
          |> mes("that, the Rogues'll")
          |> mes("always have work to do.")
          |> close()
        end

      true ->
        ctx
        |> mes("[Agent]")
        |> mes("Why are you still")
        |> mes("sticking around?")
        |> mes("Don't you have")
        |> mes("something more")
        |> mes("important to do?")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp assign_training(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Agent]")
      |> mes("You know, Rogues are")
      |> mes("tricky and hard to catch,")
      |> mes("so I'm gonna teach you to")
      |> mes("carry yourself through some")
      |> mes("self-discipline. Got it?")
      |> mes("Discipline! You need it!")
      |> next()
      |> mes("[Agent]")
      |> mes("From here on out,")
      |> mes("I want you to yell")
      |> mes("''Yes, sir!'' when you")
      |> mes("acknowledge my instructions.")
      |> mes("You got that! Loud and clear!")
      |> next()
      |> select(["Yes, Sir!", "..."])

    case choice do
      1 ->
        {ctx, _} =
          ctx
          |> emotion(:think)
          |> mes("[Agent]")
          |> mes("Right on, right on.")
          |> mes("Hm. Let's try that again...")
          |> mes("Let me hear you say it louder!")
          |> next()
          |> select(["Yes, Sir!"])

        {ctx, _} =
          ctx
          |> mes("[Agent]")
          |> mes("Nice!")
          |> next()
          |> mes("[Agent]")
          |> mes("Okay, now for your")
          |> mes("training instructions...")
          |> mes("There's a rumor that a monster")
          |> mes("has invaded the village, but")
          |> mes("I'm sure it's just someone")
          |> mes("trying to scare the public.")
          |> next()
          |> mes("[Agent]")
          |> mes("I'm pretty sure the, uh,")
          |> mes("perp is wearing a mask to")
          |> mes("fool people into thinkin'")
          |> mes("fhe's monster. This means...")
          |> mes("Your mission is to bring")
          |> mes("me some monsters masks.")
          |> next()
          |> mes("[Agent]")
          |> mes("Heh...")
          |> mes("What's your mission?!")
          |> next()
          |> select(["Bring monster masks!"])

        ctx =
          ctx
          |> mes("[Agent]")
          |> mes("Groove.")
          |> next()
          |> mes("[Agent]")
          |> mes("Alright, bring me")
          |> mes("^FF00002 scary lookin'")
          |> mes("monster masks^000000.")
          |> mes("Just 2, and make")
          |> mes("sure they're scary.")
          |> set_char_var(:rumour_nd, 19)
          |> close()

        ctx

      2 ->
        ctx
        |> mes("[Agent]")
        |> mes("What do you think")
        |> mes("you're doin'? I'm")
        |> mes("pretty insulted, seeing")
        |> mes("as you're all defiant like")
        |> mes("this. How do you expect")
        |> mes("to become a good Rogue?!")
        |> close()

      _ ->
        ctx
    end
  end

  defp check_masks(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Agent]")
      |> mes("So... You bring")
      |> mes("the masks like")
      |> mes("a good little soldier?")
      |> next()
      |> select(["Uh huh.", "Yes, Sir!"])

    case choice do
      1 ->
        ctx
        |> mes("[Agent]")
        |> mes("Hey, remember our")
        |> mes("little rule? I even")
        |> mes("clued you off when")
        |> mes("I said ''soldier!'' Heh~")
        |> close()

      2 ->
        ctx = ctx |> mes("[Agent]") |> mes("Okay, let me check.") |> next()

        if count_item(ctx, 2278) > 0 or count_item(ctx, 2281) > 0 or count_item(ctx, 5043) > 0 or
             count_item(ctx, 2288) > 0 or count_item(ctx, 2292) > 0 or
             count_item(ctx, 2297) > 0 or count_item(ctx, 5005) > 0 or
             count_item(ctx, 5086) > 0 or count_item(ctx, 5087) > 0 or
             count_item(ctx, 5088) > 0 or count_item(ctx, 5089) > 0 or
             count_item(ctx, 5090) > 0 or count_item(ctx, 5176) > 0 or
             count_item(ctx, 5203) > 0 or count_item(ctx, 5098) > 0 or
             count_item(ctx, 5121) > 0 or count_item(ctx, 5130) > 0 or
             count_item(ctx, 5177) > 0 or count_item(ctx, 5169) > 0 or
             count_item(ctx, 5143) > 0 do
          {ctx, reply} =
            ctx
            |> mes("[Agent]")
            |> mes("Excellent!")
            |> next()
            |> mes("[Agent]")
            |> mes("Look, I know I gave you")
            |> mes("a hard time. And don't worry,")
            |> mes("I'm not gonna take your masks.")
            |> mes("I just wanted to train you")
            |> mes("to be the best Rogue that")
            |> mes("you can be. Understand?")
            |> next()
            |> mes("[Agent]")
            |> mes("Eh? So what's this")
            |> mes("note you keep carrying")
            |> mes("around in your hand?")
            |> next()
            |> mes("[Agent]")
            |> mes("Hmmm... Mmmhmmm...")
            |> mes("Hmmm... Mmmhmmm...")
            |> mes("Hmmm... Mmmhmmm... Oh!")
            |> next()
            |> mes("[Agent]")
            |> mes("Aw, nuts! Why didn't")
            |> mes("you say something?")
            |> mes("I thought you were")
            |> mes("here to take the Job")
            |> mes("change test for Rogues!")
            |> emotion(:huk)
            |> next()
            |> emotion(:sorry)
            |> mes("[Agent]")
            |> mes("Aw man, you came all this")
            |> mes("way to help me out, and")
            |> mes("I thought I--I'm really,")
            |> mes("really sorry! It's just")
            |> mes("that I got you mixed up")
            |> mes("with a trainee I'm expecting...")
            |> next()
            |> mes("[Agent]")
            |> mes("Do me a favor, and")
            |> mes("not tell anyone, yeah?")
            |> mes("Consider this... I dunno,")
            |> mes("an insider look into the")
            |> mes("Rogue world if you would.")
            |> emotion(:cry)
            |> next()
            |> select(["Yes, sir!", "I won't tell anyone."])

          ctx =
            case reply do
              1 ->
                ctx
                |> mes("[Agent]")
                |> mes("Whoa! Whoa!")
                |> mes("You can knock")
                |> mes("that off now.")
                |> mes("Thanks, I really")
                |> mes("appreciate it.")
                |> next()

              2 ->
                ctx
                |> mes("[Agent]")
                |> mes("Thanks. I knew I could")
                |> mes("trust you somehow!")
                |> next()

              _ ->
                ctx
            end

          if reply in [1, 2] do
            ctx =
              ctx
              |> mes("[Agent]")
              |> mes("Anyway, you've got one")
              |> mes("last place to go, Morocc.")
              |> mes("Check in with the Rogue")
              |> mes("agent over there, will you?")
              |> mes("Oh, and take this food")
              |> mes("with my apologies, 'kay?")
              |> set_local(:sorry_item, Enum.random(1..6))

            item =
              case get_local(ctx, :sorry_item, 0) do
                1 -> 12044
                2 -> 12059
                3 -> 12064
                4 -> 12049
                5 -> 12054
                6 -> 12069
                _ -> nil
              end

            if item do
              ctx
              |> give_item(item, 1)
              |> next()
              |> mes("[Agent]")
              |> mes("Hey, be safe on your")
              |> mes("way to Morocc, alright?")
              |> mes("Good luck finding that")
              |> mes("Rogue agent over there.")
              |> mes("Oh, and mum's the word")
              |> mes("on my little mistake~")
              |> set_char_var(:rumour_nd, 20)
              |> close()
            else
              ctx
              |> mes("[Agent]")
              |> mes("Wait, something")
              |> mes("isn't quite right. You")
              |> mes("mind coming back")
              |> mes("a little later?")
              |> close()
            end
          else
            ctx
          end
        else
          ctx
          |> mes("[Agent]")
          |> mes("Hey, didja even bother")
          |> mes("to bring the masks?")
          |> mes("Go back and find them!")
          |> close()
        end

      _ ->
        ctx
    end
  end
end
