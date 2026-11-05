defmodule Aesir.ZoneServer.Content.Npc.Quests.MageSolution.Dollshoi do
  @moduledoc """
  A Payon mage guildsman who trades a Payon Solution for 50 Zeny and an Empty Test Tube.

  ## Behavior

  - Offers a Payon Solution for 50 Zeny and one Empty Test Tube (1092)
  - Closes without trading when the player has fewer than 50 Zeny or no Empty Test Tube
  - On a successful trade, consumes the Empty Test Tube and 50 Zeny, then gives a Payon
    Solution (1089)

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Zopokx

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "pay_arche",
        x: 122,
        y: 100,
        dir: 0,
        sprite: 88,
        name: "Dollshoi",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Mage Guildsman]")
      |> mes("You want a Solution? Hmm, give me 50 Zeny and at least 1 Empty Test Tube.")
      |> next()
      |> select(["Alright, Deal.", "Nah, forget it."])

    case choice do
      1 -> trade_solution(ctx)
      _ -> close(ctx)
    end
  end

  @spec trade_solution(Ctx.t()) :: Ctx.t()
  defp trade_solution(ctx) do
    ctx = mes(ctx, "[Mage Guildsman]")

    cond do
      zeny(ctx) < 50 ->
        ctx
        |> mes("Hey! You don't have enough money to cover my 50 Zeny charge.")
        |> close()

      count_item(ctx, 1092) == 0 ->
        ctx
        |> mes("You can't carry solutions without a bottle! Bring me an Empty Test Tube.")
        |> close()

      true ->
        ctx
        |> delitem(1092, 1)
        |> pay_zeny(50)
        |> give_item(1089, 1)
        |> close()
    end
  end
end
