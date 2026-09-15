defmodule Aesir.ZoneServer.Content.Npc.Cities.Prontera.Dairenne do
  @moduledoc """
  Chats about fashionable dyed dresses in Prontera.

  ## Behavior

  - Discusses costly Morocc dyes when invited to talk.
  - Rebukes visitors who cancel the conversation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 78,
        y: 150,
        dir: 3,
        sprite: 90,
        name: "Dairenne",
        scope: :shared,
        unique_name: "Dairenne#pront"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Towngirl Dairenne]")
      |> mes("Ahh...")
      |> mes(
        "The streets are too crowded these days. *Cough Cough* Look at all this dust, not everything about living in the capital city is good. Anyway, may I help you?"
      )
      |> next()
      |> select(["Talk", "Cancel"])

    if choice == 1 do
      discuss_dresses(ctx)
    else
      rebuke_visitor(ctx)
    end
  end

  defp discuss_dresses(ctx) do
    ctx
    |> mes("[Towngirl Dairenne]")
    |> mes(
      "I wonder if you are interested in parties or dresses. Hehehe. These days, the hot topic is definitely the colorful, extravagant, magnificent dresses you can wear."
    )
    |> next()
    |> mes("[Towngirl Dairenne]")
    |> mes(
      "To get such dazzling colors, I heard you have to use a dye that you can only get in Morocc. But I also heard that the price is beyond imagination."
    )
    |> next()
    |> mes("[Towngirl Dairenne]")
    |> mes("Aahhhh~ I wish I could wear such a dress. Even if it's just once...")
    |> close()
  end

  defp rebuke_visitor(ctx) do
    ctx
    |> mes("[Towngirl Dairenne]")
    |> mes("Eh~? Why talk to me in the first place? What a strange person.")
    |> close()
  end
end
