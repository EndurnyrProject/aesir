defmodule Aesir.ZoneServer.Content.Npc.Quests.MageSolution.PonkaHontas do
  @moduledoc """
  A Morocc mage guildsman who trades a Morocc Solution for 50 Zeny and an Empty Test Tube.

  ## Behavior

  - Offers a Morocc Solution for 50 Zeny and one Empty Test Tube (1092)
  - Closes without trading when the player has fewer than 50 Zeny or no Empty Test Tube
  - On a successful trade, consumes the Empty Test Tube and 50 Zeny, then gives a Morocc
    Solution (1088)

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
        map: "moc_ruins",
        x: 91,
        y: 150,
        dir: 0,
        sprite: 93,
        name: "Ponka-Hontas",
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
      |> mes(
        "Would you like a Solution? Then please give me 50 Zeny and at least 1 Empty Test Tube."
      )
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
        |> mes("I'm sorry, but you don't have enough money to cover the 50 Zeny fee.")
        |> close()

      count_item(ctx, 1092) == 0 ->
        ctx
        |> mes(
          "You can't carry liquids without using a bottle. Bring an Empty Test Tube the next time you see me."
        )
        |> close()

      true ->
        ctx
        |> delitem(1092, 1)
        |> pay_zeny(50)
        |> give_item(1088, 1)
        |> close()
    end
  end
end
