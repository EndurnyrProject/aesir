defmodule Aesir.ZoneServer.Content.Npc.Functions.FKafinfo do
  @moduledoc """
  Shows the Kafra information menu: reserve points, storage password and employee locations.

  ## Behavior

  The reserve points page reports the character name and the current Special Reserve Points; Kafra
  offices where the page is terminal return right after it. The password page runs the storage
  password service and then falls through to the employee locations, which are flagged with
  `viewpoint` markers twice. Cancelling returns from the function.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - k0b0
    - L0ne_W0lf
    - Joseph

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script kafras/functions_kafras.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Content.Npc.Functions.FSetkafcode
  alias Aesir.ZoneServer.Script.Ctx

  @viewpoint_colour 16_711_935
  @location_count 0..3

  @doc """
  Callable rAthena global function `F_KafInfo(type)`; returns `{ctx, nil}`, or throws
  `{:script_return, result}` from the reserve points page and the cancel option.
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), nil} | no_return()
  def call(ctx, args) do
    try do
      {menu_loop(ctx, menu(args), args), nil}
    catch
      :throw, {:script_return, result} -> result
    end
  end

  defp menu(args) do
    if Enum.at(args, 0, 0) == 2 do
      ["Check Special Reserve Points.", "", "", "Cancel"]
    else
      [
        "Check Special Reserve Points.",
        "Storage Password Service",
        "Kafra Employee Locations",
        "Cancel"
      ]
    end
  end

  defp menu_loop(ctx, menu, args) do
    {ctx, choice} = select(ctx, menu)

    ctx =
      case choice - 1 do
        0 ->
          reserve_points(ctx, args)

        1 ->
          {ctx, _code} = FSetkafcode.call(ctx, ["[Kafra Employee]", "Kafra Services"])
          locations(ctx)

        2 ->
          locations(ctx)

        _other ->
          halt_with_nil(ctx)
      end

    menu_loop(ctx, menu, args)
  end

  defp reserve_points(ctx, args) do
    ctx =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Let's see...")
      |> mes("#{char_name(ctx, 0)}...")
      |> mes("Ah, you have a total of")
      |> mes("#{get_char_var(ctx, :RESRVPTS, 0)} Special Reserve Points.")
      |> next()
      |> mes("[Kafra Employee]")
      |> mes("You can exchange your")
      |> mes("Special Reserve Points for")
      |> mes("rewards at the Kafra Main Office in Al De Baran. Please use our")
      |> mes("convenient services to see the benefits of our rewards program.")

    if Enum.at(args, 0, 0) == 1, do: halt_with_nil(ctx), else: next(ctx)
  end

  defp locations(ctx) do
    ctx
    |> viewpoint_markers(1)
    |> next()
    |> viewpoint_markers(2)
  end

  defp viewpoint_markers(ctx, type) do
    Enum.reduce(@location_count, ctx, fn index, ctx ->
      viewpoint(
        ctx,
        type,
        Enum.at(get_temp_var(ctx, :viewpX, []), index, 0),
        Enum.at(get_temp_var(ctx, :viewpY, []), index, 0),
        index + 1,
        @viewpoint_colour
      )
    end)
  end

  defp halt_with_nil(ctx), do: throw({:script_return, {ctx, nil}})
end
