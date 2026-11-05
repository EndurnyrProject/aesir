defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Box do
  @moduledoc """
  A dubious vending machine sells ordinary Pet Food at an inflated price.

  ## Behavior

  - Charges 1,100 zeny for one Pet Food when the adventurer can afford it.
  - Offers cancellation and refuses purchases without sufficient zeny.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "kh_vila",
        x: 16,
        y: 175,
        dir: 0,
        sprite: 111,
        name: "Box",
        scope: :shared,
        unique_name: "Box#khp1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^FFFFFF##^000000*Tasty-Nutricious-Delicious*")
      |> mes("*Cute Pet Doof Vending Machine*")
      |> mes("The best food for your Cute Pets")
      |> mes("that is superior to the Pet Food")
      |> mes("you can buy in the market!")
      |> mes("^FFFFFF_^000000")
      |> mes("Price: 1,100 zeny (cheap!)")
      |> next()
      |> select(["Buy!", "Cancel"])

    case choice do
      1 ->
        buy_pet_food(ctx)

      2 ->
        ctx
        |> mes("^3355FFThis vending machine")
        |> mes("seems really shady and")
        |> mes("suspicious for some reason.^000000")
        |> close()

      _ ->
        ctx
    end
  end

  defp buy_pet_food(ctx) do
    if zeny(ctx) < 1100 do
      ctx
      |> mes("^3355FFUnfortunately, you")
      |> mes("don't have enough")
      |> mes("zeny to insert into")
      |> mes("the vending machine.^000000")
      |> close()
    else
      ctx
      |> mes("^3355FFOh no...!^000000")
      |> mes("^3355FF1,100 zeny seems kind")
      |> mes("of expensive for Pet Food,")
      |> mes("but if it's better than the")
      |> mes("normal stuff, it might")
      |> mes("be worth a shot.^000000")
      |> next()
      |> mes("^3355FFOh no...!")
      |> mes("There's nothing")
      |> mes("special about it")
      |> mes("at all! It's just")
      |> mes("normal Pet Food!")
      |> pay_zeny(1100)
      |> give_item(537, 1)
      |> close()
    end
  end
end
