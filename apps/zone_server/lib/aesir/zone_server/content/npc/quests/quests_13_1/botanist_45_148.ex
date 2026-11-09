defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Botanist45148 do
  @moduledoc """
  The Botanist of the Manuk field, who examines the sprout grown from the rotting stem.

  ## Behavior

  - On `ep13_animal` step 8 asks for the rotting stem to be planted.
  - On step 9 admires the sprout, explains the Environmental Purifier, sets the step to 10,
    advances quest 2152 to 2153 and hides itself.
  - Says nothing on every other step.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mid_camp",
        x: 45,
        y: 148,
        dir: 7,
        sprite: 750,
        name: "Botanist",
        scope: :shared,
        unique_name: "Botanist#ep13_1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @npc "Botanist#ep13_1"

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ep13_animal, 0) do
      8 -> remind_planting(ctx)
      9 -> sprouted(ctx)
      _step -> ctx
    end
  end

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, @npc)

  defp remind_planting(ctx) do
    ctx
    |> mes("[Botanist]")
    |> mes("Please try to plant the rotting stem in the ground.")
    |> close()
  end

  defp sprouted(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("It's sprouted! That shoot looks healthy!")
    |> next()
    |> mes("[Botanist]")
    |> mes("See?")
    |> mes(
      "This giant mushroom, otherwise known as an Environmental Purifier, not only brings dying plants back to life, but also stimulates their growth."
    )
    |> next()
    |> mes("[Botanist]")
    |> mes("Isn't it amazing?!")
    |> mes("This finding will surely stir up the academic world.")
    |> next()
    |> mes("[Botanist]")
    |> mes("Now, I should get back to work. I need to write a report based on my study results.")
    |> mes("I can't wait to see how the expedition management will react to my report. Hahaha~")
    |> next()
    |> mes("[Botanist]")
    |> mes("Oh, right... Rumis!")
    |> mes("Can you please tell him that I've received his Nepenthes specimen safely?")
    |> next()
    |> mes("[Botanist]")
    |> mes(
      "And don't forget to tell him that I've produced great research results. That'll make him cry like a baby. Hahahaha!"
    )
    |> set_char_var(:ep13_animal, 10)
    |> changequest(2152, 2153)
    |> disablenpc(@npc)
    |> close()
  end
end
