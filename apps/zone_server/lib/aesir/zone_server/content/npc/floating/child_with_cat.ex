defmodule Aesir.ZoneServer.Content.Npc.Floating.ChildWithCat do
  @moduledoc """
  The cat-holding child who sits beside Madeleine Chu in the Prontera Castle kitchen and
  greets players with one of two random reactions.

  ## Behavior

  - Switches randomly between a curious "...Nya?" and a delighted laugh when talked to.
  - Restores the child's neutral portrait after either reaction.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Reddozen
    - L0ne_W0lf
    - Lupus
    - Samuray22
    - ultramage
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_cas",
        x: 329,
        y: 194,
        dir: 3,
        sprite: 877,
        name: "Child with Cat",
        scope: :renewal,
        unique_name: "Child with Cat#cook"
      },
      %{
        map: "prt_castle",
        x: 45,
        y: 28,
        dir: 3,
        sprite: 877,
        name: "Child with Cat",
        scope: :pre_renewal,
        unique_name: "Child with Cat#cook"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case Enum.random(1..2) do
      1 -> curious(ctx)
      2 -> delighted(ctx)
    end
  end

  defp curious(ctx) do
    ctx
    |> cutin("nyuang_1", 2)
    |> emotion(:question)
    |> mes("[Child with Cat]")
    |> mes("...Nya?")
    |> mes("(...Meow?)")
    |> close()
    |> cutin("nyuang_1", 255)
  end

  defp delighted(ctx) do
    ctx
    |> cutin("nyuang_3", 2)
    |> emotion(:delight)
    |> mes("[Child with Cat]")
    |> mes("Nyahahahaha,")
    |> mes("nyahahahaha~")
    |> mes("(Meow~, meow~)")
    |> close()
    |> cutin("nyuang_1", 255)
  end
end
