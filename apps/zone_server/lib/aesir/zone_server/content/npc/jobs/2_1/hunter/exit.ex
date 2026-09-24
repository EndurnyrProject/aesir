defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Hunter.Exit do
  @moduledoc """
  Escape portal of the Hunter test arena that completes the trial.

  ## Behavior

  - Stays hidden until the examinee activates the escape switch.
  - On touch, resets the arena, reopens the waiting room, and marks the trial as passed.
  - Saves the examinee in Payon and sends them to one of two Payon buildings at random.

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

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_hunte",
        x: 89,
        y: 139,
        dir: 0,
        sprite: 45,
        name: "exit",
        scope: :shared,
        unique_name: "exit#hnttest",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "exit#hnttest")

  def on_event("OnTouch", ctx) do
    ctx =
      ctx
      |> donpcevent("Manager#hnt::OnReset")
      |> donpcevent("Waiting Room#hnt::OnStart")
      |> set_char_var(:HNTR_Q, 16)
      |> changequest(4011, 4012)
      |> savepoint("payon", 104, 99)

    if :rand.uniform(2) == 2 do
      warp(ctx, "payon_in02", 21, 27)
    else
      warp(ctx, "payon_in03", 128, 7)
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
