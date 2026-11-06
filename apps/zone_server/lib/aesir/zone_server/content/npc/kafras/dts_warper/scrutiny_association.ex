defmodule Aesir.ZoneServer.Content.Npc.Kafras.DtsWarper.ScrutinyAssociation do
  @moduledoc """
  Invisible election scrutineer in Juno that re-announces the Dungeon Teleport Service election
  every two hours.

  ## Behavior

  - Restarts its own two-hour timer on init and whenever it is enabled.
  - Announces the election while no winner is decided (`DTS_Result` 0) or while the last election
    ended without enough voters (`DTS_Result` 3).

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - Silent
    - Lupus
    - L0ne_W0lf
    - Euphy
    - Liam

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script kafras/dts_warper.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 103,
        y: 225,
        dir: 0,
        sprite: -1,
        name: "Scrutiny Association",
        scope: :shared,
        unique_name: "Scrutiny Association#5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @notice "Currently, the Dungeon Teleport Service Provider Election is being held in all major cities. Your participation is appreciated."
  @color "0x70dbdb"
  @election_timer "Scrutiny Association#5::OnEnable"

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: initnpctimer(ctx)
  def on_event("OnEnable", ctx), do: initnpctimer(ctx)
  def on_event("OnTimer7200000", ctx), do: announce_election(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: initnpctimer(ctx)

  defp announce_election(ctx) do
    ctx = stopnpctimer(ctx)

    ctx =
      if get_server_var(ctx, "DTS_Result", 0) in [0, 3] do
        announce(ctx, @notice, 0, @color)
      else
        ctx
      end

    donpcevent(ctx, @election_timer)
  end
end
