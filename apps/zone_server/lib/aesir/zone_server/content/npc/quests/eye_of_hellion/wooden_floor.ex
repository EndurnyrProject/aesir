defmodule Aesir.ZoneServer.Content.Npc.Quests.EyeOfHellion.WoodenFloor do
  @moduledoc """
  A loose floor conceals an engraving in the search for Hellion's gem.

  ## Behavior

  - At quest step 53, offers to inspect or dig through the floor.
  - Consumes four supplies to reveal the engraving and advance the quest.
  - Shows the engraving again at later quest steps.

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
        map: "payon",
        x: 159,
        y: 129,
        dir: 3,
        sprite: 111,
        name: "Wooden Floor",
        scope: :shared,
        unique_name: "Wooden Floor#paypuzz5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :HELLIONQ, 0) do
      53 -> inspect_floor(ctx)
      54 -> ctx |> engraving() |> set_char_var(:HELLIONQ, 55) |> close()
      step when step > 54 -> ctx |> engraving() |> close()
      _ -> ctx
    end
  end

  defp inspect_floor(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Hey, the floor around")
      |> mes("here doesn't seem very")
      |> mes("solid. Maybe there's")
      |> mes("something underneath?")
      |> next()
      |> select(["Just check the floor.", "Dig through the dust."])

    if choice == 1, do: check_floor(ctx), else: dig(ctx)
  end

  defp check_floor(ctx) do
    ctx
    |> mes("^3355FFYou examine the floor,")
    |> mes("but are unable to find")
    |> mes("anything that resembles")
    |> mes("a clue to the location")
    |> mes("of the Hellion's gem")
    |> mes("or a tablet piece.^000000")
    |> close()
  end

  defp dig(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Oh man, there's")
      |> mes("so much dust! What")
      |> mes("can I do about all of")
      |> mes("this nasty dirt in the air?")
      |> next()

    if count_item(ctx, 953) > 0 and count_item(ctx, 533) > 0 and count_item(ctx, 511) > 0 and
         count_item(ctx, 1049) > 0 do
      reveal_engraving(ctx)
    else
      missing_supplies(ctx)
    end
  end

  defp reveal_engraving(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Well, there are all these")
      |> mes("clues Grout'he found. It sucks,")
      |> mes("but I'll use this Grape Juice")
      |> mes("to sort of keep this dust from")
      |> mes("kicking up. And if I put my morals^FFFFFFa^000000 on hold, I'll cover my face...")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("...With this Skirt of Virgin.")
      |> mes("Oh, and I can use this Stone")
      |> mes("Heart to prop any floor boards")
      |> mes("I tilt while I look underneath")
      |> mes("this floor. Oh hey! I found it!")
      |> mes("It's... It's another clue!")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Wait, wait...")
      |> mes("I can't read the")
      |> mes("engraving on this")
      |> mes("stone slab, it's way")
      |> mes("too old. Let's see...")
      |> next()
      |> mes("^3355FFYou cover the surface")
      |> mes("of the slab and begin")
      |> mes("to rub a Green Herb over")
      |> mes("it. Fortunately, the juice from")
      |> mes("the Green Herb makes the")
      |> mes("engraving appear more clearly.^000000")
      |> delitem(953, 1)
      |> delitem(511, 1)
      |> delitem(533, 1)
      |> delitem(1049, 1)
      |> set_char_var(:HELLIONQ, 54)

    ctx |> next() |> engraving() |> set_char_var(:HELLIONQ, 55) |> close()
  end

  defp missing_supplies(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Where did I leave")
    |> mes("all that stuff I got from")
    |> mes("Grout'he? Let's see,")
    |> mes("there was a Green Herb,")
    |> mes("a Stone Heart, Grape Juice")
    |> mes("and one Skirt of Virgin...")
    |> close()
  end

  defp engraving(ctx) do
    ctx
    |> mes("[Stone Engraving]")
    |> mes("^4D4DFF''This has been entrusted to")
    |> mes("the care of the compassionate")
    |> mes("one so that my friends may")
    |> mes("find peace. To he who finds")
    |> mes("this, remember that avarice")
    |> mes("knows no bounds. --Tyus.''^000000")
  end
end
