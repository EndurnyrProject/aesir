defmodule Aesir.ZoneServer.Content.Npc.Floating.SailorIzlude do
  @moduledoc """
  Sailor who runs the Izlude ferry to Byalan Island and the Alberta marina.

  ## Behavior

  - Offers two paid crossings and a cancel option: 150 zeny to the Byalan
    Island dungeon, or 500 zeny to the Alberta marina.
  - A player short of the fare is told the price and the conversation ends
    without charging or warping.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Nexon
    - Silentdragon
    - MasterOfMuppets
    - Silent
    - Evera
    - CAHTEXHuK
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script cities/izlude.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "izlude",
        x: 197,
        y: 205,
        dir: 1,
        sprite: 100,
        name: "Sailor",
        scope: :renewal,
        unique_name: "Sailor#izlude"
      },
      %{
        map: "izlude_a",
        x: 197,
        y: 205,
        dir: 1,
        sprite: 100,
        name: "Sailor",
        scope: :renewal,
        unique_name: "Sailor#izlude_a"
      },
      %{
        map: "izlude_b",
        x: 197,
        y: 205,
        dir: 1,
        sprite: 100,
        name: "Sailor",
        scope: :renewal,
        unique_name: "Sailor#izlude_b"
      },
      %{
        map: "izlude_c",
        x: 197,
        y: 205,
        dir: 1,
        sprite: 100,
        name: "Sailor",
        scope: :renewal,
        unique_name: "Sailor#izlude_c"
      },
      %{
        map: "izlude_d",
        x: 197,
        y: 205,
        dir: 1,
        sprite: 100,
        name: "Sailor",
        scope: :renewal,
        unique_name: "Sailor#izlude_d"
      },
      %{
        map: "izlude",
        x: 201,
        y: 181,
        dir: 2,
        sprite: 100,
        name: "Sailor",
        scope: :pre_renewal,
        unique_name: "Sailor#izlude"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @byalan_fare 150
  @alberta_fare 500

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, destination} =
      ctx
      |> mes("[Sailor]")
      |> mes("Hey everybody!")
      |> mes("Attention, attention!")
      |> mes("Come and ride the wind")
      |> mes("on a fascinating Ship!")
      |> mes("Hurry, hurry!")
      |> next()
      |> select(["Byalan Island -> 150 Zeny.", "Alberta Marina  -> 500 Zeny.", "Cancel."])

    case destination do
      1 -> sail_to_byalan(ctx)
      2 -> sail_to_alberta(ctx)
      3 -> close(ctx)
      _ -> ctx
    end
  end

  defp sail_to_byalan(ctx) do
    if zeny(ctx) < @byalan_fare do
      ctx
      |> mes("[Sailor]")
      |> mes("150 Zeny!")
      |> mes("Only 150 Zeny to ride!")
      |> close()
    else
      ctx
      |> pay_zeny(@byalan_fare)
      |> warp("izlu2dun", 107, 50)
    end
  end

  defp sail_to_alberta(ctx) do
    if zeny(ctx) < @alberta_fare do
      ctx
      |> mes("[Sailor]")
      |> mes("500 Zeny!")
      |> mes("Only 500 Zeny to ride!")
      |> close()
    else
      ctx
      |> pay_zeny(@alberta_fare)
      |> warp("alberta", 188, 169)
    end
  end
end
