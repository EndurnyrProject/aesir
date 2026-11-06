defmodule Aesir.ZoneServer.Content.Npc.Functions.FKaftele do
  @moduledoc """
  Teleports the player to a Kafra destination for a fee.

  ## Behavior

  The destination list is the one `F_KafSet` prepared for the current map, with prices. A Free
  Transportation Ticket skips the fee; otherwise the fee is charged and awards Special Reserve
  Points. Cancelling returns without teleporting, and an unaffordable destination ends the script
  with the fee message. Izlude lands on the mode's coordinates.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script kafras/functions_kafras.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx

  @transport_ticket 7060
  @reserve_point_divisor 16

  @destinations %{
    "Al De Baran" => {"aldebaran", 168, 112},
    "Alberta" => {"alberta", 117, 56},
    "Comodo" => {"comodo", 209, 143},
    "Comodo Pharos Beacon" => {"cmd_fild07", 127, 134},
    "Geffen" => {"geffen", 120, 39},
    "Juno" => {"yuno", 158, 125},
    "Mjolnir Dead Pit" => {"mjolnir_02", 99, 351},
    "Morocc" => {"morocc", 156, 46},
    "Orc Dungeon" => {"gef_fild10", 52, 326},
    "Payon" => {"payon", 161, 58},
    "Prontera" => {"prontera", 116, 72},
    "Umbala" => {"umbala", 100, 154}
  }

  @doc """
  Callable rAthena global function `F_KafTele(welcome)`; throws `{:script_end, ctx}` after the
  teleport, or returns `{ctx, nil}` when the player cancelled.
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), nil} | no_return()
  def call(ctx, args) do
    try do
      {ctx, destination, price} = choose(ctx)

      ctx = ctx |> charge(destination, price, args) |> cutin("", 255) |> warp_to(destination)
      halt(ctx)
    catch
      :throw, {:script_return, result} -> result
    end
  end

  defp choose(ctx) do
    ctx =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Please choose")
      |> mes("your destination.")
      |> next()

    names = get_temp_var(ctx, :"wrpC$", [])
    {ctx, choice} = select(ctx, names |> Enum.join(":") |> String.split(":"))

    index = choice - 1

    if Enum.at(names, index, "") == "Cancel" do
      halt_with_nil(ctx)
    else
      {ctx, Enum.at(get_temp_var(ctx, :"wrpD$", []), index, ""),
       Enum.at(get_temp_var(ctx, :wrpP, []), index, 0)}
    end
  end

  defp charge(ctx, destination, price, args) do
    if count_item(ctx, @transport_ticket) > 0 and Enum.at(args, 0, 0) != 2 do
      delitem(ctx, @transport_ticket, 1)
    else
      charge_fee(ctx, destination, price)
    end
  end

  defp charge_fee(ctx, destination, price) do
    if zeny(ctx) < price do
      ctx
      |> mes("[Kafra Employee]")
      |> mes("I'm sorry, but you don't have")
      |> mes("enough zeny for the Teleport")
      |> mes("Service. The fee to teleport")
      |> mes("to #{destination} is #{price} zeny.")
      |> close()
      |> cutin("", 255)
      |> halt()
    else
      ctx
      |> pay_zeny(price)
      |> set_char_var(
        :RESRVPTS,
        get_char_var(ctx, :RESRVPTS, 0) + div(price, @reserve_point_divisor)
      )
    end
  end

  defp warp_to(ctx, "Izlude") do
    if checkre(ctx, 0) == 1, do: warp(ctx, "izlude", 128, 98), else: warp(ctx, "izlude", 91, 105)
  end

  defp warp_to(ctx, destination) do
    case Map.fetch(@destinations, destination) do
      {:ok, {map, x, y}} -> warp(ctx, map, x, y)
      :error -> ctx
    end
  end

  defp halt(ctx), do: throw({:script_end, ctx})
  defp halt_with_nil(ctx), do: throw({:script_return, {ctx, nil}})
end
