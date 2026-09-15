defmodule Aesir.ZoneServer.Content.Npc.Cities.Yuno.AirshipRepresentative do
  @moduledoc """
  Offers fixed-price teleportation from Juno to several cities.

  ## Behavior

  - Offers travel to Prontera, Izlude, Geffen, Morocc, Payon, Alberta, or Comodo for 1,800 zeny.
  - Uses mode-specific arrival coordinates for Izlude and Payon.
  - Rejects travel when the player cannot afford the fare.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KitsuneStarwind
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 142,
        y: 183,
        dir: 5,
        sprite: 100,
        name: "Airship Representative",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Airship Representative]")
      |> mes("Good day, I am here to inform you")
      |> mes("about the Juno Airship which")
      |> mes("we plan to operate in the near future.")
      |> next()
      |> mes("[Air ship Representative]")
      |> mes("Unfortunately, it is still in")
      |> mes("development, and we've yet")
      |> mes("to complete testing. However,")
      |> mes("we feel the need to let our")
      |> mes("eager customers know of our")
      |> mes("progress.")
      |> next()
      |> mes("[Airship Representative]")
      |> mes(
        "The Airship we're developing will provide you with convenient travel to any town. You can also enjoy the sights while aloft in the sky. Unique products from various areas will also be provided."
      )
      |> next()
      |> mes("[Airship Representative]")
      |> mes("We promise our customers an")
      |> mes("amazing travel experience")
      |> mes("once the Airship is in")
      |> mes("operation. In the meantime,")
      |> mes("we are providing a special")
      |> mes("teleport service.")
      |> next()
      |> mes("[Airship Representative]")
      |> mes(
        "The teleport fee is 1,800 zeny, regardless of where you want to go. Please let me know your desired destination."
      )
      |> next()
      |> select([
        "Prontera",
        "Izlude",
        "Geffen",
        "Morocc",
        "Payon",
        "Alberta",
        "Comodo",
        "Cancel"
      ])

    choose_destination(ctx, choice)
  end

  defp choose_destination(ctx, 1), do: travel(ctx, "prontera", 116, 72)

  defp choose_destination(ctx, 2) do
    if Rathena.truthy?(checkre(ctx, 0)) do
      travel(ctx, "izlude", 128, 98)
    else
      travel(ctx, "izlude", 94, 103)
    end
  end

  defp choose_destination(ctx, 3), do: travel(ctx, "geffen", 120, 39)
  defp choose_destination(ctx, 4), do: travel(ctx, "morocc", 156, 46)

  defp choose_destination(ctx, 5) do
    if Rathena.truthy?(checkre(ctx, 0)) do
      travel(ctx, "payon", 162, 59)
    else
      travel(ctx, "payon", 69, 100)
    end
  end

  defp choose_destination(ctx, 6), do: travel(ctx, "alberta", 117, 56)
  defp choose_destination(ctx, 7), do: travel(ctx, "comodo", 209, 143)
  defp choose_destination(ctx, 8), do: close(ctx)
  defp choose_destination(ctx, _choice), do: travel(ctx, 0, 0, 0)

  defp travel(ctx, map, x, y) do
    if zeny(ctx) >= 1_800 do
      ctx
      |> pay_zeny(1_800)
      |> warp(map, x, y)
    else
      ctx
      |> mes("[Airship Representative]")
      |> mes("I regret to say that you do not have enough zeny with you.")
      |> mes("Please check the amount of zeny that you have.")
      |> close()
    end
  end
end
