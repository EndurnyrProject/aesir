defmodule Aesir.ZoneServer.Content.Npc.Floating.Jobs.M21.Assassin.MocAssinDup do
  @moduledoc """
  Hidden audience of the Assassin guild's written exam room.

  The bodies are cosmetic seating behind the exam hall: every placement starts
  disabled and none of them ever answers a click. The module is the shared body
  behind `[Huey]`, `[Khai]`, `[The Anonymous One]`, `[Barcardi]`,
  `[Beholder]`, `[Thomas]` and `[Gayle Maroubitz]`.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Pgro Team (OwNaGe)
    - kobra_k88
    - Lupus
    - Vicious
    - Silent
    - Toms
    - L0ne_W0lf
    - Samuray22
    - Zephyrus_cr
    - Zephyrus
    - brianluau
    - Kisuka
    - JayPee
    - Euphy
    - MrAntares
    - Atemo

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script jobs/2-1/assassin.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "in_moc_16", x: 156, y: 87, dir: 1, sprite: 55, name: "[Huey]", scope: :shared},
      %{map: "in_moc_16", x: 156, y: 85, dir: 1, sprite: 730, name: "[Khai]", scope: :shared},
      %{
        map: "in_moc_16",
        x: 156,
        y: 83,
        dir: 1,
        sprite: 106,
        name: "[The Anonymous One]",
        scope: :shared
      },
      %{map: "in_moc_16", x: 156, y: 81, dir: 2, sprite: 725, name: "[Barcardi]", scope: :shared},
      %{map: "in_moc_16", x: 156, y: 79, dir: 1, sprite: 118, name: "[Beholder]", scope: :shared},
      %{map: "in_moc_16", x: 156, y: 77, dir: 1, sprite: 118, name: "[Thomas]", scope: :shared},
      %{
        map: "in_moc_16",
        x: 156,
        y: 75,
        dir: 1,
        sprite: 55,
        name: "[Gayle Maroubitz]",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
