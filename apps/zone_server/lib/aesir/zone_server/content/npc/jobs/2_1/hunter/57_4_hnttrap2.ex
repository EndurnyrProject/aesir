defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Hunter.M574Hnttrap2 do
  @moduledoc """
  Hunter test trap that sends a careless examinee back to the starting point.

  ## Behavior

  - Broadcasts that the examinee has failed.
  - Resets the examinee's test progress and returns them to the waiting area.
  - Resets the test arena and reopens the waiting room.

  ## Credits

  - Original from rAthena, authors and Contributors
    - EREMES THE CANIVALIZER
    - yoshiki
    - kobra_k88
    - Lupus
    - celest
    - Poki#3
    - Vicious
    - Silent
    - FlavioJS
    - Samuray22
    - L0ne_W0lf
    - Kisuka
    - Vali

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
    |> mapannounce(
      "job_hunte",
      "#{char_name(ctx, 0)}, has failed me! Go back to where you started!",
      1
    )
    |> set_char_var(:HNTR_Q, 13)
    |> warp("job_hunte", 176, 22)
    |> donpcevent("Manager#hnt::OnReset")
    |> donpcevent("Waiting Room#hnt::OnStart")
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
