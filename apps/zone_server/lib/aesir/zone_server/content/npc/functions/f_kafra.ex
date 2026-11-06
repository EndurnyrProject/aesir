defmodule Aesir.ZoneServer.Content.Npc.Functions.FKafra do
  @moduledoc """
  Runs the shared Kafra employee menu.

  ## Behavior

  Clears the outdated quest variables, greets the player with the message the Kafra variant uses,
  and offers the menu that fits it: save, storage, teleport, pushcart rental, information and, in a
  guild castle, the free guild services. Each choice runs the matching Kafra helper and returns to
  the menu; cancelling closes the conversation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Darlskies
    - Darkchild
    - Syrus22
    - Lupus
    - kobra_k88
    - L0ne_W0lf
    - Joseph
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script kafras/functions_kafras.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Content.Npc.Functions.FCleargarbage
  alias Aesir.ZoneServer.Content.Npc.Functions.FKafcart
  alias Aesir.ZoneServer.Content.Npc.Functions.FKafend
  alias Aesir.ZoneServer.Content.Npc.Functions.FKafinfo
  alias Aesir.ZoneServer.Content.Npc.Functions.FKafstor
  alias Aesir.ZoneServer.Content.Npc.Functions.FKaftele
  alias Aesir.ZoneServer.Script.Ctx

  @guild_menu [
    "Use Storage",
    "Use Guild Storage",
    "Rent a Pushcart",
    "Use Teleport Service",
    "Cancel"
  ]

  @default_menu [
    "Save",
    "Use Storage",
    "Use Teleport Service",
    "Rent a Pushcart",
    "Check Other Information",
    "Cancel"
  ]

  @menus %{
    1 => ["Save", "Use Storage", "Cancel"],
    2 => ["Use Storage", "Cancel"],
    3 => ["Save", "Use Storage", "Rent a Pushcart", "Check Other Information", "Cancel"],
    5 => ["Use Storage", "Rent a Pushcart", "Check Other Information", "Cancel"],
    6 => ["Use Storage", "Check Other Information", "Cancel"],
    7 => ["Save", "Use Storage", "Rent a Pushcart", "Cancel"],
    8 => ["Save", "Use Storage", "Check Other Information", "Cancel"],
    9 => [
      "Use Storage",
      "Rent a Pushcart",
      "Use Teleport Service",
      "Check Other Information",
      "Cancel"
    ],
    10 => ["Use Storage", "Save", "Rent a Pushcart", "Cancel"]
  }

  @doc """
  Callable rAthena global function `F_Kafra(welcome, menu, info, storage_fee, cart_fee)`; throws
  `{:script_end, ctx}` when the player cancels.
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), nil} | no_return()
  def call(ctx, args) do
    {ctx, _cleared} = FCleargarbage.call(ctx, [])

    welcome = Enum.at(args, 0, 0)
    ctx = ctx |> greet(welcome) |> next()

    try do
      {menu_loop(ctx, menu(welcome, Enum.at(args, 1, 0)), args, welcome), nil}
    catch
      :throw, {:script_return, result} -> result
    end
  end

  defp menu(2, _menu_num), do: @guild_menu
  defp menu(_welcome, menu_num), do: Map.get(@menus, menu_num, @default_menu)

  defp greet(ctx, 1) do
    ctx
    |> mes("[Kafra Employee]")
    |> mes("^666666W-weeeelc-c-come")
    |> mes("to th-the K-kaaafrrrra")
    |> mes("C-coorpoor-r-ratioooonn...^000000")
  end

  defp greet(ctx, 2) do
    ctx
    |> mes("[Kafra Employee]")
    |> mes("Welcome. ^ff0000#{getguildname(ctx, getcharid(ctx, 2))}^000000 Member.")
    |> mes("The Kafra Coporation will stay with you wherever you go.")
  end

  defp greet(ctx, 3) do
    ctx
    |> mes("[Kafra Employee]")
    |> mes(
      "So, have you come from a faraway land to study our culture, or are you just sightseeing?"
    )
    |> mes("In either case, why not stay awhile?")
    |> mes("The air is eternally heavy with the")
    |> mes("scent of pleasant wildflowers.")
  end

  defp greet(ctx, 4) do
    ctx
    |> mes("[Kafra Employee]")
    |> mes("With our many Kafra")
    |> mes("service locations, you're never")
    |> mes("far from home.")
  end

  defp greet(ctx, 5), do: ctx

  defp greet(ctx, _other) do
    ctx
    |> mes("[Kafra Employee]")
    |> mes("Welcome to the")
    |> mes("Kafra Corporation.")
    |> mes("The Kafra services")
    |> mes("are always on your side.")
    |> mes("How may I assist you?")
  end

  defp menu_loop(ctx, menu, args, welcome) do
    {ctx, choice} = select(ctx, menu)

    ctx =
      case Enum.at(menu, choice - 1, "") do
        "Save" -> throw({:script_return, {ctx, nil}})
        "Use Storage" -> storage(ctx, args, welcome)
        "Use Teleport Service" -> teleport(ctx, args, welcome)
        "Rent a Pushcart" -> pushcart(ctx, args, welcome)
        "Check Other Information" -> information(ctx, args)
        "Cancel" -> cancel(ctx, welcome)
        "Use Guild Storage" -> guild_storage(ctx)
        _other -> ctx
      end

    menu_loop(ctx, menu, args, welcome)
  end

  defp storage(ctx, _args, 2) do
    {ctx, _code} = FKafstor.call(ctx, [2, 0, 0])
    next(ctx)
  end

  defp storage(ctx, args, welcome) do
    {ctx, _code} = FKafstor.call(ctx, [0, Enum.at(args, 3, 0), welcome])
    next(ctx)
  end

  defp teleport(ctx, args, welcome) do
    ctx =
      if Enum.at(args, 1, 0) == 4 do
        ctx
        |> mes("[Kafra Employee]")
        |> mes("Because of the ^FF0000Limited")
        |> mes("Transport Agreement^000000, the")
        |> mes("Kafra Corporation cannot")
        |> mes("provide Teleport Services")
        |> mes("in the Schwarzwald Republic.")
        |> next()
        |> mes("[Kafra Employee]")
        |> mes("We ask that you please")
        |> mes("use the Airship Service")
        |> mes("instead. Thank you for your")
        |> mes("understanding and cooperation.")
      else
        {ctx, _code} = FKaftele.call(ctx, [welcome])
        ctx
      end

    next(ctx)
  end

  defp pushcart(ctx, args, welcome) do
    {ctx, code} = FKafcart.call(ctx, [welcome, Enum.at(args, 4, 0)])

    if code == 1, do: next(ctx), else: ctx
  end

  defp information(ctx, args) do
    {ctx, _result} = FKafinfo.call(ctx, [Enum.at(args, 2, 0)])
    next(ctx)
  end

  defp cancel(ctx, welcome) do
    {ctx, _result} = FKafend.call(ctx, [welcome, 0])
    throw({:script_end, ctx})
  end

  defp guild_storage(ctx) do
    {ctx, _result} = FKafstor.call(ctx, [1, 0])
    next(ctx)
  end
end
