defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Hunter.Switch do
  @moduledoc """
  Escape switch in the Hunter test arena.

  ## Behavior

  - Appears once the examinee has hunted enough target monsters.
  - Lets the examinee activate the escape portal, cancel, or return to the waiting room to retake the test.
  - Hides itself and the escape portal when the arena resets.

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
        x: 93,
        y: 101,
        dir: 1,
        sprite: 723,
        name: "Switch",
        scope: :shared,
        unique_name: "Switch#hnt",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThere are 3 buttons")
      |> mes("on the escape switch.^000000")
      |> set_char_var(:HNTR_Q, 15)
      |> next()
      |> select(["Escape", "Cancel", "Re-test"])

    press_button(ctx, choice)
  end

  def on_event("OnDisable", ctx) do
    ctx
    |> disablenpc("exit#hnttest")
    |> disablenpc("Switch#hnt")
  end

  def on_event("OnEnable", ctx), do: enablenpc(ctx, "Switch#hnt")

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp press_button(ctx, 1) do
    ctx
    |> mes("^3355FFThe Escape Warp Portal")
    |> mes("has now been activated.^000000")
    |> close()
    |> mapannounce("job_hunte", " !! Escape Warp Portal activation complete. !! ", 1)
    |> enablenpc("exit#hnttest")
  end

  defp press_button(ctx, 2) do
    ctx
    |> mes("^3355FFCanceling")
    |> mes("Operation.^000000")
    |> close()
    |> mapannounce("job_hunte", " !! Operation has been cancelled. !! ", 1)
  end

  defp press_button(ctx, 3) do
    ctx
    |> mapannounce("job_hunte", " !! Cancellation warp activating... !! ", 1)
    |> mes("^3355FFYou will soon be")
    |> mes("returned to the")
    |> mes("waiting room.^000000")
    |> close()
    |> set_char_var(:HNTR_Q, 13)
    |> warp("job_hunte", 176, 22)
    |> donpcevent("Manager#hnt::OnReset")
    |> donpcevent("Waiting Room#hnt::OnStart")
  end

  defp press_button(ctx, _choice), do: ctx
end
