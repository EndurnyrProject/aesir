defmodule Aesir.ZoneServer.Content.Npc.Woe.DungeonLever do
  @moduledoc """
  Guild dungeon lever: one placement per FE castle map. An unowned castle
  turns the lever away with a single line; an owning guild member who pulls
  it is warped into the castle's guild dungeon, while anyone else who pulls
  is told nothing happened.

  The lever's own castle map is read from the hidden fragment of its
  `unique_name` (`strnpcinfo(ctx, 2)`), and ownership is looked up through
  `CastleDb.by_map/1` on that map, since the player interacting with it may
  be standing anywhere on the castle map.
  """

  use Aesir.ZoneServer.Npc,
    spawn: [
      %{
        map: "aldeg_cas01",
        x: 211,
        y: 181,
        dir: 0,
        sprite: 111,
        name: "Dungeon Lever",
        unique_name: "Dungeon Lever#aldeg_cas01"
      },
      %{
        map: "aldeg_cas02",
        x: 194,
        y: 136,
        dir: 0,
        sprite: 111,
        name: "Dungeon Lever",
        unique_name: "Dungeon Lever#aldeg_cas02"
      },
      %{
        map: "aldeg_cas03",
        x: 200,
        y: 177,
        dir: 0,
        sprite: 111,
        name: "Dungeon Lever",
        unique_name: "Dungeon Lever#aldeg_cas03"
      },
      %{
        map: "aldeg_cas04",
        x: 76,
        y: 64,
        dir: 0,
        sprite: 111,
        name: "Dungeon Lever",
        unique_name: "Dungeon Lever#aldeg_cas04"
      },
      %{
        map: "aldeg_cas05",
        x: 22,
        y: 205,
        dir: 0,
        sprite: 111,
        name: "Dungeon Lever",
        unique_name: "Dungeon Lever#aldeg_cas05"
      },
      %{
        map: "gefg_cas01",
        x: 78,
        y: 84,
        dir: 0,
        sprite: 111,
        name: "Dungeon Lever",
        unique_name: "Dungeon Lever#gefg_cas01"
      },
      %{
        map: "gefg_cas02",
        x: 167,
        y: 40,
        dir: 0,
        sprite: 111,
        name: "Dungeon Lever",
        unique_name: "Dungeon Lever#gefg_cas02"
      },
      %{
        map: "gefg_cas03",
        x: 221,
        y: 43,
        dir: 0,
        sprite: 111,
        name: "Dungeon Lever",
        unique_name: "Dungeon Lever#gefg_cas03"
      },
      %{
        map: "gefg_cas04",
        x: 58,
        y: 75,
        dir: 0,
        sprite: 111,
        name: "Dungeon Lever",
        unique_name: "Dungeon Lever#gefg_cas04"
      },
      %{
        map: "gefg_cas05",
        x: 65,
        y: 22,
        dir: 0,
        sprite: 111,
        name: "Dungeon Lever",
        unique_name: "Dungeon Lever#gefg_cas05"
      },
      %{
        map: "payg_cas01",
        x: 101,
        y: 25,
        dir: 0,
        sprite: 111,
        name: "Dungeon Lever",
        unique_name: "Dungeon Lever#payg_cas01"
      },
      %{
        map: "payg_cas02",
        x: 278,
        y: 247,
        dir: 0,
        sprite: 111,
        name: "Dungeon Lever",
        unique_name: "Dungeon Lever#payg_cas02"
      },
      %{
        map: "payg_cas03",
        x: 38,
        y: 42,
        dir: 0,
        sprite: 111,
        name: "Dungeon Lever",
        unique_name: "Dungeon Lever#payg_cas03"
      },
      %{
        map: "payg_cas04",
        x: 52,
        y: 48,
        dir: 0,
        sprite: 111,
        name: "Dungeon Lever",
        unique_name: "Dungeon Lever#payg_cas04"
      },
      %{
        map: "payg_cas05",
        x: 249,
        y: 15,
        dir: 0,
        sprite: 111,
        name: "Dungeon Lever",
        unique_name: "Dungeon Lever#payg_cas05"
      },
      %{
        map: "prtg_cas01",
        x: 94,
        y: 200,
        dir: 0,
        sprite: 111,
        name: "Dungeon Lever",
        unique_name: "Dungeon Lever#prtg_cas01"
      },
      %{
        map: "prtg_cas02",
        x: 84,
        y: 72,
        dir: 0,
        sprite: 111,
        name: "Dungeon Lever",
        unique_name: "Dungeon Lever#prtg_cas02"
      },
      %{
        map: "prtg_cas03",
        x: 5,
        y: 70,
        dir: 0,
        sprite: 111,
        name: "Dungeon Lever",
        unique_name: "Dungeon Lever#prtg_cas03"
      },
      %{
        map: "prtg_cas04",
        x: 56,
        y: 283,
        dir: 0,
        sprite: 111,
        name: "Dungeon Lever",
        unique_name: "Dungeon Lever#prtg_cas04"
      },
      %{
        map: "prtg_cas05",
        x: 212,
        y: 95,
        dir: 0,
        sprite: 111,
        name: "Dungeon Lever",
        unique_name: "Dungeon Lever#prtg_cas05"
      }
    ]

  alias Aesir.ZoneServer.Mmo.Woe.CastleDb

  @dungeons %{
    "aldeg_cas01" => {"gld_dun02", 32, 122},
    "aldeg_cas02" => {"gld_dun02", 79, 30},
    "aldeg_cas03" => {"gld_dun02", 165, 38},
    "aldeg_cas04" => {"gld_dun02", 160, 148},
    "aldeg_cas05" => {"gld_dun02", 103, 169},
    "gefg_cas01" => {"gld_dun04", 39, 258},
    "gefg_cas02" => {"gld_dun04", 125, 270},
    "gefg_cas03" => {"gld_dun04", 268, 251},
    "gefg_cas04" => {"gld_dun04", 268, 108},
    "gefg_cas05" => {"gld_dun04", 230, 35},
    "payg_cas01" => {"gld_dun01", 186, 165},
    "payg_cas02" => {"gld_dun01", 54, 165},
    "payg_cas03" => {"gld_dun01", 54, 39},
    "payg_cas04" => {"gld_dun01", 186, 39},
    "payg_cas05" => {"gld_dun01", 223, 202},
    "prtg_cas01" => {"gld_dun03", 28, 251},
    "prtg_cas02" => {"gld_dun03", 164, 268},
    "prtg_cas03" => {"gld_dun03", 164, 179},
    "prtg_cas04" => {"gld_dun03", 268, 203},
    "prtg_cas05" => {"gld_dun03", 199, 28}
  }

  @impl true
  def on_talk(ctx) do
    map = strnpcinfo(ctx, 2)

    with {:ok, destination} <- Map.fetch(@dungeons, map),
         {:ok, castle} <- CastleDb.by_map(map) do
      handle_castle(ctx, castle.id, destination)
    else
      :error -> close(ctx)
    end
  end

  defp handle_castle(ctx, castle_id, destination) do
    case castle_owner(ctx, castle_id) do
      nil -> refuse_unowned(ctx)
      owner -> prompt_pull(ctx, owner, destination)
    end
  end

  defp refuse_unowned(ctx) do
    ctx
    |> mes("[Ringing Voice]")
    |> mes(
      "'Those who overcome an ordeal shows a great deal of bravery... " <>
        "and will find their way to another ordeal.'"
    )
    |> close()
  end

  defp prompt_pull(ctx, owner, destination) do
    {ctx, choice} =
      ctx
      |> mes("[Ringing Voice]")
      |> mes("'Only the truly brave can take the test.'")
      |> next()
      |> mes(" ")
      |> mes("There's a small lever. Will you pull it?")
      |> next()
      |> select(["Pull.", "Don't pull."])

    handle_pull(ctx, choice, owner, destination)
  end

  defp handle_pull(ctx, 1, owner, {dungeon_map, x, y}) do
    if getcharid(ctx, 2) == owner do
      ctx |> close() |> warp(dungeon_map, x, y)
    else
      ctx |> mes(" ") |> mes("Nothing happened.") |> close()
    end
  end

  defp handle_pull(ctx, _decline, _owner, _destination), do: close(ctx)
end
