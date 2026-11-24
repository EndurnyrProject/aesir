defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.SchoolOfFish do
  @moduledoc """
  Lets eligible players fish for quest items and other catches.

  ## Behavior

  - Reduces casting time for equipped fishing gear and awards a randomized catch.
  - May award a quest file or bonus boxes, with announcements for rare catches.

  ## Credits

  - Original from rAthena, authors and Contributors
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

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "spl_fild03",
        x: 226,
        y: 151,
        dir: 0,
        sprite: 844,
        name: "School of Fish",
        scope: :shared,
        unique_name: "FishingHole_spl3",
        hidden_name: "5"
      },
      %{
        map: "spl_fild03",
        x: 268,
        y: 230,
        dir: 0,
        sprite: 844,
        name: "School of Fish",
        scope: :shared,
        unique_name: "School of Fish#6"
      },
      %{
        map: "spl_fild03",
        x: 293,
        y: 253,
        dir: 0,
        sprite: 844,
        name: "School of Fish",
        scope: :shared,
        unique_name: "School of Fish#7"
      },
      %{
        map: "spl_fild03",
        x: 165,
        y: 100,
        dir: 0,
        sprite: 844,
        name: "School of Fish",
        scope: :shared,
        unique_name: "School of Fish#8"
      },
      %{
        map: "spl_fild03",
        x: 317,
        y: 190,
        dir: 0,
        sprite: 844,
        name: "School of Fish",
        scope: :shared,
        unique_name: "School of Fish#9"
      },
      %{
        map: "spl_fild01",
        x: 41,
        y: 118,
        dir: 0,
        sprite: 844,
        name: "School of Fish",
        scope: :shared,
        unique_name: "School of Fish#10"
      },
      %{
        map: "spl_fild01",
        x: 317,
        y: 361,
        dir: 0,
        sprite: 844,
        name: "School of Fish",
        scope: :shared,
        unique_name: "School of Fish#11"
      },
      %{
        map: "spl_fild01",
        x: 55,
        y: 269,
        dir: 0,
        sprite: 844,
        name: "School of Fish",
        scope: :shared,
        unique_name: "School of Fish#12"
      },
      %{
        map: "spl_fild01",
        x: 332,
        y: 131,
        dir: 0,
        sprite: 844,
        name: "School of Fish",
        scope: :shared,
        unique_name: "School of Fish#13"
      },
      %{
        map: "spl_fild01",
        x: 170,
        y: 74,
        dir: 0,
        sprite: 844,
        name: "School of Fish",
        scope: :shared,
        unique_name: "School of Fish#14"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if checkquest(ctx, 12060, :playtime) == -1 and count_item(ctx, 6039) < 20 do
      fish(ctx)
    else
      ctx |> mes("Fish are swimming in the water.") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp fish(ctx) do
    ctx = ctx |> specialeffect2(:bubble) |> specialeffect2(:invenom) |> set_local(:fcast, 15)

    ctx =
      Enum.reduce(
        [{2550, 2}, {2443, 2}, {2764, 3}, {2775, 1}, {1599, 3}, {2199, 4}],
        ctx,
        fn {item, reduction}, ctx ->
          if Rathena.truthy?(is_equipped(ctx, item)) do
            set_local(ctx, :fcast, get_local(ctx, :fcast, 0) - reduction)
          else
            ctx
          end
        end
      )

    ctx = progressbar(ctx, "ffff00", get_local(ctx, :fcast, 0))

    ctx =
      if get_char_var(ctx, :ep13_1_rhea, 0) == 13 and Enum.random(1..20) == 2 do
        ctx
        |> give_item(6037, 1)
        |> set_char_var(:ep13_1_rhea, 14)
        |> specialeffect2(:bubble)
        |> announce_catch("Loose File", "0xff77ff")
      else
        ctx
      end

    ctx = set_local(ctx, :rhea_ran, Enum.random(1..70))
    roll = get_local(ctx, :rhea_ran, 0)

    item =
      cond do
        roll < 20 -> 6039
        roll == 20 -> 908
        roll == 21 -> 909
        roll == 22 -> 963
        roll == 23 -> 956
        roll == 24 -> 6049
        roll == 25 -> 918
        roll == 26 -> 960
        roll == 27 -> 910
        roll == 28 -> 6081
        roll < 40 -> 7049
        true -> nil
      end

    if item do
      ctx |> give_item(item, 1) |> bonus_catches()
    else
      ctx |> mes("Nothing was caught.") |> close()
    end
  end

  defp bonus_catches(ctx) do
    ctx = set_local(ctx, :rhea_ran5, Enum.random(1..200))

    ctx =
      if get_local(ctx, :rhea_ran5, 0) == 3,
        do: ctx |> give_item(644, 1) |> announce_catch("Gift Box", "0x00ffff"),
        else: ctx

    ctx = set_local(ctx, :rhea_ran3, Enum.random(1..500))

    ctx =
      if get_local(ctx, :rhea_ran3, 0) == 3,
        do: ctx |> give_item(603, 1) |> announce_catch("Old Blue Box", "0x00ffff"),
        else: ctx

    ctx = set_local(ctx, :rhea_ran4, Enum.random(1..3000))

    if get_local(ctx, :rhea_ran4, 0) == 3,
      do: ctx |> give_item(617, 1) |> announce_catch("Old Purple Box", "0x44ff44"),
      else: ctx
  end

  defp announce_catch(ctx, item, color) do
    mapannounce(
      ctx,
      char_name(ctx, 3),
      Rathena.concat(char_name(ctx, 0), " has caught a " <> item <> "."),
      1,
      color
    )
  end
end
