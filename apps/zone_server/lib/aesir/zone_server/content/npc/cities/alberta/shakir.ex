defmodule Aesir.ZoneServer.Content.Npc.Cities.Alberta.Shakir do
  @moduledoc """
  Randomly explains one of two Merchant business skills.

  ## Behavior

  - Describes either overcharging through negotiation or vending goods from a cart.

  ## Credits

  - Original from rAthena, authors and Contributors
    - DZeroX

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "alberta", x: 58, y: 80, dir: 2, sprite: 99, name: "Shakir", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Shakir]")

    ctx =
      if Rathena.truthy?(:rand.uniform(2) - 1) do
        explain_overcharge(ctx)
      else
        explain_vending(ctx)
      end

    close(ctx)
  end

  defp explain_overcharge(ctx) do
    ctx
    |> mes(
      "We Merchants have our own negotiating skill when we sell goods. This skill can get us more money than when other people sell goods."
    )
    |> next()
    |> mes("[Shakir]")
    |> mes(
      "It's more than just yelling 'You'll have to give more money please!' You need to have charisma, and master rhetoric!"
    )
    |> next()
    |> mes("[Shakir]")
    |> mes(
      "We can get up to 24 % more zeny with this incredible skill. But remember to train hard to acquire it!!"
    )
  end

  defp explain_vending(ctx) do
    ctx
    |> mes("We Merchants can")
    |> mes("open roadside stands")
    |> mes("to do business.")
    |> next()
    |> mes("[Shakir]")
    |> mes(
      "With the Discount skill, we can buy goods really cheap from the stores in towns and load them into the cart we rent."
    )
    |> next()
    |> mes("[Shakir]")
    |> mes("Then afterwards, we can travel anywhere, and sells our goods to make a profit!")
    |> next()
    |> mes("[Shakir]")
    |> mes(
      "This way, business is more convenient and safe. Don't fall asleep, although it's too easy to do that."
    )
  end
end
