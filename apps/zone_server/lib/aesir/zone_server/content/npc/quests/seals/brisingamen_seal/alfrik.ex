defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Alfrik do
  @moduledoc """
  Alfrik guides adventurers through awakening the dwarves of the Brisingamen seal quest.

  ## Behavior

  - Advances the quest by directing the player to Dvalin and describing Brisingamen's materials.
  - Hides after each completed conversation and on initialization.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Toms
    - L0ne_W0lf
    - Samuray22
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "xmas",
        x: 36,
        y: 103,
        dir: 4,
        sprite: 826,
        name: "Alfrik",
        scope: :shared,
        unique_name: "Alfrik#1"
      }
    ]

  @impl true
  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :god_brising, 0) == 49 ->
        ctx
        |> mes("[Alfrik]")
        |> mes("I've got nothing")
        |> mes("more to say! Now")
        |> mes("get out of here!")
        |> mes("I don't want to")
        |> mes("be found!")
        |> close2()
        |> hideonnpc("Alfrik#1")

      get_char_var(ctx, :god_brising, 0) == 48 ->
        {ctx, materials_choice} =
          ctx
          |> mes("[Alfrik]")
          |> mes("What's up, human?")
          |> mes("All of us have awakened.")
          |> next()
          |> select(["I just wanted to say hello.", "What are Brisingamen's materials?"])

        case materials_choice do
          1 ->
            ctx
            |> mes("[Alfrik]")
            |> mes(
              "Your gesture is appreciated, but I'd rather hide than socialize. I don't want to be found by the crows of Odin!"
            )
            |> close2()
            |> hideonnpc("Alfrik#1")

          2 ->
            ctx
            |> mes("[Alfrik]")
            |> mes(
              "Materials for Brisingamen? For the human imitation, the materials are pretty easy to gather..."
            )
            |> next()
            |> mes("[Alfrik]")
            |> mes(
              "The power of weapons used by gods, when they battled demons a thousand years ago, and everything detached from Brisingamen. That's basically what you need."
            )
            |> next()
            |> mes("[Alfrik]")
            |> mes("If you want to")
            |> mes("create a Brisingamen,")
            |> mes("you will need.....")
            |> next()
            |> mes("[Alfrik]")
            |> mes("^4d4dffFreya's Jewel")
            |> mes("Silver Ornament")
            |> mes("Snow Crystal")
            |> mes("Ripple")
            |> mes("Drifting Air^000000")
            |> next()
            |> mes("[Alfrik]")
            |> mes(
              "You might need some gems, like Saphire, Peal, Opal, Curse Ruby, and maybe even some Gold to decorate the necklace."
            )
            |> next()
            |> mes("[Alfrik]")
            |> mes(
              "Although I give freely of my advice, we four Dwarves will no longer do smithing work unless it be Freya's command."
            )
            |> next()
            |> mes("[Alfrik]")
            |> mes(
              "But I can promise you one thing. Since the four of us have awakened, humans will obtain the Brisingamen for sure."
            )
            |> next()
            |> mes("[Alfrik]")
            |> mes("Now...")
            |> mes("Leave me")
            |> mes("in peace.")
            |> set_char_var(:god_brising, 49)
            |> close2()
            |> hideonnpc("Alfrik#1")

          _ ->
            ctx
        end

      get_char_var(ctx, :god_brising, 0) == 40 ->
        {ctx, awakening_choice} =
          ctx
          |> mes("[Alfrik]")
          |> mes("^333333*Yawn...*^000000")
          |> mes("It's been a long time since I've been outside! W-wait! You're not...")
          |> next()
          |> mes("[Alfrik]")
          |> mes("Who sent you?!")
          |> mes("Loki? Heimdall?")
          |> mes("Or was it Freya?")
          |> next()
          |> select(["No one, it was an accident!", "It was Valkyrie."])

        case awakening_choice do
          1 ->
            {ctx, answer_choice} =
              ctx
              |> mes("[Alfrik]")
              |> mes(
                "Don't even think of lying to me, human! There's no way you could have awoken me without knowing"
              )
              |> mes("the password! Now, speak!")
              |> next()
              |> select(["Valkyrie told me.", "It was a coincidence!"])

            case answer_choice do
              1 ->
                explain_awakening(ctx)

              2 ->
                ctx
                |> mes("[Alfrik]")
                |> mes("Coincidence?")
                |> mes(
                  "Impossible! How dare you lie! Don't ever come back, or the gods will find me!"
                )
                |> close2()
                |> hideonnpc("Alfrik#1")

              _ ->
                ctx
            end

          2 ->
            explain_awakening(ctx)

          _ ->
            ctx
        end

      get_char_var(ctx, :god_brising, 0) == 41 ->
        {ctx, dvalin_choice} =
          ctx
          |> mes("[Alfrik]")
          |> mes("Why are you still here?")
          |> mes("I told you go wake Dvalin!")
          |> next()
          |> select(["Where is he?", "Tell me more about Brisingamen."])

        case dvalin_choice do
          1 ->
            ctx
            |> mes("[Alfrik]")
            |> mes("Ah. Right.")
            |> mes("I forgot to tell")
            |> mes("you. Poor Dvalin.")
            |> mes("Now, where was it?")
            |> next()
            |> mes("[Alfrik]")
            |> mes(
              "We were afraid that Odin and Heimdall would punish us because, well, in their eyes we disgraced the goddess."
            )
            |> next()
            |> mes("[Alfrik]")
            |> mes(
              "Oh course, they never would have been angered if it weren't for Loki's trickery."
            )
            |> next()
            |> mes("[Alfrik]")
            |> mes(
              "We loved Freya so much that we decided to hide ourselves beneath the path that she walked. To be as close to any trace of her as we could."
            )
            |> next()
            |> mes("[Alfrik]")
            |> mes("Poor Dvalin is sleeping")
            |> mes(
              "under the path in the East. Once there, you'll feel the scent the goddess. I can't remember where the others are sleeping, but you cannot forget these words..."
            )
            |> next()
            |> mes("[Alfrik]")
            |> mes("^4d4dffHer lovely scent")
            |> mes("Still lingers in the wind.")
            |> mes("We surrendered our hearts")
            |> mes("To those tender teardrops")
            |> mes("Those seductive red lips.^000000")
            |> set_char_var(:god_brising, 42)
            |> close2()
            |> hideonnpc("Alfrik#1")

          2 ->
            ctx
            |> mes("[Alfrik]")
            |> mes(
              "Brisingamen is our masterpiece, a necklace we forged for Freya. Even if we tried making it again, I doubt it would be as good."
            )
            |> next()
            |> mes("[Alfrik]")
            |> mes(
              "It looked perfect on Freya. Very difficult to create jewelry that actually enhances the attractiveness of the goddess of beauty."
            )
            |> next()
            |> mes("[Alfrik]")
            |> mes(
              "Perhaps our greatest reward was that beautiful smile of satisfaction she gave us when that we gave her that necklace. We loved her so."
            )
            |> next()
            |> mes("[Alfrik]")
            |> mes(
              "Is it that wrong for dwarves to love a goddess? Perhaps we were punished because the gods, even Odin, loved her as well."
            )
            |> next()
            |> mes("[Alfrik]")
            |> mes(
              "In any case, we've never seen the true Brisingamen again. But something very similar to it can be created..."
            )
            |> next()
            |> mes("[Alfrik]")
            |> mes(
              "You'll need materials that have been graced by the goddess' presense. Traces of the goddess in the earth, water and the wind."
            )
            |> next()
            |> mes("[Alfrik]")
            |> mes(
              "And if the Brisingamen is recreated, the power of a god will be in the hands of a human. That human could be you!"
            )
            |> next()
            |> mes("[Alfrik]")
            |> mes(
              "Poor Dvalin is sleeping under the path in the East. Once there, you'll feel the scent the goddess."
            )
            |> next()
            |> mes("[Alfrik]")
            |> mes(
              "I can't remember where the others are sleeping, but you cannot forget these words..."
            )
            |> next()
            |> mes("[Alfrik]")
            |> mes("^4d4dffHer lovely scent")
            |> mes("Still lingers in the wind.")
            |> mes("We surrendered our hearts")
            |> mes("To those tender teardrops")
            |> mes("Those seductive red lips.^000000")
            |> set_char_var(:god_brising, 42)
            |> close2()
            |> hideonnpc("Alfrik#1")

          _ ->
            ctx
        end

      get_char_var(ctx, :god_brising, 0) == 42 ->
        ctx
        |> mes("[Alfrik]")
        |> mes("Will you please!")
        |> mes(
          "Get lost before Loki and Heimdall find out I've awakened! Now hurry, find Dvalin, and wake him up!"
        )
        |> close2()
        |> hideonnpc("Alfrik#1")

      get_char_var(ctx, :god_brising, 0) > 42 and
          get_char_var(ctx, :god_brising, 0) < 48 ->
        ctx
        |> mes("[Alfrik]")
        |> mes(
          "Oh, finally all of us have awakened! Now, the power of the goddess can be retrieved from the earth, water and the wind!"
        )
        |> next()
        |> mes("[Alfrik]")
        |> mes("Hahahahaha!")
        |> mes("This should be")
        |> mes("interesting!")
        |> close2()
        |> hideonnpc("Alfrik#1")

      true ->
        ctx
        |> mes("[Alfrik]")
        |> mes("Mmm...?")
        |> mes("I've got")
        |> mes("no business")
        |> mes("with you.")
        |> close2()
        |> hideonnpc("Alfrik#1")
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp explain_awakening(ctx) do
    ctx
    |> mes("[Alfrik]")
    |> mes("Valkyrie...?")
    |> mes("Odin's warmonger?")
    |> mes("What could Odin want,")
    |> mes("I haven't done anything wrong!")
    |> next()
    |> mes(
      "^3355FFYou explained everything to Alfrik, who seems to worry about being targeted by Odin.^000000"
    )
    |> next()
    |> mes("[Alfrik]")
    |> mes("So that's it.")
    |> mes("Seeking out our")
    |> mes("masterpiece? You")
    |> mes("humans must desire")
    |> mes("the power of the gods.")
    |> mes("Interesting.")
    |> next()
    |> mes("[Alfrik]")
    |> mes("The time for us to revive may actually have come! Alright then,")
    |> mes("I, Alfrik shall cooperate with you humans.")
    |> next()
    |> mes("[Alfrik]")
    |> mes(
      "After all, getting on Odin's good side like this is much better than being tortured by Loki."
    )
    |> next()
    |> mes("[Alfrik]")
    |> mes("Now...")
    |> mes("Understand that")
    |> mes("there can only be")
    |> mes("one true Brisingamen.")
    |> mes("After all, it's our")
    |> mes("masterpiece.")
    |> next()
    |> mes("[Alfrik]")
    |> mes(
      "However, that doesn't mean an imitation, with the same power as that godly item, can't be made. Isn't it tempting, the power of a god?"
    )
    |> next()
    |> mes("[Alfrik]")
    |> mes("First things first. If you want to make the necklace, you must")
    |> mes(
      "awaken all four of us. Because of Loki's threat, we all hid ourselves in different places."
    )
    |> next()
    |> mes("[Alfrik]")
    |> mes("Go wake all my brothers!")
    |> mes(
      "Let's see if the Brisingamen can be made once again! First, go and wake Dvalin before the gods and giants find out!"
    )
    |> set_char_var(:god_brising, 41)
    |> close2()
    |> hideonnpc("Alfrik#1")
  end

  def ev_oninit(ctx) do
    hideonnpc(ctx, "Alfrik#1")
  end
end
