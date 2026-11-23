defmodule Aesir.ZoneServer.Content.Npc.Functions.Jewel132 do
  @moduledoc """
  Handles the half-buried gem investigation.

  ## Behavior

  - Offers a gem excavation during the Rhea quest, with a chance of a Thief Bug attack.
  - Records successful excavations and gives the matching gem.

  ## Credits

  - Original from rAthena, authors and contributors:
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  import Aesir.ZoneServer.Script.Dsl, warn: false
  alias Aesir.ZoneServer.Script.Rathena

  @doc "Runs the gem interaction and ends the current script."
  def call(ctx, args) do
    ctx = set_local(ctx, :"color$", Enum.at(args, 0, 0))
    progress = get_char_var(ctx, :ep13_2_rhea, 0)

    ctx =
      cond do
        progress < 5 ->
          ctx |> buried_gem() |> close()

        progress == 5 ->
          investigate(ctx, args)

        true ->
          already_dug(ctx)
      end

    throw({:script_end, ctx})
  end

  defp investigate(ctx, args) do
    if Rathena.truthy?(checkweight(ctx, [{7575, 2}])) do
      ctx = set_local(ctx, :num, Enum.at(args, 1, 0))

      if checkquest(ctx, 8240 + get_local(ctx, :num, 0)) == -1 do
        {ctx, choice} =
          ctx |> buried_gem() |> next() |> select(["Dig out the Gem", "Leave it alone"])

        cond do
          choice == 2 -> leave_gem(ctx)
          Enum.random(1..4) == 2 -> take_gem(ctx)
          true -> encounter_bug(ctx)
        end
      else
        already_dug(ctx)
      end
    else
      ctx |> mes("Sorry, your inventory is full!") |> close()
    end
  end

  defp buried_gem(ctx) do
    ctx = mes(ctx, "- Under a round pile of earth, -")

    ctx
    |> mes(
      Rathena.concat(Rathena.concat("- there's a ", get_local(ctx, :"color$", "")), " Gem -")
    )
    |> mes("- half-buried. -")
  end

  defp already_dug(ctx) do
    ctx = mes(ctx, "- Small pile of earth -")

    ctx
    |> mes(
      Rathena.concat(
        Rathena.concat("- which you dug up the ", get_local(ctx, :"color$", "")),
        " Gem -"
      )
    )
    |> close()
  end

  defp leave_gem(ctx) do
    ctx =
      ctx
      |> mes("- You overspread some earth over the Gem -")
      |> mes("- and left the Gem as it was. -")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("...What the heck am I doing now...")
    |> close()
  end

  defp take_gem(ctx) do
    ctx = mes(ctx, "- You dug up a pile of earth -")

    ctx =
      mes(
        ctx,
        Rathena.concat(
          Rathena.concat("- and pulled out the ", get_local(ctx, :"color$", "")),
          " Gem -"
        )
      )

    ctx = setquest(ctx, 8240 + get_local(ctx, :num, 0))
    ctx |> give_item(7574 + get_local(ctx, :num, 0), 1) |> close()
  end

  defp encounter_bug(ctx) do
    ctx = ctx |> mes("- As you dug up a pile of earth, -") |> mes("- a Thief Bug attacks you! -")

    ctx =
      ctx
      |> donpcevent(
        Rathena.concat(Rathena.concat("Half-buried Gem#", get_local(ctx, :num, 0)), "::OnDisable")
      )
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("What the heck is this?!?!?!")
    |> close()
  end
end
