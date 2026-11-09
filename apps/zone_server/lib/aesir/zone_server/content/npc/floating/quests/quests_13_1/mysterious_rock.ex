defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Quests131.MysteriousRock do
  @moduledoc """
  One of the mysterious rocks of the Manuk fields, mined for unidentified minerals and
  elemental stones.

  ## Behavior

  - Rejects a player who already holds three unidentified minerals or is inside the mining
    quest's playtime, closing the dialog.
  - Otherwise plays the mining effect and progress bar and yields one drop: a Stone, one of
    the four elemental stones, or an unidentified mineral.
  - Hides itself and starts its reappearance timer after a successful mining.

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
        map: "man_fild01",
        x: 180,
        y: 170,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#1"
      },
      %{
        map: "man_fild01",
        x: 147,
        y: 157,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#2"
      },
      %{
        map: "man_fild01",
        x: 114,
        y: 174,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#3"
      },
      %{
        map: "man_fild01",
        x: 92,
        y: 155,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#4"
      },
      %{
        map: "man_fild01",
        x: 170,
        y: 318,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#5"
      },
      %{
        map: "man_fild01",
        x: 146,
        y: 269,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#6"
      },
      %{
        map: "man_fild01",
        x: 118,
        y: 238,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#7"
      },
      %{
        map: "man_fild01",
        x: 70,
        y: 246,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#8"
      },
      %{
        map: "man_fild01",
        x: 64,
        y: 197,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#9"
      },
      %{
        map: "man_fild03",
        x: 82,
        y: 134,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#10"
      },
      %{
        map: "man_fild03",
        x: 67,
        y: 160,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#11"
      },
      %{
        map: "man_fild03",
        x: 66,
        y: 171,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#12"
      },
      %{
        map: "man_fild03",
        x: 81,
        y: 198,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#13"
      },
      %{
        map: "man_fild03",
        x: 82,
        y: 216,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#14"
      },
      %{
        map: "man_fild03",
        x: 98,
        y: 226,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#15"
      },
      %{
        map: "man_fild03",
        x: 104,
        y: 248,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#16"
      },
      %{
        map: "man_fild03",
        x: 91,
        y: 272,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#17"
      },
      %{
        map: "man_fild03",
        x: 95,
        y: 301,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#18"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @stone 7049
  @boody_red 990
  @crystal_blue 991
  @wind_of_verdure 992
  @yellow_live 993
  @unidentified_mineral 6048

  @mining_limit_quest 12062
  @minerals_per_visit 3

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if mineable?(ctx) do
      ctx =
        ctx
        |> specialeffect2(:repairweapon)
        |> progressbar("ffff00", 10)
        |> set_local(:rhea_ran, Enum.random(1..20))

      ctx
      |> give_item(rolled_item(ctx), 1)
      |> initnpctimer()
      |> disablenpc()
    else
      exhausted(ctx)
    end
  end

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTimer120000", ctx), do: ctx |> enablenpc() |> stopnpctimer()

  # The rock stops paying out while the player holds three minerals or is already inside the
  # playtime of the mining quest.
  defp mineable?(ctx) do
    count_item(ctx, @unidentified_mineral) < @minerals_per_visit and
      checkquest(ctx, @mining_limit_quest, :playtime) == -1
  end

  # The roll decides the drop: 1..12 a Stone, 13..16 the elemental stones, 17..20 the
  # unidentified mineral that the visit limit counts.
  defp rolled_item(ctx) do
    case get_local(ctx, :rhea_ran, 0) do
      roll when roll < 13 -> @stone
      13 -> @boody_red
      14 -> @crystal_blue
      15 -> @wind_of_verdure
      16 -> @yellow_live
      _roll -> @unidentified_mineral
    end
  end

  defp exhausted(ctx) do
    ctx
    |> mes("This rock contains unidentified minerals.")
    |> mes("It's not possible to mine more than the limit.")
    |> close()
  end
end
