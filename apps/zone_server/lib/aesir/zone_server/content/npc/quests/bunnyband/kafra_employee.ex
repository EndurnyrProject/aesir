defmodule Aesir.ZoneServer.Content.Npc.Quests.Bunnyband.KafraEmployee do
  @moduledoc """
  The Kafra Corporation's Bunny Band event employee in Alberta, who assembles a Bunny
  Band for players who bring her the required items.

  ## Behavior

  - Invites players into the event and records their participation in the `BUNYBND`
    character variable.
  - Explains the event and the required items when asked.
  - Checks for 100 Feathers, 1 Four-Leaf Clover, 1 Scarlet Jewel and 1 Cat Hairband,
    naming the first item the player is short of.
  - Checks the items again on the crafting page, then trades them for a Bunny Band and
    clears `BUNYBND`.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta",
        x: 26,
        y: 229,
        dir: 0,
        sprite: 83,
        name: "Kafra Employee",
        scope: :shared,
        unique_name: "Kafra Employee#bunny"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FInsertplural
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @required_items [{949, 100}, {706, 1}, {722, 1}, {2213, 1}]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :BUNYBND, 0) == 1 do
      offer_bunny_band(ctx)
    else
      introduce_event(ctx)
    end
  end

  defp offer_bunny_band(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Hello there~!")
      |> mes("How'd you like to")
      |> mes("participate in Kafra")
      |> mes("Corporation's special")
      |> mes("^529DFFBunny Band Event^000000?")
      |> next()
      |> select(["Sure, I brought the items.", "Event Information", "Cancel"])

    case choice do
      1 -> assemble_bunny_band(ctx)
      2 -> explain_event(ctx)
      3 -> close(ctx)
      # An out-of-range choice resumes the greeting, as it did in the transpiled script.
      _ -> introduce_event(ctx)
    end
  end

  defp introduce_event(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Hi there~! Would you like")
      |> mes("to join our special ^529DFFBunny")
      |> mes("Band Event^000000 hosted by the Kafra")
      |> mes("Corporation and sponsored by")
      |> mes("the Alberta Merchant Guild?")
      |> next()
      |> select(["Join the Event", "Event Information", "Cancel"])

    case choice do
      1 -> join_event(ctx)
      3 -> close(ctx)
      _ -> explain_event(ctx)
    end
  end

  defp join_event(ctx) do
    ctx
    |> set_char_var(:BUNYBND, 1)
    |> mes("[Kafra Employee]")
    |> mes("Great! Thanks for")
    |> mes("participating! If you")
    |> mes("haven't already heard,")
    |> mes("you need to collect these")
    |> mes("items if you want me put a")
    |> mes("Bunny Band together for you...")
    |> next()
    |> mes("[Kafra Employee]")
    |> mes("100 Feathers,")
    |> mes("1 Four-Leaf Clover,")
    |> mes("1 Kitty Band and")
    |> mes("1 Pearl. That's it!")
    |> mes("Good luck and I'll be")
    |> mes("waiting for you here~")
    |> close()
  end

  defp assemble_bunny_band(ctx) do
    ctx =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Alrighty~")
      |> mes("Let me check to")
      |> mes("see if you brought")
      |> mes("all the items...")
      |> next()

    case missing_item(ctx) do
      nil ->
        ctx
        |> mes("[Kafra Employee]")
        |> mes("Great, I see that")
        |> mes("you've gathered")
        |> mes("everything I need to")
        |> mes("make the Bunny Band.")
        |> mes("Please wait a moment")
        |> mes("while I put it together...")
        |> next()
        |> craft_bunny_band()

      {item_id, amount} ->
        ctx =
          ctx
          |> mes("[Kafra Employee]")
          |> mes("Ooh, I'm sorry")
          |> mes("but you need to")
          |> mes("bring at least")

        {ctx, items} = FInsertplural.call(ctx, [amount, Rathena.getitemname(item_id)])

        ctx
        |> mes("#{items}.")
        |> close()
    end
  end

  defp craft_bunny_band(ctx) do
    case missing_item(ctx) do
      nil ->
        ctx
        |> delitem(949, 100)
        |> delitem(706, 1)
        |> delitem(722, 1)
        |> delitem(2213, 1)
        |> mes("[Kafra Employee]")
        |> mes("Ah, here you go~")
        |> mes("The perfect Bunny Band!")
        |> mes("Well, I hope you enjoy it.")
        |> give_item(2214, 1)
        |> set_char_var(:BUNYBND, 0)
        |> next()
        |> mes("[Kafra Employee]")
        |> mes("Thank you for")
        |> mes("participating in this")
        |> mes("special event and your")
        |> mes("continued patronage")
        |> mes("of the Kafra Services~")
        |> close()

      {item_id, amount} ->
        ctx =
          ctx
          |> mes("[Kafra Employee]")
          |> mes("Hm? I'm sorry,")
          |> mes("but I actually can't")
          |> mes("make this right now. You")

        {ctx, items} = FInsertplural.call(ctx, [amount, Rathena.getitemname(item_id)])

        ctx
        |> mes("need #{items}")
        |> mes("in order for me to put this")
        |> mes("Bunny Band together...")
        |> close()
    end
  end

  defp explain_event(ctx) do
    ctx
    |> mes("[Kafra Employee]")
    |> mes("To thank our valued")
    |> mes("customers, Kafra Corporation")
    |> mes("has prepared a special event")
    |> mes("where Kafra Employee will assemble")
    |> mes("Bunny Bands for adventurers")
    |> mes("who bring the required items.")
    |> next()
    |> mes("[Kafra Employee]")
    |> mes("For this special,")
    |> mes("one of a kind item,")
    |> mes("bring 100 Feathers,")
    |> mes("1 Four-Leaf Clover,")
    |> mes("1 Kitty Band and")
    |> mes("1 Pearl.")
    |> next()
    |> mes("[Kafra Employee]")
    |> mes("When you're ready,")
    |> mes("come back and bring")
    |> mes("those items to me.")
    |> mes("(Sponsored by the")
    |> mes("Alberta Merchant Guild).")
    |> close()
  end

  defp missing_item(ctx) do
    Enum.find(@required_items, fn {item_id, amount} -> count_item(ctx, item_id) < amount end)
  end
end
