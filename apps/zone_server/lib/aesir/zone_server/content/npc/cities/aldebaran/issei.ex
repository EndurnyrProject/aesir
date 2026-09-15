defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.Issei do
  @moduledoc """
  Talks about his girlfriend and equipment dropped by monsters.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldebaran",
        x: 93,
        y: 80,
        dir: 4,
        sprite: 48,
        name: "Issei",
        scope: :shared,
        unique_name: "Issei#alde"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Issei]")
      |> mes(
        "Al De Baran is such a wonderful place with its romantic canals and classic architecture. I love nothing more than to stroll through this city with my beautiful girlfriend."
      )
      |> next()
      |> select(["You have a girlfriend?", "End Conversation."])

    if choice == 1 do
      ctx
      |> mes("[Issei]")
      |> mes("Hey...")
      |> mes(
        "Is that so hard to believe?! Yeah, ask anyone! She really exists! Although, sometimes, just sometimes mind you, she gets too excited about weapons and armor."
      )
      |> next()
      |> mes("[Issei]")
      |> mes(
        "I mean, instead of enjoying a romantic dinner, she'll just go on about how equipment dropped from monsters is higher quality than those sold in shops..."
      )
      |> next()
      |> mes("[Issei]")
      |> mes(
        "I mean, why should I care if equipment dropped by monsters tend to have more Slots?! I can't even kill a Poring!"
      )
      |> next()
      |> mes("[Issei]")
      |> mes("As you can see,")
      |> mes("I'm a lover,")
      |> mes(" not a fighter.")
      |> close()
    else
      ctx |> mes("[Issei]") |> mes("So, you don't think of me stupid, do you?") |> close()
    end
  end
end
