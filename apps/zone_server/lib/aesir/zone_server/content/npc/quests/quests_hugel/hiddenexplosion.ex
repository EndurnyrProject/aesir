defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Hiddenexplosion do
  @moduledoc """
  Damages a player caught in the machine explosion.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_dun02",
        x: 244,
        y: 227,
        dir: 0,
        sprite: 139,
        name: "HiddenExplosion",
        scope: :shared,
        trigger: {5, 5}
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: disable_explosion(ctx)
  def on_event("OnTouch", ctx), do: explode(ctx)
  @impl true
  def on_talk(ctx) do
    disable_explosion(ctx)
  end

  defp disable_explosion(ctx) do
    disablenpc(ctx, "HiddenExplosion")
  end

  defp explode(ctx) do
    ctx |> percent_heal(hp: -10, sp: 0) |> specialeffect(:hit5) |> disablenpc("HiddenExplosion")
  end
end
