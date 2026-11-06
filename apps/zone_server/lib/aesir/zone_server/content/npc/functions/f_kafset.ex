defmodule Aesir.ZoneServer.Content.Npc.Functions.FKafset do
  @moduledoc """
  Prepares the Kafra teleport menu and viewpoint markers for the current map.

  ## Behavior

  Clears the previous menu arrays, then fills them from the table for the NPC's map: destination
  names, their prices, and up to four viewpoints. Characters on a server that scripts `VIP_SCRIPT`
  pay double unless their VIP status is active. The menu labels combine destination and price,
  with `Cancel` appended last.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Joseph
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script kafras/functions_kafras.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @warp_destinations :"wrpD$"
  @warp_prices :wrpP
  @warp_menu :"wrpC$"

  # The reference clears `@wrpP$` but fills the numeric `@wrpP`, so the string array stays empty.
  @cleared [@warp_menu, @warp_destinations, :"wrpP$", :viewpX, :viewpY]

  @maps %{
    "prontera" => [
      {@warp_destinations, ["Izlude", "Geffen", "Payon", "Morocc", "Orc Dungeon", "Alberta"]},
      {@warp_prices, [600, 1200, 1200, 1200, 1700, 1800]},
      {:viewpX, [151, 29, 282, 152]},
      {:viewpY, [29, 207, 200, 326]}
    ],
    "alberta" => [
      {@warp_prices, [1200, 1800, 1800]},
      {@warp_destinations, ["Payon", "Morocc", "Prontera"]},
      {:viewpX, [28, 113, 0, 0]},
      {:viewpY, [229, 60, 0, 0]}
    ],
    "aldebaran" => [
      {@warp_prices, [1200, 1200, 1800, 1700]},
      {@warp_destinations, ["Geffen", "Juno", "Izlude", "Mjolnir Dead Pit"]}
    ],
    "comodo" => [
      {@warp_destinations, ["Morocc", "Comodo Pharos Beacon", "Umbala"]},
      {@warp_prices, [1800, 1200, 1800]}
    ],
    "cmd_fild07" => [
      {@warp_destinations, ["Comodo", "Morocc"]},
      {@warp_prices, [1200, 1200]}
    ],
    "geffen" => [
      {@warp_destinations, ["Prontera", "Al De Baran", "Orc Dungeon", "Mjolnir Dead Pit"]},
      {@warp_prices, [1200, 1200, 1700, 1700]},
      {:viewpX, [120, 203]},
      {:viewpY, [62, 123]}
    ],
    "izlude" => [
      {@warp_destinations, ["Geffen", "Payon", "Morocc", "Al De Baran"]},
      {@warp_prices, [1200, 1200, 1200, 1800]}
    ],
    "morocc" => [
      {@warp_destinations, ["Prontera", "Payon", "Alberta", "Comodo", "Comodo Pharos Beacon"]},
      {@warp_prices, [1200, 1200, 1800, 1800, 1200]},
      {:viewpX, [156, 163, 28, 292]},
      {:viewpY, [97, 260, 167, 211]}
    ],
    "umbala" => [
      {@warp_destinations, ["Comodo"]},
      {@warp_prices, [1800]}
    ],
    "payon" => [
      {@warp_destinations, ["Prontera", "Alberta", "Morocc"]},
      {@warp_prices, [1200, 1200, 1200]}
    ],
    "yuno" => [
      {@warp_destinations, ["Al De Baran"]},
      {@warp_prices, [1200]},
      {:viewpX, [328, 278, 153, 0]},
      {:viewpY, [108, 221, 187, 0]}
    ],
    "job3_rune01" => [
      {@warp_destinations, ["Izlude", "Geffen", "Payon", "Morocc", "Alberta"]},
      {@warp_prices, [600, 1200, 1200, 1200, 1800]}
    ]
  }

  @doc """
  Callable rAthena global function `F_KafSet`; rewrites the teleport menu arrays for the NPC's map.
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), nil}
  def call(ctx, _args) do
    ctx = Enum.reduce(@cleared, ctx, fn key, ctx -> set_temp_var(ctx, key, []) end)

    ctx =
      @maps
      |> Map.get(strnpcinfo(ctx, 4), [])
      |> Enum.reduce(ctx, fn {key, values}, ctx -> set_temp_var(ctx, key, values) end)

    destinations = get_temp_var(ctx, @warp_destinations, [])

    ctx =
      if vip_surcharge?(ctx),
        do: double_prices(ctx, length(destinations)),
        else: ctx

    ctx =
      destinations
      |> build_menu(ctx, get_temp_var(ctx, @warp_prices, []))
      |> then(&set_temp_var(&1, @warp_menu, append_cancel(&1, length(destinations))))

    {ctx, nil}
  end

  defp vip_surcharge?(ctx) do
    Rathena.truthy?(get_char_var(ctx, :VIP_SCRIPT, 0)) and not Rathena.truthy?(vip_status(ctx, 1))
  end

  defp double_prices(ctx, count) do
    Enum.reduce(0..(count - 1)//1, ctx, fn index, ctx ->
      prices = get_temp_var(ctx, @warp_prices, [])

      set_temp_var(
        ctx,
        @warp_prices,
        Rathena.put_at(prices, index, Enum.at(prices, index, 0) * 2, 0)
      )
    end)
  end

  defp build_menu(destinations, ctx, prices) do
    Enum.reduce(0..(length(destinations) - 1)//1, ctx, fn index, ctx ->
      label = "#{Enum.at(destinations, index, "")} -> #{Enum.at(prices, index, 0)} z"

      set_temp_var(
        ctx,
        @warp_menu,
        Rathena.put_at(get_temp_var(ctx, @warp_menu, []), index, label, "")
      )
    end)
  end

  defp append_cancel(ctx, count) do
    Rathena.put_at(get_temp_var(ctx, @warp_menu, []), count, "Cancel", "")
  end
end
