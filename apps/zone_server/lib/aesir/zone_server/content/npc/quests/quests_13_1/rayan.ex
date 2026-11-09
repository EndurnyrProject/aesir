defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Rayan do
  @moduledoc """
  Rayan, shivering in the hideout's inner room while Rin explains what is wrong with him.

  ## Behavior

  - Shows Rin's portrait while she explains Rayan's state, and restores her normal portrait
    after closing the dialog.
  - Hides itself on boot and when disabled, and reveals itself when enabled.

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
        map: "que_job01",
        x: 143,
        y: 50,
        dir: 1,
        sprite: 456,
        name: "Rayan",
        scope: :shared,
        unique_name: "Rayan#moc_room2_2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @npc "Rayan#moc_room2_2"

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("- For some reason, Rayan is shivering in fear. -")
    |> next()
    |> cutin("moc2_rin02", 2)
    |> mes("[Rin]")
    |> mes("He's not being himself for some reason.")
    |> mes("I'm just glad that he's sane enough to speak to me.")
    |> mes("I don't know what's going on with him.")
    |> close()
    |> cutin("moc2_rin01", 255)
  end

  # The reference's `OnInit` label is empty, so booting falls through into `OnDisable`.
  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, @npc)
  def on_event("OnDisable", ctx), do: disablenpc(ctx, @npc)
  def on_event("OnEnable", ctx), do: enablenpc(ctx, @npc)
end
