defmodule Aesir.ZoneServer.Content.Npc.Floating.DancestepSteptrigger do
  @moduledoc """
  Dance floor triggers that fail a Dancer applicant who steps out of rhythm.

  ## Behavior

  - Each of the five cells around the dance floor is a touch trigger. Stepping
    on one interrupts the backdancers' performance, announces the failure to the
    whole map, sets `DANC_Q` to 8, stops the dance timer, reopens the waiting
    room and sends the player back to Comodo.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kalen (original jAthena)
    - Fredzilla
    - Lupus
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script jobs/2-2/dancer.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_duncer",
        x: 69,
        y: 113,
        dir: 0,
        sprite: -1,
        name: "dance",
        scope: :shared,
        unique_name: "dance#up",
        trigger: {1, 1}
      },
      %{
        map: "job_duncer",
        x: 69,
        y: 107,
        dir: 0,
        sprite: -1,
        name: "dance",
        scope: :shared,
        unique_name: "dance#down",
        trigger: {1, 1}
      },
      %{
        map: "job_duncer",
        x: 66,
        y: 110,
        dir: 0,
        sprite: -1,
        name: "dance",
        scope: :shared,
        unique_name: "dance#left",
        trigger: {1, 1}
      },
      %{
        map: "job_duncer",
        x: 72,
        y: 110,
        dir: 0,
        sprite: -1,
        name: "dance",
        scope: :shared,
        unique_name: "dance#right",
        trigger: {1, 1}
      },
      %{
        map: "job_duncer",
        x: 69,
        y: 110,
        dir: 0,
        sprite: -1,
        name: "dance",
        scope: :shared,
        unique_name: "dance#cen",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @floor "job_duncer"
  # rAthena `bc_map` announcement flag.
  @bc_map 1

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx), do: miss_step(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: miss_step(ctx)

  defp miss_step(ctx) do
    ctx
    |> donpcevent("Backdancer#1::OnOmg")
    |> mapannounce(
      @floor,
      Rathena.concat(
        Rathena.concat(" ", char_name(ctx, 0)),
        ", you lack rhythm... Your timing was too late!"
      ),
      @bc_map
    )
    |> set_char_var(:DANC_Q, 8)
    |> donpcevent("Bijou#dance_timer::OnDisable")
    |> donpcevent("Waiting Room#dance::OnEnable")
    |> warp("comodo", 188, 162)
  end
end
