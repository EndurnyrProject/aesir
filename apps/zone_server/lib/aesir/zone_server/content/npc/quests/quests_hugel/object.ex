defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Object do
  @moduledoc """
  A ruined structure hides a shining stone inside the Odin Shrine.

  ## Behavior

  - Offers a chance to discover the stone while exploring the ruins.
  - Moves the player deeper into the shrine after the stone is picked up.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_hugel",
        x: 35,
        y: 29,
        dir: 5,
        sprite: 139,
        name: "object",
        scope: :shared,
        unique_name: "object#1",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch_", ctx), do: on_talk(ctx)

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :hg_odin, 0) do
      21 -> explore_ruins(ctx)
      22 -> warp(ctx, "que_hugel", 163, 31)
      _ -> ctx
    end
  end

  defp explore_ruins(ctx) do
    ctx =
      ctx
      |> mes("^3355FFA weathered structure")
      |> mes("of the Odin Shrine is")
      |> mes("half buried beneath the")
      |> mes("ground, but it still looks")
      |> mes("fairly stable and durable.^000000")
      |> next()

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("......")
      |> mes(".........")
      |> next()
      |> select(["Pass", "Explore"])

    case choice do
      1 ->
        ctx
        |> mes("^3355FFYou decided to pass")
        |> mes("by the shrine's remnants.^000000")
        |> close()

      2 ->
        search_ruins(ctx)

      _ ->
        ctx
    end
  end

  defp search_ruins(ctx) do
    if Enum.random(1..3) == 1 do
      {ctx, choice} =
        ctx
        |> mes("^3355FFYou catch a bright")
        |> mes("shimmer among the")
        |> mes("remnants of the shrine.^000000")
        |> next()
        |> select(["Ignore", "Pick it up"])

      case choice do
        1 ->
          ctx
          |> mes("^3355FFYou decide to continue")
          |> mes("searching through the")
          |> mes("shrine's ruins.^000000")
          |> close()

        2 ->
          pick_up_stone(ctx)

        _ ->
          ctx
      end
    else
      ctx
      |> mes("^3355FFUnfortunately, you")
      |> mes("were unable to find")
      |> mes("anything in the ruins.^000000")
      |> close()
    end
  end

  defp pick_up_stone(ctx) do
    ctx =
      ctx
      |> mes("^3355FFYou find a shining stone")
      |> mes("within the ruins, and carefully")
      |> mes("put it into your bag.^000000")
      |> next()
      |> mes("^FF0000Thud!^000000")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("What...?")
      |> mes("What was")
      |> mes("that noise?!")
      |> next()
      |> specialeffect(:lord)
      |> specialeffect(:lord)
      |> specialeffect(:lord)

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Wa...waaaahhhh!")
    |> close()
    |> set_char_var(:hg_odin, 22)
    |> warp("que_hugel", 163, 31)
  end
end
