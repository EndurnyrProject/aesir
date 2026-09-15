defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.Mark do
  @moduledoc """
  Sells admission and an optional Apple Combo Set for Einbroch Tower.

  ## Behavior

  - Charges 10 zeny for tower admission and transfers the visitor inside.
  - Charges 20 zeny for admission with an Apple after checking carrying capacity.
  - Serves the same interaction through Mark, Oberu, and Khemko placements.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - reddozen
    - Komurka
    - erKURITA
    - RockmanEXE
    - Dj-Yhn
    - Silent
    - Evera
    - Samuray22
    - DZeroX
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "einbroch",
        x: 218,
        y: 198,
        dir: 5,
        sprite: 855,
        name: "Mark",
        scope: :shared,
        unique_name: "Mark#ein"
      },
      %{
        map: "einbroch",
        x: 173,
        y: 229,
        dir: 5,
        sprite: 855,
        name: "Oberu",
        scope: :shared,
        unique_name: "Oberu#ein"
      },
      %{
        map: "einbroch",
        x: 176,
        y: 172,
        dir: 5,
        sprite: 855,
        name: "Khemko",
        scope: :shared,
        unique_name: "Khemko#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    npc_name = strnpcinfo(ctx, 1)

    {ctx, choice} =
      ctx
      |> mes("[#{npc_name}]")
      |> mes("Good day~")
      |> mes("I'm #{npc_name}, your")
      |> mes("guide to exploring")
      |> mes("the Einbroch Tower.")
      |> next()
      |> mes("[#{npc_name}]")
      |> mes("Einbroch Tower offers")
      |> mes("the best view of our city")
      |> mes("and it's a great place to")
      |> mes("meet with friends or take")
      |> mes("a date. The Einbroch Tower")
      |> mes("admission fee is 10 zeny.")
      |> next()
      |> mes("[#{npc_name}]")
      |> mes("Right now, we're offering")
      |> mes("a special promotion called")
      |> mes("the Apple Combo Set for only")
      |> mes("20 zeny. This set includes")
      |> mes("Einbroch Tower admission")
      |> mes("and an Apple to snack on.")
      |> next()
      |> select(["Tower Admission Only", "Apple Combo Set", "Cancel"])

    case choice do
      1 -> buy_admission(ctx, npc_name)
      2 -> buy_apple_combo(ctx, npc_name)
      3 -> cancel(ctx, npc_name)
      _ -> ctx
    end
  end

  defp buy_admission(ctx, npc_name) do
    if zeny(ctx) < 10 do
      ctx
      |> mes("[#{npc_name}]")
      |> mes("I'm sorry, but you")
      |> mes("don't have enough")
      |> mes("zeny. The Einbroch")
      |> mes("Tower Admission")
      |> mes("fee is 10 zeny.")
      |> close()
    else
      ctx
      |> mes("[#{npc_name}]")
      |> mes("Thank you for")
      |> mes("using our services.")
      |> mes("Let me guide you to")
      |> mes("the tower right away.")
      |> pay_zeny(10)
      |> close()
      |> warp("einbroch", 181, 196)
    end
  end

  defp buy_apple_combo(ctx, npc_name) do
    if zeny(ctx) < 20 do
      ctx
      |> mes("[#{npc_name}]")
      |> mes("I'm sorry, but you don't")
      |> mes("have enough zeny. The")
      |> mes("Apple Combo Set is 20 zeny.")
      |> close()
    else
      ctx
      |> mes("[#{npc_name}]")
      |> mes("Before I guide you to")
      |> mes("the tower, let me check")
      |> mes("your status to insure")
      |> mes("your safety before I give")
      |> mes("you the Apple Combo Set.")
      |> next()
      |> complete_apple_combo(npc_name)
    end
  end

  defp complete_apple_combo(ctx, npc_name) do
    if Rathena.truthy?(checkweight(ctx, [{512, 1}])) do
      ctx
      |> mes("[#{npc_name}]")
      |> mes("Thank you for")
      |> mes("using our services.")
      |> mes("Let me guide you to")
      |> mes("the tower right away.")
      |> pay_zeny(20)
      |> give_item(512, 1)
      |> close()
      |> warp("einbroch", 174, 204)
    else
      ctx
      |> mes("[#{npc_name}]")
      |> mes("I'm sorry, but you're carrying")
      |> mes(
        "too many items with you. Please store some of your things in your Kafra Storage before purchasing"
      )
      |> mes("the Apple Combo Set.")
      |> close()
    end
  end

  defp cancel(ctx, npc_name) do
    ctx
    |> mes("[#{npc_name}]")
    |> mes("I see.")
    |> mes("Feel free to")
    |> mes("come back any")
    |> mes("time. Thank you.")
    |> close()
  end
end
