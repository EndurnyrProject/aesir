defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.Employee107189 do
  @moduledoc """
  Offers access to Jawaii's Honey Room.

  ## Behavior

  - Charges 1,000 zeny before transferring a guest to the room.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - DNett123
    - L0ne_w0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "jawaii",
        x: 107,
        y: 189,
        dir: 5,
        sprite: 93,
        name: "Employee",
        scope: :shared,
        unique_name: "Employee#horoom"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sharkie Rania]")
      |> mes("I'll take you")
      |> mes("to the Honey Room.")
      |> mes("It costs 1,000 zeny.")
      |> next()
      |> mes("[Sharkie Rania]")
      |> mes("So you wanna go?")
      |> next()
      |> select(["Use.", "Cancel."])

    case choice do
      1 -> open_honey_room(ctx)
      _ -> ctx |> mes("[Sharkie Rania]") |> mes("No prob.") |> close()
    end
  end

  defp open_honey_room(ctx) do
    ctx = mes(ctx, "[Sharkie Rania]")

    if zeny(ctx) > 999 do
      ctx
      |> mes("Eh, alright.")
      |> mes("Let's get going.")
      |> close()
      |> pay_zeny(1000)
      |> warp("jawaii_in", 86, 117)
    else
      ctx
      |> mes("You...")
      |> mes("Don't have")
      |> mes("enough money.")
      |> mes("C'mon, romance")
      |> mes("takes zeny, got it?")
      |> close()
    end
  end
end
