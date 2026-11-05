defmodule Aesir.ZoneServer.Content.Npc.Quests.JuiceMaker.Marianne do
  @moduledoc """
  Morrison's mother, who lets slip where fruit juice is made once she gives up on feeding her
  son fruit.

  ## Behavior

  - Once the quest is known, or Morrison has given up on Meat, she resets the argument and
    points the player to the fruit juice merchant on Payon or Morocc.
  - Feeding Morrison Meat gets the player thrown out of the house the first time.
  - After she has thrown them out, she scolds them for the Meat, or warns them to stop when
    they stay quiet.
  - Otherwise she complains about her son and explains the problem.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 49,
        y: 172,
        dir: 3,
        sprite: 53,
        name: "Marianne",
        scope: :shared,
        unique_name: "Marianne#juice"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @speaker "[Housewife Marianne]"
  # The reference script misspells the speaker on the father and son page; kept verbatim.
  @misspelled_speaker "[Housewife Marinaa]"

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      quest_known?(ctx) -> reveal_juice_rumour(ctx)
      get_char_var(ctx, :mother_marienu, 0) == 1 -> know_about_meat(ctx)
      get_char_var(ctx, :morison_meat, 0) > 0 -> chase_out(ctx)
      true -> complain_about_son(ctx)
    end
  end

  defp quest_known?(ctx) do
    Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 1)) or
      get_char_var(ctx, :morison_meat, 0) == 15
  end

  defp reveal_juice_rumour(ctx) do
    ctx =
      ctx
      |> mes(@speaker)
      |> mes("Whew...!")
      |> mes(
        "Still, he won't eat anything unless it's Meat. But maybe he will eat fruit if it was cut so that it was easy to eat. Like, if it was blended into juice..."
      )
      |> next()
      |> set_char_var(:mother_marienu, 0)
      |> set_char_var(:morison_meat, 0)

    ctx
    |> set_char_var(:MISC_QUEST, :erlang.bor(get_char_var(ctx, :MISC_QUEST, 0), 1))
    |> mes(@speaker)
    |> mes(
      "Ah! Come to think of it, I heard they were making fruit juice somewhere. Now where was it... Payon Village, or Morocc?"
    )
    |> close()
  end

  defp know_about_meat(ctx) do
    {ctx, choice} =
      ctx
      |> mes(@speaker)
      |> mes(
        "Morrison!! Eat some fruits!! You don't want to become a slobby fat pig when you grow up, do you?"
      )
      |> next()
      |> select(["Talk", "Cancel"])

    if choice == 1 do
      scold_meat_giver(ctx)
    else
      warn_meat_giver(ctx)
    end
  end

  defp scold_meat_giver(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Hm? ...You!")
    |> mes(
      "You're the one who gave, my little Morrison that Meat?! Did you come here thinking I wouldn't know about it?!"
    )
    |> next()
    |> mes(@speaker)
    |> mes("Go away, get out of my house NOW!!")
    |> close()
  end

  defp warn_meat_giver(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Morrison!! I'm going to be very very mad if you keep doing this!")
    |> close()
  end

  defp chase_out(ctx) do
    ctx
    |> set_char_var(:mother_marienu, 1)
    |> mes(@speaker)
    |> mes("Oh!!.... This...")
    |> mes("what is this...??")
    |> mes("How could you do something like this to my boy?!")
    |> next()
    |> mes(@speaker)
    |> mes("Argh! Get out of my house right this instant!")
    |> close()
  end

  defp complain_about_son(ctx) do
    # rAthena ignores the answer of this menu: the page and the close below run either way.
    {ctx, _choice} =
      ctx
      |> mes(@speaker)
      |> mes("Morrison!! Please eat some fruits!! Please~!")
      |> next()
      |> mes(@misspelled_speaker)
      |> mes("Sigh~!! Like father, like son...")
      |> next()
      |> select(["Talk", "Cancel"])

    ctx
    |> mes(@speaker)
    |> mes("*Sigh*... This is Morrison...")
    |> mes("My one and only son.")
    |> next()
    |> mes(@speaker)
    |> mes(
      "But these days, he just won't eat fruits. His face is so dull because he refuses to eat healthy. He just wants to eat Meat. I need to find a way to feed him fruits or vegetables...."
    )
    |> close()
  end
end
