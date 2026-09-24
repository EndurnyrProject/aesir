defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Priest.PeterSAlberto23187 do
  @moduledoc """
  Father Peter's stand-in while an Acolyte is inside the Priest spiritual training.

  ## Behavior

  - Starts disabled and is toggled by the training hall events.
  - Asks Priests and waiting Acolytes to come back once the current Acolyte finishes.
  - Sends anyone else back to Prontera.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Pgro Team (OwNaGe)
    - kobra_k88
    - Lupus
    - Vicious
    - KarLaeda
    - L0ne_W0lf
    - Samuray22
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_prist",
        x: 23,
        y: 187,
        dir: 1,
        sprite: 110,
        name: "Peter S. Alberto",
        scope: :shared,
        unique_name: "Peter S. Alberto#2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Peter S. Alberto#2")
  def on_event("OnEnable", ctx), do: enablenpc(ctx, "Peter S. Alberto#2")
  def on_event("OnDisable", ctx), do: disablenpc(ctx, "Peter S. Alberto#2")

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Father Peter]")
    quest = get_char_var(ctx, :PRIEST_Q, 0)

    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:priest) ->
        ask_priest_to_wait(ctx)

      quest == 5 or quest == 6 ->
        ctx
        |> mes("Please hold on for a while. Another acolyte is in the training ground right now.")
        |> next()
        |> mes("[Father Peter]")
        |> mes("If you want to take the test, please wait a while and talk to me again.")
        |> close()

      true ->
        ctx |> mes("Peace...") |> mes("Be with you.") |> close() |> warp("prontera", 234, 318)
    end
  end

  defp ask_priest_to_wait(ctx) do
    ctx
    |> mes("Welcome!")
    |> mes("#{sibling_title(ctx)} #{char_name(ctx, 0)}!")
    |> mes("So good to see you!")
    |> next()
    |> mes("[Father Peter]")
    |> mes(
      "Are you here to help an Acolyte friend for the spiritual training? That's great~ I think you'll do a good job."
    )
    |> next()
    |> mes("[Father Peter]")
    |> mes(
      "Well, another Acolyte is in the training ground right now. You'll need to wait a little bit longer..."
    )
    |> next()
    |> mes("[Father Peter]")
    |> mes(
      "Please come back a little later. If this acolyte's done with the training, I will send you to the training area."
    )
    |> close()
  end

  defp sibling_title(ctx) do
    if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0), do: "Brother", else: "Sister"
  end
end
