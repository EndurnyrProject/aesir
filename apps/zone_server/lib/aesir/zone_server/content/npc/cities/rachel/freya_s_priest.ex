defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.FreyaSPriest do
  @moduledoc """
  Demands entertainment and uses a random item effect on compliant visitors.

  ## Behavior

  - Accepts a joke or randomly warps the visitor, consumes a Speed Up Potion, or consumes a Slow Down Potion.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Tsuyuki and Harp
    - L0ne_W0lf
    - Lupus
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "rachel",
        x: 206,
        y: 30,
        dir: 3,
        sprite: 920,
        name: "Freya's Priest",
        scope: :shared,
        unique_name: "Freya's Priest#play"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Freya's Priest]")
      |> mes("This...")
      |> mes("bores me...")
      |> next()
      |> mes("[Freya's Priest]")
      |> mes("You!")
      |> mes("Entertain me!")
      |> emotion(:anger)
      |> next()
      |> select(["What? You can't tell me what to do!", "You got it."])

    case choice do
      1 -> refuse_entertainment(ctx)
      _ -> offer_entertainment(ctx)
    end
  end

  defp refuse_entertainment(ctx) do
    ctx
    |> mes("[Freya's Priest]")
    |> mes("Oh. That much is")
    |> mes("true, I suppose.")
    |> close()
  end

  defp offer_entertainment(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Freya's Priest]")
      |> mes("Well, then,")
      |> mes("what will you be")
      |> mes("doing to entertain me?")
      |> next()
      |> select(["Here's a funny story...", "I will do what you want me to do."])

    case choice do
      1 -> tell_joke(ctx)
      _ -> use_random_item_effect(ctx)
    end
  end

  defp tell_joke(ctx) do
    ctx
    |> mes("^3355FFYou told her the first")
    |> mes("funny story that you")
    |> mes("could think of.^000000")
    |> specialeffect2(:talk_frostjoke)
    |> next()
    |> mes("[Freya's Priest]")
    |> mes("That's supposed to")
    |> mes("be funny? I suppose")
    |> mes("that I don't understand")
    |> mes("hoi polloi humor.")
    |> close()
  end

  defp use_random_item_effect(ctx) do
    ctx =
      ctx
      |> mes("[Freya's Priest]")
      |> mes("Fine, fine~")
      |> mes("Let me see what these")
      |> mes("item of yours can do...")
      |> mes("Oh? Oh! That's wonderful!")
      |> close()

    case Enum.random(1..10) do
      roll when roll < 3 -> warp(ctx, :random)
      roll when roll < 5 -> consumeitem(ctx, 12_016)
      _ -> consumeitem(ctx, 12_017)
    end
  end
end
