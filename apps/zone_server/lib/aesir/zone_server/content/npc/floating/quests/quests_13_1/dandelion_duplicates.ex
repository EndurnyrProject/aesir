defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Quests131.DandelionDuplicates do
  @moduledoc """
  The Dandelion gang members holed up in the hideout below Morocc, all sharing one hidden
  placeholder body.

  ## Behavior

  - Says nothing when talked to: the reference body ends the script immediately.
  - Hides every one of its placements on boot and when disabled, and reveals them when
    enabled.

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
        map: "que_dan01",
        x: 34,
        y: 34,
        dir: 7,
        sprite: 885,
        name: "Rin",
        scope: :shared,
        unique_name: "Rin#moc2_bt_rin01"
      },
      %{
        map: "que_dan01",
        x: 29,
        y: 34,
        dir: 7,
        sprite: 885,
        name: "Rin",
        scope: :shared,
        unique_name: "Rin#moc2_bt_rin02"
      },
      %{
        map: "que_dan01",
        x: 36,
        y: 34,
        dir: 3,
        sprite: 456,
        name: "Rayan",
        scope: :shared,
        unique_name: "Rayan#moc2_bt_r01"
      },
      %{
        map: "que_dan01",
        x: 39,
        y: 37,
        dir: 3,
        sprite: 456,
        name: "Dandelion Member",
        scope: :shared,
        unique_name: "Dandelion Member#moc2_1"
      },
      %{
        map: "que_dan01",
        x: 41,
        y: 34,
        dir: 3,
        sprite: 456,
        name: "Dandelion Member",
        scope: :shared,
        unique_name: "Dandelion Member#moc2_2"
      },
      %{
        map: "que_dan01",
        x: 26,
        y: 40,
        dir: 5,
        sprite: 456,
        name: "Dandelion Member",
        scope: :shared,
        unique_name: "Dandelion Member#moc2_3"
      },
      %{
        map: "que_dan01",
        x: 21,
        y: 35,
        dir: 5,
        sprite: 456,
        name: "Dandelion Member",
        scope: :shared,
        unique_name: "Dandelion Member#moc2_4"
      },
      %{
        map: "que_dan01",
        x: 25,
        y: 32,
        dir: 7,
        sprite: 456,
        name: "Dandelion Member",
        scope: :shared,
        unique_name: "Dandelion Member#moc2_5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx)
  def on_event("OnDisable", ctx), do: disablenpc(ctx)
  def on_event("OnEnable", ctx), do: enablenpc(ctx)
end
