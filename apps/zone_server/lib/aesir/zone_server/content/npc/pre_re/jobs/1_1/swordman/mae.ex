defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Swordman.Mae do
  @moduledoc """
  Congratulates applicants who pass the swordman test.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script pre-re/jobs/1-1/swordman.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "job_sword1",
        x: 223,
        y: 167,
        dir: 2,
        sprite: 92,
        name: "Mae",
        scope: :pre_renewal,
        unique_name: "Mae#swd_1_success"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mapannounce(
      "job_sword1",
      Rathena.concat(
        Rathena.concat("Applicant ", char_name(ctx, 0)),
        ". You successfully passed the test."
      ),
      1
    )
    |> set_char_var(:job_sword_q, 4)
    |> mes("[Mae]")
    |> mes("I sencerely congratulate you for passing the test!")
    |> mes(
      "I already sent your test result to the Job Department. Please inquire at the Officer in Centre.Thank you."
    )
    |> close()
    |> warp("izlude_in", 66, 173)
  end
end
