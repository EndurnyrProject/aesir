defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Swordman.TestHallStaff do
  @moduledoc """
  Admits eligible applicants to the swordman test.

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
        x: 30,
        y: 163,
        dir: 0,
        sprite: 105,
        name: "Test Hall Staff",
        scope: :pre_renewal,
        unique_name: "Test Hall Staff#swd_1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Test Hall Staff]")

    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:swordman) ->
        ctx
        |> mes(
          "Hm? How did you get inside? You're not supposed to be in here, so please leave now."
        )
        |> close()
        |> warp("izlude_in", 66, 170)

      Rathena.job_id(base_job(ctx)) != Rathena.job_id(:novice) ->
        ctx
        |> mes(
          "Who are you?! This place is for the Swordman Test! You're not allowed to be in here! Leave now!"
        )
        |> close()
        |> warp("izlude_in", 66, 170)

      true ->
        ctx |> prepare_applicant() |> close() |> warp("job_sword1", 10, 245)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp prepare_applicant(ctx) do
    case get_char_var(ctx, :job_sword_q, 0) do
      1 ->
        ctx
        |> mes("So are you the one who wants to be a Swordman? Alright! You look reliable!")
        |> next()
        |> mes("[Test Hall Staff]")
        |> mes("Try to relax and do your best. This course isn't so difficult.")
        |> set_char_var(:job_sword_q, 2)

      2 ->
        ctx
        |> mes(
          "Retesting? Try not to worry about it. It's good that you don't back down from a challenge! Here, take these and cheer up!"
        )
        |> give_item(512, 5)
        |> set_char_var(:job_sword_q, 3)

      3 ->
        mes(ctx, "Don't ever give up! Now retesting!")

      _ ->
        ctx
    end
  end
end
