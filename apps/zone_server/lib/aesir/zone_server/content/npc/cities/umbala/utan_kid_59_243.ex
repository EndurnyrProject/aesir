defmodule Aesir.ZoneServer.Content.Npc.Cities.Umbala.UtanKid59243 do
  @moduledoc """
  Trades rewards for Meat and lashes out when the visitor cannot provide it.

  ## Behavior

  - Speaks intelligibly only after Umbalan language progress reaches stage 3.
  - Takes one Meat and gives a mode-dependent reward when the visitor agrees and has Meat.
  - Reduces HP when the visitor refuses or falsely offers Meat.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - Fusion Dev Team
    - Muad Dib
    - Darkchild

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "umbala",
        x: 59,
        y: 243,
        dir: 5,
        sprite: 787,
        name: "Utan Kid",
        scope: :shared,
        unique_name: "Utan Kid#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :event_umbala, 0) >= 3 do
      offer_trade(ctx)
    else
      offer_trade_in_umbalan(ctx)
    end
  end

  defp offer_trade(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kotan]")
      |> mes("............")
      |> mes(".........poop!")
      |> mes(".....me like Meat.")
      |> mes("....gimme a Meat.")
      |> emotion(:rock)
      |> next()
      |> select(["Give him Meat.", "Refuse."])

    cond do
      choice != 1 -> refuse_trade(ctx)
      count_item(ctx, 517) > 0 -> complete_trade(ctx, :translated)
      true -> punish_false_offer(ctx)
    end
  end

  defp offer_trade_in_umbalan(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[???]")
      |> mes("............")
      |> mes("........umbah.")
      |> mes(".......umbabah.")
      |> mes("......humbah.")
      |> emotion(:rock)
      |> next()
      |> select(["Umbah", "Umbaboo"])

    cond do
      choice != 1 -> refuse_trade_in_umbalan(ctx)
      count_item(ctx, 517) > 0 -> complete_trade(ctx, :umbalan)
      true -> punish_false_offer_in_umbalan(ctx)
    end
  end

  defp complete_trade(ctx, :translated) do
    ctx
    |> mes("[Kotan]")
    |> mes("Whoa, are you really giving me")
    |> mes("Meat? Thanks! I will pay you")
    |> mes("back with these.")
    |> delitem(517, 1)
    |> give_trade_reward()
    |> emotion(:scissor)
    |> close()
  end

  defp complete_trade(ctx, :umbalan) do
    ctx
    |> mes("[???]")
    |> mes("Umbaumbaumbabababah.")
    |> mes("Umbababahum.")
    |> delitem(517, 1)
    |> give_trade_reward()
    |> emotion(:scissor)
    |> close()
  end

  defp give_trade_reward(ctx) do
    if Rathena.truthy?(checkre(ctx, 0)) do
      case Enum.random(1..4) do
        1 -> give_item(ctx, 909, 3)
        2 -> give_item(ctx, 914, 3)
        3 -> give_item(ctx, 705, 3)
        4 -> give_item(ctx, 705, 3)
        _ -> ctx
      end
    else
      ctx
      |> give_item(909, 2)
      |> give_item(914, 2)
      |> give_item(705, 2)
    end
  end

  defp punish_false_offer(ctx) do
    ctx
    |> mes("[Kotan]")
    |> mes("Hah! You don't have Meat,")
    |> mes("but pretend that you do?!")
    |> mes("I hate people who lie")
    |> mes("to me!!")
    |> percent_heal(hp: -20, sp: 0)
    |> emotion(:fret)
    |> close()
  end

  defp punish_false_offer_in_umbalan(ctx) do
    ctx
    |> mes("[???]")
    |> mes("Umbahumumhumbubabababah!!")
    |> mes("Umbahumbababah umbahumboo!")
    |> percent_heal(hp: -20, sp: 0)
    |> emotion(:fret)
    |> close()
  end

  defp refuse_trade(ctx) do
    ctx
    |> mes("[Kotan]")
    |> mes(".........")
    |> mes(".....hungwee.")
    |> mes(".....I want Meat.")
    |> percent_heal(hp: -1, sp: 0)
    |> emotion(:cry)
    |> close()
  end

  defp refuse_trade_in_umbalan(ctx) do
    ctx
    |> mes("[???]")
    |> mes("...........")
    |> mes("......woong bah.")
    |> mes("....umbabababah.")
    |> emotion(:cry)
    |> percent_heal(hp: -1, sp: 0)
    |> close()
  end
end
