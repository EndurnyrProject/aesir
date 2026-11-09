defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.CampGuard do
  @moduledoc """
  The camp guard at the three exits of the expedition camp, who opens the way into the
  fields once the expedition is underway.

  ## Behavior

  - Stops every player at the danger zone boundary and closes the dialog unless the expedition
    is under way (`ep13_ryu` or `ep13_start` at 100 or above).
  - Offers to open the way: entering closes the dialog and warps to the field that matches the
    guard's own name suffix, advancing `ep13_animal` from 1 to 2 on the Manuk exit.
  - Refusing sends the player back to the camp.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mid_camp",
        x: 336,
        y: 171,
        dir: 1,
        sprite: 852,
        name: "Camp Guard",
        scope: :shared,
        unique_name: "Camp Guard#man1"
      },
      %{
        map: "mid_camp",
        x: 13,
        y: 143,
        dir: 5,
        sprite: 852,
        name: "Camp Guard",
        scope: :shared,
        unique_name: "Camp Guard#man2"
      },
      %{
        map: "mid_camp",
        x: 9,
        y: 215,
        dir: 5,
        sprite: 852,
        name: "Camp Guard",
        scope: :shared,
        unique_name: "Camp Guard#man3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Camp Guard]")
      |> mes("Stop!")
      |> mes("You're about to enter an area that has not been fully explored.")
      |> mes(
        "Only personnel--researchers and explorers--authorized by United Midgard and the garrison are allowed to enter the danger zone."
      )

    if get_char_var(ctx, :ep13_ryu, 0) < 100 and get_char_var(ctx, :ep13_start, 0) < 100 do
      close(ctx)
    else
      passage_menu(ctx)
    end
  end

  defp passage_menu(ctx) do
    {ctx, choice} =
      ctx
      |> next()
      |> select(["I want to enter the next area.", "I want to stay."])

    case choice do
      1 -> cross(ctx)
      2 -> stay(ctx)
      _ -> ctx
    end
  end

  defp cross(ctx) do
    ctx =
      ctx
      |> mes("[Camp Guard]")
      |> mes("Please be careful out there.")
      |> mes(
        "If you encounter any threats or strange phenomenon, then please don't hesitate to report to us at the garrison."
      )
      |> close()

    # The destination comes from the guard's own name suffix: `Camp Guard#man1` sends the
    # player to the Manuk field, `#man2` and `#man3` to two spots of the Splendid field.
    case Rathena.atoi(Rathena.charat(strnpcinfo(ctx, 2), 3)) do
      1 -> enter_manuk(ctx)
      2 -> warp(ctx, "spl_fild02", 379, 143)
      3 -> warp(ctx, "spl_fild02", 380, 217)
      _other -> ctx
    end
  end

  defp enter_manuk(ctx) do
    ctx =
      if get_char_var(ctx, :ep13_animal, 0) == 1 do
        set_char_var(ctx, :ep13_animal, 2)
      else
        ctx
      end

    warp(ctx, "man_fild01", 36, 235)
  end

  defp stay(ctx) do
    ctx
    |> mes("[Camp Guard]")
    |> mes("No, you can't. Please return to the expedition camp.")
    |> close()
  end
end
