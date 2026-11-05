defmodule Aesir.ZoneServer.Content.Npc.Quests.EyeOfHellion.Npc4567 do
  @moduledoc """
  The Veggie Lady, a hidden Prontera shrub that trades the vendor code for the
  `BINGO` password from the training dummy's clue.

  ## Behavior

  - On touch while `HELLIONQ` is 40 or 41, asks for the missing last word of the
    clue and spells out the code `3847147298` twice when the player answers
    `BINGO`, advancing `HELLIONQ` to 42 or 43 respectively.
  - Any other answer ends the conversation with the player unable to recall the word.
  - Silent at every other quest step.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 45,
        y: 67,
        dir: 0,
        sprite: 111,
        name: " ",
        scope: :shared,
        unique_name: " #prt_key-1-1",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    case get_char_var(ctx, :HELLIONQ, 0) do
      step when step in [40, 41] -> ask_password(ctx, step)
      _step -> ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnTouch_", ctx)

  defp ask_password(ctx, step) do
    {ctx, answer} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Well, according to the")
      |> mes("message in that old training")
      |> mes("dummy, this is where I'm")
      |> mes("supposed to go. Nine steps")
      |> mes("north, 3 steps west. And now...")
      |> mes("Veggie Lady. Okay, okay...")
      |> next()
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Huh. That's creepy.")
      |> mes("There's one right there")
      |> mes("staring at me. But after")
      |> mes("the words ''Veggie Lady,''")
      |> mes("all the message says is, um,")
      |> mes("what was that last word again?")
      |> next()
      |> input(:string)

    if answer == "BINGO" do
      give_code(ctx, step)
    else
      reject_answer(ctx, answer)
    end
  end

  defp give_code(ctx, step) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Of course!")
    |> mes("''BINGO!'' But")
    |> mes("I don't see a hall")
    |> mes("full of old people")
    |> mes("around here, I--")
    |> next()
    |> mes("[Veggie Lady]")
    |> mes("Finally, you say it.")
    |> mes("Yeesh, I thought I was")
    |> mes("going to wait forever for")
    |> mes("somebody to say that")
    |> mes("password. Okay, here's")
    |> mes("the code number you want...")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("C-code number?")
    |> mes("Wait, wh-what...?")
    |> next()
    |> mes("[Veggie Lady]")
    |> mes("Awww...I don't know!")
    |> mes("I'm only gonna say it")
    |> mes("now:^4D4DFF 3847147298^000000. One")
    |> mes("more time, in case you")
    |> mes("didn't get it:^4D4DFF 3847147298^000000.")
    |> mes("Don't forget it, adventurer.")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Wait... What does")
    |> mes("this all mean? Won't")
    |> mes("you tell me more?")
    |> next()
    |> mes("[Veggie Lady]")
    |> mes("No. I've been given")
    |> mes("explicit instructions")
    |> mes("to not tell you more.")
    |> mes("In fact, I hate talking.")
    |> mes("That's why I sell vegetables.")
    |> set_char_var(:HELLIONQ, step + 2)
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Holy cow...")
    |> mes("This is all")
    |> mes("really cloak and")
    |> mes("dagger type stuff!")
    |> close()
  end

  defp reject_answer(ctx, answer) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("#{answer}!")
    |> mes("Hmmm. No, no that couldn't")
    |> mes("be it. What in the world was that word and why can't I remember it")
    |> mes("when I seemingly need it most?")
    |> close()
  end
end
