defmodule Aesir.ZoneServer.Content.Npc.Floating.Jobs.M21.Priest.ZC do
  @moduledoc """
  Kill counter of the zombie generator used by the final Priest job change test.

  ## Behavior

  - Every summoned zombie reports its own death here, which decrements the
    `MyMobs` counter kept by the `Zombie_Generator#prst` controller.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Pgro Team (OwNaGe) (Aegis)
    - kobra_k88
    - Lupus
    - Vicious
    - KarLaeda
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script jobs/2-1/priest.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: [%{name: "Z_C", unique_name: "Z_C#prst"}]

  @generator "Zombie_Generator#prst"

  @impl true
  def on_event("OnMyMobDead", ctx) do
    remaining = get_npc_var_of(ctx, "MyMobs", @generator, 0) - 1
    set_npc_var_of(ctx, "MyMobs", @generator, remaining)
  end

  @impl true
  def on_talk(ctx), do: ctx
end
