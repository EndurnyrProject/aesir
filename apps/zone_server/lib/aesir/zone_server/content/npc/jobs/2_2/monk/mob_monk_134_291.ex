defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Monk.MobMonk134291 do
  @moduledoc """
  Spawns undead in the Monk spirit maze when a candidate steps on this spot.

  ## Behavior

  - Summons four Zombies when touched.
  - Removes every monster from the test map when disabled.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Dino9021
    - Celest
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Lupus
    - Yor
    - Zephiris
    - Vicious
    - Silent

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    ctx
    |> summon_mob(mob_id: 1015, map: "monk_test", at: {134, 291})
    |> summon_mob(mob_id: 1015, map: "monk_test", at: {134, 291})
    |> summon_mob(mob_id: 1015, map: "monk_test", at: {134, 291})
    |> summon_mob(mob_id: 1015, map: "monk_test", at: {134, 291})
  end

  def on_event("OnDisable", ctx), do: killmonsterall(ctx, "monk_test")

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
