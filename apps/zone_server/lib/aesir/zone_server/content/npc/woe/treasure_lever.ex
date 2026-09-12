defmodule Aesir.ZoneServer.Content.Npc.Woe.TreasureLever do
  @moduledoc """
  Castle treasure-room exit lever: one placement per FE castle map. Pulling
  it warps the puller back to the map's entrance near the steward; declining
  closes without effect.

  The lever's own castle map is read from the hidden fragment of its
  `unique_name` (`strnpcinfo(ctx, 2)`), not the player's current position,
  so one `on_talk/1` serves every placement.
  """

  use Aesir.ZoneServer.Npc,
    spawn: [
      %{
        map: "aldeg_cas01",
        x: 123,
        y: 223,
        dir: 0,
        sprite: 111,
        name: "Lever",
        unique_name: "Lever#aldeg_cas01"
      },
      %{
        map: "aldeg_cas02",
        x: 139,
        y: 234,
        dir: 0,
        sprite: 111,
        name: "Lever",
        unique_name: "Lever#aldeg_cas02"
      },
      %{
        map: "aldeg_cas03",
        x: 229,
        y: 267,
        dir: 0,
        sprite: 111,
        name: "Lever",
        unique_name: "Lever#aldeg_cas03"
      },
      %{
        map: "aldeg_cas04",
        x: 83,
        y: 17,
        dir: 0,
        sprite: 111,
        name: "Lever",
        unique_name: "Lever#aldeg_cas04"
      },
      %{
        map: "aldeg_cas05",
        x: 64,
        y: 8,
        dir: 0,
        sprite: 111,
        name: "Lever",
        unique_name: "Lever#aldeg_cas05"
      },
      %{
        map: "gefg_cas01",
        x: 152,
        y: 117,
        dir: 0,
        sprite: 111,
        name: "Lever",
        unique_name: "Lever#gefg_cas01"
      },
      %{
        map: "gefg_cas02",
        x: 145,
        y: 114,
        dir: 0,
        sprite: 111,
        name: "Lever",
        unique_name: "Lever#gefg_cas02"
      },
      %{
        map: "gefg_cas03",
        x: 275,
        y: 289,
        dir: 0,
        sprite: 111,
        name: "Lever",
        unique_name: "Lever#gefg_cas03"
      },
      %{
        map: "gefg_cas04",
        x: 116,
        y: 123,
        dir: 0,
        sprite: 111,
        name: "Lever",
        unique_name: "Lever#gefg_cas04"
      },
      %{
        map: "gefg_cas05",
        x: 149,
        y: 107,
        dir: 0,
        sprite: 111,
        name: "Lever",
        unique_name: "Lever#gefg_cas05"
      },
      %{
        map: "payg_cas01",
        x: 295,
        y: 8,
        dir: 0,
        sprite: 111,
        name: "Lever",
        unique_name: "Lever#payg_cas01"
      },
      %{
        map: "payg_cas02",
        x: 149,
        y: 149,
        dir: 0,
        sprite: 111,
        name: "Lever",
        unique_name: "Lever#payg_cas02"
      },
      %{
        map: "payg_cas03",
        x: 163,
        y: 167,
        dir: 0,
        sprite: 111,
        name: "Lever",
        unique_name: "Lever#payg_cas03"
      },
      %{
        map: "payg_cas04",
        x: 151,
        y: 47,
        dir: 0,
        sprite: 111,
        name: "Lever",
        unique_name: "Lever#payg_cas04"
      },
      %{
        map: "payg_cas05",
        x: 161,
        y: 136,
        dir: 0,
        sprite: 111,
        name: "Lever",
        unique_name: "Lever#payg_cas05"
      },
      %{
        map: "prtg_cas01",
        x: 15,
        y: 208,
        dir: 0,
        sprite: 111,
        name: "Lever",
        unique_name: "Lever#prtg_cas01"
      },
      %{
        map: "prtg_cas02",
        x: 207,
        y: 228,
        dir: 0,
        sprite: 111,
        name: "Lever",
        unique_name: "Lever#prtg_cas02"
      },
      %{
        map: "prtg_cas03",
        x: 193,
        y: 130,
        dir: 0,
        sprite: 111,
        name: "Lever",
        unique_name: "Lever#prtg_cas03"
      },
      %{
        map: "prtg_cas04",
        x: 275,
        y: 160,
        dir: 0,
        sprite: 111,
        name: "Lever",
        unique_name: "Lever#prtg_cas04"
      },
      %{
        map: "prtg_cas05",
        x: 281,
        y: 176,
        dir: 0,
        sprite: 111,
        name: "Lever",
        unique_name: "Lever#prtg_cas05"
      }
    ]

  @exits %{
    "aldeg_cas01" => {218, 176},
    "aldeg_cas02" => {78, 75},
    "aldeg_cas03" => {110, 119},
    "aldeg_cas04" => {67, 117},
    "aldeg_cas05" => {51, 179},
    "gefg_cas01" => {40, 49},
    "gefg_cas02" => {12, 67},
    "gefg_cas03" => {106, 24},
    "gefg_cas04" => {73, 47},
    "gefg_cas05" => {70, 53},
    "payg_cas01" => {120, 59},
    "payg_cas02" => {22, 261},
    "payg_cas03" => {50, 261},
    "payg_cas04" => {38, 285},
    "payg_cas05" => {277, 250},
    "prtg_cas01" => {112, 183},
    "prtg_cas02" => {94, 62},
    "prtg_cas03" => {51, 101},
    "prtg_cas04" => {259, 265},
    "prtg_cas05" => {36, 38}
  }

  @impl true
  def on_talk(ctx) do
    map = strnpcinfo(ctx, 2)

    case Map.fetch(@exits, map) do
      {:ok, {x, y}} -> prompt_pull(ctx, map, x, y)
      :error -> close(ctx)
    end
  end

  defp prompt_pull(ctx, map, x, y) do
    {ctx, choice} =
      ctx
      |> mes(" ")
      |> mes("There's a small lever. Will you pull it?")
      |> next()
      |> select(["Pull.", "Do not."])

    handle_pull(ctx, choice, map, x, y)
  end

  defp handle_pull(ctx, 1, map, x, y), do: ctx |> close() |> warp(map, x, y)
  defp handle_pull(ctx, _decline, _map, _x, _y), do: close(ctx)
end
