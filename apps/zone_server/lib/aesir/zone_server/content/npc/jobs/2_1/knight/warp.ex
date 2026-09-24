defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Knight.Warp do
  @moduledoc """
  Exit portal of the Knight patience test arena.

  ## Behavior

  - Starts hidden; the arena timer reveals it once the patience test time runs out.
  - Touching it marks the patience test as passed, advances the quest log, and
    returns the candidate to the Prontera Chivalry.

  ## Credits

  - Original from rAthena, authors and Contributors
    - PGRO TEAM (Aegis)
    - kobra_k88
    - Lupus
    - Vicious
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Vali
    - Euphy
    - Joseph

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_knt",
        x: 143,
        y: 57,
        dir: 1,
        sprite: 107,
        name: "Warp",
        scope: :shared,
        unique_name: "Warp#knt",
        trigger: {22, 22}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Warp#knt")

  def on_event("OnTouch", ctx) do
    ctx
    |> set_char_var(:KNIGHT_Q, 12)
    |> changequest(9010, 9011)
    |> warp("prt_in", 80, 100)
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
