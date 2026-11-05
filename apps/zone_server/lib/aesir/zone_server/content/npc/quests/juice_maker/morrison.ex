defmodule Aesir.ZoneServer.Content.Npc.Quests.JuiceMaker.Morrison do
  @moduledoc """
  Morrison, the little boy in Prontera who refuses fruit until he is fed Meat.

  ## Behavior

  - Once the quest is known, or he has given up on Meat, he refuses to talk about it.
  - Ten pieces of Meat are enough: he stops asking for more, and on the last piece he offers the
    sweets he had been saving.
  - Carrying Meat lets him beg for it; handing one over advances the count, refusing turns him
    against the player for good.
  - Otherwise he rants about fruit, or sulks when the player ends the conversation.

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
        x: 47,
        y: 173,
        dir: 3,
        sprite: 97,
        name: "Morrison",
        scope: :shared,
        unique_name: "Morrison#juice"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @speaker "[Little Morrison]"
  @meat 517

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      quest_known?(ctx) -> refuse_discussion(ctx)
      get_char_var(ctx, :morison_meat, 0) > 9 -> fed_enough(ctx)
      true -> beg_for_meat(ctx)
    end
  end

  defp quest_known?(ctx) do
    Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 1)) or
      get_char_var(ctx, :morison_meat, 0) == 15
  end

  defp refuse_discussion(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Bleh... Forget it.")
    |> mes(
      "I'm just going to shrivel to death just eating fruits. Don't bother worrying about me ."
    )
    |> close()
  end

  defp fed_enough(ctx) do
    ctx =
      ctx
      |> mes(@speaker)
      |> mes("Ah... so full~")
      |> mes("I think I can live now.")
      |> mes(
        "You don't have to give me any more Meat. I feel like I'm going to explode if I eat any more."
      )

    if get_char_var(ctx, :morison_meat, 0) == 10 do
      ctx
      |> next()
      |> set_char_var(:morison_meat, get_char_var(ctx, :morison_meat, 0) + 1)
      |> mes(@speaker)
      |> mes("Oh... and... um.")
      |> mes("Take this.")
      |> next()
      |> mes(@speaker)
      |> mes(
        "It's a little something I've been saving to eat for later, but since you gave me Meat, I think I can pass on the sweets."
      )
      |> close()
    else
      close(ctx)
    end
  end

  defp beg_for_meat(ctx) do
    ctx =
      ctx
      |> mes(@speaker)
      |> mes("Agh....Noooo!!!")
      |> mes("No, don't make me eat it! I can't bear to taste fruits!")
      |> next()

    if count_item(ctx, @meat) > 0 do
      meat_menu(ctx)
    else
      short_talk(ctx)
    end
  end

  defp meat_menu(ctx) do
    {ctx, choice} = select(ctx, ["Talk", "Show the Meat", "Cancel"])

    case choice do
      1 -> refuse_fruit_again(ctx)
      2 -> offer_meat(ctx)
      3 -> refuse_fruits_and_vegetables(ctx)
      _ -> ctx
    end
  end

  defp refuse_fruit_again(ctx) do
    ctx
    |> mes(@speaker)
    |> mes(
      "Aaaagh!! Once or twice is enough!! I refuse to eat any more fruits! You have to peel them and there's so much juice that it makes you feel icky..."
    )
    |> next()
    |> mes(@speaker)
    |> mes(
      "And they're all slippery and sour... Even if I eat it, I still feel hungry. Aaaah~! Give me Meat!"
    )
    |> close()
  end

  defp offer_meat(ctx) do
    {ctx, choice} =
      ctx
      |> mes(@speaker)
      |> mes("Ooh! M-Meaaat~")
      |> mes("Ah... hu...hungry...")
      |> mes("The scent of Meat...")
      |> mes("Excuse me...")
      |> mes("C-can I please have one?")
      |> next()
      |> select(["Give Meat", "Don't Give Meat"])

    if choice == 1 do
      give_meat(ctx)
    else
      refuse_meat(ctx)
    end
  end

  defp give_meat(ctx) do
    ctx
    |> delitem(@meat, 1)
    |> set_char_var(:morison_meat, get_char_var(ctx, :morison_meat, 0) + 1)
    |> mes(@speaker)
    |> mes("Wow~!!! Meat!!")
    |> mes("So yummy!")
    |> mes("Thank you,")
    |> mes("I think I can")
    |> mes("live now.")
    |> mes("*Chew chew*")
    |> close()
  end

  defp refuse_meat(ctx) do
    ctx
    |> set_char_var(:morison_meat, 15)
    |> mes(@speaker)
    |> mes("Waah...!")
    |> mes("Fine, I get it now.")
    |> mes("Adults are all the same!")
    |> close()
  end

  defp short_talk(ctx) do
    {ctx, choice} = select(ctx, ["Talk", "Cancel"])

    if choice == 1 do
      explain_fruit_disgust(ctx)
    else
      refuse_fruits_and_vegetables(ctx)
    end
  end

  defp explain_fruit_disgust(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Aaah!! I can't eat any more fruits!")
    |> next()
    |> mes(@speaker)
    |> mes(
      "I refuse to eat any more fruits! You have to peel them and there's so much juice that it makes you feel icky..."
    )
    |> next()
    |> mes(@speaker)
    |> mes("And they're all slippery and sour... Even if I eat it, I still feel hungry.")
    |> mes("Aaaah~!")
    |> mes("Give me Meat!")
    |> close()
  end

  defp refuse_fruits_and_vegetables(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Aaaaah!!! No matter what, I'm not going to eat fruits and vegetables!")
    |> close()
  end
end
