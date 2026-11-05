defmodule Aesir.ZoneServer.Content.Npc.Quests.EyeOfHellion.BuddhaStatue do
  @moduledoc """
  A statue judges adventurers seeking a tablet piece.

  ## Behavior

  - Warns players without enough inventory capacity.
  - Poses a moral question at quest step 56; one answer awards a tablet and the others kill the player.
  - Signals a nearby tablet piece when the player enters its area.

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
        map: "pay_arche",
        x: 142,
        y: 28,
        dir: 0,
        sprite: 111,
        name: "Buddha Statue",
        scope: :shared,
        unique_name: "Buddha Statue#paypuzz6",
        trigger: {5, 5}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :HELLIONQ, 0) == 56 and count_item(ctx, 7333) > 0 do
      ctx
      |> specialeffect2(:heal2)
      |> specialeffect(:heal2)
      |> mes("^3355FFThe piece of tablet")
      |> mes("that you have is shining")
      |> mes("with light as if in response")
      |> mes("to something in the area.^000000")
      |> close()
    else
      ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 2000 or checkweight(ctx, [{1201, 1}]) == 0 ->
        ctx
        |> mes("^3355FFHold it right there!")
        |> mes(
          "You're carrying too many items and don't have enough inventory space to receive any rewards. Please make more inventory space available and come back to take this challenge."
        )
        |> close()

      get_char_var(ctx, :HELLIONQ, 0) == 56 ->
        question(ctx)

      true ->
        ctx
    end
  end

  defp question(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Hey, here's a huge")
      |> mes("stone statue. This")
      |> mes("must be what Grout'he")
      |> mes("was telling me about.")
      |> next()
      |> mes("[Echoing Voice]")
      |> mes("^4d4dffYou must...")
      |> mes("You must be...^000000")
      |> next()

    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("What the--?")
      |> mes("There's a voice")
      |> mes("inside my head!")
      |> mes("And it's not even mine!")
      |> next()
      |> mes("[Echoing Voice]")
      |> mes("You who have come")
      |> mes("for the Tablet Piece,")
      |> mes("I shall judge whether")
      |> mes("or not you are worthy.")
      |> mes("Answer this one question.")
      |> next()
      |> mes("[Echoing Voice]")
      |> mes("You are in a situation")
      |> mes("in which you will die,")
      |> mes("but if you cause the death")
      |> mes("of another person, you will")
      |> mes("surely save yourself. So...")
      |> mes("What do you do?")
      |> next()
      |> select([
        "I will kill to survive.",
        "I have no choice, but to die.",
        "I won't kill, but I'll find a way to live!",
        "I'll ask that person if it's okay to kill him."
      ])

    answer(ctx, choice)
  end

  defp answer(ctx, 1) do
    ctx
    |> mes("[Echoing Voice]")
    |> mes("There is a primal truth")
    |> mes("to your answer. However...")
    |> mes("You have chosen poorly.")
    |> close()
    |> percent_heal(hp: -100, sp: 0)
  end

  defp answer(ctx, 2) do
    ctx
    |> mes("[Echoing Voice]")
    |> mes("There is a kindness and")
    |> mes("compassion in your answer")
    |> mes("that is indeed rare. However,")
    |> mes("where is the respect for your")
    |> mes("own life? If you are that willing to throw it away, you are no hero.")
    |> close()
    |> percent_heal(hp: -100, sp: 0)
  end

  defp answer(ctx, 3) do
    ctx
    |> mes("[Echoing Voice]")
    |> mes("Yes. Love for all life,")
    |> mes("including your own, is")
    |> mes("a trait that all true heroes")
    |> mes("must have. You have chosen...")
    |> mes("Wisely. Please, take this into")
    |> mes("your capable hands, adventurer.")
    |> next()
    |> mes("^3355FFA stone slab at the foot")
    |> mes("of the statue slides open,")
    |> mes("revealing a piece of the")
    |> mes("tablet that will lead you")
    |> mes("to the Hellion's gem.")
    |> set_char_var(:HELLIONQ, 57)
    |> give_item(7334, 1)
    |> close()
  end

  defp answer(ctx, 4) do
    ctx
    |> mes("[Echoing Voice]")
    |> mes("The veneer of honesty in")
    |> mes("your answer is surpassed by")
    |> mes("your own cowardice. You have")
    |> mes("chosen extremely poorly...")
    |> close()
    |> percent_heal(hp: -100, sp: 0)
  end

  defp answer(ctx, _), do: ctx
end
