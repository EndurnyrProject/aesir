defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Quests132.MysteriousRock do
  @moduledoc """
  Provides random mining rewards for the Bradium collection quest.

  ## Behavior

  - Restricts mining by quest cooldown and mineral count.
  - Awards a random item and temporarily disables the rock.

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

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{name: "Mysterious Rock", unique_name: "manukrock2"},
      %{
        map: "man_fild02",
        x: 146,
        y: 81,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#31"
      },
      %{
        map: "man_fild02",
        x: 140,
        y: 148,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#32"
      },
      %{
        map: "man_fild02",
        x: 88,
        y: 263,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#33"
      },
      %{
        map: "man_fild02",
        x: 146,
        y: 365,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#34"
      },
      %{
        map: "man_fild02",
        x: 336,
        y: 305,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#35"
      },
      %{
        map: "man_fild02",
        x: 248,
        y: 124,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#36"
      },
      %{
        map: "man_fild02",
        x: 285,
        y: 115,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#37"
      },
      %{
        map: "man_fild02",
        x: 346,
        y: 116,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#38"
      },
      %{
        map: "man_fild02",
        x: 358,
        y: 174,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#39"
      },
      %{
        map: "man_fild02",
        x: 241,
        y: 227,
        dir: 0,
        sprite: 844,
        name: "Mysterious Rock",
        scope: :shared,
        unique_name: "Mysterious Rock#40"
      }
    ]

  @impl true
  def on_event("OnTimer120000", ctx) do
    ev_ontimer120000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    if count_item(ctx, 6048) < 3 and checkquest(ctx, 12_062, :playtime) == -1 do
      ctx =
        ctx
        |> specialeffect2(:repairweapon)
        |> progressbar("ffff00", 10)
        |> set_local(:rhea_ran, Enum.random(1..20))

      item =
        case get_local(ctx, :rhea_ran, 0) do
          roll when roll < 13 -> 7049
          13 -> 990
          14 -> 991
          15 -> 992
          16 -> 993
          17 -> 6080
          _ -> 6048
        end

      ctx |> give_item(item, 1) |> initnpctimer() |> disablenpc()
    else
      ctx
      |> mes("This rock contains unidentified minerals.")
      |> mes("It's not possible to mine more than the limit.")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontimer120000(ctx) do
    ctx |> enablenpc() |> stopnpctimer()
  end
end
