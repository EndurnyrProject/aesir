defmodule Aesir.ZoneServer.Content.Npc.PreRe.Warps.Fields.VeinsFild.VeFild62 do
  @moduledoc """
  Hidden canyon passage on the Veins fields that drops travelers into one of two field maps.

  ## Credits

  - Original from rAthena, authors and Contributors
    - $ephiroth
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script pre-re/warps/fields/veins_fild.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "ve_fild06",
        x: 81,
        y: 177,
        dir: 0,
        sprite: 45,
        name: "ve_fild6-2",
        scope: :pre_renewal,
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case :rand.uniform(2) - 1 do
      0 -> warp(ctx, "ve_fild05", 354, 191)
      1 -> warp(ctx, "ve_fild04", 115, 55)
    end
  end
end
