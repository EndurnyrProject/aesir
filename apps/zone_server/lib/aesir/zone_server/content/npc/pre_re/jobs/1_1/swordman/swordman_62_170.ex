defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Swordman.Swordman62170 do
  @moduledoc """
  Controls entry to the swordman test hall.

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
        map: "izlude_in",
        x: 62,
        y: 170,
        dir: 6,
        sprite: 85,
        name: "Swordman",
        scope: :pre_renewal,
        unique_name: "Swordman#swd_2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Swordman]")

    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:swordman) ->
        ctx |> mes("Sorry guy, but I can only allow Novices to enter the Test Hall.") |> close()

      Rathena.job_id(base_job(ctx)) != Rathena.job_id(:novice) ->
        ctx
        |> mes("Who the hell are you?! Nobody, other than Novices, is permitted to come in here!")
        |> close()

      not Rathena.truthy?(can_change_job?(ctx)) ->
        ctx
        |> mes(
          "Stop! I can't let you in until you learn all of the Basic Skills. The Test Hall isn't for goofing off!"
        )
        |> close()

      get_char_var(ctx, :job_sword_q, 0) == 4 ->
        ctx
        |> mes("Hey. You need to talk to the Swordman in the center of the room, not me.")
        |> close()

      get_char_var(ctx, :job_sword_q, 0) == 0 ->
        ctx
        |> mes(
          "Stop! If you want to take the Swordman Test, you'll need to fill out an application first."
        )
        |> next()
        |> mes("[Swordman]")
        |> mes("The Swordman in the center of the room can help you with that, got it?")
        |> close()

      true ->
        ctx |> savepoint("izlude_in", 65, 165) |> warp("izlude_in", 39, 170)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
