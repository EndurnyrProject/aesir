defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Room2timer do
  @moduledoc """
  The invisible timer of the Morocc job quest's Master Zone 2, which opens and closes the
  area's security gates.

  ## Behavior

  - On enable and on a click announces the surveillance of Master Zone 2 and starts the timer.
  - At four minutes enables both area gates, at 4:05 disables them together with Rin and
    Rayan, and at 4:10 announces the release and resets the room.
  - On stop announces the shield reset, disables both gates, Rin and Rayan, resets the room
    and stops the timer.

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
        y: 2,
        dir: 0,
        sprite: 844,
        name: " ",
        scope: :shared,
        unique_name: " #room2timer"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @map "que_job01"

  @enter_message "Master Zone 2 is now under surveillance."
  @reset_message "The magic shield of Master Zone 2 has been reset."
  @released_message "Master Zone 2 has been released from surveillance."

  @first_warp "#room2_1_warp"
  @second_warp "#room2_2_warp"
  @rin "Rin#moc_room2_2"
  @rayan "Rayan#moc_room2_2"
  @room "que_job01#room_2"

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: announce_entry(ctx)

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx), do: announce_entry(ctx)

  def on_event("OnStop", ctx) do
    ctx
    |> mapannounce(@map, @reset_message, 1, "0x70DBDB")
    |> donpcevent("#{@first_warp}::OnDisable")
    |> donpcevent("#{@second_warp}::OnDisable")
    |> donpcevent("#{@rin}::OnDisable")
    |> donpcevent("#{@rayan}::OnDisable")
    |> donpcevent("#{@room}::OnReset")
    |> stopnpctimer()
  end

  def on_event("OnTimer240000", ctx) do
    ctx
    |> donpcevent("#{@first_warp}::OnEnable")
    |> donpcevent("#{@second_warp}::OnEnable")
  end

  def on_event("OnTimer245000", ctx) do
    ctx
    |> donpcevent("#{@first_warp}::OnDisable")
    |> donpcevent("#{@second_warp}::OnDisable")
    |> donpcevent("#{@rin}::OnDisable")
    |> donpcevent("#{@rayan}::OnDisable")
  end

  def on_event("OnTimer250000", ctx) do
    ctx
    |> mapannounce(@map, @released_message, 1, "0x70DBDB")
    |> donpcevent("#{@room}::OnReset")
    |> stopnpctimer()
  end

  defp announce_entry(ctx) do
    ctx
    |> initnpctimer()
    |> mapannounce(@map, @enter_message, 1, "0x70DBDB")
  end
end
