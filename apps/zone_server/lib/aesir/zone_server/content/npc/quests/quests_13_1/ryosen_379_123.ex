defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Ryosen379123 do
  @moduledoc """
  The Ryosen of the three-kingdom talks, hidden in the camp's main building until the
  talks need them.

  ## Behavior

  - Says nothing when talked to: the reference body ends the script immediately.
  - Hides itself on boot, and starts its timer and reveals itself when enabled.
  - On disable stops the timer and hides itself, because the reference's `OnDisable` body runs
    off its end into the `OnInit` label that follows it.
  - Five minutes later disables itself, which stops the timer and hides it again.

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
        map: "mid_campin",
        x: 379,
        y: 123,
        dir: 5,
        sprite: 748,
        name: "Ryosen",
        scope: :shared,
        unique_name: "Ryosen#ep131_rhea05"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @npc "Ryosen#ep131_rhea05"

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx), do: ctx |> initnpctimer() |> enablenpc(@npc)
  def on_event("OnDisable", ctx), do: ctx |> stopnpctimer() |> disablenpc(@npc)
  def on_event("OnInit", ctx), do: disablenpc(ctx, @npc)
  def on_event("OnTimer300000", ctx), do: donpcevent(ctx, "Ryosen#ep131_rhea05::OnDisable")
end
