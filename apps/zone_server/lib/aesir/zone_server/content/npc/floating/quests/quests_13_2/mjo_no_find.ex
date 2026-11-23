defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Quests132.MjoNoFind do
  @moduledoc """
  Offers a mineral detector check at empty locations.

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
      %{
        map: "mjolnir_03",
        x: 76,
        y: 258,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj03_find_1",
        trigger: {5, 5}
      },
      %{
        map: "mjolnir_03",
        x: 227,
        y: 204,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj03_find_2",
        trigger: {5, 5}
      },
      %{
        map: "mjolnir_05",
        x: 82,
        y: 171,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj05_find_1",
        trigger: {5, 5}
      },
      %{
        map: "mjolnir_05",
        x: 219,
        y: 375,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj05_find_2",
        trigger: {5, 5}
      },
      %{
        map: "mjolnir_06",
        x: 28,
        y: 332,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj06_find_1",
        trigger: {5, 5}
      },
      %{
        map: "mjolnir_06",
        x: 275,
        y: 50,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj06_find_2",
        trigger: {5, 5}
      },
      %{
        map: "mjolnir_06",
        x: 371,
        y: 78,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj06_find_3",
        trigger: {5, 5}
      },
      %{
        map: "mjolnir_07",
        x: 26,
        y: 373,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj07_find_1",
        trigger: {5, 5}
      },
      %{
        map: "mjolnir_07",
        x: 214,
        y: 373,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj07_find_2",
        trigger: {5, 5}
      },
      %{
        map: "mjolnir_07",
        x: 372,
        y: 355,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj07_find_3",
        trigger: {5, 5}
      },
      %{
        map: "mjolnir_07",
        x: 375,
        y: 233,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj07_find_4",
        trigger: {5, 5}
      },
      %{
        map: "mjolnir_07",
        x: 26,
        y: 78,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj07_find_5",
        trigger: {5, 5}
      },
      %{
        map: "mjolnir_07",
        x: 157,
        y: 25,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj07_find_6",
        trigger: {5, 5}
      },
      %{
        map: "mjolnir_08",
        x: 39,
        y: 239,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj08_find_1",
        trigger: {5, 5}
      },
      %{
        map: "mjolnir_08",
        x: 36,
        y: 344,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj08_find_2",
        trigger: {5, 5}
      },
      %{
        map: "mjolnir_08",
        x: 160,
        y: 349,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj08_find_3",
        trigger: {5, 5}
      },
      %{
        map: "mjolnir_08",
        x: 359,
        y: 258,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj08_find_4",
        trigger: {5, 5}
      },
      %{
        map: "mjolnir_08",
        x: 193,
        y: 62,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj08_find_5",
        trigger: {5, 5}
      },
      %{
        map: "mjolnir_11",
        x: 29,
        y: 220,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj11_find_1",
        trigger: {5, 5}
      },
      %{
        map: "mjolnir_11",
        x: 175,
        y: 29,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj11_find_2",
        trigger: {5, 5}
      },
      %{
        map: "mjolnir_12",
        x: 199,
        y: 370,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj12_find_1",
        trigger: {5, 5}
      },
      %{
        map: "mjolnir_12",
        x: 44,
        y: 25,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj12_find_2",
        trigger: {5, 5}
      },
      %{
        map: "mjolnir_12",
        x: 220,
        y: 37,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj12_find_3",
        trigger: {5, 5}
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.Find132

  @impl true
  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx), do: ctx

  def ev_ontouch(ctx) do
    {ctx, _} = Find132.call(ctx, [0, 0])
    ctx
  end
end
