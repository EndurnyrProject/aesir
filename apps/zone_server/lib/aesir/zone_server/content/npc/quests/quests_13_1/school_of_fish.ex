defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.SchoolOfFish do
  @moduledoc """
  A fishing hole of the Splendid field and the expedition camp, where a cast yields fish and
  the occasional treasure.

  ## Behavior

  - A cast is only possible while the fishing quest's playtime is unset and the player holds
    fewer than 20 Pieces of Fish; otherwise the fish only swim in the water.
  - Each piece of fishing gear (Fisher's Muffler, Fish Shoes, Small Fishing Rod, Lure, Ahura
    Mazda, Angra Manyu) shortens the 15 second progress bar.
  - On the three-kingdom errand's step 13, one cast in twenty also yields the Messy File.
  - The catch roll picks the Piece of Fish, Junk items, the Marlin or a Stone, and nothing
    catches the player's attention on the remaining rolls.
  - A caught fish can additionally be a Gift Box, an Old Blue Box or an Old Purple Box, each
    announced to the map.

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
        map: "spl_fild02",
        x: 314,
        y: 165,
        dir: 0,
        sprite: 844,
        name: "School of Fish",
        scope: :shared,
        unique_name: "Fishinghole"
      },
      %{
        map: "spl_fild02",
        x: 321,
        y: 169,
        dir: 0,
        sprite: 844,
        name: "School of Fish",
        scope: :shared,
        unique_name: "School of Fish#2"
      },
      %{
        map: "spl_fild02",
        x: 326,
        y: 171,
        dir: 0,
        sprite: 844,
        name: "School of Fish",
        scope: :shared,
        unique_name: "School of Fish#3"
      },
      %{
        map: "mid_camp",
        x: 75,
        y: 135,
        dir: 0,
        sprite: 844,
        name: "School of Fish",
        scope: :shared,
        unique_name: "School of Fish#4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @fishing_quest 12060
  @piece_of_fish 6039
  @fish_limit 20

  @base_cast 15

  # Each piece of fishing gear shortens the cast.
  @fishing_gear [{2550, 2}, {2443, 2}, {2764, 3}, {2775, 1}, {1599, 3}, {2199, 4}]

  @rough_file 6037
  @stone 7049
  @gift_box 644
  @old_blue_box 603
  @old_purple_box 617

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if checkquest(ctx, @fishing_quest, :playtime) == -1 and
         count_item(ctx, @piece_of_fish) < @fish_limit do
      cast_the_line(ctx)
    else
      ctx |> mes("Fish are swimming in the water.") |> close()
    end
  end

  defp cast_the_line(ctx) do
    ctx =
      ctx
      |> specialeffect2(:bubble)
      |> specialeffect2(:invenom)
      |> progressbar("ffff00", cast_time(ctx))
      |> maybe_messy_file()

    catch_fish(ctx)
  end

  defp cast_time(ctx) do
    Enum.reduce(@fishing_gear, @base_cast, fn {item, reduction}, time ->
      if Rathena.truthy?(is_equipped(ctx, item)), do: time - reduction, else: time
    end)
  end

  # The rough file can only be fished up while the three-kingdom errand is on its step 13.
  defp maybe_messy_file(ctx) do
    if get_char_var(ctx, :ep13_1_rhea, 0) == 13 and Enum.random(1..20) == 2 do
      ctx
      |> give_item(@rough_file, 1)
      |> set_char_var(:ep13_1_rhea, 14)
      |> specialeffect(:bubble)
      |> mapannounce(
        char_name(ctx, 3),
        "#{char_name(ctx, 0)} has caught a Messy File!!",
        1,
        "0xff77ff"
      )
    else
      ctx
    end
  end

  defp catch_fish(ctx) do
    case Enum.random(1..70) do
      roll when roll < 20 -> catch_item(ctx, @piece_of_fish)
      20 -> catch_item(ctx, 908)
      21 -> catch_item(ctx, 909)
      22 -> catch_item(ctx, 963)
      23 -> catch_item(ctx, 956)
      24 -> catch_item(ctx, 6049)
      25 -> catch_item(ctx, 918)
      26 -> catch_item(ctx, 960)
      27 -> catch_item(ctx, 910)
      28 -> catch_item(ctx, 938)
      roll when roll < 40 -> catch_item(ctx, @stone)
      _nothing -> nothing_caught(ctx)
    end
  end

  defp catch_item(ctx, item) do
    ctx
    |> give_item(item, 1)
    |> gift_box_chance()
    |> old_blue_box_chance()
    |> old_purple_box_chance()
  end

  defp nothing_caught(ctx), do: ctx |> mes("Nothing was caught.") |> close()

  defp gift_box_chance(ctx) do
    if Enum.random(1..200) == 3 do
      ctx
      |> give_item(@gift_box, 1)
      |> mapannounce(
        char_name(ctx, 3),
        "#{char_name(ctx, 0)} has caught a Gift Box!!",
        1,
        "0x00ffff"
      )
    else
      ctx
    end
  end

  defp old_blue_box_chance(ctx) do
    if Enum.random(1..500) == 3 do
      ctx
      |> give_item(@old_blue_box, 1)
      |> mapannounce(
        char_name(ctx, 3),
        "#{char_name(ctx, 0)} has caught an Old Blue Box!!",
        1,
        "0x00ffff"
      )
    else
      ctx
    end
  end

  defp old_purple_box_chance(ctx) do
    if Enum.random(1..3000) == 3 do
      ctx
      |> give_item(@old_purple_box, 1)
      |> mapannounce(
        char_name(ctx, 3),
        "#{char_name(ctx, 0)} has caught an Old Purple Box!!",
        1,
        "0x44ff44"
      )
    else
      ctx
    end
  end
end
