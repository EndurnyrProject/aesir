defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Room1timer do
  @moduledoc """
  The invisible timer of the Morocc job quest's Master Zone Area 1, which opens and closes
  the area's security gate.

  ## Behavior

  - On enable and on a click announces the entry into Master Zone Area 1 and starts the timer.
  - At four minutes enables the area gate, at 4:05 disables it together with Valdes and resets
    Marjana, and at 4:10 announces the activated security magic and resets the room.
  - On stop announces the deactivation, disables the gate and Valdes, resets Marjana and the
    room, and stops the timer.

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
        x: 1,
        y: 1,
        dir: 0,
        sprite: 844,
        name: " ",
        scope: :shared,
        unique_name: " #room1timer"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @map "que_job01"

  @enter_message "You will now enter the Master Zone, Area 1."
  @deactivated_message "The security magic in the Master Zone, Area 1 is deactivated."
  @activated_message "The security magic Master Zone, Area 1 is now activated."

  @warp_gate "#room1_warp13"
  @valdes "Valdes#moc_master_1"
  @marjana "Marjana#poison"
  @room "que_job01#room_1"

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: announce_entry(ctx)

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx), do: announce_entry(ctx)

  def on_event("OnStop", ctx) do
    ctx
    |> mapannounce(@map, @deactivated_message, 1, "0x70DBDB")
    |> donpcevent("#{@warp_gate}::OnDisable")
    |> donpcevent("#{@valdes}::OnDisable")
    |> donpcevent("#{@marjana}::OnInit")
    |> donpcevent("#{@room}::OnReset")
    |> stopnpctimer()
  end

  def on_event("OnTimer240000", ctx), do: donpcevent(ctx, "#{@warp_gate}::OnEnable")

  def on_event("OnTimer245000", ctx) do
    ctx
    |> donpcevent("#{@warp_gate}::OnDisable")
    |> donpcevent("#{@valdes}::OnDisable")
    |> donpcevent("#{@marjana}::OnInit")
  end

  def on_event("OnTimer250000", ctx) do
    ctx
    |> mapannounce(@map, @activated_message, 1, "0x70DBDB")
    |> donpcevent("#{@room}::OnReset")
    |> stopnpctimer()
  end

  defp announce_entry(ctx) do
    ctx
    |> initnpctimer()
    |> mapannounce(@map, @enter_message, 1, "0x70DBDB")
  end
end
